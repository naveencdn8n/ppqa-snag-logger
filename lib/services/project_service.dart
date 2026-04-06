import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_enums.dart';
import '../models/project_model.dart';

/// Handles all Firestore reads and writes for the `projects` collection
/// and its `members` sub-collection.
///
/// Snag / location / trade reads live in [FirestoreService] and
/// [ConfigService] — they will be updated in Step 3 to accept a projectId.
class ProjectService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  // ── Project streams ──────────────────────────────────────────────────────────

  /// All projects — for super-admin / portfolio view.
  Stream<List<ProjectModel>> get allProjectsStream {
    return _projects
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectModel.fromFirestore).toList());
  }

  /// Projects where [uid] is a member — for the mobile project selector.
  Stream<List<ProjectModel>> userProjectsStream(String uid) {
    // Firestore doesn't support collection-group queries with sub-collection
    // filters in a single call, so we store a denormalised `memberUids` array
    // on the project document for efficient querying.
    return _projects
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectModel.fromFirestore).toList());
  }

  /// Single project by ID — useful for detail screens.
  Stream<ProjectModel?> projectStream(String projectId) {
    return _projects.doc(projectId).snapshots().map((doc) =>
        doc.exists ? ProjectModel.fromFirestore(doc) : null);
  }

  // ── Project CRUD ─────────────────────────────────────────────────────────────

  /// Creates a new project and adds [creatorUid] as the first Project Manager.
  /// Returns the new document ID.
  Future<String> createProject(ProjectModel project, String creatorUid) async {
    final docRef = _projects.doc(); // auto-ID

    final data = {
      ...project.toMap(),
      'id': docRef.id,
      // Denormalised member list for `userProjectsStream` query
      'memberUids': [creatorUid],
    };

    final batch = _db.batch();

    // Write project document
    batch.set(docRef, data);

    // Add creator as Project Manager in members sub-collection
    batch.set(
      docRef.collection('members').doc(creatorUid),
      ProjectMember(
        uid: creatorUid,
        role: ProjectMemberRole.projectManager,
        joinedAt: DateTime.now(),
      ).toMap(),
    );

    await batch.commit();
    return docRef.id;
  }

  /// Partially updates a project document (name, status, dates, etc.).
  Future<void> updateProject(
      String projectId, Map<String, dynamic> data) async {
    await _projects.doc(projectId).update(data);
  }

  /// Archives a project — sets status to archived.
  /// Does not delete any data.
  Future<void> archiveProject(String projectId) async {
    await _projects.doc(projectId).update({
      'status': ProjectStatus.archived.firestoreValue,
    });
  }

  // ── Member management ────────────────────────────────────────────────────────

  /// Real-time stream of all members in a project.
  /// Returns a map of uid → [ProjectMember].
  Stream<Map<String, ProjectMember>> membersStream(String projectId) {
    return _projects
        .doc(projectId)
        .collection('members')
        .snapshots()
        .map((snap) {
      return {
        for (final doc in snap.docs)
          doc.id: ProjectMember.fromFirestore(doc),
      };
    });
  }

  /// Adds a user to a project with the given role.
  /// Also appends uid to the denormalised `memberUids` array.
  Future<void> addMember(
      String projectId, String uid, ProjectMemberRole role) async {
    final batch = _db.batch();
    final projectRef = _projects.doc(projectId);

    // Write member sub-document
    batch.set(
      projectRef.collection('members').doc(uid),
      ProjectMember(uid: uid, role: role, joinedAt: DateTime.now()).toMap(),
    );

    // Append to denormalised array
    batch.update(projectRef, {
      'memberUids': FieldValue.arrayUnion([uid]),
    });

    await batch.commit();
  }

  /// Removes a user from a project.
  Future<void> removeMember(String projectId, String uid) async {
    final batch = _db.batch();
    final projectRef = _projects.doc(projectId);

    batch.delete(projectRef.collection('members').doc(uid));
    batch.update(projectRef, {
      'memberUids': FieldValue.arrayRemove([uid]),
    });

    await batch.commit();
  }

  /// Changes a member's role within a project.
  Future<void> updateMemberRole(
      String projectId, String uid, ProjectMemberRole newRole) async {
    await _projects
        .doc(projectId)
        .collection('members')
        .doc(uid)
        .update({'role': newRole.firestoreValue});
  }

  /// Fetches a single member's role — used to verify permissions.
  Future<ProjectMemberRole?> getMemberRole(
      String projectId, String uid) async {
    final doc = await _projects
        .doc(projectId)
        .collection('members')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return ProjectMemberRoleExt.fromFirestore(
        doc.data()?['role'] as String?);
  }

  // ── Default project (migration helper) ───────────────────────────────────────

  /// Creates the "Default Project" used to hold all v1 data after migration.
  /// Safe to call multiple times — checks for existing default first.
  ///
  /// Returns the project ID (either newly created or the existing one).
  Future<String> ensureDefaultProject(String creatorUid) async {
    // Check if a default project already exists
    final existing = await _projects
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Create it
    final defaultProject = ProjectModel(
      id: '',
      name: 'Default Project',
      clientName: '',
      address: '',
      description:
          'Auto-created project containing all snags logged before '
          'multi-project support was enabled.',
      status: ProjectStatus.active,
      colorIndex: 0, // Blue
      createdAt: DateTime.now(),
      createdBy: creatorUid,
      isDefault: true,
    );

    return createProject(defaultProject, creatorUid);
  }
}
