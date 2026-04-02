import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../models/user_model.dart';
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
  StreamSubscription<List<SnagModel>>? _snagsSubscription;

  UserModel? _currentUser;
  List<SnagModel> _snags = [];

  // Tracks async operations on the snag list (upload + Firestore write)
  bool _isSyncing = false;
  String? _syncError;

  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  AppState() {
    _subscribeToSnags();
  }

  // ─── Firestore stream ──────────────────────────────────────────────────────

  void _subscribeToSnags() {
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

  @override
  void dispose() {
    _snagsSubscription?.cancel();
    super.dispose();
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Simple credential check — will be replaced with Firebase Auth later.
  Future<bool> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (username.isNotEmpty && password.isNotEmpty) {
      _currentUser = UserModel(
        id: 'user_001',
        username: username,
        email: '$username@ppqa.com',
        role: 'auditor',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ─── Snags ─────────────────────────────────────────────────────────────────
  List<SnagModel> get snags => List.unmodifiable(_snags);

  /// Writes the snag to Firestore. If [imageFile] is provided it is uploaded
  /// to Firebase Storage first. The stream listener updates [_snags] automatically
  /// once Firestore confirms the write — no manual list manipulation needed.
  Future<void> addSnag(SnagModel snag, {File? imageFile}) async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await _service.addSnag(snag, imageFile: imageFile);
    } catch (e) {
      _syncError = e.toString();
      rethrow; // Let the screen handle it with a SnackBar
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Updates only the status field in Firestore.
  Future<void> updateSnagStatus(String snagId, SnagStatus newStatus) async {
    await _service.updateSnagStatus(snagId, newStatus);
    // Stream update is automatic — no local mutation needed
  }

  // ─── Computed Stats ────────────────────────────────────────────────────────
  int get totalSnags => _snags.length;

  int get openSnags =>
      _snags.where((s) => s.status == SnagStatus.open).length;

  int get inProgressSnags =>
      _snags.where((s) => s.status == SnagStatus.inProgress).length;

  int get closedSnags =>
      _snags.where((s) => s.status == SnagStatus.closed).length;

  int get redLineOpen => _snags
      .where((s) =>
          s.severity == SnagSeverity.redLine && s.status != SnagStatus.closed)
      .length;

  int get majorOpen => _snags
      .where((s) =>
          s.severity == SnagSeverity.major && s.status != SnagStatus.closed)
      .length;

  int get minorOpen => _snags
      .where((s) =>
          s.severity == SnagSeverity.minor && s.status != SnagStatus.closed)
      .length;

  double get percentClosed =>
      totalSnags == 0 ? 0 : (closedSnags / totalSnags) * 100;

  // ─── Filtered Views ────────────────────────────────────────────────────────
  List<SnagModel> getSnagsBySeverity(SnagSeverity severity) =>
      _snags.where((s) => s.severity == severity).toList();

  List<SnagModel> getSnagsByTrade(SnagTrade trade) =>
      _snags.where((s) => s.trade == trade).toList();

  List<SnagModel> getSnagsByLocation(SnagLocation location) =>
      _snags.where((s) => s.location == location).toList();

  List<SnagModel> getSnagsByUnit(FlatNo unit) =>
      _snags.where((s) => s.flatNo == unit).toList();

  List<SnagModel> getMySnags(String userId) =>
      _snags.where((s) => s.createdBy == userId).toList();

  List<SnagModel> filterSnags({
    DefectsListTrade? trade,
    SnagTrade? category,
  }) {
    return _snags.where((s) {
      if (category != null && s.trade != category) return false;
      return true;
    }).toList();
  }

  // ─── Weekly Grouping ───────────────────────────────────────────────────────
  List<WeeklySnagData> getSnagsByWeek() {
    if (_snags.isEmpty) return [];

    final Map<DateTime, List<SnagModel>> grouped = {};
    for (final snag in _snags) {
      final weekStart = snag.weekStart;
      grouped.putIfAbsent(weekStart, () => []).add(snag);
    }

    final weeks = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return weeks.map((entry) {
      final list = entry.value;
      return WeeklySnagData(
        weekStart: entry.key,
        total: list.length,
        open: list.where((s) => s.status == SnagStatus.open).length,
        inProgress: list.where((s) => s.status == SnagStatus.inProgress).length,
        closed: list.where((s) => s.status == SnagStatus.closed).length,
        redLineOpen: list
            .where((s) =>
                s.severity == SnagSeverity.redLine &&
                s.status != SnagStatus.closed)
            .length,
        majorOpen: list
            .where((s) =>
                s.severity == SnagSeverity.major &&
                s.status != SnagStatus.closed)
            .length,
        minorOpen: list
            .where((s) =>
                s.severity == SnagSeverity.minor &&
                s.status != SnagStatus.closed)
            .length,
      );
    }).toList();
  }

  // ─── Trade / Location / Unit counts for reports ───────────────────────────
  Map<SnagTrade, int> get snagCountByTrade {
    final map = <SnagTrade, int>{};
    for (final snag in _snags) {
      map[snag.trade] = (map[snag.trade] ?? 0) + 1;
    }
    return map;
  }

  Map<SnagLocation, int> get snagCountByLocation {
    final map = <SnagLocation, int>{};
    for (final snag in _snags) {
      map[snag.location] = (map[snag.location] ?? 0) + 1;
    }
    return map;
  }

  Map<FlatNo, int> get snagCountByUnit {
    final map = <FlatNo, int>{};
    for (final snag in _snags) {
      map[snag.flatNo] = (map[snag.flatNo] ?? 0) + 1;
    }
    return map;
  }
}
