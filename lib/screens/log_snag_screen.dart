import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/snag_model.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/ppqa_dropdown.dart';

class LogSnagScreen extends StatefulWidget {
  const LogSnagScreen({super.key});

  @override
  State<LogSnagScreen> createState() => _LogSnagScreenState();
}

class _LogSnagScreenState extends State<LogSnagScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  SnagLocation? _location;
  int? _floorNo;
  FlatNo? _flatNo;
  SnagElement? _element;
  SnagTrade? _trade;
  String? _defectDescription;
  SnagSeverity? _severity;
  XFile? _evidenceImage;
  bool _isSubmitting = false;

  static const List<String> _defectDescriptions = [
    'Defect 1 — Surface crack',
    'Defect 2 — Paint peeling',
    'Defect 3 — Tile misalignment',
    'Defect 4 — Leakage / Dampness',
    'Others',
  ];

  static final List<int> _floorNumbers =
      List.generate(15, (i) => i + 1);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _evidenceImage = image);
    }
  }

  void _removeImage() => setState(() => _evidenceImage = null);

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final state = context.read<AppState>();

    // Build the snag — id is left empty; Firestore assigns the real auto-ID
    final snag = SnagModel(
      id: '',
      createdBy: state.currentUser?.id ?? 'unknown',
      createdAt: DateTime.now(),
      location: _location!,
      floorNo: _floorNo!,
      flatNo: _flatNo!,
      element: _element!,
      trade: _trade!,
      defectDescription: _defectDescription!,
      severity: _severity!,
      status: SnagStatus.open,
      evidenceImagePath: null, // set by FirestoreService after upload
    );

    try {
      await state.addSnag(
        snag,
        imageFile: _evidenceImage != null ? File(_evidenceImage!.path) : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snag logged and saved to cloud successfully!'),
          backgroundColor: AppTheme.statusClosed,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      // Reset form
      setState(() {
        _location = null;
        _floorNo = null;
        _flatNo = null;
        _element = null;
        _trade = null;
        _defectDescription = null;
        _severity = null;
        _evidenceImage = null;
      });
      _formKey.currentState!.reset();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PPQAAppBar(title: 'Log a Snag'),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section 1: Location ─────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.location_on_outlined,
                title: 'Location Details',
              ),
              const SizedBox(height: 12),

              PPQADropdown<SnagLocation>(
                label: 'Location',
                isRequired: true,
                value: _location,
                items: SnagLocation.values,
                labelBuilder: (l) => l.label,
                onChanged: (val) => setState(() => _location = val),
                validator: (val) => val == null ? 'Please select a location' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: _floorNo,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Floor No. *'),
                      items: _floorNumbers
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('Floor $n'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _floorNo = val),
                      validator: (val) =>
                          val == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PPQADropdown<FlatNo>(
                      label: 'Flat No.',
                      isRequired: true,
                      value: _flatNo,
                      items: FlatNo.values,
                      labelBuilder: (f) => f.label,
                      onChanged: (val) => setState(() => _flatNo = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              PPQADropdown<SnagElement>(
                label: 'Element / Room',
                isRequired: true,
                value: _element,
                items: SnagElement.values,
                labelBuilder: (e) => e.label,
                onChanged: (val) => setState(() => _element = val),
                validator: (val) => val == null ? 'Please select an element' : null,
              ),
              const SizedBox(height: 20),

              // ── Section 2: Defect Details ───────────────────────────────────
              const _SectionHeader(
                icon: Icons.warning_amber_outlined,
                title: 'Defect Details',
              ),
              const SizedBox(height: 12),

              PPQADropdown<SnagTrade>(
                label: 'Trade',
                isRequired: true,
                value: _trade,
                items: SnagTrade.values,
                labelBuilder: (t) => t.label,
                onChanged: (val) => setState(() => _trade = val),
                validator: (val) => val == null ? 'Please select a trade' : null,
              ),
              const SizedBox(height: 12),

              PPQADropdown<String>(
                label: 'Defect Description',
                isRequired: true,
                value: _defectDescription,
                items: _defectDescriptions,
                labelBuilder: (s) => s,
                onChanged: (val) => setState(() => _defectDescription = val),
                validator: (val) =>
                    val == null ? 'Please select a defect description' : null,
              ),
              const SizedBox(height: 12),

              PPQADropdown<SnagSeverity>(
                label: 'Severity',
                isRequired: true,
                value: _severity,
                items: SnagSeverity.values,
                labelBuilder: (s) => s.label,
                itemColorBuilder: (s) => s.color,
                onChanged: (val) => setState(() => _severity = val),
                validator: (val) => val == null ? 'Please select severity' : null,
              ),
              const SizedBox(height: 20),

              // ── Section 3: Evidence ─────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.camera_alt_outlined,
                title: 'Evidence',
              ),
              const SizedBox(height: 12),

              _evidenceImage == null
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo Evidence'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: AppTheme.secondary),
                        foregroundColor: AppTheme.secondary,
                      ),
                      onPressed: _pickImage,
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_evidenceImage!.path),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: _removeImage,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Photo attached',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 28),

              // ── Submit button ───────────────────────────────────────────────
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
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Snag'),
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
