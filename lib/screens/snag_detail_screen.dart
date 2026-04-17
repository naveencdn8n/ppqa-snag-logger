import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import 'markup_viewer_screen.dart';

class SnagDetailScreen extends StatefulWidget {
  const SnagDetailScreen({
    super.key,
    required this.snag,
    this.serialNumber,
  });

  final SnagModel snag;
  final int? serialNumber;

  @override
  State<SnagDetailScreen> createState() => _SnagDetailScreenState();
}

class _SnagDetailScreenState extends State<SnagDetailScreen> {
  bool _savingStatus = false;

  Future<void> _changeStatus() async {
    final appState = context.read<AppState>();
    final currentSnag = appState.snags.firstWhere(
      (s) => s.id == widget.snag.id,
      orElse: () => widget.snag,
    );

    final newStatus = await showModalBottomSheet<SnagStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusPicker(currentStatus: currentSnag.status),
    );

    if (newStatus == null || newStatus == currentSnag.status || !mounted) return;

    if (newStatus == SnagStatus.closed) {
      final result = await showDialog<_CloseNoteResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CloseNoteDialog(),
      );
      if (result == null || !mounted) return;
      await _doSave(newStatus, closeNote: result.note, closeMediaFiles: result.files);
    } else {
      await _doSave(newStatus);
    }
  }

  Future<void> _doSave(
    SnagStatus newStatus, {
    String? closeNote,
    List<File> closeMediaFiles = const [],
  }) async {
    setState(() => _savingStatus = true);
    try {
      await context.read<AppState>().updateSnagStatus(
        widget.snag.id,
        newStatus,
        closeNote: closeNote,
        closeMediaFiles: closeMediaFiles,
      );
      if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Use live snag from AppState if available, fallback to widget.snag
    final snag = appState.snags.firstWhere(
      (s) => s.id == widget.snag.id,
      orElse: () => widget.snag,
    );

    final inspectorName = appState.resolveInspector(snag.createdBy);
    final canChangeStatus =
        appState.canChangeOwnStatus || appState.canChangeAnyStatus;

    final appTitle = widget.serialNumber != null
        ? 'Snag #${widget.serialNumber}'
        : 'Snag Detail';

    return Scaffold(
      appBar: PPQAAppBar(title: appTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status + Severity header card ─────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Severity icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: snag.severity.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForSeverity(snag.severity),
                        color: snag.severity.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snag.defectDescription,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212529),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.serialNumber != null) ...[
                                _SerialBadge(number: widget.serialNumber!),
                                const SizedBox(width: 8),
                              ],
                              _Chip(
                                label: snag.severity.label,
                                color: snag.severity.color,
                              ),
                              const SizedBox(width: 8),
                              _Chip(
                                label: snag.status.label,
                                color: snag.status.color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Location details ──────────────────────────────────────────
            _SectionCard(
              title: 'Location',
              icon: Icons.location_on_outlined,
              children: [
                _DetailRow(label: 'Tower / Location', value: snag.location),
                _DetailRow(label: 'Floor',            value: snag.floorNo),
                _DetailRow(label: 'Unit / Flat',      value: snag.flatNo),
                if (snag.room.isNotEmpty)
                  _DetailRow(label: 'Room',           value: snag.room),
                _DetailRow(label: 'Element',          value: snag.element),
              ],
            ),
            const SizedBox(height: 12),

            // ── Defect details ────────────────────────────────────────────
            _SectionCard(
              title: 'Defect',
              icon: Icons.build_outlined,
              children: [
                _DetailRow(label: 'Trade', value: snag.trade),
                _DetailRow(
                    label: 'Description', value: snag.defectDescription),
              ],
            ),
            const SizedBox(height: 12),

            // ── Log info ──────────────────────────────────────────────────
            _SectionCard(
              title: 'Logged By',
              icon: Icons.person_outline,
              children: [
                _DetailRow(label: 'Inspector', value: inspectorName),
                _DetailRow(
                  label: 'Date & Time',
                  value: DateFormat('dd MMM yyyy, HH:mm').format(snag.createdAt),
                ),
                if (widget.serialNumber != null)
                  _DetailRow(
                    label: 'Serial No.',
                    value: '#${widget.serialNumber}',
                  ),
                _DetailRow(label: 'Snag ID', value: snag.id),
                if (snag.notes != null && snag.notes!.isNotEmpty)
                  _DetailRow(label: 'Notes', value: snag.notes!),
              ],
            ),

            // ── Original evidence media ───────────────────────────────────
            if (snag.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MediaSection(
                title:
                    'Evidence (${snag.mediaUrls.length} file${snag.mediaUrls.length == 1 ? '' : 's'})',
                icon: Icons.photo_library_outlined,
                urls: snag.mediaUrls,
              ),
            ],

            // ── Close-out section ─────────────────────────────────────────
            if (snag.status == SnagStatus.closed &&
                ((snag.closeNote != null && snag.closeNote!.isNotEmpty) ||
                    snag.closeEvidenceUrls.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Card(
                color: AppTheme.statusClosed.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: AppTheme.statusClosed.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 16, color: AppTheme.statusClosed),
                          const SizedBox(width: 6),
                          const Text(
                            'Close-Out Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.statusClosed,
                            ),
                          ),
                        ],
                      ),
                      if (snag.closeNote != null &&
                          snag.closeNote!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Close Note',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snag.closeNote!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF212529),
                          ),
                        ),
                      ],
                      if (snag.closeEvidenceUrls.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Close Evidence (${snag.closeEvidenceUrls.length} file${snag.closeEvidenceUrls.length == 1 ? '' : 's'})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: snag.closeEvidenceUrls.length,
                          itemBuilder: (_, i) {
                            final url = snag.closeEvidenceUrls[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFECEFF4),
                                  child: const Icon(Icons.broken_image,
                                      color: Color(0xFFCED4DA)),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ── Change Status button ──────────────────────────────────────
            if (canChangeStatus) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: _savingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz, size: 18),
                label: Text(_savingStatus ? 'Updating...' : 'Change Status'),
                onPressed: _savingStatus ? null : _changeStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _iconForSeverity(SnagSeverity s) {
    switch (s) {
      case SnagSeverity.redLine:
        return Icons.block;
      case SnagSeverity.major:
        return Icons.warning_amber;
      case SnagSeverity.minor:
        return Icons.info_outline;
    }
  }
}

