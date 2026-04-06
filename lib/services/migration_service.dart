import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_enums.dart';
import 'project_service.dart';

// ── Progress model ─────────────────────────────────────────────────────────────

enum MigrationStepStatus { pending, running, done, error }

class MigrationStep {
  final String title;
  final String detail;
  final MigrationStepStatus status;
  final int? done;
  final int? total;

  const MigrationStep({
    required this.title,
    required this.detail,
    required this.status,
    this.done,
    this.total,
  });

  factory MigrationStep.pending(String title) => MigrationStep(
      title: title, detail: '', status: MigrationStepStatus.pending);

  factory MigrationStep.running(String title, String detail,
          {int? done, int? total}) =>
      MigrationStep(
          title: title,
          detail: detail,
          status: MigrationStepStatus.running,
          done: done,
          total: total);

  factory MigrationStep.done(String title, String detail) =>
      MigrationStep(title: title, detail: detail, status: MigrationStepStatus.done);

  factory MigrationStep.error(String title, String detail) =>
      MigrationStep(
          title: title, detail: detail, status: MigrationStepStatus.error);

  bool get isRunning => status == MigrationStepStatus.running;
  bool get isDone    => status == MigrationStepStatus.done;
  bool get isError   => status == MigrationStepStatus.error;
}

// ── Migration service ──────────────────────────────────────────────────────────

