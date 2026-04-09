import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class _SnagStats {
  final int total;
  final int open;
  final int inProgress;
  final int closed;
  final int void_;

  const _SnagStats({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.closed,
    required this.void_,
  });

  double get closurePct => total == 0 ? 0 : (closed / total) * 100;

  factory _SnagStats.from(List<SnagModel> snags) {
    return _SnagStats(
      total:      snags.length,
      open:       snags.where((s) => s.status == SnagStatus.open).length,
      inProgress: snags.where((s) => s.status == SnagStatus.inProgress).length,
      closed:     snags.where((s) => s.status == SnagStatus.closed).length,
      void_:      snags.where((s) => s.status == SnagStatus.void_).length,
    );
  }
}

// Group snags into nested map: tower → floor → unit → [snags]
Map<String, Map<String, Map<String, List<SnagModel>>>> _buildTree(
    List<SnagModel> snags) {
  final Map<String, Map<String, Map<String, List<SnagModel>>>> tree = {};
  for (final s in snags) {
    final tower = s.location.isEmpty ? '(No Tower)' : s.location;
    final floor = s.floorNo.isEmpty  ? '(No Floor)' : s.floorNo;
    final unit  = s.flatNo.isEmpty   ? '(No Unit)'  : s.flatNo;
    tree.putIfAbsent(tower, () => {});
    tree[tower]!.putIfAbsent(floor, () => {});
    tree[tower]![floor]!.putIfAbsent(unit, () => []);
    tree[tower]![floor]![unit]!.add(s);
  }
  return tree;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TowerReportScreen extends StatelessWidget {
  const TowerReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snags = context.watch<AppState>().snags;
    final tree  = _buildTree(snags);

    // Sort towers alphabetically
    final towers = tree.keys.toList()..sort();

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Tower Report', showBack: true),
      backgroundColor: AppTheme.background,
      body: snags.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Project-level header bar ──────────────────────────────────
                _ProjectSummaryBar(stats: _SnagStats.from(snags)),
                const SizedBox(height: 12),

                // ── One card per tower ────────────────────────────────────────
                ...towers.map(
                  (tower) => _TowerCard(
                    towerName: tower,
                    floorMap:  tree[tower]!,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Project-level summary bar ────────────────────────────────────────────────

class _ProjectSummaryBar extends StatelessWidget {
  const _ProjectSummaryBar({required this.stats});
  final _SnagStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROJECT OVERVIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(label: 'Total',    value: stats.total,      color: AppTheme.primary),
                _MiniStat(label: 'Open',     value: stats.open,       color: AppTheme.statusOpen),
                _MiniStat(label: 'In Prog',  value: stats.inProgress, color: AppTheme.statusInProgress),
                _MiniStat(label: 'Closed',   value: stats.closed,     color: AppTheme.statusClosed),
                _MiniStat(label: 'Void',     value: stats.void_,      color: const Color(0xFF78909C)),
              ],
            ),
            const SizedBox(height: 12),
            _ClosureBar(stats: stats),
          ],
        ),
      ),
    );
  }
}

// ─── Tower card with floor expansion ─────────────────────────────────────────

class _TowerCard extends StatelessWidget {
  const _TowerCard({
    required this.towerName,
    required this.floorMap,
  });
  final String towerName;
  final Map<String, Map<String, List<SnagModel>>> floorMap;

  @override
  Widget build(BuildContext context) {
    // Build flat list of all snags in this tower
    final allSnags = floorMap.values
        .expand((fm) => fm.values.expand((u) => u))
        .toList();
    final stats = _SnagStats.from(allSnags);

    // Sort floors: numbers first, then alphanumeric
    final floors = floorMap.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_city_outlined,
                color: AppTheme.primary, size: 22),
          ),
          title: Text(
            towerName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTheme.primary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPillRow(stats: stats),
                const SizedBox(height: 6),
                _ClosureBar(stats: stats, compact: true),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF4)),
            ...floors.map((floor) => _FloorRow(
                  floorName: floor,
                  unitMap:   floorMap[floor]!,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Floor row with unit expansion ───────────────────────────────────────────

class _FloorRow extends StatelessWidget {
  const _FloorRow({required this.floorName, required this.unitMap});
  final String floorName;
  final Map<String, List<SnagModel>> unitMap;

  @override
  Widget build(BuildContext context) {
    final allSnags = unitMap.values.expand((u) => u).toList();
    final stats    = _SnagStats.from(allSnags);

    final units = unitMap.keys.toList()..sort();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 56, right: 16, top: 2, bottom: 2),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.layers_outlined,
              color: AppTheme.secondary, size: 18),
        ),
        title: Text(
          'Floor $floorName',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: Color(0xFF212529),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 4),
          child: _StatusPillRow(stats: stats, small: true),
        ),
        children: [
          const Divider(height: 1, thickness: 1,
              color: Color(0xFFECEFF4), indent: 56),
          ...units.map((unit) => _UnitRow(
                unitName: unit,
                snags:    unitMap[unit]!,
              )),
        ],
      ),
    );
  }
}

