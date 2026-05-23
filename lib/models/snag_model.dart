import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_enums.dart';

class SnagModel {
  final String id;
  final String createdBy;
  final DateTime createdAt;

  // ── Location fields — 5-level hierarchy ─────────────────────────────────────
  final String location;   // Level 1 — Tower / Block  e.g. "Tower 1"
  final String floorNo;    // Level 2 — Floor           e.g. "GF", "3", "Roof"
  final String flatNo;     // Level 3 — Unit            e.g. "A101", "Unit 3"
  final String room;       // Level 4 — Room            e.g. "Living Room"
  final String element;    // Level 5 — Element         e.g. "Walls", "Ceiling"

  // ── Defect fields (now plain strings — set by admin panel config) ───────────
  final String trade;             // e.g. "Tiling", "Electrical"
  final String defectDescription; // e.g. "Crack in plaster"

  // ── Fixed-value enums (not admin-configurable) ───────────────────────────────
  final SnagSeverity severity;
  final SnagStatus status;

  /// All uploaded media URLs (photos + videos). Replaces the old single
  /// [evidenceImagePath]. Old snags with a single [evidenceImageUrl] field
  /// are transparently migrated in [fromFirestore].
  final List<String> mediaUrls;
  final String? notes;

  // ── Close-out fields (written when status → closed) ─────────────────────────
  /// Mandatory note added by the inspector when closing a snag.
  final String? closeNote;

  /// Photos/videos uploaded as evidence when closing a snag.
  /// Kept separate from [mediaUrls] so original evidence is preserved.
  final List<String> closeEvidenceUrls;

  /// UID of the user who closed this snag (audit trail).
  /// Resolved to a display name via AppState.resolveInspector(), same as
  /// [createdBy]. Empty/null for snags closed before the audit field existed.
  final String? closedBy;

  /// Timestamp of when this snag was closed (audit trail).
  /// Null for snags closed before the audit field existed.
  final DateTime? closedAt;

  // ── In-Progress status-change fields (written when status → inProgress) ─────
  //
  // These fields are populated when ANY user (commonly a viewer using the
  // dedicated "Mark as In Progress" flow) transitions a snag from Open to
  // In Progress. Only the most recent transition is kept — earlier values
  // are overwritten on subsequent re-transitions.

  /// Mandatory note attached when changing status to In Progress.
  final String? statusChangeNote;

  /// Optional photos uploaded as evidence when changing status to In Progress.
  /// Stored separately from [mediaUrls] and [closeEvidenceUrls] so each audit
  /// trail keeps its own evidence.
  final List<String> statusChangePhotos;

  /// UID of the user who performed the status change (audit trail).
  /// Resolved to a display name via AppState.resolveInspector().
  final String? statusChangedBy;

  /// Server-side timestamp of when the status was changed (audit trail).
  final DateTime? statusChangedAt;

  const SnagModel({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.location,
    required this.floorNo,
    required this.flatNo,
    this.room = '',
    required this.element,
    required this.trade,
    required this.defectDescription,
    required this.severity,
    required this.status,
    this.mediaUrls = const [],
    this.notes,
    this.closeNote,
    this.closeEvidenceUrls = const [],
    this.closedBy,
    this.closedAt,
    this.statusChangeNote,
    this.statusChangePhotos = const [],
    this.statusChangedBy,
    this.statusChangedAt,
  });

  /// Convenience getter — first photo URL (used by list tile preview).
  String? get firstMediaUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;

  SnagModel copyWith({
    String? id,
    String? createdBy,
    DateTime? createdAt,
    String? location,
    String? floorNo,
    String? flatNo,
    String? room,
    String? element,
    String? trade,
    String? defectDescription,
    SnagSeverity? severity,
    SnagStatus? status,
    List<String>? mediaUrls,
    String? notes,
    String? closeNote,
    List<String>? closeEvidenceUrls,
    String? closedBy,
    DateTime? closedAt,
    String? statusChangeNote,
    List<String>? statusChangePhotos,
    String? statusChangedBy,
    DateTime? statusChangedAt,
  }) {
    return SnagModel(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      floorNo: floorNo ?? this.floorNo,
      flatNo: flatNo ?? this.flatNo,
      room: room ?? this.room,
      element: element ?? this.element,
      trade: trade ?? this.trade,
      defectDescription: defectDescription ?? this.defectDescription,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      notes: notes ?? this.notes,
      closeNote: closeNote ?? this.closeNote,
      closeEvidenceUrls: closeEvidenceUrls ?? this.closeEvidenceUrls,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      statusChangeNote: statusChangeNote ?? this.statusChangeNote,
      statusChangePhotos: statusChangePhotos ?? this.statusChangePhotos,
      statusChangedBy: statusChangedBy ?? this.statusChangedBy,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    );
  }

