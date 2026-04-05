import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/ppqa_dropdown.dart';
import 'snag_detail_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Shared filters ──────────────────────────────────────────────────────────
  String? _selectedLocation;
  String? _selectedFloor;
  SnagStatus? _selectedStatus; // null = All

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // rebuild on tab switch
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _floorsFor(AppState appState) {
    if (_selectedLocation == null) return [];
    return appState.locations
            .where((l) => l.name == _selectedLocation)
            .firstOrNull
            ?.floors ??
        [];
  }

  List<SnagModel> _applyFilters(List<SnagModel> source) {
    return source.where((s) {
      if (_selectedLocation != null && s.location != _selectedLocation) {
        return false;
      }
      if (_selectedFloor != null && s.floorNo != _selectedFloor) return false;
      if (_selectedStatus != null && s.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  void _clearFilters() => setState(() {
        _selectedLocation = null;
        _selectedFloor = null;
        _selectedStatus = null;
      });

  bool get _hasFilter =>
      _selectedLocation != null ||
      _selectedFloor != null ||
      _selectedStatus != null;

  // ── Status change bottom sheet ──────────────────────────────────────────────

  void _showStatusSheet(BuildContext context, SnagModel snag) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusSheet(snag: snag),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myName = appState.currentUser?.username ?? '';
    final locationNames = appState.locations.map((l) => l.name).toList();
    final floors = _floorsFor(appState);

    final mySnags = _applyFilters(appState.getMySnags(myName));
    final teamSnags = _applyFilters(appState.getTeamSnags(myName));
    final myTotal = appState.getMySnags(myName).length;
    final teamTotal = appState.getTeamSnags(myName).length;

    // Role-based permission flags
    final canChangeOwn = appState.canChangeOwnStatus;   // inspector + supervisor
    final canChangeAny = appState.canChangeAnyStatus;   // supervisor only

    return Scaffold(
      appBar: PPQAAppBar(
        title: 'Tasks',
        showBack: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 6),
                  const Text('My Snags'),
                  const SizedBox(width: 6),
                  _TabBadge(count: myTotal),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Team'),
                  const SizedBox(width: 6),
                  _TabBadge(count: teamTotal),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Shared filter bar ─────────────────────────────────────────────
          Container(
            color: const Color(0xFFECEFF4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PPQADropdown<String>(
                        label: 'Tower / Location',
                        value: _selectedLocation,
                        items: locationNames,
                        labelBuilder: (l) => l,
                        hint: 'All locations',
                        onChanged: (val) => setState(() {
                          _selectedLocation = val;
                          _selectedFloor = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PPQADropdown<String>(
                        label: 'Floor',
                        value: _selectedFloor,
                        items: floors,
                        labelBuilder: (f) => f,
                        hint: _selectedLocation == null
                            ? 'Select location first'
                            : 'All floors',
                        onChanged: floors.isEmpty
                            ? null
                            : (val) =>
                                setState(() => _selectedFloor = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _selectedStatus == null,
                          color: const Color(0xFF546E7A),
                          onTap: () =>
                              setState(() => _selectedStatus = null),
                        ),
                        const SizedBox(width: 8),
                        for (final status in SnagStatus.values) ...[
                          _FilterChip(
                            label: status.label,
                            selected: _selectedStatus == status,
                            color: status.color,
                            onTap: () =>
                                setState(() => _selectedStatus = status),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Count + clear bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tabController.index == 0
                      ? '${mySnags.length} of $myTotal snag${myTotal == 1 ? '' : 's'}'
                      : '${teamSnags.length} of $teamTotal snag${teamTotal == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasFilter)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear filters'),
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: My Snags ──────────────────────────────────────
                _MySnagsList(
                  snags: mySnags,
                  total: myTotal,
                  canChangeStatus: canChangeOwn,
                  onTap: (snag) => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => SnagDetailScreen(snag: snag)),
                  ),
                  onChangeStatus: (snag) => _showStatusSheet(context, snag),
                ),

                // ── Tab 2: Team Snags ────────────────────────────────────
                _TeamSnagsList(
                  snags: teamSnags,
                  total: teamTotal,
                  resolveInspector: appState.resolveInspector,
                  canChangeStatus: canChangeAny,
                  onTap: (snag) => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => SnagDetailScreen(snag: snag)),
                  ),
                  onChangeStatus: (snag) => _showStatusSheet(context, snag),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── My Snags list ─────────────────────────────────────────────────────────────

class _MySnagsList extends StatelessWidget {
  const _MySnagsList({
    required this.snags,
    required this.total,
    required this.canChangeStatus,
    required this.onTap,
    required this.onChangeStatus,
  });

  final List<SnagModel> snags;
  final int total;
  final bool canChangeStatus;
  final void Function(SnagModel) onTap;
  final void Function(SnagModel) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const _EmptyState(
        icon: Icons.task_alt,
        message: 'You have no snags logged yet.',
        sub: 'Snags you log will appear here.',
      );
    }
    if (snags.isEmpty) {
      return const _NoMatchState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: snags.length,
      itemBuilder: (_, i) {
        final snag = snags[i];
        return _TaskCard(
          snag: snag,
          showInspector: false,
          canChangeStatus: canChangeStatus,
          onTap: () => onTap(snag),
          onChangeStatus: () => onChangeStatus(snag),
        );
      },
    );
  }
}

// ── Team Snags list (grouped by inspector) ────────────────────────────────────

class _TeamSnagsList extends StatelessWidget {
  const _TeamSnagsList({
    required this.snags,
    required this.total,
    required this.resolveInspector,
    required this.canChangeStatus,
    required this.onTap,
    required this.onChangeStatus,
  });

  final List<SnagModel> snags;
  final int total;
  final String Function(String) resolveInspector;
  final bool canChangeStatus;
  final void Function(SnagModel) onTap;
  final void Function(SnagModel) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const _EmptyState(
        icon: Icons.group_outlined,
        message: 'No team snags found.',
        sub: 'Snags logged by your team will appear here.',
      );
    }
    if (snags.isEmpty) {
      return const _NoMatchState();
    }

    // Group snags by resolved inspector display name, sorted alphabetically
    final Map<String, List<SnagModel>> grouped = {};
    for (final snag in snags) {
      final name = resolveInspector(snag.createdBy);
      grouped.putIfAbsent(name, () => []).add(snag);
    }
    final sortedNames = grouped.keys.toList()..sort();

    // Build flat list: [header, card, card, ..., header, card, ...]
    final items = <_ListItem>[];
    for (final name in sortedNames) {
      final group = grouped[name]!;
      items.add(_HeaderItem(name: name, count: group.length));
      for (final snag in group) {
        items.add(_SnagItem(snag: snag));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _HeaderItem) {
          return _InspectorHeader(name: item.name, count: item.count);
        }
        final snag = (item as _SnagItem).snag;
        return _TaskCard(
          snag: snag,
          showInspector: false, // name already shown in group header
          canChangeStatus: canChangeStatus,
          onTap: () => onTap(snag),
          onChangeStatus: () => onChangeStatus(snag),
        );
      },
    );
  }
}

// ── List item types (sealed pattern) ─────────────────────────────────────────

abstract class _ListItem {}

class _HeaderItem extends _ListItem {
  final String name;
  final int count;
  _HeaderItem({required this.name, required this.count});
}

class _SnagItem extends _ListItem {
  final SnagModel snag;
  _SnagItem({required this.snag});
}

// ── Inspector group header ────────────────────────────────────────────────────

class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count snag${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.snag,
    required this.showInspector,
    required this.canChangeStatus,
    required this.onTap,
    required this.onChangeStatus,
  });

  final SnagModel snag;
  final bool showInspector;
  final bool canChangeStatus;
  final VoidCallback onTap;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      snag.defectDescription,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF212529),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: snag.status),
                ],
              ),
              const SizedBox(height: 6),
              // Location
              Text(
                [
                  snag.location,
                  'Floor ${snag.floorNo}',
                  snag.flatNo,
                  if (snag.room.isNotEmpty) snag.room,
                ].join('  ·  '),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 4),
              // Trade / Element
              Text(
                '${snag.trade}  ·  ${snag.element}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                ),
              ),
              if (showInspector) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 4),
                    Text(
                      snag.createdBy,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              if (canChangeStatus) ...[
                const SizedBox(height: 10),
                // Action row — only shown when user has permission
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Change Status'),
                      onPressed: onChangeStatus,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status change bottom sheet ────────────────────────────────────────────────

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.snag});
  final SnagModel snag;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  bool _saving = false;

  Future<void> _save(SnagStatus newStatus) async {
    if (_saving || newStatus == widget.snag.status) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().updateSnagStatus(widget.snag.id, newStatus);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.label}'),
            backgroundColor: newStatus.color,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Change Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.snag.defectDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final status in SnagStatus.values)
                _StatusOption(
                  status: status,
                  isCurrent: widget.snag.status == status,
                  onTap: () => _save(status),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.isCurrent,
    required this.onTap,
  });

  final SnagStatus status;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: status.color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        status.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          color: isCurrent ? status.color : const Color(0xFF212529),
        ),
      ),
      trailing: isCurrent
          ? Icon(Icons.check_circle, color: status.color, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

// ── Tab badge ─────────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  final IconData icon;
  final String message;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: const Color(0xFFCED4DA)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
          ),
        ],
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No snags match the selected filters.',
        style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
      ),
    );
  }
}
