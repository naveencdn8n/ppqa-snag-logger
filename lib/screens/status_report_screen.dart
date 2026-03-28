import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/stat_card.dart';

class StatusReportScreen extends StatelessWidget {
  const StatusReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Status Report', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top summary row ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Snags',
                    value: state.totalSnags.toString(),
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: '% Closed',
                    value: '${state.percentClosed.toStringAsFixed(1)}%',
                    color: AppTheme.statusClosed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Status breakdown grid ──────────────────────────────────────
            const _SectionLabel(text: 'BY STATUS'),
            const SizedBox(height: 8),
            _StatGrid(
              items: [
                _StatItem(
                  label: 'Open Snags',
                  value: state.openSnags.toString(),
                  color: AppTheme.statusOpen,
                ),
                _StatItem(
                  label: 'In Progress',
                  value: state.inProgressSnags.toString(),
                  color: AppTheme.statusInProgress,
                ),
                _StatItem(
                  label: 'Closed Snags',
                  value: state.closedSnags.toString(),
                  color: AppTheme.statusClosed,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Severity breakdown grid ────────────────────────────────────
            const _SectionLabel(text: 'OPEN BY SEVERITY'),
            const SizedBox(height: 8),
            _StatGrid(
              items: [
                _StatItem(
                  label: 'Red Line Open',
                  value: state.redLineOpen.toString(),
                  color: AppTheme.severityRedLine,
                ),
                _StatItem(
                  label: 'Major Open',
                  value: state.majorOpen.toString(),
                  color: AppTheme.severityMajor,
                ),
                _StatItem(
                  label: 'Minor Open',
                  value: state.minorOpen.toString(),
                  color: AppTheme.severityMinor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Progress bar ───────────────────────────────────────────────
            if (state.totalSnags > 0) ...[
              const _SectionLabel(text: 'CLOSURE PROGRESS'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Snags Closed',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            '${state.closedSnags} / ${state.totalSnags}',
                            style: const TextStyle(
                                color: Color(0xFF6C757D), fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: state.percentClosed / 100,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFE9ECEF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.statusClosed),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.percentClosed.toStringAsFixed(1)}% closure rate',
                        style: const TextStyle(
                            color: AppTheme.statusClosed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6C757D),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final isLast = items.last == item;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: StatCard(
              label: item.label,
              value: item.value,
              color: item.color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
