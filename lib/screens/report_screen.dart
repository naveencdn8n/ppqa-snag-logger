import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import 'weekly_progress_screen.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PPQAAppBar(title: 'Reports'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ReportSectionHeader(text: 'Snag Analysis'),
          const SizedBox(height: 8),
          _ReportNavTile(
            icon: Icons.warning_amber_outlined,
            iconColor: AppTheme.severityRedLine,
            label: 'Snags by Severity',
            subtitle: 'Red Line / Major / Minor breakdown',
            onTap: () => _showSeveritySheet(context),
          ),
          _ReportNavTile(
            icon: Icons.category_outlined,
            iconColor: AppTheme.secondary,
            label: 'Snags by Trade / Category',
            subtitle: 'Distribution across all trades',
            onTap: () => _showTradeSheet(context),
          ),
          _ReportNavTile(
            icon: Icons.apartment_outlined,
            iconColor: const Color(0xFF6A1B9A),
            label: 'Snags by Tower',
            subtitle: 'Per tower snag counts',
            onTap: () => _showTowerSheet(context),
          ),
          _ReportNavTile(
            icon: Icons.door_front_door_outlined,
            iconColor: const Color(0xFF00695C),
            label: 'Snags by Unit',
            subtitle: 'Per unit snag counts',
            onTap: () => _showUnitSheet(context),
          ),
          const SizedBox(height: 16),
          const _ReportSectionHeader(text: 'Progress Tracking'),
          const SizedBox(height: 8),
          _ReportNavTile(
            icon: Icons.trending_up,
            iconColor: AppTheme.statusClosed,
            label: 'Weekly Progress',
            subtitle: 'Week-by-week snag summary',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const WeeklyProgressScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _showSeveritySheet(BuildContext context) {
    final state = context.read<AppState>();
    final data = {
      'Red Line': state.getSnagsBySeverity(SnagSeverity.redLine).length,
      'Major': state.getSnagsBySeverity(SnagSeverity.major).length,
      'Minor': state.getSnagsBySeverity(SnagSeverity.minor).length,
    };
    final colors = {
      'Red Line': AppTheme.severityRedLine,
      'Major': AppTheme.severityMajor,
      'Minor': AppTheme.severityMinor,
    };
    _showReportSheet(context, 'Snags by Severity', data, colors);
  }

  void _showTradeSheet(BuildContext context) {
    final state = context.read<AppState>();
    final raw = state.snagCountByTrade;
    final data = <String, int>{
      for (final entry in raw.entries) entry.key.label: entry.value
    };
    _showReportSheet(context, 'Snags by Trade', data, {});
  }

  void _showTowerSheet(BuildContext context) {
    final state = context.read<AppState>();
    final towerLocations = [
      SnagLocation.tower1,
      SnagLocation.tower2,
      SnagLocation.tower3,
      SnagLocation.tower4,
    ];
    final data = <String, int>{
      for (final loc in towerLocations)
        loc.label: state.getSnagsByLocation(loc).length,
    };
    _showReportSheet(context, 'Snags by Tower', data, {});
  }

  void _showUnitSheet(BuildContext context) {
    final state = context.read<AppState>();
    final raw = state.snagCountByUnit;
    final data = <String, int>{
      for (final entry in raw.entries) entry.key.label: entry.value
    };
    _showReportSheet(context, 'Snags by Unit', data, {});
  }

  void _showReportSheet(
    BuildContext context,
    String title,
    Map<String, int> data,
    Map<String, Color> colors,
  ) {
    final total = data.values.fold(0, (a, b) => a + b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            final entries = data.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Column(
              children: [
                // Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCED4DA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$total total',
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No data available.\nLog some snags first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6C757D)),
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final entry = entries[i];
                            final pct = total == 0
                                ? 0.0
                                : entry.value / total;
                            final barColor = colors[entry.key] ??
                                AppTheme.secondary;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} (${(pct * 100).toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6C757D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor:
                                          const Color(0xFFE9ECEF),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              barColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader({required this.text});
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

class _ReportNavTile extends StatelessWidget {
  const _ReportNavTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF6C757D)),
        onTap: onTap,
      ),
    );
  }
}
