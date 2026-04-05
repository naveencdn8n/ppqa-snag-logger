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

class _MyTasksScreenState extends State<MyTasksScreen> {
  String? _selectedLocation;
  String? _selectedFloor;
  SnagStatus? _selectedStatus; // null = All

  List<String> _floorsFor(AppState appState) {
    if (_selectedLocation == null) return [];
    final loc = appState.locations
        .where((l) => l.name == _selectedLocation)
        .firstOrNull;
    return loc?.floors ?? [];
  }

  List<SnagModel> _applyFilters(List<SnagModel> mine) {
    return mine.where((s) {
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myName = appState.currentUser?.username ?? '';
    final mySnags = appState.getMySnags(myName);
    final filtered = _applyFilters(mySnags);

    final locationNames = appState.locations.map((l) => l.name).toList();
    final floors = _floorsFor(appState);

    return Scaffold(
      appBar: const PPQAAppBar(title: 'My Tasks', showBack: true),
      body: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
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
                            : (val) => setState(() => _selectedFloor = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Status chips
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

          // ── Count bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} of ${mySnags.length} task${mySnags.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasFilter)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
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

          // ── Task list ───────────────────────────────────────────────────
          Expanded(
            child: mySnags.isEmpty
                ? const _EmptyState()
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks match the selected filters.',
                          style: TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final snag = filtered[i];
                          return _TaskCard(
                            snag: snag,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SnagDetailScreen(snag: snag),
                              ),
                            ),
                            onChangeStatus: () =>
                                _showStatusSheet(context, snag),
                          );
                        },
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
    required this.onTap,
    required this.onChangeStatus,
  });

  final SnagModel snag;
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: snag.status),
                ],
              ),
              const SizedBox(height: 6),
              // Location row
              Text(
                '${snag.location}  ·  Floor ${snag.floorNo}  ·  ${snag.flatNo}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${snag.trade}  ·  ${snag.element}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 10),
              // Action row
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
            // Header
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
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6C757D),
              ),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 72, color: Color(0xFFCED4DA)),
          SizedBox(height: 16),
          Text(
            'You have no snags logged yet.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Snags you log will appear here.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
          ),
        ],
      ),
    );
  }
}
