import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_painter/image_painter.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen photo markup screen.
///
/// Opens an image (from a local [file] OR a network [url]) and lets the user
/// annotate it with pens, lines, circles, rectangles, and text.
///
/// **Returns:**
/// - `File` — if the user taps "Use This" (annotated image captured to temp dir).
/// - `null`  — if the user taps back/cancel.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<File>(
///   context,
///   MaterialPageRoute(builder: (_) => MarkupViewerScreen.file(file: myFile)),
/// );
/// if (result != null) { /* use annotated file */ }
/// ```
class MarkupViewerScreen extends StatefulWidget {
  const MarkupViewerScreen._({
    required this.file,
    required this.url,
    required this.viewOnly,
  });

  /// Open a local file for markup. Set [viewOnly] = true to hide "Use This".
  factory MarkupViewerScreen.file({
    required File file,
    bool viewOnly = false,
  }) =>
      MarkupViewerScreen._(file: file, url: null, viewOnly: viewOnly);

  /// Open a network URL for view+markup. [viewOnly] = true hides "Use This".
  factory MarkupViewerScreen.network({
    required String url,
    bool viewOnly = true,
  }) =>
      MarkupViewerScreen._(file: null, url: url, viewOnly: viewOnly);

  final File? file;
  final String? url;
  final bool viewOnly;

  @override
  State<MarkupViewerScreen> createState() => _MarkupViewerScreenState();
}

class _MarkupViewerScreenState extends State<MarkupViewerScreen> {
  late final ImagePainterController _controller;
  final _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = ImagePainterController(
      strokeWidth: 4,
      color: Colors.red,
      mode: PaintMode.freeStyle,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Capture the RepaintBoundary that wraps the ImagePainter
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/markup_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      if (mounted) Navigator.pop(context, file);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text(
          'Markup',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: () => _controller.undo(),
          ),
          // Clear all
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all',
            onPressed: () => _controller.clear(),
          ),
          if (!widget.viewOnly) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _save,
                      child: const Text('Use This',
                          style: TextStyle(fontSize: 13)),
                    ),
            ),
          ],
        ],
      ),
      body: RepaintBoundary(
        key: _repaintKey,
        child: widget.file != null
            ? ImagePainter.file(
                widget.file!,
                controller: _controller,
                scalable: true,
              )
            : ImagePainter.network(
                widget.url!,
                controller: _controller,
                scalable: true,
              ),
      ),
    );
  }
}
