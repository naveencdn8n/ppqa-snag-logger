import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';
import '../main.dart';
import 'migration_screen.dart';
import 'resources_screen.dart';
import 'status_report_screen.dart';
import 'report_screen.dart';
import 'my_tasks_screen.dart';

class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _switchToDefectsList(BuildContext context) {
    final shell = context.findAncestorStateOfType<AppShellScreenState>();
    if (shell != null) {
      shell.switchTo(1);
    } else {
      // Fallback: push as a standalone screen
      _push(context, const _DefectsListNavigationWrapper());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final isAdmin = appState.isAdmin;

    return Scaffold(
      appBar: PPQAAppBar(
        title: 'Dashboard',
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => context.read<AppState>().signOut(),
            // authStateChanges() handles navigation back to LoginScreen automatically
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Welcome banner ──────────────────────────────────────────────
              Card(
                color: AppTheme.primary,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.domain_verification,
                          color: Colors.white, size: 38),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.username ?? 'Inspector'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Pre-Possession Quality Audit',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'QUICK ACCESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C757D),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),

              // ── Dashboard grid ──────────────────────────────────────────────
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _DashboardCard(
                    icon: Icons.assessment_outlined,
                    label: 'Benchmark\nReport',
                    color: const Color(0xFF1565C0),
                    onTap: () => _push(
                        context, const ResourcesScreen(initialTab: 2)),
                  ),
                  _DashboardCard(
                    icon: Icons.description_outlined,
                    label: 'Specifications',
                    color: const Color(0xFF00695C),
                    onTap: () => _push(
                        context, const ResourcesScreen(initialTab: 0)),
                  ),
                  _DashboardCard(
                    icon: Icons.map_outlined,
                    label: 'Layout\nDrawings',
                    color: const Color(0xFF6A1B9A),
                    onTap: () => _push(
                        context, const ResourcesScreen(initialTab: 1)),
                  ),
                  _DashboardCard(
                    icon: Icons.analytics_outlined,
                    label: 'Status\nReport',
                    color: const Color(0xFF558B2F),
                    onTap: () => _push(context, const StatusReportScreen()),
                  ),
                  _DashboardCard(
                    icon: Icons.summarize_outlined,
                    label: 'Reports',
                    color: const Color(0xFFE65100),
                    onTap: () => _push(context, const ReportScreen()),
                  ),
                  _DashboardCard(
                    icon: Icons.format_list_bulleted,
                    label: 'Open Snags',
                    color: const Color(0xFFB71C1C),
                    onTap: () => _switchToDefectsList(context),
                  ),
                  _DashboardCard(
                    icon: Icons.assignment_ind_outlined,
                    label: 'My Tasks',
                    color: const Color(0xFF1A3A5C),
                    onTap: () => _push(context, const MyTasksScreen()),
                  ),
                  // Migration card — admin only, v2 transition tool
                  if (isAdmin)
                    _DashboardCard(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Data\nMigration',
                      color: const Color(0xFF6A1B9A),
                      badge: 'ADMIN',
                      onTap: () => _push(context, const MigrationScreen()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Optional small badge shown in the top-right corner (e.g. 'ADMIN').
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212529),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Admin / role badge in top-right corner
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Thin wrapper so "Defects List" from dashboard can work as a standalone push.
class _DefectsListNavigationWrapper extends StatelessWidget {
  const _DefectsListNavigationWrapper();

  @override
  Widget build(BuildContext context) {
    // Avoid circular import by deferring to the named route
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Defects List')),
        ),
      ),
    );
  }
}
