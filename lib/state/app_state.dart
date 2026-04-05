import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_enums.dart';
import '../models/config_models.dart';
import '../models/snag_model.dart';
import '../models/user_model.dart';
import '../services/config_service.dart';
import '../services/firestore_service.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth ───────────────────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _authLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get authLoading => _authLoading;

  // ── Snags ──────────────────────────────────────────────────────────────────
  StreamSubscription<List<SnagModel>>? _snagsSubscription;
  List<SnagModel> _snags = [];
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
    // If it's a known UID, return the mapped display name
    final resolved = _userProfiles[createdBy];
    if (resolved != null) return resolved;
    // Already a display name (not a UID in our map)
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
    // React to Firebase Auth state changes automatically
    _auth.authStateChanges().listen((user) {
      _authLoading = false;
      if (user != null) {
        _currentUser = UserModel.fromFirebaseUser(user);
        // Upsert display name into Firestore users collection (fire-and-forget)
        _service.saveUserProfile(
          user.uid,
          user.displayName ?? user.email?.split('@').first ?? 'User',
          user.email ?? '',
        );
        _subscribeToSnags();
        _subscribeToConfig();
        _subscribeToUsers();
      } else {
        _currentUser = null;
        _cancelDataSubscriptions();
        _snags = [];
        _trades = [];
        _locations = [];
        _userProfiles = {};
      }
      notifyListeners();
    });
  }

  // ── Sign in with Google ────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
    // authStateChanges() listener above handles the rest automatically
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    // authStateChanges() listener clears user + cancels subscriptions
  }

  // ── Legacy stub (kept so nothing else breaks during migration) ─────────────
  Future<bool> login(String username, String password) async => false;
  void logout() => signOut();

  // ── Firestore subscriptions ────────────────────────────────────────────────

  void _subscribeToSnags() {
    _snagsSubscription?.cancel();
    _snagsSubscription = _service.snagsStream.listen(
      (snagList) {
        _snags = snagList;
        notifyListeners();
      },
      onError: (e) {
        _syncError = 'Failed to load snags: $e';
        notifyListeners();
      },
    );
  }

  void _subscribeToConfig() {
    _tradesSubscription?.cancel();
    _tradesSubscription = _configService.tradesStream.listen(
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
    _locationsSubscription = _configService.locationsStream.listen(
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

  void _cancelDataSubscriptions() {
    _snagsSubscription?.cancel();
    _tradesSubscription?.cancel();
    _locationsSubscription?.cancel();
    _usersSubscription?.cancel();
    _snagsSubscription = null;
    _tradesSubscription = null;
    _locationsSubscription = null;
    _usersSubscription = null;
    _configLoading = true;
  }

  @override
  void dispose() {
    _cancelDataSubscriptions();
    super.dispose();
  }

  // ── Snag CRUD ──────────────────────────────────────────────────────────────

  List<SnagModel> get snags => List.unmodifiable(_snags);

  Future<void> addSnag(SnagModel snag,
      {List<File> mediaFiles = const []}) async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await _service.addSnag(snag, mediaFiles: mediaFiles);
    } catch (e) {
      _syncError = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> updateSnagStatus(String snagId, SnagStatus newStatus) async {
    await _service.updateSnagStatus(snagId, newStatus);
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

  /// Counts open/in-progress snags by severity (excludes closed + void).
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
  /// Matches both new snags (display name) and old snags (UID stored before fix).
  List<SnagModel> getMySnags(String myName) {
    final myUid = _currentUser?.id ?? '';
    return _snags
        .where((s) => s.createdBy == myName || s.createdBy == myUid)
        .toList();
  }

  /// Returns snags logged by other team members.
  /// Excludes current user's snags (both by name and by old UID).
  List<SnagModel> getTeamSnags(String myName) {
    final myUid = _currentUser?.id ?? '';
    return _snags
        .where((s) =>
            s.createdBy != myName &&
            s.createdBy != myUid &&
            s.createdBy.isNotEmpty)
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
