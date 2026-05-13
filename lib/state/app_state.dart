import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_enums.dart';
import '../models/config_models.dart';
import '../models/project_model.dart';
import '../models/snag_model.dart';
import '../models/user_model.dart';
import '../services/config_service.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';
import '../services/offline_queue_service.dart';
import '../services/project_service.dart';

class WeeklySnagData {
  final DateTime weekStart;
  final int total;
  final int open;
  final int inProgress;
  final int closed;
  final int redLineOpen;
  final int majorOpen;
  final int minorOpen;

  const WeeklySnagData({
    required this.weekStart,
    required this.total,
    required this.open,
    required this.inProgress,
    required this.closed,
    required this.redLineOpen,
    required this.majorOpen,
    required this.minorOpen,
  });

  double get percentClosed => total == 0 ? 0 : (closed / total) * 100;
}

class AppState extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  final ConfigService _configService = ConfigService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _offlineQueueService = OfflineQueueService();
  final ProjectService _projectService = ProjectService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Connectivity + offline queue ───────────────────────────────────────────
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;
  int _pendingUploadCount = 0;
  bool _isSyncingPending = false;

  bool get isOnline => _isOnline;
  int get pendingUploadCount => _pendingUploadCount;
  bool get isSyncingPending => _isSyncingPending;

  // ── Auth ───────────────────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _authLoading = true;
  bool _roleLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get authLoading => _authLoading;
  bool get roleLoading => _roleLoading;

  // ── Role / permission convenience getters ─────────────────────────────────
  bool get isBlocked => _currentUser?.isBlocked ?? false;
  bool get canLogSnags => _currentUser?.canLogSnags ?? false;
  bool get canChangeAnyStatus => _currentUser?.canChangeAnyStatus ?? false;
  bool get canChangeOwnStatus => _currentUser?.canChangeOwnStatus ?? false;
  bool get isViewOnly => _currentUser?.isViewOnly ?? true;

  /// True when the user is a global admin (web portal + migration screen access).
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // ── Projects ───────────────────────────────────────────────────────────────
  StreamSubscription<List<ProjectModel>>? _projectsSubscription;
  List<ProjectModel> _availableProjects = [];
  String? _activeProjectId;
  bool _projectsLoading = true;

  List<ProjectModel> get availableProjects =>
      List.unmodifiable(_availableProjects);
  String? get activeProjectId => _activeProjectId;
  bool get projectsLoading => _projectsLoading;

  /// True when a project has been selected and data streams are live.
  bool get hasActiveProject => _activeProjectId != null;

  /// The currently active [ProjectModel], or null if none selected yet.
  ProjectModel? get activeProject => _availableProjects
      .where((p) => p.id == _activeProjectId)
      .firstOrNull;

  /// Switches to the given project: re-subscribes all data streams.
  void setActiveProject(String projectId) {
    if (_activeProjectId == projectId) return;
    _activeProjectId = projectId;
    _cancelDataSubscriptions(keepProjects: true);
    _snags = [];
    _snagSerialMapCache = null;
    _trades = [];
    _locations = [];
    _configLoading = true;
    notifyListeners();
    _subscribeToSnags();
    _subscribeToConfig();
  }

  // ── Snags ──────────────────────────────────────────────────────────────────
  StreamSubscription<List<SnagModel>>? _snagsSubscription;
  List<SnagModel> _snags = [];
  /// Cached serial map — rebuilt only when [_snags] changes, not on every read.
  Map<String, int>? _snagSerialMapCache;
  bool _isSyncing = false;
  String? _syncError;

  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  // ── User profiles (uid → displayName) ─────────────────────────────────────
  StreamSubscription<Map<String, String>>? _usersSubscription;
  Map<String, String> _userProfiles = {};

  /// Resolves a [createdBy] value to a human-readable display name.
  /// Handles both old snags (stored UID) and new snags (stored display name).
  String resolveInspector(String createdBy) {
    if (createdBy.isEmpty) return 'Unknown';
    final resolved = _userProfiles[createdBy];
    if (resolved != null) return resolved;
    return createdBy;
  }

  // ── Config ─────────────────────────────────────────────────────────────────
  StreamSubscription<List<TradeItem>>? _tradesSubscription;
  StreamSubscription<List<LocationItem>>? _locationsSubscription;
  List<TradeItem> _trades = [];
  List<LocationItem> _locations = [];
  bool _configLoading = true;

  bool get configLoading => _configLoading;
  List<TradeItem> get trades => List.unmodifiable(_trades);
  List<LocationItem> get locations => List.unmodifiable(_locations);

  AppState() {
    _initConnectivity();
    // React to Firebase Auth state changes automatically
    _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _authLoading = false;
        _roleLoading = false;
        _currentUser = null;
        _activeProjectId = null;
        _availableProjects = [];
        _projectsLoading = true;
        _cancelDataSubscriptions();
        _snags = [];
        _snagSerialMapCache = null;
        _trades = [];
        _locations = [];
        _userProfiles = {};
        notifyListeners();
        return;
      }

      // User is signed in — onboard them and load their profile.
      _authLoading = false;
      _roleLoading = true;
      notifyListeners();

      // Step 1: Upsert display profile. This creates users/{uid} so that
      // Firestore security rules can evaluate the profile in later calls.
      await _service.saveUserProfile(
        user.uid,
        user.displayName ?? user.email?.split('@').first ?? 'User',
        user.email ?? '',
      );

      // Step 2: Claim any pending invitation (sets role + project membership).
      // Silently ignored when there is no invitation or it is already claimed.
      // A failure here must never block the sign-in flow.
      if (user.email != null) {
        try {
          await _service.applyPendingInvitation(user.uid, user.email!);
        } catch (e) {
          // Non-fatal — user can still sign in; admin can assign roles manually.
          debugPrint('[AppState] applyPendingInvitation skipped: $e');
        }
      }

      // Step 3: Fetch fresh profile (role may have just been applied above).
      final profileData = await _service.getUserProfileData(user.uid);
      _currentUser = UserModel.fromFirebaseUser(user, profileData: profileData);
      _roleLoading = false;

      if (_currentUser!.isBlocked) {
        // Blocked: keep user object (so UI shows blocked screen) but don't
        // subscribe to any data streams — they should see nothing.
        notifyListeners();
        return;
      }

      _subscribeToProjects(user.uid);
      _subscribeToUsers();
      notifyListeners();
    });
  }

  // ── Sign in with Google ────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    _isOnline = await _connectivityService.isOnline;
    _pendingUploadCount = await _offlineQueueService.pendingCount;
    notifyListeners();

    _connectivitySubscription =
        _connectivityService.onStatusChanged.listen((online) async {
      final wasOffline = !_isOnline;
      _isOnline = online;
      notifyListeners();

      if (online && wasOffline && _pendingUploadCount > 0) {
        await _processPendingUploads();
      }
    });
  }

  Future<void> _processPendingUploads() async {
    if (_isSyncingPending) return;
    _isSyncingPending = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 3));
      await _offlineQueueService.processPendingUploads(_service);
    } catch (_) {
      // Non-fatal — will retry on next reconnect
    } finally {
      _isSyncingPending = false;
      _pendingUploadCount = await _offlineQueueService.pendingCount;
      notifyListeners();
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Legacy stub (kept so nothing else breaks during migration) ─────────────
  Future<bool> login(String username, String password) async => false;
  void logout() => signOut();

  // ── Project subscription ───────────────────────────────────────────────────

  void _subscribeToProjects(String uid) {
    _projectsSubscription?.cancel();
    _projectsLoading = true;

    _projectsSubscription =
        _projectService.userProjectsStream(uid).listen((projects) {
      _availableProjects = projects;
      _projectsLoading = false;

      // Auto-select the only project — no selector screen needed
      if (projects.length == 1 && _activeProjectId != projects.first.id) {
        _activeProjectId = projects.first.id;
        _subscribeToSnags();
        _subscribeToConfig();
      }

      // If the active project was removed from the list, clear it
      if (_activeProjectId != null &&
          !projects.any((p) => p.id == _activeProjectId)) {
        _activeProjectId = null;
        _cancelDataSubscriptions(keepProjects: true);
        _snags = [];
        _snagSerialMapCache = null;
        _trades = [];
        _locations = [];
      }

      notifyListeners();
    }, onError: (_) {
      _projectsLoading = false;
      notifyListeners();
    });
  }

  // ── Firestore subscriptions ────────────────────────────────────────────────

  void _subscribeToSnags() {
    final pid = _activeProjectId;
    if (pid == null) return;

    _snagsSubscription?.cancel();
    _snagsSubscription = _service.snagsStream(pid).listen(
      (snagList) {
        _snags = snagList;
        _snagSerialMapCache = null;
        notifyListeners();
      },
      onError: (e) {
        _syncError = 'Failed to load snags: $e';
        notifyListeners();
      },
    );
  }

  void _subscribeToConfig() {
    final pid = _activeProjectId;
    if (pid == null) return;

    _tradesSubscription?.cancel();
    _tradesSubscription = _configService.tradesStream(pid).listen(
      (trades) {
        _trades = trades;
        _configLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _configLoading = false;
        notifyListeners();
      },
    );

    _locationsSubscription?.cancel();
    _locationsSubscription = _configService.locationsStream(pid).listen(
      (locations) {
        _locations = locations;
        notifyListeners();
      },
    );
  }

  void _subscribeToUsers() {
    _usersSubscription?.cancel();
    _usersSubscription = _service.usersStream.listen((profiles) {
      _userProfiles = profiles;
      notifyListeners();
    });
  }

  /// Cancels snag / config / users subscriptions.
  /// Pass [keepProjects] = true when switching projects (don't re-fetch project list).
  void _cancelDataSubscriptions({bool keepProjects = false}) {
    _snagsSubscription?.cancel();
    _tradesSubscription?.cancel();
    _locationsSubscription?.cancel();
    _usersSubscription?.cancel();
    _snagsSubscription = null;
    _tradesSubscription = null;
    _locationsSubscription = null;
    _usersSubscription = null;
    _configLoading = true;

    if (!keepProjects) {
      _projectsSubscription?.cancel();
      _projectsSubscription = null;
    }
  }

  @override
  void dispose() {
    _cancelDataSubscriptions();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ── Snag CRUD ──────────────────────────────────────────────────────────────

  List<SnagModel> get snags => List.unmodifiable(_snags);

  /// Saves a snag and its media files.
  ///
  /// Returns `true` if photos were queued for later upload (offline / timeout),
  /// `false` if all photos uploaded immediately (or there were none).
  ///
  /// Strategy — save first, upload second:
  ///   1. The snag text data is ALWAYS written to Firestore instantly via
  ///      offline persistence (< 100 ms regardless of network state).
  ///   2. Photo upload is then attempted with a hard 25-second timeout.
  ///   3. If the upload times out, fails, or there is no internet, ALL photos
  ///      are queued to the local offline queue and uploaded automatically
  ///      when connectivity is restored.
  ///
  /// This eliminates the previous behaviour where a stalled upload could
  /// block the entire submission for 30+ seconds on a poor connection.
  Future<bool> addSnag(SnagModel snag,
      {List<File> mediaFiles = const []}) async {
    final pid = _activeProjectId;
    if (pid == null) throw StateError('No active project selected');

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    bool mediaQueued = false;
    bool hasInternet = false;
    final stopwatch = Stopwatch()..start();

    try {
      // ── Step 1: Check internet BEFORE touching Firestore ────────────────
      // This MUST come first. If we call docRef.set() while Firestore still
      // thinks it's online, it waits for a server ACK and hangs for 10–30 s.
      // The check itself is hard-capped at 4 s by isReallyOnline().
      hasInternet = await _connectivityService.isReallyOnline();
      debugPrint(
          'addSnag: internet check = $hasInternet (${stopwatch.elapsedMilliseconds} ms)');

      if (!hasInternet) {
        // Tell Firestore to stop all network traffic immediately so the
        // upcoming write commits to the local cache instantly. Hard-capped
        // at 2 s by goOffline() — if it hangs we continue regardless.
        await _service.goOffline();
        debugPrint(
            'addSnag: goOffline done (${stopwatch.elapsedMilliseconds} ms)');
      }

      // ── Step 2: Save snag text data to Firestore ───────────────────────
      // Online  → server write (fast on good connection).
      // Offline → local cache write (instant once goOffline() has run).
      // Internal 3-second timeout in addSnagOffline guarantees we never
      // wait more than 3 s here even on a flaky SDK state.
      final snagId = await _service.addSnagOffline(snag, pid);
      debugPrint(
          'addSnag: snag $snagId saved (${stopwatch.elapsedMilliseconds} ms)');

      // ── Step 3: Handle media files ──────────────────────────────────────
      if (mediaFiles.isNotEmpty) {
        if (hasInternet) {
          // Try to upload all files. Each has a 20 s individual timeout;
          // the whole batch is capped at 25 s.
          final results = await _service
              .uploadAllMedia(mediaFiles, snagId, pid)
              .timeout(const Duration(seconds: 25),
                  onTimeout: () => List.filled(mediaFiles.length, null));

          final urls = results.whereType<String>().toList();

          if (urls.length == mediaFiles.length) {
            await _service.appendMediaUrls(snagId, pid, urls);
          } else {
            // Partial or total failure — queue ALL for retry.
            await _offlineQueueService.enqueue(snagId, pid, mediaFiles);
            _pendingUploadCount = await _offlineQueueService.pendingCount;
            mediaQueued = true;
          }
        } else {
          // No internet — queue immediately, upload when back online.
          await _offlineQueueService.enqueue(snagId, pid, mediaFiles);
          _pendingUploadCount = await _offlineQueueService.pendingCount;
          mediaQueued = true;
          debugPrint(
              'addSnag: media queued (${stopwatch.elapsedMilliseconds} ms)');
        }
      }

      debugPrint('addSnag: DONE in ${stopwatch.elapsedMilliseconds} ms');
      return mediaQueued;
    } catch (e) {
      _syncError = e.toString();
      debugPrint('addSnag: error after ${stopwatch.elapsedMilliseconds} ms: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (!hasInternet) {
        // Re-enable Firestore networking in the background so all queued
        // local writes sync to the server once connectivity is restored.
        unawaited(_service.goOnline());
      }
    }
  }

  Future<void> updateSnagStatus(
    String snagId,
    SnagStatus newStatus, {
    String? closeNote,
    List<File> closeMediaFiles = const [],
  }) async {
    final pid = _activeProjectId;
    if (pid == null) return;
    await _service.updateSnagStatus(
      snagId,
      pid,
      newStatus,
      closeNote: closeNote,
      closeMediaFiles: closeMediaFiles,
    );
  }

  // ── Serial number map ──────────────────────────────────────────────────────
  /// Stable { snagId → serialNumber } map. Oldest snag = #1, next = #2, etc.
  /// Result is cached and only rebuilt when [_snags] changes — never on every
  /// widget build, so the O(n log n) sort runs at most once per Firestore update.
  Map<String, int> get snagSerialMap =>
      _snagSerialMapCache ??= _buildSnagSerialMap();

  Map<String, int> _buildSnagSerialMap() {
    final sorted = [..._snags]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final map = <String, int>{};
    for (var i = 0; i < sorted.length; i++) {
      map[sorted[i].id] = i + 1;
    }
    return map;
  }

  // ── Computed Stats ─────────────────────────────────────────────────────────

  int get totalSnags => _snags.length;
  int get openSnags => _snags.where((s) => s.status == SnagStatus.open).length;
  int get inProgressSnags =>
      _snags.where((s) => s.status == SnagStatus.inProgress).length;
  int get closedSnags =>
      _snags.where((s) => s.status == SnagStatus.closed).length;
  int get voidSnags =>
      _snags.where((s) => s.status == SnagStatus.void_).length;

  bool _isActive(SnagModel s) =>
      s.status != SnagStatus.closed && s.status != SnagStatus.void_;

  int get redLineOpen => _snags
      .where((s) => s.severity == SnagSeverity.redLine && _isActive(s))
      .length;

  int get majorOpen => _snags
      .where((s) => s.severity == SnagSeverity.major && _isActive(s))
      .length;

  int get minorOpen => _snags
      .where((s) => s.severity == SnagSeverity.minor && _isActive(s))
      .length;

  double get percentClosed =>
      totalSnags == 0 ? 0 : (closedSnags / totalSnags) * 100;

  // ── Filtered Views ─────────────────────────────────────────────────────────

  List<SnagModel> getSnagsBySeverity(SnagSeverity severity) =>
      _snags.where((s) => s.severity == severity).toList();

  List<SnagModel> getSnagsByTrade(String trade) =>
      _snags.where((s) => s.trade == trade).toList();

  List<SnagModel> getSnagsByLocation(String location) =>
      _snags.where((s) => s.location == location).toList();

  List<SnagModel> getSnagsByUnit(String unit) =>
      _snags.where((s) => s.flatNo == unit).toList();

  /// Returns snags logged by the current user.
  ///
  /// Primary match is by Firebase UID (the correct, canonical value stored
  /// since this bug was fixed). A secondary fallback matches by display name
  /// to surface legacy snags that were accidentally stored with a display name
  /// instead of a UID before the fix was applied.
  List<SnagModel> getMySnags() {
    final myUid  = _currentUser?.id       ?? '';
    final myName = _currentUser?.username ?? '';
    if (myUid.isEmpty) return [];
    return _snags
        .where((s) =>
            s.createdBy == myUid ||
            (myName.isNotEmpty && s.createdBy == myName))
        .toList();
  }

  /// Returns snags logged by other team members (everyone except current user).
  List<SnagModel> getTeamSnags() {
    final myUid = _currentUser?.id ?? '';
    return _snags
        .where((s) => s.createdBy != myUid && s.createdBy.isNotEmpty)
        .toList();
  }

  // ── Weekly Grouping ────────────────────────────────────────────────────────

  List<WeeklySnagData> getSnagsByWeek() {
    if (_snags.isEmpty) return [];

    final Map<DateTime, List<SnagModel>> grouped = {};
    for (final snag in _snags) {
      grouped.putIfAbsent(snag.weekStart, () => []).add(snag);
    }

    final weeks = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return weeks.map((entry) {
      final list = entry.value;
      return WeeklySnagData(
        weekStart: entry.key,
        total: list.length,
        open: list.where((s) => s.status == SnagStatus.open).length,
        inProgress:
            list.where((s) => s.status == SnagStatus.inProgress).length,
        closed: list.where((s) => s.status == SnagStatus.closed).length,
        redLineOpen: list
            .where((s) =>
                s.severity == SnagSeverity.redLine && _isActive(s))
            .length,
        majorOpen: list
            .where((s) =>
                s.severity == SnagSeverity.major && _isActive(s))
            .length,
        minorOpen: list
            .where((s) =>
                s.severity == SnagSeverity.minor && _isActive(s))
            .length,
      );
    }).toList();
  }

  // ── Count maps for Reports ─────────────────────────────────────────────────

  Map<String, int> get snagCountByTrade {
    final map = <String, int>{};
    for (final snag in _snags) {
      map[snag.trade] = (map[snag.trade] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get snagCountByLocation {
    final map = <String, int>{};
    for (final snag in _snags) {
      map[snag.location] = (map[snag.location] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get snagCountByUnit {
    final map = <String, int>{};
    for (final snag in _snags) {
      map[snag.flatNo] = (map[snag.flatNo] ?? 0) + 1;
    }
    return map;
  }
}
