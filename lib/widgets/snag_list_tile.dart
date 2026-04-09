import 'package:flutter/material.dart';
import '../models/snag_model.dart';
import '../models/app_enums.dart';

/// A list tile representing a single snag entry.
/// Pass [serialNumber] to show a stable #N badge (oldest snag = #1).
class SnagListTile extends StatelessWidget {
  const SnagListTile({
    super.key,
    required this.snag,
    this.serialNumber,
  });

  final SnagModel snag;
  final int? serialNumber;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _SeverityAvatar(severity: snag.severity),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Serial number badge ────────────────────────────────────────
            if (serialNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6, top: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A5C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: const Color(0xFF1A3A5C).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '#$serialNumber',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A3A5C),
                    fontFamily: 'monospace',
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            // ── Description ────────────────────────────────────────────────
            Expanded(
              child: Text(
                snag.defectDescription,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              snag.location,
              if (snag.floorNo.isNotEmpty) 'Floor ${snag.floorNo}',
              if (snag.flatNo.isNotEmpty) snag.flatNo,
              if (snag.room.isNotEmpty) snag.room,
              if (snag.trade.isNotEmpty) snag.trade,
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: _StatusChip(status: snag.status),
      ),
    );
  }
}

class _SeverityAvatar extends StatelessWidget {
  const _SeverityAvatar({required this.severity});
  final SnagSeverity severity;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: severity.color.withValues(alpha: 0.15),
      child: Icon(
        _iconFor(severity),
        color: severity.color,
        size: 22,
      ),
    );
  }

  IconData _iconFor(SnagSeverity s) {
    switch (s) {
      case SnagSeverity.redLine: return Icons.block;
      case SnagSeverity.major:   return Icons.warning_amber;
      case SnagSeverity.minor:   return Icons.info_outline;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SnagStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
