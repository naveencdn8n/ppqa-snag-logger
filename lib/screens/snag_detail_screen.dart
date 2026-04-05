import 'package:flutter/material.dart';
import '../models/snag_model.dart';
import '../models/app_enums.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import 'package:intl/intl.dart';

class SnagDetailScreen extends StatelessWidget {
  const SnagDetailScreen({super.key, required this.snag});

  final SnagModel snag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PPQAAppBar(title: 'Snag Detail'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status + Severity header card ─────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Severity icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: snag.severity.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForSeverity(snag.severity),
                        color: snag.severity.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snag.defectDescription,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212529),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _Chip(
                                label: snag.severity.label,
                                color: snag.severity.color,
                              ),
                              const SizedBox(width: 8),
                              _Chip(
                                label: snag.status.label,
                                color: snag.status.color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Location details ──────────────────────────────────────────
            _SectionCard(
              title: 'Location',
              icon: Icons.location_on_outlined,
              children: [
                _DetailRow(label: 'Tower / Location', value: snag.location),
                _DetailRow(label: 'Floor',            value: snag.floorNo),
                _DetailRow(label: 'Unit / Flat',      value: snag.flatNo),
                if (snag.room.isNotEmpty)
                  _DetailRow(label: 'Room',           value: snag.room),
                _DetailRow(label: 'Element',          value: snag.element),
              ],
            ),
            const SizedBox(height: 12),

            // ── Defect details ────────────────────────────────────────────
            _SectionCard(
              title: 'Defect',
              icon: Icons.build_outlined,
              children: [
                _DetailRow(label: 'Trade', value: snag.trade),
                _DetailRow(
                    label: 'Description', value: snag.defectDescription),
              ],
            ),
            const SizedBox(height: 12),

            // ── Log info ──────────────────────────────────────────────────
            _SectionCard(
              title: 'Logged By',
              icon: Icons.person_outline,
              children: [
                _DetailRow(label: 'Inspector', value: snag.createdBy),
                _DetailRow(
                  label: 'Date & Time',
                  value: DateFormat('dd MMM yyyy, HH:mm').format(snag.createdAt),
                ),
                if (snag.notes != null && snag.notes!.isNotEmpty)
                  _DetailRow(label: 'Notes', value: snag.notes!),
              ],
            ),

            // ── Evidence media ────────────────────────────────────────────
            if (snag.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Evidence (${snag.mediaUrls.length} file${snag.mediaUrls.length == 1 ? '' : 's'})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: snag.mediaUrls.length,
                        itemBuilder: (_, i) {
                          final url = snag.mediaUrls[i];
                          final isVideo = url.contains('_') &&
                              (url.endsWith('.mp4') ||
                                  url.contains('video'));
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? Container(
                                    color: const Color(0xFF1A3A5C),
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill,
                                          color: Colors.white, size: 32),
                                    ),
                                  )
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFECEFF4),
                                      child: const Icon(Icons.broken_image,
                                          color: Color(0xFFCED4DA)),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _iconForSeverity(SnagSeverity s) {
    switch (s) {
      case SnagSeverity.redLine:
        return Icons.block;
      case SnagSeverity.major:
        return Icons.warning_amber;
      case SnagSeverity.minor:
        return Icons.info_outline;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6C757D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF212529),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
