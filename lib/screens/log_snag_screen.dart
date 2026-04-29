import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/config_models.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/ppqa_dropdown.dart';
import 'markup_viewer_screen.dart';

class LogSnagScreen extends StatefulWidget {
  const LogSnagScreen({super.key});

  @override
  State<LogSnagScreen> createState() => _LogSnagScreenState();
}

class _LogSnagScreenState extends State<LogSnagScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customDefectController = TextEditingController();
  final _notesController = TextEditingController();
  final _roomController = TextEditingController();
  final _scrollController = ScrollController();

  // ── Form state ────────────────────────────────────────────────────────────
  String? _location;
  String? _floor;
  String? _unit;
  String? _room;
  String? _element;
  String? _trade;
  String? _predefinedDefect;   // selected from dropdown
  bool _useCustomDefect = false; // toggle between dropdown ↔ text field
  SnagSeverity? _severity;

  // ── Media ─────────────────────────────────────────────────────────────────
  final List<XFile> _mediaFiles = [];
  static const int _maxMedia = 6;

  bool _isSubmitting = false;

  /// Incremented on each form reset to force a full rebuild of all
  /// DropdownButtonFormFields (which keep internal state that reset() alone
  /// does not always clear visually).
  int _formVersion = 0;

  @override
  void dispose() {
    _customDefectController.dispose();
    _notesController.dispose();
    _roomController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Media helpers ─────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    if (_mediaFiles.length >= _maxMedia) return;
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (f != null) setState(() => _mediaFiles.add(f));
  }

  Future<void> _pickFromGallery() async {
    if (_mediaFiles.length >= _maxMedia) return;
    final remaining = _maxMedia - _mediaFiles.length;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked.isNotEmpty) {
      setState(() {
        _mediaFiles.addAll(picked.take(remaining));
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaFiles.length >= _maxMedia) return;
    final f = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (f != null) setState(() => _mediaFiles.add(f));
  }

  void _removeMedia(int index) =>
      setState(() => _mediaFiles.removeAt(index));

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Add Evidence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.camera_alt, color: Color(0xFF1565C0)),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select up to 6 photos'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFCE4EC),
                  child: Icon(Icons.videocam, color: Color(0xFFC62828)),
                ),
                title: const Text('Record a Video'),
                subtitle: const Text('Max 2 minutes'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final state = context.read<AppState>();
    final defectText = _useCustomDefect
        ? _customDefectController.text.trim()
        : _predefinedDefect!;

    final snag = SnagModel(
      id: '',
      createdBy: state.currentUser?.username ?? 'unknown',
      createdAt: DateTime.now(),
      location: _location!,
      floorNo: _floor!,
      flatNo: _unit!,
      room: _room ?? '',
      element: _element!,
      trade: _trade!,
      defectDescription: defectText,
      severity: _severity!,
      status: SnagStatus.open,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      final mediaQueued = await state.addSnag(
        snag,
        mediaFiles: _mediaFiles.map((f) => File(f.path)).toList(),
      );

      if (!mounted) return;

      final int fileCount = _mediaFiles.length;
      final String message;
      if (fileCount == 0) {
        message = 'Snag logged successfully!';
      } else if (mediaQueued) {
        message = 'Snag saved! '
            '$fileCount photo${fileCount == 1 ? '' : 's'} will upload when back online.';
      } else {
        message = 'Snag logged with $fileCount file${fileCount == 1 ? '' : 's'}!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              mediaQueued ? Colors.orange.shade700 : AppTheme.statusClosed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save snag: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    // Clear text controllers before setState so they don't flash old values
    _customDefectController.clear();
    _notesController.clear();
    _roomController.clear();

    setState(() {
      _location = null;
      _floor = null;
      _unit = null;
      _room = null;
      _element = null;
      _trade = null;
      _predefinedDefect = null;
      _useCustomDefect = false;
      _severity = null;
      _mediaFiles.clear();
      // Incrementing the version forces all dropdown children to rebuild fresh,
      // clearing their internal FormField state along with the displayed value.
      _formVersion++;
    });

    // Scroll back to the top so the user sees the blank Location fields,
    // making it clear the form has been reset and is ready for the next snag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Cascade helpers ────────────────────────────────────────────────────────

  List<ElementItem> _availableElements(List<TradeItem> trades) {
    if (_trade == null) return [];
    return trades.firstWhere((t) => t.name == _trade,
            orElse: () => TradeItem(id: '', name: '', elements: []))
        .elements;
  }

  List<DefectItem> _availableDefects(List<ElementItem> elements) {
    if (_element == null) return [];
    return elements.firstWhere((e) => e.name == _element,
            orElse: () => ElementItem(id: '', name: '', defects: []))
        .defects;
  }

  static final List<String> _fallbackFloors =
      ['GF', ...List.generate(20, (i) => '${i + 1}'), 'Roof'];

  List<String> _availableFloors(List<LocationItem> locations) {
    if (_location == null) return _fallbackFloors;
    final loc = locations.firstWhere((l) => l.name == _location,
        orElse: () => LocationItem(id: '', name: '', floors: [], units: []));
    return loc.floors.isNotEmpty ? loc.floors : _fallbackFloors;
  }

  List<String> _availableUnits(List<LocationItem> locations) {
    if (_location == null) return [];
    final loc = locations.firstWhere((l) => l.name == _location,
        orElse: () => LocationItem(id: '', name: '', floors: [], units: []));
    return loc.units;
  }

  List<String> _availableRooms(List<LocationItem> locations) {
    if (_location == null) return [];
    final loc = locations.firstWhere((l) => l.name == _location,
        orElse: () => LocationItem(id: '', name: '', floors: [], units: []));
    return loc.rooms;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Viewers (and blocked users) cannot log snags
    if (!appState.canLogSnags) {
      return Scaffold(
        appBar: const PPQAAppBar(title: 'Log a Snag'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 20),
                const Text(
                  'View-Only Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your current role does not allow logging snags.\n'
                  'Contact your supervisor to request access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final trades = appState.trades;
    final locations = appState.locations;

    final availableElements = _availableElements(trades);
    final availableDefects = _availableDefects(availableElements);
    final availableFloors = _availableFloors(locations);
    final availableUnits  = _availableUnits(locations);
    final availableRooms  = _availableRooms(locations);

    return Scaffold(
      appBar: const PPQAAppBar(title: 'Log a Snag'),
      body: appState.configLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  key: ValueKey(_formVersion),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Section 1: Location ─────────────────────────────────
                    const _SectionHeader(
                      icon: Icons.location_on_outlined,
                      title: 'Location Details',
                    ),
                    const SizedBox(height: 12),

                    PPQADropdown<String>(
                      label: 'Location',
                      isRequired: true,
                      value: _location,
                      items: locations.map((l) => l.name).toList(),
                      labelBuilder: (s) => s,
                      onChanged: (val) => setState(() {
                        _location = val;
                        _floor = null;
                        _unit = null;
                        _room = null;
                        _roomController.clear();
                      }),
                      validator: (val) =>
                          val == null ? 'Please select a location' : null,
                      hint: locations.isEmpty
                          ? 'No locations configured'
                          : 'Select location',
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: PPQADropdown<String>(
                            label: 'Floor',
                            isRequired: true,
                            value: _floor,
                            items: availableFloors,
                            labelBuilder: (s) => s,
                            onChanged: (val) =>
                                setState(() => _floor = val),
                            validator: (val) =>
                                val == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PPQADropdown<String>(
                            label: 'Unit',
                            isRequired: true,
                            value: _unit,
                            items: availableUnits,
                            labelBuilder: (s) => s,
                            onChanged: (val) =>
                                setState(() => _unit = val),
                            validator: (val) =>
                                val == null ? 'Required' : null,
                            hint: availableUnits.isEmpty
                                ? 'No units configured'
                                : 'Select unit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Room (level 4) — always shown once a location is picked.
                    // Dropdown when rooms are configured in admin; free-text otherwise.
                    if (_location != null) ...[
                      if (availableRooms.isNotEmpty)
                        PPQADropdown<String>(
                          label: 'Room',
                          isRequired: false,
                          value: _room,
                          items: availableRooms,
                          labelBuilder: (s) => s,
                          onChanged: (val) => setState(() => _room = val),
                          hint: 'Select room (optional)',
                        )
                      else
                        TextFormField(
                          controller: _roomController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (val) =>
                              setState(() => _room = val.trim().isEmpty ? null : val.trim()),
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            hintText: 'e.g. Kitchen, Bedroom 1, Living Room…',
                            prefixIcon: Icon(Icons.door_front_door_outlined),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),

                    // ── Section 2: Defect Details ───────────────────────────
                    const _SectionHeader(
                      icon: Icons.warning_amber_outlined,
                      title: 'Defect Details',
                    ),
                    const SizedBox(height: 12),

                    // Trade
                    PPQADropdown<String>(
                      label: 'Trade',
                      isRequired: true,
                      value: _trade,
                      items: trades.map((t) => t.name).toList(),
                      labelBuilder: (s) => s,
                      onChanged: (val) => setState(() {
                        _trade = val;
                        _element = null;
                        _predefinedDefect = null;
                      }),
                      validator: (val) =>
                          val == null ? 'Please select a trade' : null,
                      hint: trades.isEmpty
                          ? 'No trades configured'
                          : 'Select trade',
                    ),
                    const SizedBox(height: 12),

                    // Element (cascades from trade)
                    PPQADropdown<String>(
                      label: 'Element / Room',
                      isRequired: true,
                      value: _element,
                      items: availableElements.map((e) => e.name).toList(),
                      labelBuilder: (s) => s,
                      onChanged: (val) => setState(() {
                        _element = val;
                        _predefinedDefect = null;
                      }),
                      validator: (val) =>
                          val == null ? 'Please select an element' : null,
                      hint: _trade == null
                          ? 'Select a trade first'
                          : availableElements.isEmpty
                              ? 'No elements for this trade'
                              : 'Select element',
                    ),
                    const SizedBox(height: 12),

                    // ── Defect Description — predefined or custom ────────────
                    Row(
                      children: [
                        const Text(
                          'Defect Description',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF495057),
                          ),
                        ),
                        const Spacer(),
                        // Toggle chip
                        GestureDetector(
                          onTap: () => setState(() {
                            _useCustomDefect = !_useCustomDefect;
                            _predefinedDefect = null;
                            _customDefectController.clear();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _useCustomDefect
                                  ? AppTheme.secondary
                                  : const Color(0xFFECEFF4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _useCustomDefect
                                      ? Icons.edit
                                      : Icons.list_alt,
                                  size: 13,
                                  color: _useCustomDefect
                                      ? Colors.white
                                      : const Color(0xFF6C757D),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _useCustomDefect
                                      ? 'Custom'
                                      : 'Predefined',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _useCustomDefect
                                        ? Colors.white
                                        : const Color(0xFF6C757D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Either dropdown OR text field
                    if (!_useCustomDefect)
                      PPQADropdown<String>(
                        label: 'Select Defect',
                        isRequired: true,
                        value: _predefinedDefect,
                        items: availableDefects.map((d) => d.name).toList(),
                        labelBuilder: (s) => s,
                        onChanged: (val) =>
                            setState(() => _predefinedDefect = val),
                        validator: (val) =>
                            val == null ? 'Please select a defect' : null,
                        hint: _element == null
                            ? 'Select an element first'
                            : availableDefects.isEmpty
                                ? 'No defects — use Custom mode'
                                : 'Select defect',
                      )
                    else
                      TextFormField(
                        controller: _customDefectController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Describe the defect *',
                          hintText:
                              'e.g. Hairline crack running diagonally on the north wall',
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (!_useCustomDefect) return null;
                          if (val == null || val.trim().isEmpty) {
                            return 'Please describe the defect';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),

                    // Severity
                    PPQADropdown<SnagSeverity>(
                      label: 'Severity',
                      isRequired: true,
                      value: _severity,
                      items: SnagSeverity.values,
                      labelBuilder: (s) => s.label,
                      itemColorBuilder: (s) => s.color,
                      onChanged: (val) =>
                          setState(() => _severity = val),
                      validator: (val) =>
                          val == null ? 'Please select severity' : null,
                    ),
                    const SizedBox(height: 12),

                    // Notes (optional)
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Any additional observations...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Section 3: Evidence ─────────────────────────────────
                    const _SectionHeader(
                      icon: Icons.camera_alt_outlined,
                      title: 'Evidence',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_mediaFiles.length} / $_maxMedia files added',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Media grid
                    _MediaGrid(
                      files: _mediaFiles,
                      maxFiles: _maxMedia,
                      onAdd: _showMediaPicker,
                      onRemove: _removeMedia,
                      onMarkup: (int index, XFile original) async {
                        final annotated = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarkupViewerScreen.file(
                              file: File(original.path),
                            ),
                          ),
                        );
                        if (annotated != null) {
                          setState(() {
                            _mediaFiles[index] = XFile(annotated.path);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Submit ──────────────────────────────────────────────
                    FilledButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Snag',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: _isSubmitting ? null : _onSubmit,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Media grid widget ─────────────────────────────────────────────────────────

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.files,
    required this.maxFiles,
    required this.onAdd,
    required this.onRemove,
    required this.onMarkup,
  });

  final List<XFile> files;
  final int maxFiles;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final Future<void> Function(int index, XFile file) onMarkup;

  bool _isVideo(XFile f) {
    final p = f.path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    final showAdd = files.length < maxFiles;
    final itemCount = files.length + (showAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // Last cell = add button
        if (showAdd && i == files.length) {
          return _AddCell(onTap: onAdd);
        }
        final f = files[i];
        return _MediaCell(
          file: f,
          isVideo: _isVideo(f),
          onRemove: () => onRemove(i),
          onMarkup: _isVideo(f) ? null : () => onMarkup(i, f),
        );
      },
    );
  }
}

class _AddCell extends StatelessWidget {
  const _AddCell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.secondary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: AppTheme.secondary),
            const SizedBox(height: 6),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCell extends StatelessWidget {
  const _MediaCell({
    required this.file,
    required this.isVideo,
    required this.onRemove,
    this.onMarkup,
  });

  final XFile file;
  final bool isVideo;
  final VoidCallback onRemove;
  final VoidCallback? onMarkup;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isVideo
              ? Container(
                  color: const Color(0xFF1A3A5C),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 36),
                  ),
                )
              : Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                ),
        ),

        // Video badge
        if (isVideo)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),

        // Markup button (photos only)
        if (onMarkup != null)
          Positioned(
            bottom: 4,
            left: 4,
            child: GestureDetector(
              onTap: onMarkup,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Section header widget ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
