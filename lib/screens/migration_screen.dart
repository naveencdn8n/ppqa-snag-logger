import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/migration_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final MigrationService _migrationService = MigrationService();

  _MigState _state = _MigState.checking;
  final List<MigrationStep> _steps = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    final needed = await _migrationService.isMigrationNeeded;
    if (!mounted) return;
    setState(() {
      _state = needed ? _MigState.ready : _MigState.alreadyDone;
    });
  }

  Future<void> _startMigration() async {
    final uid = context.read<AppState>().currentUser?.id ?? '';
    if (uid.isEmpty) return;

    setState(() {
      _isRunning = true;
      _steps.clear();
    });

    await for (final step in _migrationService.migrate(uid)) {
      if (!mounted) return;
      setState(() {
        // Replace last step if same title (running → done/error transition)
        if (_steps.isNotEmpty && _steps.last.title == step.title) {
          _steps[_steps.length - 1] = step;
        } else {
          _steps.add(step);
        }

        if (step.title == 'Migration Complete' || step.isError) {
          _isRunning = false;
          _state = step.isError ? _MigState.error : _MigState.done;
        }
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PPQAAppBar(title: 'Data Migration', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_steps.isNotEmpty) ...[
                Expanded(child: _buildStepLog()),
                const SizedBox(height: 16),
              ],
              _buildActionArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _headerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _headerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _headerColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_headerIcon, size: 32, color: _headerColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headerTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _headerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _headerSubtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6C757D), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _headerColor {
    switch (_state) {
      case _MigState.checking:   return AppTheme.primary;
      case _MigState.ready:      return const Color(0xFFE65100);
      case _MigState.running:    return AppTheme.primary;
      case _MigState.done:       return const Color(0xFF2E7D32);
      case _MigState.alreadyDone:return const Color(0xFF2E7D32);
      case _MigState.error:      return const Color(0xFFB71C1C);
    }
  }

  IconData get _headerIcon {
    switch (_state) {
      case _MigState.checking:   return Icons.hourglass_top_rounded;
      case _MigState.ready:      return Icons.upload_rounded;
      case _MigState.running:    return Icons.sync_rounded;
      case _MigState.done:       return Icons.check_circle_rounded;
      case _MigState.alreadyDone:return Icons.check_circle_rounded;
      case _MigState.error:      return Icons.error_rounded;
    }
  }

  String get _headerTitle {
    switch (_state) {
      case _MigState.checking:    return 'Checking migration status…';
      case _MigState.ready:       return 'Migration Required';
      case _MigState.running:     return 'Migration in Progress';
      case _MigState.done:        return 'Migration Complete';
      case _MigState.alreadyDone: return 'Already Migrated';
      case _MigState.error:       return 'Migration Failed';
    }
  }

  String get _headerSubtitle {
    switch (_state) {
      case _MigState.checking:
        return 'Connecting to Firestore…';
      case _MigState.ready:
        return 'Your v1 data (snags, locations, trades) needs to be copied '
            'into the new multi-project structure. Original data is never deleted.';
      case _MigState.running:
        return 'Copying data to the Default Project. Do not close the app.';
      case _MigState.done:
        return 'All v1 data is now in the Default Project. '
            'The original collections are still intact for the v1 app.';
      case _MigState.alreadyDone:
        return 'The Default Project already exists. Migration was previously '
            'completed successfully.';
      case _MigState.error:
        return 'An error occurred. You can safely retry — '
            'the migration is idempotent.';
    }
  }

  // ── Step log ─────────────────────────────────────────────────────────────────

  Widget _buildStepLog() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _steps.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFDEE2E6)),
        itemBuilder: (_, i) => _StepRow(step: _steps[i]),
      ),
    );
  }

  // ── Action area ───────────────────────────────────────────────────────────────

  Widget _buildActionArea() {
    if (_state == _MigState.checking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state == _MigState.alreadyDone || _state == _MigState.done) {
      return FilledButton.icon(
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Back to Dashboard'),
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }

    if (_state == _MigState.running) {
      return const Column(
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Please keep the app open until migration completes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
          ),
        ],
      );
    }

    // ready or error
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This copies data — it does NOT delete anything. '
                  'Run it once. It is safe to retry if interrupted.',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF6C757D), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: Icon(_state == _MigState.error
              ? Icons.refresh_rounded
              : Icons.play_arrow_rounded),
          label: Text(_state == _MigState.error
              ? 'Retry Migration'
              : 'Start Migration'),
          onPressed: _isRunning ? null : _startMigration,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: _state == _MigState.error
                ? const Color(0xFFB71C1C)
                : AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

// ── Step row widget ───────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final MigrationStep step;

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    final color = _color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon / spinner
          SizedBox(
            width: 24,
            height: 24,
            child: step.isRunning
                ? CircularProgressIndicator(
                    strokeWidth: 2.5, color: color)
                : Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (step.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    step.detail,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6C757D), height: 1.3),
                  ),
                ],
                // Progress bar for snag migration
                if (step.isRunning &&
                    step.total != null &&
                    step.total! > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (step.done ?? 0) / step.total!,
                      minHeight: 5,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${step.done} / ${step.total}',
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    switch (step.status) {
      case MigrationStepStatus.pending: return Icons.radio_button_unchecked;
      case MigrationStepStatus.running: return Icons.sync_rounded;
      case MigrationStepStatus.done:    return Icons.check_circle_rounded;
      case MigrationStepStatus.error:   return Icons.error_rounded;
    }
  }

  Color get _color {
    switch (step.status) {
      case MigrationStepStatus.pending: return const Color(0xFF9E9E9E);
      case MigrationStepStatus.running: return AppTheme.primary;
      case MigrationStepStatus.done:    return const Color(0xFF2E7D32);
      case MigrationStepStatus.error:   return const Color(0xFFB71C1C);
    }
  }
}

// ── State enum ────────────────────────────────────────────────────────────────

enum _MigState { checking, ready, running, done, alreadyDone, error }
