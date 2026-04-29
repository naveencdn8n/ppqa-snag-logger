import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';

/// Handles all reads and writes to Cloud Firestore and Firebase Storage.
/// No Flutter widgets or BuildContext are used here — this class is purely
/// a data layer and can be tested independently.
///
/// All snag operations are project-scoped (v2):
///   `projects/{projectId}/snags/{snagId}`
///
/// User profile operations remain at the top-level `users` collection
/// because users are global across all projects.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Collection references ──────────────────────────────────────────────────

  /// Snags sub-collection for the given project.
  CollectionReference<Map<String, dynamic>> _snagsRef(String projectId) =>
      _db.collection('projects').doc(projectId).collection('snags');

  /// Global users collection — not project-scoped.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // ── User profiles ──────────────────────────────────────────────────────────

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

  /// Fetches a user's Firestore profile (role, status, isAdmin, displayName).
  /// Returns an empty map only when the document genuinely does not exist
  /// (i.e. a brand-new user who has not yet been assigned a profile).
  /// Network / permission errors are re-thrown so the caller (AppState) can
  /// handle them and avoid defaulting a blocked user to an active role.
  Future<Map<String, dynamic>> getUserProfileData(String uid) async {
    final snap = await _usersRef.doc(uid).get();
    return snap.exists ? (snap.data() ?? {}) : {};
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

  // ── Snag stream ────────────────────────────────────────────────────────────

  /// Real-time stream of all snags in [projectId], ordered newest first.
  Stream<List<SnagModel>> snagsStream(String projectId) {
    return _snagsRef(projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SnagModel.fromFirestore).toList());
  }

  // ── Write: add snag ────────────────────────────────────────────────────────

  /// Adds a new snag to the given project. Any [mediaFiles] are uploaded to
  /// Firebase Storage first and their download URLs stored on the snag.
  ///
  /// The Firestore auto-ID becomes the snag's canonical [SnagModel.id].
  Future<void> addSnag(
    SnagModel snag,
    String projectId, {
    List<File> mediaFiles = const [],
  }) async {
    // Reserve the document ID upfront so we can use it in Storage paths
    final docRef = _snagsRef(projectId).doc();

    // Upload all media files in parallel
    final urls = await Future.wait(
      mediaFiles.asMap().entries.map(
        (e) => _uploadMedia(
          e.value,
          docRef.id,
          projectId: projectId,
          index: e.key,
        ),
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

  // ── Write: add snag offline (no media) ────────────────────────────────────

  /// Saves a snag to Firestore without any media files.
  /// Used when the device is offline — Firestore's offline cache queues the
  /// write and syncs automatically once connectivity is restored.
  ///
  /// **Hard 3-second timeout** on the underlying [DocumentReference.set]:
  /// the document ID is generated locally and is always returned immediately,
  /// but the Future returned by `set()` can still hang in some SDK states
  /// (e.g. partial connection drop). Once timed out we fire-and-forget the
  /// write — Firestore's internal retry queue will complete it in the
  /// background as soon as network is available.
  Future<String> addSnagOffline(SnagModel snag, String projectId) async {
    final docRef = _snagsRef(projectId).doc();
    final finalSnag = snag.copyWith(id: docRef.id, mediaUrls: const []);

    try {
      await docRef
          .set(finalSnag.toMap())
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Future didn't resolve in 3 s. The set() call itself has been
      // accepted by Firestore — it will be retried/synced in the background.
      // Continue without awaiting so the UI is never blocked.
      debugPrint(
          'addSnagOffline: docRef.set() timed out after 3 s, continuing');
    }

    return docRef.id;
  }

  // ── Write: update status ───────────────────────────────────────────────────

  /// Updates the [status] field of an existing snag.
  /// When [newStatus] is [SnagStatus.closed], also uploads any
  /// [closeMediaFiles] to Firebase Storage and writes [closeNote] +
  /// [closeEvidenceUrls] to Firestore. Original [mediaUrls] are preserved.
  Future<void> updateSnagStatus(
    String snagId,
    String projectId,
    SnagStatus newStatus, {
    String? closeNote,
    List<File> closeMediaFiles = const [],
  }) async {
    final Map<String, dynamic> update = {
      'status': newStatus.firestoreValue,
    };

    if (newStatus == SnagStatus.closed) {
      // Upload close-out evidence in parallel
      final urls = await Future.wait(
        closeMediaFiles.asMap().entries.map(
          (e) => _uploadMedia(
            e.value,
            '${snagId}_close',
            projectId: projectId,
            index: e.key,
          ),
        ),
      );
      update['closeNote'] = closeNote ?? '';
      update['closeEvidenceUrls'] =
          FieldValue.arrayUnion(urls.whereType<String>().toList());
    }

    await _snagsRef(projectId).doc(snagId).update(update);
  }

  // ── Write: append media URLs (used after offline upload) ──────────────────

  /// Appends [urls] to an existing snag's [mediaUrls] list using arrayUnion.
  /// Uses set+merge so it is safe even if the doc hasn't fully synced yet.
  Future<void> appendMediaUrls(
    String snagId,
    String projectId,
    List<String> urls,
  ) async {
    await _snagsRef(projectId).doc(snagId).set(
      {'mediaUrls': FieldValue.arrayUnion(urls)},
      SetOptions(merge: true),
    );
  }

  // ── Invitation onboarding ─────────────────────────────────────────────────

  /// Checks for a pending invitation at `invitations/{emailLower}` and, if
  /// found, applies the assigned role + project membership in a single batch.
  ///
  /// Called once on every sign-in. Safe to call repeatedly:
  ///   • No-op when there is no invitation or it is already claimed.
  ///   • Throws only on unexpected Firestore errors — callers should catch
  ///     and log so that a missing invitation never blocks the sign-in flow.
  ///
  /// Batch operations (all or nothing):
  ///   1. Update `users/{uid}.role` to the invited role.
  ///   2. Create `projects/{projectId}/members/{uid}` with the invited role.
  ///   3. Append uid to `projects/{projectId}.memberUids`.
  ///   4. Mark the invitation as `claimed`.
  Future<void> applyPendingInvitation(String uid, String email) async {
    final emailKey = email.toLowerCase().trim();

    final inviteSnap =
        await _db.collection('invitations').doc(emailKey).get();

    if (!inviteSnap.exists) return;
    final invite = inviteSnap.data()!;
    if (invite['status'] != 'pending') return;

    final role      = (invite['role']      as String?) ?? 'inspector';
    final projectId = (invite['projectId'] as String?) ?? '';

    final batch = _db.batch();

    // 1. Self-apply role (Firestore rule allows this for pending invitations)
    batch.update(_usersRef.doc(uid), {'role': role});

    if (projectId.isNotEmpty) {
      // 2. Create member sub-document
      batch.set(
        _db
            .collection('projects')
            .doc(projectId)
            .collection('members')
            .doc(uid),
        {
          'role':     role,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );

      // 3. Add uid to the denormalised memberUids array
      batch.update(
        _db.collection('projects').doc(projectId),
        {'memberUids': FieldValue.arrayUnion([uid])},
      );
    }

    // 4. Mark invitation as claimed so it can only be used once
    batch.update(inviteSnap.reference, {
      'status':    'claimed',
      'claimedBy': uid,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Storage: upload media ──────────────────────────────────────────────────

  /// Attempts to upload all [mediaFiles] in parallel.
  /// Each individual file has a 20-second timeout so a stalled connection
  /// can't block the UI indefinitely.
  ///
  /// Returns a list with one entry per input file:
  ///   - non-null String → download URL (upload succeeded)
  ///   - null            → that file failed or timed out
  Future<List<String?>> uploadAllMedia(
    List<File> mediaFiles,
    String snagId,
    String projectId,
  ) {
    return Future.wait(
      mediaFiles.asMap().entries.map((e) async {
        try {
          return await _uploadMedia(
            e.value,
            snagId,
            projectId: projectId,
            index: e.key,
          ).timeout(const Duration(seconds: 20));
        } catch (_) {
          return null; // timeout or error — caller decides what to queue
        }
      }),
    );
  }

  /// Public wrapper used by [OfflineQueueService] to re-upload queued files.
  Future<String?> uploadMediaFile(
    File file,
    String snagId,
    String projectId, {
    required int index,
  }) =>
      _uploadMedia(file, snagId, projectId: projectId, index: index);

  // ── Offline network control ────────────────────────────────────────────────

  /// Tells the Firestore SDK to stop all network traffic immediately.
  /// After this call, every write (set/update/delete) commits to the local
  /// cache and resolves in < 100 ms instead of waiting for a server ACK.
  ///
  /// Wrapped in a 2-second timeout because [FirebaseFirestore.disableNetwork]
  /// itself can hang if the SDK is mid-handshake with the backend.
  Future<void> goOffline() async {
    try {
      await _db.disableNetwork().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      debugPrint('goOffline: disableNetwork() timed out, continuing');
    }
  }

  /// Re-enables Firestore networking. Pending local writes are synced to the
  /// server as soon as the connection is available.
  Future<void> goOnline() async {
    try {
      await _db.enableNetwork().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      debugPrint('goOnline: enableNetwork() timed out, continuing');
    }
  }

  /// Uploads a photo or video file to Firebase Storage.
  /// Path: `evidence/{projectId}/{snagId}_{index}.{ext}`
  /// Returns the download URL. Throws on failure so the caller can surface
  /// the error to the user — silent failures hide real problems (e.g.
  /// missing profile / wrong role / Storage rules denying writes).
  Future<String?> _uploadMedia(
    File file,
    String snagId, {
    required String projectId,
    required int index,
  }) async {
    final path = file.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv');

    final ext = isVideo ? 'mp4' : 'jpg';
    final contentType = isVideo ? 'video/mp4' : 'image/jpeg';

    final ref = _storage
        .ref()
        .child('evidence/$projectId/${snagId}_$index.$ext');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );
    return await task.ref.getDownloadURL();
  }
}
