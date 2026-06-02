import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';

/// Generates a PDF snag report and shares it via the OS share sheet.
///
/// Usage:
///   await PdfExportService.shareSnagReport(
///     snags: filteredSnags,
///     serialMap: appState.snagSerialMap,
///     projectName: appState.currentProject?.name ?? 'PPQA Project',
///     filterLabel: 'Open – Tower A',
///   );
class PdfExportService {
  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> shareSnagReport({
    required List<SnagModel> snags,
    required Map<String, int> serialMap,
    required String projectName,
    String? filterLabel,
  }) async {
    final bytes = await _buildPdf(
      snags: snags,
      serialMap: serialMap,
      projectName: projectName,
      filterLabel: filterLabel,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'snag_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  // ── PDF builder ────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required List<SnagModel> snags,
    required Map<String, int> serialMap,
    required String projectName,
    String? filterLabel,
  }) async {
    final pdf = pw.Document();

    // ── Colours ───────────────────────────────────────────────────────────
    const headerBg  = PdfColor.fromInt(0xFF1A3A5C);
    const altRowBg  = PdfColor.fromInt(0xFFF5F7FA);
    const white     = PdfColors.white;
    const bodyText  = PdfColor.fromInt(0xFF212529);
    const mutedText = PdfColor.fromInt(0xFF6C757D);

    // ── Severity colours ─────────────────────────────────────────────────
    PdfColor sevColor(SnagSeverity s) => switch (s) {
          SnagSeverity.redLine => const PdfColor.fromInt(0xFFB71C1C),
          SnagSeverity.major   => const PdfColor.fromInt(0xFFE65100),
          SnagSeverity.minor   => const PdfColor.fromInt(0xFFF9A825),
        };

    // ── Status colours ───────────────────────────────────────────────────
    PdfColor statusColor(SnagStatus s) => switch (s) {
          SnagStatus.open       => const PdfColor.fromInt(0xFFE65100),
          SnagStatus.inProgress => const PdfColor.fromInt(0xFF1565C0),
          SnagStatus.closed     => const PdfColor.fromInt(0xFF2E7D32),
          SnagStatus.void_      => const PdfColor.fromInt(0xFF78909C),
        };

    // ── Stats ─────────────────────────────────────────────────────────────
    final now         = DateTime.now();
    final dateStr     = DateFormat('dd MMM yyyy, HH:mm').format(now);
    final byStatus    = <SnagStatus, int>{};
    final bySeverity  = <SnagSeverity, int>{};
    for (final s in snags) {
      byStatus[s.status]     = (byStatus[s.status] ?? 0) + 1;
      bySeverity[s.severity] = (bySeverity[s.severity] ?? 0) + 1;
    }

    // ── Column widths (points, A4 portrait = 595pt wide, 72pt margins) ────
    // Available width ≈ 451pt
    const colWidths = [
      30.0,  // #
      52.0,  // Date
      72.0,  // Location / Floor
      55.0,  // Unit
      60.0,  // Trade
      112.0, // Description (widest)
      40.0,  // Severity
      30.0,  // Status
    ];

    // ── Fonts ────────────────────────────────────────────────────────────
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfB = await PdfGoogleFonts.notoSansBold();

    // Helper builders
    pw.TextStyle bodyStyle({bool bold = false, PdfColor? color, double size = 7}) =>
        pw.TextStyle(
          font: bold ? ttfB : ttf,
          fontSize: size,
          color: color ?? bodyText,
        );

    pw.Widget headerCell(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: ttfB, fontSize: 7, color: white),
          ),
        );

    pw.Widget dataCell(String text,
            {bool bold = false, PdfColor? color, int maxLines = 3}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            text,
            maxLines: maxLines,
            overflow: pw.TextOverflow.clip,
            style: bodyStyle(bold: bold, color: color),
          ),
        );

    pw.Widget badge(String text, PdfColor bg) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: ttfB, fontSize: 6, color: white),
          ),
        );

    // ── Summary row builder ───────────────────────────────────────────────
    pw.Widget summaryCard(String label, String value, PdfColor accent) =>
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
            color: altRowBg,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      font: ttfB, fontSize: 16, color: accent)),
              pw.SizedBox(height: 2),
              pw.Text(label,
                  style: pw.TextStyle(
                      font: ttf, fontSize: 8, color: mutedText)),
            ],
          ),
        );

    // ── Page builder ─────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Title bar ────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              color: headerBg,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PPQA Snag Report',
                        style: pw.TextStyle(
                            font: ttfB, fontSize: 14, color: white),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        projectName,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 9, color: white),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(dateStr,
                          style: pw.TextStyle(
                              font: ttf, fontSize: 8, color: white)),
                      if (filterLabel != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Filter: $filterLabel',
                            style: pw.TextStyle(
                                font: ttf, fontSize: 7, color: white)),
                      ],
                      pw.SizedBox(height: 2),
                      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                          style: pw.TextStyle(
                              font: ttf, fontSize: 7, color: white)),
                    ],
                  ),
                ],
              ),
            ),
            // Only show summary section on page 1
            if (ctx.pageNumber == 1) ...[
              pw.SizedBox(height: 12),
              // ── Summary cards ─────────────────────────────────────
              pw.Row(
                children: [
                  pw.Expanded(
                    child: summaryCard('Total Snags', '${snags.length}',
                        const PdfColor.fromInt(0xFF1A3A5C)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: summaryCard(
                      'Open',
                      '${byStatus[SnagStatus.open] ?? 0}',
                      statusColor(SnagStatus.open),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: summaryCard(
                      'In Progress',
                      '${byStatus[SnagStatus.inProgress] ?? 0}',
                      statusColor(SnagStatus.inProgress),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: summaryCard(
                      'Closed',
                      '${byStatus[SnagStatus.closed] ?? 0}',
                      statusColor(SnagStatus.closed),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: summaryCard(
                      'Red Line',
                      '${bySeverity[SnagSeverity.redLine] ?? 0}',
                      sevColor(SnagSeverity.redLine),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              // ── Table header ──────────────────────────────────────
              pw.Container(
                color: headerBg,
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: colWidths[0], child: headerCell('#')),
                    pw.SizedBox(width: colWidths[1], child: headerCell('Date')),
                    pw.SizedBox(width: colWidths[2], child: headerCell('Location / Floor')),
                    pw.SizedBox(width: colWidths[3], child: headerCell('Unit')),
                    pw.SizedBox(width: colWidths[4], child: headerCell('Trade')),
                    pw.Expanded(child: headerCell('Description')),
                    pw.SizedBox(width: colWidths[6], child: headerCell('Severity')),
                    pw.SizedBox(width: colWidths[7], child: headerCell('Status')),
                  ],
                ),
              ),
            ],
            // On subsequent pages: just the table header
            if (ctx.pageNumber > 1)
              pw.Container(
                color: headerBg,
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: colWidths[0], child: headerCell('#')),
                    pw.SizedBox(width: colWidths[1], child: headerCell('Date')),
                    pw.SizedBox(width: colWidths[2], child: headerCell('Location / Floor')),
                    pw.SizedBox(width: colWidths[3], child: headerCell('Unit')),
                    pw.SizedBox(width: colWidths[4], child: headerCell('Trade')),
                    pw.Expanded(child: headerCell('Description')),
                    pw.SizedBox(width: colWidths[6], child: headerCell('Severity')),
                    pw.SizedBox(width: colWidths[7], child: headerCell('Status')),
                  ],
                ),
              ),
          ],
        ),
        build: (ctx) => [
          // ── Snag rows ────────────────────────────────────────────────
          if (snags.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Center(
                child: pw.Text(
                  'No snags match the selected filters.',
                  style: bodyStyle(color: mutedText, size: 10),
                ),
              ),
            )
          else
            ...snags.asMap().entries.map((entry) {
              final idx  = entry.key;
              final snag = entry.value;
              final serial = serialMap[snag.id];
              final isAlt = idx.isEven;

              final locationLine =
                  [snag.location, if (snag.floorNo.isNotEmpty) 'Fl ${snag.floorNo}']
                      .join(' / ');
              final unitLine = [
                snag.flatNo,
                if (snag.room.isNotEmpty) snag.room,
              ].where((s) => s.isNotEmpty).join(', ');

              return pw.Container(
                color: isAlt ? altRowBg : white,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: colWidths[0],
                      child: dataCell(serial != null ? '#$serial' : '—',
                          bold: true,
                          color: const PdfColor.fromInt(0xFF1A3A5C)),
                    ),
                    pw.SizedBox(
                      width: colWidths[1],
                      child: dataCell(
                          DateFormat('dd/MM/yy').format(snag.createdAt)),
                    ),
                    pw.SizedBox(
                      width: colWidths[2],
                      child: dataCell(locationLine),
                    ),
                    pw.SizedBox(
                      width: colWidths[3],
                      child: dataCell(unitLine.isEmpty ? '—' : unitLine),
                    ),
                    pw.SizedBox(
                      width: colWidths[4],
                      child: dataCell(snag.trade),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(snag.defectDescription,
                                maxLines: 3,
                                overflow: pw.TextOverflow.clip,
                                style: bodyStyle()),
                            if (snag.notes != null &&
                                snag.notes!.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text('Note: ${snag.notes}',
                                  maxLines: 2,
                                  overflow: pw.TextOverflow.clip,
                                  style: bodyStyle(
                                      color: mutedText, size: 6)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: colWidths[6],
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: badge(snag.severity.label,
                            sevColor(snag.severity)),
                      ),
                    ),
                    pw.SizedBox(
                      width: colWidths[7],
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: badge(snag.status.label,
                            statusColor(snag.status)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Divider(color: mutedText, thickness: 0.3),
        ),
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }
}
