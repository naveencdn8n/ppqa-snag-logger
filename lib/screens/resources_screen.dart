import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/resource_model.dart';
import '../services/resources_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

class ResourcesScreen extends StatelessWidget {
  /// [initialTab]: 0 = Specifications, 1 = Drawings, 2 = Benchmark Reports
  const ResourcesScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: PPQAAppBar(
          title: 'Resources',
          showBack: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.description_outlined), text: 'Specs'),
              Tab(icon: Icon(Icons.architecture_outlined), text: 'Drawings'),
              Tab(icon: Icon(Icons.assessment_outlined), text: 'Benchmark'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ResourceTab(
              stream: ResourcesService().specificationsStream,
              emptyIcon: Icons.description_outlined,
              emptyMessage: 'No specifications uploaded yet.\n'
                  'Add them in the PPQA Admin panel.',
            ),
            _ResourceTab(
              stream: ResourcesService().drawingsStream,
              emptyIcon: Icons.architecture_outlined,
              emptyMessage: 'No drawings uploaded yet.\n'
                  'Add them in the PPQA Admin panel.',
              showLocationBadges: true,
            ),
            _ResourceTab(
              stream: ResourcesService().benchmarkReportsStream,
              emptyIcon: Icons.assessment_outlined,
              emptyMessage: 'No benchmark reports uploaded yet.\n'
                  'Add them in the PPQA Admin panel.',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab content ──────────────────────────────────────────────────────────────

class _ResourceTab extends StatelessWidget {
  const _ResourceTab({
    required this.stream,
    required this.emptyIcon,
    required this.emptyMessage,
    this.showLocationBadges = false,
  });

  final Stream<List<ResourceFile>> stream;
  final IconData emptyIcon;
  final String emptyMessage;
  final bool showLocationBadges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResourceFile>>(
      stream: stream,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 56, color: Color(0xFFCED4DA)),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load files.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6C757D)),
                  ),
                ],
              ),
            ),
          );
        }

        final files = snapshot.data ?? [];

        // Empty state
        if (files.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 72, color: const Color(0xFFCED4DA)),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF6C757D), fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          );
        }

        // File list
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ResourceCard(
            file: files[i],
            showLocationBadges: showLocationBadges,
          ),
        );
      },
    );
  }
}

// ─── File card ────────────────────────────────────────────────────────────────

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.file, required this.showLocationBadges});

  final ResourceFile file;
  final bool showLocationBadges;

  IconData get _fileIcon {
    switch (file.fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'dwg':
      case 'dxf':
        return Icons.architecture_outlined;
      case 'docx':
      case 'doc':
        return Icons.description_outlined;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color get _fileColor {
    switch (file.fileType?.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFB71C1C);
      case 'dwg':
      case 'dxf':
        return const Color(0xFF6A1B9A);
      case 'docx':
      case 'doc':
        return const Color(0xFF1565C0);
      case 'xlsx':
      case 'xls':
        return const Color(0xFF2E7D32);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF00695C);
      default:
        return AppTheme.primary;
    }
  }

  Future<void> _openFile(BuildContext context) async {
    if (file.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File URL not available')),
      );
      return;
    }
    final uri = Uri.parse(file.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file. No app available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File type icon ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _fileColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_fileIcon, size: 28, color: _fileColor),
            ),
            const SizedBox(width: 14),

            // ── Info ──────────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + type badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212529),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (file.fileType != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _fileColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.fileType!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _fileColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Description
                  if (file.description != null &&
                      file.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      file.description!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6C757D)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Floor / Unit badges for drawings
                  if (showLocationBadges &&
                      (file.floor != null || file.unit != null)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (file.floor != null && file.floor!.isNotEmpty)
                          _Badge(
                              label: 'Floor ${file.floor}',
                              color: const Color(0xFF1565C0)),
                        if (file.unit != null && file.unit!.isNotEmpty)
                          _Badge(
                              label: file.unit!,
                              color: const Color(0xFF6A1B9A)),
                      ],
                    ),
                  ],

                  // Size + date + open button
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (file.formattedSize.isNotEmpty)
                        Text(
                          file.formattedSize,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFADB5BD)),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(80, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () => _openFile(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small badge ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
