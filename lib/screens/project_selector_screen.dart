import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

/// Shown when the user belongs to multiple projects and must choose one,
/// or when they want to switch projects from inside the app.
///
/// [showBack] controls whether the AppBar shows a back arrow.
///   • false → first-launch flow (no back, selecting navigates to AppShell via Consumer rebuild)
///   • true  → in-app switch (back arrow present, selecting pops this screen)
class ProjectSelectorScreen extends StatelessWidget {
  const ProjectSelectorScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final projects = appState.availableProjects;
    final user = appState.currentUser;

    return Scaffold(
      appBar: showBack
          ? PPQAAppBar(
              title: 'Switch Project',
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_outlined),
                  tooltip: 'Logout',
                  onPressed: () => context.read<AppState>().signOut(),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: projects.isEmpty
            ? _buildEmptyState(context)
            : _buildProjectList(context, projects, user?.username),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_off_outlined,
                size: 64,
                color: AppTheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No Project Assigned',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212529),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have not been added to any project yet.\n'
              'Please ask your administrator to run the data migration '
              'or add you to a project.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              onPressed: () => context.read<AppState>().signOut(),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Project list ─────────────────────────────────────────────────────────────

  Widget _buildProjectList(
    BuildContext context,
    List<ProjectModel> projects,
    String? username,
  ) {
    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.domain_verification,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username != null
                                ? 'Welcome, $username'
                                : 'Welcome',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
                    // Sign out (only on first-launch flow)
                    if (!showBack)
                      IconButton(
                        icon: const Icon(Icons.logout_outlined,
                            color: Colors.white70),
                        tooltip: 'Logout',
                        onPressed: () =>
                            context.read<AppState>().signOut(),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${projects.length} PROJECT${projects.length == 1 ? '' : 'S'} AVAILABLE',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a project to continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Project cards ──────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProjectCard(
                  project: projects[i],
                  isActive: context.read<AppState>().activeProjectId ==
                      projects[i].id,
                  onTap: () => _selectProject(context, projects[i].id),
                ),
              ),
              childCount: projects.length,
            ),
          ),
        ),
      ],
    );
  }

  void _selectProject(BuildContext context, String projectId) {
    context.read<AppState>().setActiveProject(projectId);
    if (showBack && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // If showBack == false, Consumer in PPQAApp will rebuild to AppShellScreen
  }
}

// ── Project card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.isActive,
    required this.onTap,
  });

  final ProjectModel project;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.color);

    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: projectColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            // ── Colour bar ───────────────────────────────────────────────────
            Container(
              width: 6,
              height: 90,
              decoration: BoxDecoration(
                color: projectColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212529),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: project.status),
                      ],
                    ),
                    if (project.clientName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        project.clientName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF495057),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (project.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF6C757D)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              project.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6C757D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Arrow / active indicator ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: isActive
                  ? Icon(Icons.check_circle_rounded,
                      color: projectColor, size: 22)
                  : const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFADB5BD), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color; // already a Flutter Color
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
