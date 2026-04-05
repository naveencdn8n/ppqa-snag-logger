import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_enums.dart';

// ── Colour palette ─────────────────────────────────────────────────────────────
// Fixed set of project colours the admin picks from. Stored as the index (int)
// in Firestore so it's display-theme-independent.
const List<int> kProjectColors = [
  0xFF1565C0, // Blue
  0xFF2E7D32, // Green
  0xFF6A1B9A, // Purple
  0xFFE65100, // Orange
  0xFF00838F, // Teal
  0xFFC62828, // Red
  0xFF4527A0, // Deep Purple
  0xFF00695C, // Dark Teal
  0xFFAD1457, // Pink
  0xFF558B2F, // Light Green
];

// ── Project member ─────────────────────────────────────────────────────────────

/// A lightweight record of a single member's role inside a project.
/// Full profile (displayName, email) is resolved from the `users` collection.
class ProjectMember {
  final String uid;
  final ProjectMemberRole role;
  final DateTime joinedAt;

  const ProjectMember({
    required this.uid,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProjectMember(
      uid: doc.id,
      role: ProjectMemberRoleExt.fromFirestore(d['role'] as String?),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role.firestoreValue,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };

  ProjectMember copyWith({ProjectMemberRole? role}) => ProjectMember(
        uid: uid,
        role: role ?? this.role,
        joinedAt: joinedAt,
      );
}

// ── Project model ──────────────────────────────────────────────────────────────

/// Represents one construction project.
///
/// Firestore path: `projects/{projectId}`
///
/// Sub-collections (populated in Step 2 — migration):
///   • `projects/{id}/snags`
///   • `projects/{id}/locations`
///   • `projects/{id}/trades`
///   • `projects/{id}/members`
class ProjectModel {
  final String id;

  // ── Identity ─────────────────────────────────────────────────────────────────
  final String name;         // "CRC Tower Phase 1"
  final String clientName;   // "ABC Developers Pvt Ltd"
  final String address;      // "Andheri East, Mumbai"
  final String description;  // optional free text

  // ── Status + appearance ───────────────────────────────────────────────────────
  final ProjectStatus status;
  final int colorIndex;      // index into kProjectColors

  // ── Dates ─────────────────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? targetDate;

  // ── Ownership ─────────────────────────────────────────────────────────────────
  final String createdBy; // Firebase UID of creator

  /// True for the auto-created project that holds all v1 (pre-multi-project) data.
  /// Prevents accidental deletion of legacy data.
  final bool isDefault;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.clientName,
    required this.address,
    this.description = '',
    required this.status,
    this.colorIndex = 0,
    required this.createdAt,
    this.startDate,
    this.targetDate,
    required this.createdBy,
    this.isDefault = false,
  });

  // ── Derived helpers ──────────────────────────────────────────────────────────

  /// The display colour for this project's chip / badge.
  int get color => kProjectColors[colorIndex.clamp(0, kProjectColors.length - 1)];

  /// Short label shown in compact UI (max ~15 chars).
  String get shortName =>
      name.length > 18 ? '${name.substring(0, 16)}…' : name;

  // ── Firestore serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'name': name,
        'clientName': clientName,
        'address': address,
        'description': description,
        'status': status.firestoreValue,
        'colorIndex': colorIndex,
        'createdAt': Timestamp.fromDate(createdAt),
        'startDate':
            startDate != null ? Timestamp.fromDate(startDate!) : null,
        'targetDate':
            targetDate != null ? Timestamp.fromDate(targetDate!) : null,
        'createdBy': createdBy,
        'isDefault': isDefault,
      };

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      name: d['name'] as String? ?? 'Untitled Project',
      clientName: d['clientName'] as String? ?? '',
      address: d['address'] as String? ?? '',
      description: d['description'] as String? ?? '',
      status: ProjectStatusExt.fromFirestore(d['status'] as String?),
      colorIndex: (d['colorIndex'] as int?) ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      targetDate: (d['targetDate'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] as String? ?? '',
      isDefault: d['isDefault'] as bool? ?? false,
    );
  }

  ProjectModel copyWith({
    String? name,
    String? clientName,
    String? address,
    String? description,
    ProjectStatus? status,
    int? colorIndex,
    DateTime? startDate,
    DateTime? targetDate,
  }) =>
      ProjectModel(
        id: id,
        name: name ?? this.name,
        clientName: clientName ?? this.clientName,
        address: address ?? this.address,
        description: description ?? this.description,
        status: status ?? this.status,
        colorIndex: colorIndex ?? this.colorIndex,
        createdAt: createdAt,
        startDate: startDate ?? this.startDate,
        targetDate: targetDate ?? this.targetDate,
        createdBy: createdBy,
        isDefault: isDefault,
      );
}
