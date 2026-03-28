import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import 'pdf_viewer_screen.dart';

class _DrawingItem {
  const _DrawingItem({required this.label, required this.url, required this.icon});
  final String label;
  final String url;
  final IconData icon;
}

class LayoutDrawingsScreen extends StatelessWidget {
  const LayoutDrawingsScreen({super.key});

  // Replace URLs with actual hosted PDF links in production
  static const List<_DrawingItem> _drawings = [
    _DrawingItem(
      label: 'Tower 1',
      url: 'https://example.com/layout-tower1.pdf',
      icon: Icons.apartment,
    ),
    _DrawingItem(
      label: 'Tower 2',
      url: 'https://example.com/layout-tower2.pdf',
      icon: Icons.apartment,
    ),
    _DrawingItem(
      label: 'Tower 3',
      url: 'https://example.com/layout-tower3.pdf',
      icon: Icons.apartment,
    ),
    _DrawingItem(
      label: 'Tower 4',
      url: 'https://example.com/layout-tower4.pdf',
      icon: Icons.apartment,
    ),
    _DrawingItem(
      label: 'Club',
      url: 'https://example.com/layout-club.pdf',
      icon: Icons.sports_tennis,
    ),
    _DrawingItem(
      label: 'NTA',
      url: 'https://example.com/layout-nta.pdf',
      icon: Icons.location_city,
    ),
    _DrawingItem(
      label: 'Common Area',
      url: 'https://example.com/layout-common-area.pdf',
      icon: Icons.park_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PPQAAppBar(title: 'Layout Drawings', showBack: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _drawings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = _drawings[i];
          return Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: AppTheme.primary),
              ),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Layout Drawing (PDF)',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.secondary),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                    title: '${item.label} Layout Drawing',
                    pdfUrl: item.url,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