// ─── Unit row (leaf) ──────────────────────────────────────────────────────────

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unitName, required this.snags});
  final String unitName;
  final List<SnagModel> snags;

  @override
  Widget build(BuildContext context) {
    final stats = _SnagStats.from(snags);

    // Choose badge color by worst open status
    Color unitColor = AppTheme.statusClosed;
    if (stats.open > 0)       unitColor = AppTheme.statusOpen;
    else if (stats.inProgress > 0) unitColor = AppTheme.statusInProgress;

    // Readiness label
    final String readiness;
    if (stats.open == 0 && stats.inProgress == 0) {
      readiness = '✓ Ready';
    } else if (stats.open > 0) {
      readiness = '${stats.open} open';
    } else {
      readiness = '${stats.inProgress} in prog.';
    }

    return Container(
      color: const Color(0xFFFAFAFA),
      child: Padding(
        padding: const EdgeInsets.only(left: 96, right: 16, top: 8, bottom: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: unitColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.door_front_door_outlined,
                  color: unitColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit $unitName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.total} snag${stats.total == 1 ? '' : 's'}  ·  '
                    'Closed ${stats.closed}  ·  '
                    '${stats.closurePct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF6C757D)),
                  ),
                ],
              ),
            ),
            // Readiness badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: unitColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: unitColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                readiness,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: unitColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int    value;
  final Color  color;

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
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF6C757D)),
          ),
        ],
      ),
    );
  }
}

class _StatusPillRow extends StatelessWidget {
  const _StatusPillRow({required this.stats, this.small = false});
  final _SnagStats stats;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fs = small ? 10.0 : 11.0;
    return Wrap(
      spacing: 5,
      children: [
        if (stats.open > 0)
          _pill('${stats.open} Open', AppTheme.statusOpen, fs),
        if (stats.inProgress > 0)
          _pill('${stats.inProgress} In Prog', AppTheme.statusInProgress, fs),
        if (stats.closed > 0)
          _pill('${stats.closed} Closed', AppTheme.statusClosed, fs),
        if (stats.void_ > 0)
          _pill('${stats.void_} Void', const Color(0xFF78909C), fs),
      ],
    );
  }

  Widget _pill(String text, Color color, double fs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ClosureBar extends StatelessWidget {
  const _ClosureBar({required this.stats, this.compact = false});
  final _SnagStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pct = stats.closurePct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Closure',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  '${stats.closed} / ${stats.total}  '
                  '(${pct.toStringAsFixed(1)}%)',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6C757D)),
                ),
              ],
            ),
          ),
        Stack(
          children: [
            Container(
              height: compact ? 6 : 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                height: compact ? 6 : 10,
                decoration: BoxDecoration(
                  color: pct >= 80
                      ? AppTheme.statusClosed
                      : pct >= 50
                          ? AppTheme.statusInProgress
                          : AppTheme.statusOpen,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        if (compact)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${pct.toStringAsFixed(0)}% closed  ·  ${stats.total} total',
              style: const TextStyle(
                  fontSize: 10.5, color: Color(0xFF6C757D)),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_city_outlined,
              size: 64, color: Color(0xFFB0BEC5)),
          SizedBox(height: 16),
          Text(
            'No snags logged yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C757D),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Log snags on-site to see\nper-tower breakdown here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFFB0BEC5)),
          ),
        ],
      ),
    );
  }
}
