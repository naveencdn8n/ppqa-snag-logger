import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';

/// Exports all snags to a Google Sheet using a service account.
///
/// Setup required (one-time):
/// 1. Enable Google Sheets API in GCP Console.
/// 2. Create a service account → download JSON key →
///    save as `assets/credentials/sheets_credentials.json`.
/// 3. Create a Google Sheet and share it with the service account email.
/// 4. Paste the Spreadsheet ID into [_spreadsheetId] below.
class SheetsExportService {
  // ── Configure these two values after completing the setup steps ────────────

  /// The long alphanumeric ID from your sheet's URL:
  /// https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
  static const String _spreadsheetId = '1OTEnNiwq-guFoRmXy1akS-BzbsMOnuA9JWHHJaAAWbk';

  /// The tab name inside the spreadsheet where snags will be written.
  static const String _worksheetTitle = 'Snags';

  // ── Column headers (A–O) ───────────────────────────────────────────────────
  static const List<String> _headers = [
    'ID',
    'Created By',
    'Created At',
    'Location',
    'Floor No',
    'Unit',
    'Room',
    'Element',
    'Trade',
    'Defect Description',
    'Severity',
    'Status',
    'Evidence Image URL',
    'Notes',
    'Week Start',
  ];

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Writes all [snags] to the configured Google Sheet.
  ///
  /// - Creates the worksheet if it does not exist.
  /// - Writes headers on first run.
  /// - Clears and rewrites data rows on every subsequent run so the sheet
  ///   always reflects the current Firestore state.
  ///
  /// Returns the number of snag rows written.
  /// Throws on authentication failure, network error, or missing credentials.
  Future<int> exportSnags(List<SnagModel> snags) async {
    final credentialsJson = await rootBundle.loadString(
      'assets/credentials/sheets_credentials.json',
    );

    final gsheets = GSheets(credentialsJson);
    final spreadsheet = await gsheets.spreadsheet(_spreadsheetId);

    // Find or create the target worksheet
    final sheet = spreadsheet.worksheetByTitle(_worksheetTitle) ??
        await spreadsheet.addWorksheet(_worksheetTitle);

    // Clear the entire sheet and rewrite headers + data fresh each time.
    // This ensures the Sheet always mirrors the current Firestore state exactly.
    await sheet.clear();
    await sheet.values.insertRow(1, _headers);

    if (snags.isEmpty) return 0;

    // Build one row per snag
    final rows = snags
        .map((s) => [
              s.id,
              s.createdBy,
              _dateFmt.format(s.createdAt),
              s.location,
              s.floorNo,
              s.flatNo,
              s.room,
              s.element,
              s.trade,
              s.defectDescription,
              s.severity.label,
              s.status.label,
              s.mediaUrls.join(', '), // all media URLs comma-separated
              s.notes ?? '',
              _dateFmt.format(s.weekStart),
            ])
        .toList();

    await sheet.values.appendRows(rows);
    return rows.length;
  }
}
