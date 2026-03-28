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
}
