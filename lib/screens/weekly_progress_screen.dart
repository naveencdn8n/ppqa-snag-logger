import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

class WeeklyProgressScreen extends StatelessWidget {
  const WeeklyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weeks = context.watch<AppState>().getSnagsByWeek();

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Weekly Progress', showBack: true),
      body: weeks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 72, color: Color(0xFFCED4DA)),
                  SizedBox(height: 16),
                  Text(
                    'No weekly data yet.\nLog snags to see progress here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: weeks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final week = weeks[i];
                final weekLabel =
                    'Week of ${DateFormat('MMM d, y').format(week.weekStart)}';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Week header ──────────────────────────────────────
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Text(
                              weekLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${week.total} total',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Status row ───────────────────────────────────────
                        Row(
                          children: [
                            _WeekStat(
                                label: 'Open',
                                value: week.open,
                                color: AppTheme.statusOpen),
                            _WeekStat(
                                label: 'In Progress',
                                value: week.inProgress,
                                color: AppTheme.statusInProgress),
                            _WeekStat(
                                label: 'Closed',
                                value: week.closed,
                                color: AppTheme.statusClosed),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Severity row ─────────────────────────────────────
                        Row(
                          children: [
                            _WeekStat(
                                label: 'Red Line Open',
                                value: week.redLineOpen,
                                color: AppTheme.severityRedLine),
                            _WeekStat(
                                label: 'Major Open',
                                value: week.majorOpen,
                                color: AppTheme.severityMajor),
                            _WeekStat(
                                label: 'Minor Open',
                                value: week.minorOpen,
                                color: AppTheme.severityMinor),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Progress bar ─────────────────────────────────────
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: week.percentClosed / 100,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE9ECEF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.statusClosed),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${week.percentClosed.toStringAsFixed(1)}% closed this week',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.statusClosed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }
}
