import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/resource_model.dart';

/// Streams files from the three admin-managed Firestore collections.
/// Each stream emits in real-time whenever the admin panel updates data.
class ResourcesService {
  final _db = FirebaseFirestore.instance;

  Stream<List<ResourceFile>> get specificationsStream =>
      _collectionStream('specifications');

  Stream<List<ResourceFile>> get drawingsStream =>
      _collectionStream('drawings');

  Stream<List<ResourceFile>> get benchmarkReportsStream =>
      _collectionStream('benchmark_reports');

  Stream<List<ResourceFile>> _collectionStream(String collection) {
    return _db
        .collection(collection)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ResourceFile.fromFirestore).toList());
  }
}
