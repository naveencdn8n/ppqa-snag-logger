import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a file document from any of the three resource collections
/// (specifications, drawings, benchmark_reports) stored in Firestore.
class ResourceFile {
  final String id;
  final String name;
  final String? description;
  final String url;
  final String? fileName;
  final String? fileType;   // e.g. 'pdf', 'dwg', 'docx'
  final int? fileSize;      // bytes
  final DateTime? uploadedAt;

  // Layout Drawings only
  final String? floor;
  final String? unit;

  const ResourceFile({
    required this.id,
    required this.name,
    this.description,
    required this.url,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.uploadedAt,
    this.floor,
    this.unit,
  });

  factory ResourceFile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['uploadedAt'];
    return ResourceFile(
      id: doc.id,
      name: d['name'] as String? ?? 'Untitled',
      description: d['description'] as String?,
      url: d['url'] as String? ?? '',
      fileName: d['fileName'] as String?,
      fileType: d['fileType'] as String?,
      fileSize: d['fileSize'] as int?,
      uploadedAt: ts is Timestamp ? ts.toDate() : null,
      floor: d['floor'] as String?,
      unit: d['unit'] as String?,
    );
  }

  /// Human-readable file size, e.g. "1.2 MB" or "340 KB".
  String get formattedSize {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(fileSize! / 1024).round()} KB';
  }
}
