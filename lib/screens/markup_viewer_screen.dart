import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_painter/image_painter.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen photo markup screen.
///
/// Opens an image (from a local [file] OR a network [url]) and lets the user
/// annotate it with pens, circles, rectangles, arrows, and text.
///
/// **Returns:**
/// - `File` — if the user taps "Use This" (annotated image captured to temp dir).
/// - `null`  — if the user taps back/cancel.
class MarkupViewerScreen extends StatefulWidget {
  const MarkupViewerScreen._({
    required this.file,
    required this.url,
    required this.viewOnly,
  });

  factory MarkupViewerScreen.file({
    required File file,
    bool viewOnly = false,
  }) =>
      MarkupViewerScreen._(file: file, url: null, viewOnly: viewOnly);

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

// ── Tool definitions ──────────────────────────────────────────────────────────

class _ToolDef {
  const _ToolDef({
    required this.mode,
    required this.icon,
    required this.label,
    this.fill = false,
    this.fixedColor,
    this.fixedStroke,
  });

  final PaintMode mode;
  final IconData icon;
  final String label;
  /// Whether to fill closed shapes (rect / circle).
  final bool fill;
  /// If non-null, this tool always uses this colour (ignores the colour picker).
  final Color? fixedColor;
  /// If non-null, this tool always uses this stroke width.
  final double? fixedStroke;
}

const _kTools = [
  _ToolDef(mode: PaintMode.freeStyle, icon: Icons.edit,            label: 'Pen'),
  _ToolDef(mode: PaintMode.circle,    icon: Icons.circle_outlined, label: 'Circle'),
  _ToolDef(mode: PaintMode.rect,      icon: Icons.crop_square,     label: 'Rect'),
  _ToolDef(mode: PaintMode.arrow,     icon: Icons.arrow_forward,   label: 'Arrow'),
  _ToolDef(mode: PaintMode.line,      icon: Icons.remove,          label: 'Line'),
  _ToolDef(mode: PaintMode.text,      icon: Icons.text_fields,     label: 'Text'),
  // Highlight = filled semi-transparent yellow rectangle
  _ToolDef(
    mode:        PaintMode.rect,
    icon:        Icons.highlight,
    label:       'Highlight',
    fill:        true,
    fixedColor:  Color(0xAAFFEB3B), // semi-transparent yellow
    fixedStroke: 2,
  ),
];

// ── Colour palette ────────────────────────────────────────────────────────────

const _kColors = [
  Color(0xFFE53935), // red
  Color(0xFFFF6F00), // orange
  Color(0xFFFFEB3B), // yellow
  Color(0xFF43A047), // green
  Color(0xFF1E88E5), // blue
  Color(0xFFFFFFFF), // white
  Color(0xFF212121), // black
];

// ── Stroke widths ─────────────────────────────────────────────────────────────

const _kStrokes = [2.0, 4.0, 8.0];

// ── State ─────────────────────────────────────────────────────────────────────

class _MarkupViewerScreenState extends State<MarkupViewerScreen> {
  late final ImagePainterController _controller;
  final _repaintKey = GlobalKey();

  bool _saving   = false;
  int  _toolIdx  = 0;
  Color  _color  = const Color(0xFFE53935); // red
  double _stroke = 4.0;

  @override
  void initState() {
    super.initState();
    _controller = ImagePainterController(
      strokeWidth: _stroke,
      color:       _color,
      mode:        _kTools[_toolIdx].mode,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Tool / colour / stroke selection ─────────────────────────────────────────

  void _selectTool(int index) {
    final tool = _kTools[index];
    setState(() => _toolIdx = index);
    _controller.update(
      mode:        tool.mode,
      color:       tool.fixedColor ?? _color,
      strokeWidth: tool.fixedStroke ?? _stroke,
      fill:        tool.fill,
    );
  }

  void _selectColor(Color color) {
    setState(() => _color = color);
    // Only override the controller colour when the active tool doesn't lock it.
    if (_kTools[_toolIdx].fixedColor == null) {
      _controller.setColor(color);
    }
  }

  void _selectStroke(double width) {
    setState(() => _stroke = width);
    if (_kTools[_toolIdx].fixedStroke == null) {
      _controller.setStrokeWidth(width);
    }
  }

  // ── Save annotated image ──────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;

      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/markup_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      if (mounted) Navigator.pop(context, file);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text(
          'Markup Photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last stroke',
            onPressed: () => _controller.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all annotations',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear all?'),
                  content:
                      const Text('Remove all markup from this photo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) _controller.clear();
            },
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _save,
                      child: const Text('Use This',
                          style: TextStyle(fontSize: 13)),
                    ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Canvas ─────────────────────────────────────────────────────────
          Expanded(
            child: RepaintBoundary(
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
          ),

          // ── Toolbar ────────────────────────────────────────────────────────
          _buildToolbar(),
        ],
      ),
    );
  }

  // ── Toolbar widget ────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: colours + stroke widths ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Colour dots
                Row(
                  children: _kColors.map((c) {
                    final isHighlightTool =
                        _kTools[_toolIdx].fixedColor != null;
                    final isActive = !isHighlightTool && _color == c;
                    return GestureDetector(
                      onTap: isHighlightTool ? null : () => _selectColor(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        width:  isActive ? 28 : 22,
                        height: isActive ? 28 : 22,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHighlightTool
                                ? Colors.white12
                                : isActive
                                    ? Colors.white
                                    : Colors.white30,
                            width: isActive ? 2.5 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Stroke width toggle — three dot sizes
                Row(
                  children: _kStrokes.map((w) {
                    final isHighlightTool =
                        _kTools[_toolIdx].fixedStroke != null;
                    final isActive = !isHighlightTool && _stroke == w;
                    return GestureDetector(
                      onTap: isHighlightTool ? null : () => _selectStroke(w),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(left: 6),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white24
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHighlightTool
                                ? Colors.white12
                                : isActive
                                    ? Colors.white
                                    : Colors.white30,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width:  w * 2.5,
                            height: w * 2.5,
                            decoration: BoxDecoration(
                              color: isHighlightTool
                                  ? Colors.white30
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Row 2: tool buttons ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_kTools.length, (i) {
                final tool    = _kTools[i];
                final isActive = _toolIdx == i;
                final iconColor = tool.fixedColor != null
                    ? tool.fixedColor!
                    : isActive
                        ? _color
                        : Colors.white54;

                return GestureDetector(
                  onTap: () => _selectTool(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white24 : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tool.icon,
                            color: iconColor,
                            size: isActive ? 22 : 18),
                        const SizedBox(height: 3),
                        Text(
                          tool.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color:
                                isActive ? Colors.white : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
