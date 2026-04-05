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
    );
  }
}
