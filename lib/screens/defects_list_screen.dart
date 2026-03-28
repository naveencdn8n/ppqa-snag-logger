import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/ppqa_dropdown.dart';
import '../widgets/snag_list_tile.dart';

class DefectsListScreen extends StatefulWidget {
  const DefectsListScreen({super.key});

  @override
  State<DefectsListScreen> createState() => _DefectsListScreenState();
}

class _DefectsListScreenState extends State<DefectsListScreen> {
  DefectsListTrade? _selectedTrade;
  SnagTrade? _selectedCategory;

  List<SnagModel> _applyFilters(List<SnagModel> all) {
    return all.where((s) {
      if (_selectedCategory != null && s.trade != _selectedCategory) return false;
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedTrade = null;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSnags = context.watch<AppState>().snags;
    final filtered = _applyFilters(allSnags.toList());

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Defects List'),
      body: Column(
        children: [
          // ── Filter bar ────────────────────────────────────────────────────
          Container(
            color: const Color(0xFFECEFF4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: PPQADropdown<DefectsListTrade>(
                    label: 'Trade',
                    value: _selectedTrade,
                    items: DefectsListTrade.values,
                    labelBuilder: (t) => t.label,
                    onChanged: (val) => setState(() => _selectedTrade = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PPQADropdown<SnagTrade>(
                    label: 'Category',
                    value: _selectedCategory,
                    items: SnagTrade.values,
                    labelBuilder: (t) => t.label,
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                ),
              ],
            ),
          ),

          // ── Results count + clear ─────────────────────────────────────────
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
                if (_selectedTrade != null || _selectedCategory != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filters'),
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

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          allSnags.isEmpty
                              ? Icons.format_list_bulleted
                              : Icons.check_circle_outline,
                          size: 72,
                          color: const Color(0xFFCED4DA),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allSnags.isEmpty
                              ? 'No snags logged yet.\nTap "Log Snag" to get started.'
                              : 'No snags match the selected filters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => SnagListTile(snag: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