// ── Status picker bottom sheet ────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.currentStatus});
  final SnagStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Change Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final status in SnagStatus.values)
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                    fontWeight: currentStatus == status
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: currentStatus == status
                        ? status.color
                        : const Color(0xFF212529),
                  ),
                ),
                trailing: currentStatus == status
                    ? Icon(Icons.check_circle, color: status.color, size: 20)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Close note result ─────────────────────────────────────────────────────────

class _CloseNoteResult {
  final String note;
  final List<File> files;
  const _CloseNoteResult({required this.note, required this.files});
}

// ── Close note dialog ─────────────────────────────────────────────────────────

class _CloseNoteDialog extends StatefulWidget {
  const _CloseNoteDialog();

  @override
  State<_CloseNoteDialog> createState() => _CloseNoteDialogState();
}

class _CloseNoteDialogState extends State<_CloseNoteDialog> {
  final _noteController = TextEditingController();
  final List<File> _mediaFiles = [];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _noteController.text.trim().isNotEmpty || _mediaFiles.isNotEmpty;

  Future<void> _pickFromCamera() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (f != null) setState(() => _mediaFiles.add(File(f.path)));
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked.isNotEmpty) {
      setState(() => _mediaFiles.addAll(picked.map((f) => File(f.path))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppTheme.statusClosed),
          SizedBox(width: 8),
          Text('Close Snag'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a close note and/or photo evidence before closing this snag.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Close Note',
                hintText: 'Describe how the defect was resolved...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_mediaFiles.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final file = _mediaFiles[i];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final annotated =
                                await Navigator.push<File>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MarkupViewerScreen.file(file: file),
                              ),
                            );
                            if (annotated != null) {
                              setState(() => _mediaFiles[i] = annotated);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _mediaFiles.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Camera'),
                  onPressed: _pickFromCamera,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Gallery'),
                  onPressed: _pickFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (!_isValid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Please add a close note or at least one photo.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid
              ? () => Navigator.pop(
                    context,
                    _CloseNoteResult(
                      note: _noteController.text.trim(),
                      files: List.of(_mediaFiles),
                    ),
                  )
              : null,
          child: const Text('Close Snag'),
        ),
      ],
    );
  }
}

// ── Media section ─────────────────────────────────────────────────────────────

class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.title,
    required this.icon,
    required this.urls,
  });

  final String title;
  final IconData icon;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: urls.length,
              itemBuilder: (context, i) {
                final url = urls[i];
                final isVideo = url.endsWith('.mp4') || url.contains('video');
                return GestureDetector(
                  onTap: isVideo
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MarkupViewerScreen.network(url: url),
                            ),
                          ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? Container(
                                color: const Color(0xFF1A3A5C),
                                child: const Center(
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 32),
                                ),
                              )
                            : Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFECEFF4),
                                  child: const Icon(Icons.broken_image,
                                      color: Color(0xFFCED4DA)),
                                ),
                              ),
                      ),
                      // Markup hint icon (photos only)
                      if (!isVideo)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 11),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6C757D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF212529),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SerialBadge extends StatelessWidget {
  const _SerialBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF1A3A5C).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '#$number',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A3A5C),
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
