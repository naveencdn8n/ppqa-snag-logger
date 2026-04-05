import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'firestore_service.dart';

/// A single queued media upload — one per offline snag that had media files.
class PendingMediaUpload {
  final String snagId;

  /// Absolute paths to media files copied into persistent app storage.
  final List<String> mediaFilePaths;

  const PendingMediaUpload({
    required this.snagId,
    required this.mediaFilePaths,
  });

  Map<String, dynamic> toJson() => {
        'snagId': snagId,
        'mediaFilePaths': mediaFilePaths,
      };

  factory PendingMediaUpload.fromJson(Map<String, dynamic> json) =>
      PendingMediaUpload(
        snagId: json['snagId'] as String,
        mediaFilePaths: List<String>.from(json['mediaFilePaths'] as List),
      );
}

/// Manages a persistent JSON queue of media uploads that failed to upload
/// because the device was offline when the snag was logged.
///
/// When connectivity is restored, [processPendingUploads] re-attempts all
/// queued uploads and patches the corresponding Firestore snag documents.
class OfflineQueueService {
  static const _queueFile = 'ppqa_pending_uploads.json';
  static const _mediaDir = 'pending_media';

  // ── Queue file helpers ──────────────────────────────────────────────────────

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_queueFile');
  }

  Future<List<PendingMediaUpload>> readQueue() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final List<dynamic> list = jsonDecode(await f.readAsString());
      return list
          .map((e) => PendingMediaUpload.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<PendingMediaUpload> queue) async {
    final f = await _file();
    await f.writeAsString(
      jsonEncode(queue.map((e) => e.toJson()).toList()),
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Number of snags waiting for their media to be uploaded.
  Future<int> get pendingCount async => (await readQueue()).length;

  /// Copies [mediaFiles] to persistent app storage and adds them to the queue
  /// so they can be uploaded when connectivity is restored.
  Future<void> enqueue(String snagId, List<File> mediaFiles) async {
    if (mediaFiles.isEmpty) return;

    // Copy files to a persistent directory (image_picker temp cache gets cleared)
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_mediaDir');
    await dir.create(recursive: true);

    final persistentPaths = <String>[];
    for (int i = 0; i < mediaFiles.length; i++) {
      final ext = mediaFiles[i].path.split('.').last.toLowerCase();
      final dest = File('${dir.path}/${snagId}_$i.$ext');
      await mediaFiles[i].copy(dest.path);
      persistentPaths.add(dest.path);
    }

    final queue = await readQueue();
    queue.add(PendingMediaUpload(
      snagId: snagId,
      mediaFilePaths: persistentPaths,
    ));
    await _writeQueue(queue);
  }

  /// Uploads all queued media files and patches the Firestore snag documents.
  ///
  /// Successfully uploaded items are removed from the queue and their local
  /// copies are deleted. Items that fail remain for the next retry.
  ///
  /// Returns the number of snags whose media was successfully uploaded.
  Future<int> processPendingUploads(FirestoreService firestoreService) async {
    final queue = await readQueue();
    if (queue.isEmpty) return 0;

    final remaining = <PendingMediaUpload>[];
    int processed = 0;

    for (final item in queue) {
      try {
        final files = item.mediaFilePaths
            .map(File.new)
            .where((f) => f.existsSync())
            .toList();

        if (files.isEmpty) {
          // Local copies were deleted — discard entry silently
          processed++;
          continue;
        }

        // Upload all media files in parallel
        final urls = await Future.wait(
          files.asMap().entries.map(
                (e) => firestoreService.uploadMediaFile(
                  e.value,
                  item.snagId,
                  index: e.key,
                ),
              ),
        );

        final validUrls = urls.whereType<String>().toList();
        if (validUrls.isNotEmpty) {
          await firestoreService.appendMediaUrls(item.snagId, validUrls);
        }

        // Clean up local copies after successful upload
        for (final f in files) {
          try {
            await f.delete();
          } catch (_) {}
        }

        processed++;
      } catch (_) {
        // Network error or Firestore not yet synced — keep for next retry
        remaining.add(item);
      }
    }

    await _writeQueue(remaining);
    return processed;
  }
}