/// Migrates all v1 top-level Firestore data into the `projects/{id}/...`
/// sub-collection structure required by v2.
///
/// Safe to run multiple times — checks if the default project already exists
/// and skips documents that have already been copied (idempotent).
///
/// Original top-level collections are LEFT INTACT so the v1 app continues
/// working during the transition period.
class MigrationService {
  final _db = FirebaseFirestore.instance;
  final _projectService = ProjectService();

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Returns true if the Default Project does not exist yet.
  Future<bool> get isMigrationNeeded async {
    final snap = await _db
        .collection('projects')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  /// Runs the full migration and yields live progress steps.
  ///
  /// Yields [MigrationStep] events so the UI can show a real-time log.
  /// The final event always has title == 'Migration Complete' or title
  /// starts with an error message.
  Stream<MigrationStep> migrate(String adminUid) async* {
    String projectId = '';

    // ── 1. Create / locate default project ─────────────────────────────────
    yield MigrationStep.running(
        'Create Default Project', 'Setting up project container…');
    try {
      projectId = await _projectService.ensureDefaultProject(adminUid);
      yield MigrationStep.done(
          'Create Default Project', 'Project ID: $projectId');
    } catch (e) {
      yield MigrationStep.error('Create Default Project', e.toString());
      return;
    }

    // ── 2. Add all existing users as members ────────────────────────────────
    yield MigrationStep.running(
        'Add Existing Users as Members', 'Reading users collection…');
    try {
      final count = await _migrateMembers(projectId, adminUid);
      yield MigrationStep.done('Add Existing Users as Members',
          '$count user${count == 1 ? '' : 's'} added to Default Project');
    } catch (e) {
      yield MigrationStep.error('Add Existing Users as Members', e.toString());
      return;
    }

    // ── 3. Migrate locations ────────────────────────────────────────────────
    yield MigrationStep.running('Migrate Locations', 'Reading locations…');
    try {
      final count = await _migrateLocations(projectId);
      yield MigrationStep.done(
          'Migrate Locations', '$count location${count == 1 ? '' : 's'} copied');
    } catch (e) {
      yield MigrationStep.error('Migrate Locations', e.toString());
      return;
    }

    // ── 4. Migrate trades tree ──────────────────────────────────────────────
    yield MigrationStep.running(
        'Migrate Trades Library', 'Reading trades + elements + defects…');
    try {
      final count = await _migrateTrades(projectId);
      yield MigrationStep.done('Migrate Trades Library',
          '$count trade${count == 1 ? '' : 's'} (with all elements + defects) copied');
    } catch (e) {
      yield MigrationStep.error('Migrate Trades Library', e.toString());
      return;
    }

    // ── 5. Migrate snags ────────────────────────────────────────────────────
    final snagSnap = await _db.collection('snags').get();
    final totalSnags = snagSnap.docs.length;

    yield MigrationStep.running('Migrate Snags',
        'Found $totalSnags snag${totalSnags == 1 ? '' : 's'} to copy…',
        done: 0, total: totalSnags);

    try {
      int migrated = 0;
      final destSnags = _db
          .collection('projects')
          .doc(projectId)
          .collection('snags');

      for (final doc in snagSnap.docs) {
        final dest = destSnags.doc(doc.id);
        final existing = await dest.get();
        if (!existing.exists) {
          await dest.set(doc.data());
        }
        migrated++;
        yield MigrationStep.running('Migrate Snags',
            'Copied $migrated of $totalSnags…',
            done: migrated, total: totalSnags);
      }
      yield MigrationStep.done('Migrate Snags',
          '$migrated snag${migrated == 1 ? '' : 's'} copied');
    } catch (e) {
      yield MigrationStep.error('Migrate Snags', e.toString());
      return;
    }

    // ── Done ────────────────────────────────────────────────────────────────
    yield MigrationStep.done(
      'Migration Complete',
      'All data is now in the Default Project.\n'
          'Original v1 collections are untouched — the v1 app still works.',
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<int> _migrateMembers(String projectId, String adminUid) async {
    final usersSnap = await _db.collection('users').get();
    int count = 0;

    for (final doc in usersSnap.docs) {
      final uid  = doc.id;
      final data = doc.data();

      // Skip blocked users — they should not be project members
      if ((data['status'] as String?) == 'blocked') continue;

      // Check if already a member (idempotency)
      final memberDoc = await _db
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(uid)
          .get();
      if (memberDoc.exists) continue;

      // Map v1 role → ProjectMemberRole
      final role = _mapRole(data['role'] as String?);
      await _projectService.addMember(projectId, uid, role);
      count++;
    }
    return count;
  }

  Future<int> _migrateLocations(String projectId) async {
    final snap = await _db.collection('locations').get();
    final destCol = _db
        .collection('projects')
        .doc(projectId)
        .collection('locations');
    int count = 0;

    for (final doc in snap.docs) {
      final dest = destCol.doc(doc.id);
      if (!(await dest.get()).exists) {
        await dest.set(doc.data());
      }
      count++;
    }
    return count;
  }

  Future<int> _migrateTrades(String projectId) async {
    final tradesSnap = await _db.collection('trades').get();
    final destTrades = _db
        .collection('projects')
        .doc(projectId)
        .collection('trades');
    int count = 0;

    for (final tradeDoc in tradesSnap.docs) {
      final destTrade = destTrades.doc(tradeDoc.id);
      if (!(await destTrade.get()).exists) {
        await destTrade.set(tradeDoc.data());
      }

      // Elements sub-collection
      final elemSnap = await _db
          .collection('trades')
          .doc(tradeDoc.id)
          .collection('elements')
          .get();

      for (final elemDoc in elemSnap.docs) {
        final destElem = destTrade.collection('elements').doc(elemDoc.id);
        if (!(await destElem.get()).exists) {
          await destElem.set(elemDoc.data());
        }

        // Defects sub-collection
        final defSnap = await _db
            .collection('trades')
            .doc(tradeDoc.id)
            .collection('elements')
            .doc(elemDoc.id)
            .collection('defects')
            .get();

        for (final defDoc in defSnap.docs) {
          final destDef = destElem.collection('defects').doc(defDoc.id);
          if (!(await destDef.get()).exists) {
            await destDef.set(defDoc.data());
          }
        }
      }
      count++;
    }
    return count;
  }

  /// Maps a v1 role string → the correct [ProjectMemberRole] for v2.
  ProjectMemberRole _mapRole(String? v1Role) {
    switch (v1Role) {
      case 'supervisor':     return ProjectMemberRole.supervisor;
      case 'viewer':         return ProjectMemberRole.viewer;
      case 'projectManager': return ProjectMemberRole.projectManager;
      default:               return ProjectMemberRole.inspector;
      // 'auditor' (old hardcoded v1 role) and 'inspector' both → inspector
    }
  }
}
