import 'package:cloud_functions/cloud_functions.dart';

import '../models/snag_model.dart';

/// Exports snags to Google Sheets by calling a Firebase Cloud Function.
///
/// The Cloud Function holds the Google Sheets service account credentials
/// server-side so the private key is never bundled inside the APK.
///
/// ── One-time setup required ──────────────────────────────────────────────────
/// 1. Deploy the `exportSnagsToSheets` callable Cloud Function (Node.js):
///    - Install googleapis npm package in your functions project
///    - Load the service account JSON from an environment secret (not a file)
///    - Receive `data.snags` (List of row maps), write them to the Sheet
///    - Return `{ count: <int> }` on success
///
/// 2. In Firebase Console → Functions → (your function) → Environment:
///    Set secret `SHEETS_CREDENTIALS` = contents of your service account JSON
///    Set secret `SPREADSHEET_ID`     = your Google Sheet ID
///
/// See the Cloud Function template at:
///   https://firebase.google.com/docs/functions/callable
/// ─────────────────────────────────────────────────────────────────────────────
class SheetsExportService {
  static const String _functionName = 'exportSnagsToSheets';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Sends [snags] to the Cloud Function which writes them to Google Sheets.
  ///
  /// Returns the number of rows exported.
  /// Throws [FirebaseFunctionsException] on authentication / network errors,
  /// or if the Cloud Function has not been deployed yet.
  Future<int> exportSnags(List<SnagModel> snags) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      _functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    // Serialise each snag into a plain map the Cloud Function can parse.
    final rows = snags
        .map((s) => {
              'id': s.id,
              'createdBy': s.createdBy,
              'createdAt': s.createdAt.toIso8601String(),
              'location': s.location,
              'floorNo': s.floorNo,
              'flatNo': s.flatNo,
              'room': s.room,
              'element': s.element,
              'trade': s.trade,
              'defectDescription': s.defectDescription,
              'severity': s.severity.label,
              'status': s.status.label,
              'mediaUrls': s.mediaUrls.join(', '),
              'notes': s.notes ?? '',
              'weekStart': s.weekStart.toIso8601String(),
            })
        .toList();

    final result = await callable.call({'snags': rows});

    // Cloud Function returns { count: <int> }
    return (result.data['count'] as int?) ?? rows.length;
  }
}
