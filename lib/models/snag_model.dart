import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_enums.dart';

class SnagModel {
  final String id;
  final String createdBy;
  final DateTime createdAt;
  final SnagLocation location;
  final int floorNo;
  final FlatNo flatNo;
  final SnagElement element;
  final SnagTrade trade;
  final String defectDescription;
  final SnagSeverity severity;
  final SnagStatus status;
  final String? evidenceImagePath;
  final String? notes;

  const SnagModel({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.location,
    required this.floorNo,
    required this.flatNo,
    required this.element,
    required this.trade,
    required this.defectDescription,
    required this.severity,
    required this.status,
    this.evidenceImagePath,
    this.notes,
  });

  SnagModel copyWith({
    String? id,
    String? createdBy,
    DateTime? createdAt,
    SnagLocation? location,
    int? floorNo,
    FlatNo? flatNo,
    SnagElement? element,
    SnagTrade? trade,
    String? defectDescription,
    SnagSeverity? severity,
    SnagStatus? status,
    String? evidenceImagePath,
    String? notes,
  }) {
    return SnagModel(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      floorNo: floorNo ?? this.floorNo,
      flatNo: flatNo ?? this.flatNo,
      element: element ?? this.element,
      trade: trade ?? this.trade,
      defectDescription: defectDescription ?? this.defectDescription,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      evidenceImagePath: evidenceImagePath ?? this.evidenceImagePath,
      notes: notes ?? this.notes,
    );
  }

  /// Returns the week start (Monday) for this snag's createdAt date.
  DateTime get weekStart {
    final d = createdAt;
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  // ─── Firestore serialization ───────────────────────────────────────────────

  /// Converts this snag to a Firestore-compatible map.
  /// Note: [id] is NOT included — Firestore uses the document ID.
  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location.name,
      'floorNo': floorNo,
      'flatNo': flatNo.name,
      'element': element.name,
      'trade': trade.name,
      'defectDescription': defectDescription,
      'severity': severity.name,
      'status': status.name,
      'evidenceImageUrl': evidenceImagePath,
      'notes': notes,
    };
  }

  /// Constructs a [SnagModel] from a Firestore document snapshot.
  factory SnagModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SnagModel(
      id: doc.id,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      location: SnagLocation.values.byName(d['location'] as String),
      floorNo: d['floorNo'] as int,
      flatNo: FlatNo.values.byName(d['flatNo'] as String),
      element: SnagElement.values.byName(d['element'] as String),
      trade: SnagTrade.values.byName(d['trade'] as String),
      defectDescription: d['defectDescription'] as String,
      severity: SnagSeverity.values.byName(d['severity'] as String),
      status: SnagStatus.values.byName(d['status'] as String),
      evidenceImagePath: d['evidenceImageUrl'] as String?,
      notes: d['notes'] as String?,
    );
  }
}
