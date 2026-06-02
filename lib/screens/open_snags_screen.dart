import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../services/pdf_export_service.dart';
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
  // ── Export state ──────────────────────────────────────────────────────────
  bool _isPdfExporting = false;

  // ── Filter state ──────────────────────────────────────────────────────────
  String _searchQuery = '';
  final _searchController = TextEditingController();

  String? _selectedLocation;
  String? _selectedFloor;
  String? _selectedTrade;
  SnagStatus? _selectedStatus = SnagStatus.open; // default: Open only
  SnagSeverity? _selectedSeverity;              // null = Any severity

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<String> _floorsFor(AppState appState) {
    if (_selectedLocation == null) return [];
    final loc = appState.locations
        .where((l) => l.name == _selectedLocation)
        .firstOrNull;
    return loc?.floors ?? [];
  }

  List<SnagModel> _applyFilters(List<SnagModel> all) {
    final query = _searchQuery.trim().toLowerCase();
    return all.where((s) {
      if (_selectedLocation != null && s.location != _selectedLocation) return false;
      if (_selectedFloor != null && s.floorNo != _selectedFloor) return false;
      if (_selectedStatus != null && s.status != _selectedStatus) return false;
      if (_selectedSeverity != null && s.severity != _selectedSeverity) return false;
      if (_selectedTrade != null && s.trade != _selectedTrade) return false;
      if (query.isNotEmpty) {
        final hit =
            s.defectDescription.toLowerCase().contains(query) ||
            s.trade.toLowerCase().contains(query) ||
            s.flatNo.toLowerCase().contains(query) ||
            s.element.toLowerCase().contains(query) ||
            s.floorNo.toLowerCase().contains(query) ||
            s.room.toLowerCase().contains(query) ||
            (s.notes?.toLowerCase().contains(query) ?? false);
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedLocation = null;
      _selectedFloor = null;
      _selectedTrade = null;
      _selectedStatus = SnagStatus.open;
      _selectedSeverity = null;
    });
  }

  bool get _hasActiveFilter =>
      _searchQuery.isNotEmpty ||
      _selectedLocation != null ||
      _selectedFloor != null ||
      _selectedTrade != null ||
      _selectedStatus != SnagStatus.open ||
      _selectedSeverity != null;

  int get _activeFilterCount {
    int n = 0;
    if (_searchQuery.isNotEmpty) n++;
    if (_selectedLocation != null) n++;
    if (_selectedFloor != null) n++;
    if (_selectedTrade != null) n++;
    if (_selectedStatus != SnagStatus.open) n++;
    if (_selectedSeverity != null) n++;
    return n;
  }

  // ── PDF export ───────────────────────────────────────────────────────────

  Future<void> _exportToPdf(
      List<SnagModel> filtered, Map<String, int> serialMap, AppState appState) async {
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No snags to export — adjust your filters first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPdfExporting = true);
    try {
      // Build a human-readable filter label for the PDF header.
      final parts = <String>[];
      if (_selectedStatus != null)   parts.add(_selectedStatus!.label);
      if (_selectedSeverity != null) parts.add(_selectedSeverity!.label);
      if (_selectedLocation != null) parts.add(_selectedLocation!);
      if (_selectedFloor != null)    parts.add('Floor $_selectedFloor');
      if (_selectedTrade != null)    parts.add(_selectedTrade!);
      if (_searchQuery.isNotEmpty)   parts.add('"$_searchQuery"');
      final filterLabel = parts.isEmpty ? 'All snags' : parts.join(' · ');

      await PdfExportService.shareSnagReport(
        snags: filtered,
        serialMap: serialMap,
        projectName: appState.activeProject?.name ?? 'PPQA Project',
        filterLabel: filterLabel,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPdfExporting = false);
    }
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  /// Groups snags: location → floor → snags
  Map<String, Map<String, List<SnagModel>>> _group(List<SnagModel> snags) {
    final Map<String, Map<String, List<SnagModel>>> result = {};
    for (final s in snags) {
      final loc   = s.location.isEmpty ? 'Unknown Location' : s.location;
      final floor = s.floorNo.isEmpty  ? '—'               : 'Floor ${s.floorNo}';
      result.putIfAbsent(loc, () => {});
      result[loc]!.putIfAbsent(floor, () => []);
      result[loc]![floor]!.add(s);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appState      = context.watch<AppState>();
    final allSnags      = appState.snags;
    final serialMap     = appState.snagSerialMap;
    final filtered      = _applyFilters(allSnags.toList());
    final grouped       = _group(filtered);

    final locationNames = appState.locations.map((l) => l.name).toList();
    final tradeNames    = appState.trades.map((t) => t.name).toList();
    final floors        = _floorsFor(appState);

    return Scaffold(
      appBar: PPQAAppBar(
        title: 'Open Snags',
        actions: [
          _isPdfExporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      color: Colors.white),
                  tooltip: 'Export filtered snags to PDF',
                  onPressed: () =>
                      _exportToPdf(filtered, serialMap, appState),
                ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter panel ─────────────────────────────────────────────────
          Container(
            color: const Color(0xFFECEFF4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Search bar ───────────────────────────────────────────
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Search description, trade, unit…',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF1A3A5C), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Location + Floor ─────────────────────────────────────
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

                const SizedBox(height: 8),

                // ── Trade ────────────────────────────────────────────────
                PPQADropdown<String>(
                  label: 'Trade',
                  value: _selectedTrade,
                  items: tradeNames,
                  labelBuilder: (t) => t,
                  hint: 'All trades',
                  onChanged: tradeNames.isEmpty
                      ? null
                      : (val) => setState(() => _selectedTrade = val),
                ),

                const SizedBox(height: 10),

                // ── Status chips ─────────────────────────────────────────
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

                const SizedBox(height: 8),

                // ── Severity chips ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Any severity',
                          selected: _selectedSeverity == null,
                          color: const Color(0xFF546E7A),
                          onTap: () =>
                              setState(() => _selectedSeverity = null),
                        ),
                        const SizedBox(width: 8),
                        for (final sev in SnagSeverity.values) ...[
                          _FilterChip(
                            label: sev.label,
                            selected: _selectedSeverity == sev,
                            color: sev.color,
                            onTap: () =>
                                setState(() => _selectedSeverity = sev),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                    label: Text('Reset${_activeFilterCount > 1 ? ' ($_activeFilterCount)' : ''}'),
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
                ? _EmptyState(hasSnags: allSnags.isNotEmpty, isSearching: _searchQuery.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _countItems(grouped),
                    itemBuilder: (_, index) =>
                        _buildItem(context, grouped, index, serialMap),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Flat index → grouped item builder ────────────────────────────────────

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
    Map<String, int> serialMap,
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
            final serial = serialMap[snag.id];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SnagDetailScreen(
                    snag: snag,
                    serialNumber: serial,
                  ),
                ),
              ),
              child: SnagListTile(snag: snag, serialNumber: serial),
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

/// Generic filter chip used for both Status and Severity rows.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String       label;
  final bool         selected;
  final Color        color;
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
          const Expanded(
              child: Divider(color: Color(0xFF1A3A5C), thickness: 0.5)),
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
  const _EmptyState({required this.hasSnags, required this.isSearching});
  final bool hasSnags;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;

    if (isSearching) {
      message = 'No snags match your search.\nTry different keywords.';
      icon = Icons.search_off;
    } else if (hasSnags) {
      message =
          'No snags match the selected filters.\nTry changing status, severity, or location.';
      icon = Icons.check_circle_outline;
    } else {
      message = 'No snags logged yet.\nTap "Log Snag" to get started.';
      icon = Icons.format_list_bulleted;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: const Color(0xFFCED4DA)),
          const SizedBox(height: 16),
          Text(
            message,
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