  /// Returns the Monday of the week this snag was created.
  DateTime get weekStart {
    final d = createdAt;
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  // ─── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location,
      'floorNo': floorNo,
      'flatNo': flatNo,
      'room': room,
      'element': element,
      'trade': trade,
      'defectDescription': defectDescription,
      'severity': severity.name,
      'status': status.firestoreValue,
      'mediaUrls': mediaUrls,
      'notes': notes,
      'closeNote': closeNote,
      'closeEvidenceUrls': closeEvidenceUrls,
      'closedBy': closedBy,
      'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
      'statusChangeNote': statusChangeNote,
      'statusChangePhotos': statusChangePhotos,
      'statusChangedBy': statusChangedBy,
      'statusChangedAt': statusChangedAt == null
          ? null
          : Timestamp.fromDate(statusChangedAt!),
    };
  }

  factory SnagModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // Backwards-compatible media: prefer new [mediaUrls] list, fall back to
    // old single [evidenceImageUrl] string.
    List<String> mediaUrls;
    if (d['mediaUrls'] is List) {
      mediaUrls = List<String>.from(d['mediaUrls'] as List);
    } else if (d['evidenceImageUrl'] is String &&
        (d['evidenceImageUrl'] as String).isNotEmpty) {
      mediaUrls = [d['evidenceImageUrl'] as String];
    } else {
      mediaUrls = [];
    }

    // Close-out evidence urls — backwards-compatible (old snags won't have it)
    final List<String> closeEvidenceUrls = d['closeEvidenceUrls'] is List
        ? List<String>.from(d['closeEvidenceUrls'] as List)
        : [];

    // Close-out audit fields — backwards-compatible (legacy snags lack these).
    // closedBy is stored as a UID string; closedAt is a Firestore Timestamp.
    final String? closedBy = d['closedBy'] as String?;
    final DateTime? closedAt = d['closedAt'] is Timestamp
        ? (d['closedAt'] as Timestamp).toDate()
        : null;

    // Status-change audit fields (In Progress flow). Backwards-compatible —
    // older snags simply don't have these keys and the model defaults apply.
    final List<String> statusChangePhotos = d['statusChangePhotos'] is List
        ? List<String>.from(d['statusChangePhotos'] as List)
        : [];
    final String? statusChangedBy = d['statusChangedBy'] as String?;
    final DateTime? statusChangedAt = d['statusChangedAt'] is Timestamp
        ? (d['statusChangedAt'] as Timestamp).toDate()
        : null;

    return SnagModel(
      id: doc.id,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      location: d['location'] as String? ?? '',
      floorNo: (d['floorNo'] ?? '').toString(),
      flatNo:  d['flatNo'] as String? ?? '',
      room:    d['room']   as String? ?? '', // '' for old snags without room
      element: d['element'] as String? ?? '',
      trade: d['trade'] as String? ?? '',
      defectDescription: d['defectDescription'] as String? ?? '',
      severity: SnagSeverity.values.byName(
        d['severity'] as String? ?? 'minor',
      ),
      status: SnagStatusExt.fromFirestore(d['status'] as String?),
      mediaUrls: mediaUrls,
      notes: d['notes'] as String?,
      closeNote: d['closeNote'] as String?,
      closeEvidenceUrls: closeEvidenceUrls,
      closedBy: (closedBy != null && closedBy.isNotEmpty) ? closedBy : null,
      closedAt: closedAt,
      statusChangeNote: d['statusChangeNote'] as String?,
      statusChangePhotos: statusChangePhotos,
      statusChangedBy:
          (statusChangedBy != null && statusChangedBy.isNotEmpty)
              ? statusChangedBy
              : null,
      statusChangedAt: statusChangedAt,
    );
  }
}
