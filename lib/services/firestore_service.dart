import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';

/// Handles all reads and writes to Cloud Firestore and Firebase Storage.
/// No Flutter widgets or BuildContext are used here — this class is purely
/// a data layer and can be tested independently.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _snagsRef =>
      _db.collection('snags');

  // ─── Snag stream ───────────────────────────────────────────────────────────

  /// Real-time stream of all snags, ordered newest first.
  /// Every device listening to this stream will receive updates automatically
  /// when any team member logs or updates a snag.
  Stream<List<SnagModel>> get snagsStream {
    return _snagsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SnagModel.fromFirestore).toList());
  }

  // ─── Write: add snag ───────────────────────────────────────────────────────

  /// Adds a new snag to Firestore. If [imageFile] is provided, it is uploaded
  /// to Firebase Storage first and the download URL is stored in the document.
  ///
  /// The Firestore auto-ID becomes the snag's canonical [SnagModel.id].
  Future<void> addSnag(SnagModel snag, {File? imageFile}) async {
    // Reserve the document ID upfront so we can use it as the Storage filename
    final docRef = _snagsRef.doc();

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadPhoto(imageFile, docRef.id);
    }

    // Build the final model with the Firestore doc ID and (optional) image URL
    final finalSnag = SnagModel(
      id: docRef.id,
      createdBy: snag.createdBy,
      createdAt: snag.createdAt,
      location: snag.location,
      floorNo: snag.floorNo,
      flatNo: snag.flatNo,
      element: snag.element,
      trade: snag.trade,
      defectDescription: snag.defectDescription,
      severity: snag.severity,
      status: snag.status,
      evidenceImagePath: imageUrl,
      notes: snag.notes,
    );

    await docRef.set(finalSnag.toMap());
  }

  // ─── Write: update status ──────────────────────────────────────────────────

  /// Updates only the [status] field of an existing snag document.
  /// All other fields are left untouched.
  Future<void> updateSnagStatus(String snagId, SnagStatus newStatus) async {
    await _snagsRef.doc(snagId).update({'status': newStatus.name});
  }

  // ─── Storage: upload photo ─────────────────────────────────────────────────

  /// Uploads [imageFile] to Firebase Storage under `evidence/{snagId}.jpg`.
  /// Returns the public download URL on success, or `null` if the upload fails
  /// (in which case the snag is still saved without a photo).
  Future<String?> _uploadPhoto(File imageFile, String snagId) async {
    try {
      final ref = _storage.ref().child('evidence/$snagId.jpg');
      final task = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      // Upload failure is non-fatal — the snag is saved without a photo URL
      return null;
    }
  }
}
