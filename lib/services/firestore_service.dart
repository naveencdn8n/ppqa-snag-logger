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

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // ─── User profiles ─────────────────────────────────────────────────────────

  /// Upserts the signed-in user's display name into the `users` collection.
  /// Called on every sign-in so the name is always current.
  Future<void> saveUserProfile(
      String uid, String displayName, String email) async {
    await _usersRef.doc(uid).set({
      'displayName': displayName,
      'email': email,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetches a user's Firestore profile (role, status, displayName).
  /// Returns an empty map if the document doesn't exist yet (new user).
  Future<Map<String, dynamic>> getUserProfileData(String uid) async {
    try {
      final snap = await _usersRef.doc(uid).get();
      return snap.exists ? (snap.data() ?? {}) : {};
    } catch (_) {
      return {};
    }
  }

  /// Real-time stream of uid → displayName for all team members.
  Stream<Map<String, String>> get usersStream {
    return _usersRef.snapshots().map((snap) {
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final name = doc.data()['displayName'] as String?;
        if (name != null && name.isNotEmpty) {
          map[doc.id] = name;
        }
      }
      return map;
    });
  }

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

  /// Adds a new snag to Firestore. Any [mediaFiles] are uploaded to Firebase
  /// Storage first and their download URLs stored in [SnagModel.mediaUrls].
  ///
  /// The Firestore auto-ID becomes the snag's canonical [SnagModel.id].
  Future<void> addSnag(SnagModel snag, {List<File> mediaFiles = const []}) async {
    // Reserve the document ID upfront so we can use it in Storage paths
    final docRef = _snagsRef.doc();

    // Upload all media files in parallel
    final urls = await Future.wait(
      mediaFiles.asMap().entries.map(
        (e) => _uploadMedia(e.value, docRef.id, index: e.key),
      ),
    );

    // Filter nulls (failed uploads) and build final model
    final mediaUrls = urls.whereType<String>().toList();

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
      mediaUrls: mediaUrls,
      notes: snag.notes,
    );

    await docRef.set(finalSnag.toMap());
  }

  // ─── Write: add snag offline (no media) ───────────────────────────────────

  /// Saves a snag to Firestore without any media files.
  /// Used when the device is offline — Firestore's offline cache queues the
  /// write and syncs automatically once connectivity is restored.
  ///
  /// Returns the generated document ID so it can be used in the media queue.
  Future<String> addSnagOffline(SnagModel snag) async {
    final docRef = _snagsRef.doc();
    final finalSnag = snag.copyWith(id: docRef.id, mediaUrls: const []);
    await docRef.set(finalSnag.toMap());
    return docRef.id;
  }

  // ─── Write: update status ──────────────────────────────────────────────────

  /// Updates only the [status] field of an existing snag document.
  /// All other fields are left untouched.
  Future<void> updateSnagStatus(String snagId, SnagStatus newStatus) async {
    await _snagsRef.doc(snagId).update({'status': newStatus.firestoreValue});
  }

  // ─── Write: append media URLs (used after offline upload) ─────────────────

  /// Appends [urls] to an existing snag's [mediaUrls] list using arrayUnion.
  /// Uses set+merge so it is safe even if the doc hasn't fully synced yet.
  Future<void> appendMediaUrls(String snagId, List<String> urls) async {
    await _snagsRef.doc(snagId).set(
      {'mediaUrls': FieldValue.arrayUnion(urls)},
      SetOptions(merge: true),
    );
  }

  // ─── Storage: upload media ─────────────────────────────────────────────────

  /// Public wrapper used by [OfflineQueueService] to re-upload queued files.
  Future<String?> uploadMediaFile(File file, String snagId,
          {required int index}) =>
      _uploadMedia(file, snagId, index: index);

  /// Uploads a photo or video file to Firebase Storage.
  /// Path: `evidence/{snagId}_{index}.{ext}`
  /// Returns the download URL or null on failure (non-fatal).
  Future<String?> _uploadMedia(File file, String snagId,
      {required int index}) async {
    try {
      final path = file.path.toLowerCase();
      final isVideo = path.endsWith('.mp4') ||
          path.endsWith('.mov') ||
          path.endsWith('.avi') ||
          path.endsWith('.mkv');

      final ext = isVideo ? 'mp4' : 'jpg';
      final contentType = isVideo ? 'video/mp4' : 'image/jpeg';

      final ref =
          _storage.ref().child('evidence/${snagId}_$index.$ext');
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null; // non-fatal — snag is saved without this file
    }
  }
}
