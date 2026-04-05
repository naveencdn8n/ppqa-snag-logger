import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/snag_model.dart';
import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/ppqa_dropdown.dart';
import '../widgets/snag_list_tile.dart';
import 'snag_detail_screen.dart';

class OpenSnagsScreen extends StatefulWidget {
  const OpenSnagsScreen({super.key});

  @override
  State<OpenSnagsScreen> createState() => _OpenSnagsScreenState();
}

class _OpenSnagsScreenState extends State<OpenSnagsScreen> {
  String? _selectedLocation;
  String? _selectedFloor;
  // null = All statuses; otherwise filter to this status
  SnagStatus? _selectedStatus = SnagStatus.open; // default: Open

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<String> _floorsFor(AppState appState) {
    if (_selectedLocation == null) return [];
    final loc = appState.locations
        .where((l) => l.name == _selectedLocation)
        .firstOrNull;
    return loc?.floors ?? [];
  }

  List<SnagModel> _applyFilters(List<SnagModel> all) {
    return all.where((s) {
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
        _selectedStatus = SnagStatus.open;
      });

  bool get _hasActiveFilter =>
      _selectedLocation != null ||
      _selectedFloor != null ||
      _selectedStatus != SnagStatus.open;

  // ── Grouping ──────────────────────────────────────────────────────────────

  /// Groups snags: location → floor → snags
  Map<String, Map<String, List<SnagModel>>> _group(List<SnagModel> snags) {
    final Map<String, Map<String, List<SnagModel>>> result = {};
    for (final s in snags) {
      final loc = s.location.isEmpty ? 'Unknown Location' : s.location;
      final floor = s.floorNo.isEmpty ? '—' : 'Floor ${s.floorNo}';
      result.putIfAbsent(loc, () => {});
      result[loc]!.putIfAbsent(floor, () => []);
      result[loc]![floor]!.add(s);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allSnags = appState.snags;
    final filtered = _applyFilters(allSnags.toList());
    final grouped = _group(filtered);

    final locationNames = appState.locations.map((l) => l.name).toList();
    final floors = _floorsFor(appState);

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Open Snags'),
      body: Column(
        children: [
          // ── Filter bar ───────────────────────────────────────────────────
          Container(
            color: const Color(0xFFECEFF4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Row 1: Location + Floor dropdowns
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
                          _selectedFloor = null; // reset floor when location changes
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

                // Row 2: Status chips
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusChip(
                          label: 'All',
                          selected: _selectedStatus == null,
                          color: const Color(0xFF546E7A),
                          onTap: () =>
                              setState(() => _selectedStatus = null),
                        ),
                        const SizedBox(width: 8),
                        for (final status in SnagStatus.values) ...[
                          _StatusChip(
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

          // ── Results bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} snag${filtered.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasActiveFilter)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Reset'),
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

          // ── Grouped list ─────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(hasSnags: allSnags.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _countItems(grouped),
                    itemBuilder: (_, index) =>
                        _buildItem(context, grouped, index),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Flat index → grouped item builder ────────────────────────────────────

  /// Flattens the nested map into a list of items:
  /// LocationHeader | FloorHeader | SnagTile | SnagTile | FloorHeader | ...
  int _countItems(Map<String, Map<String, List<SnagModel>>> grouped) {
    int count = 0;
    for (final floors in grouped.values) {
      count += 1; // location header
      for (final snags in floors.values) {
        count += 1 + snags.length; // floor header + tiles
      }
    }
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    Map<String, Map<String, List<SnagModel>>> grouped,
    int targetIndex,
  ) {
    int i = 0;
    for (final locEntry in grouped.entries) {
      if (i == targetIndex) return _LocationHeader(label: locEntry.key);
      i++;
      for (final floorEntry in locEntry.value.entries) {
        if (i == targetIndex) return _FloorHeader(label: floorEntry.key);
        i++;
        for (final snag in floorEntry.value) {
          if (i == targetIndex) {
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SnagDetailScreen(snag: snag),
                ),
              ),
              child: SnagListTile(snag: snag),
            );
          }
          i++;
        }
      }
    }
    return const SizedBox.shrink();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.apartment, size: 16, color: Color(0xFF1A3A5C)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A3A5C),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xFF1A3A5C), thickness: 0.5)),
        ],
      ),
    );
  }
}

class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF6C757D)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSnags});
  final bool hasSnags;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSnags
                ? Icons.check_circle_outline
                : Icons.format_list_bulleted,
            size: 72,
            color: const Color(0xFFCED4DA),
          ),
          const SizedBox(height: 16),
          Text(
            hasSnags
                ? 'No snags match the selected filters.\nTry changing the status or location.'
                : 'No snags logged yet.\nTap "Log Snag" to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6C757D),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
