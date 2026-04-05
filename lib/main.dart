import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/open_snags_screen.dart';
import 'screens/log_snag_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence so snag text data is cached locally
  // and queued writes sync automatically when connectivity is restored.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const PPQAApp(),
    ),
  );
}

class PPQAApp extends StatelessWidget {
  const PPQAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PPQA Snag Logger',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          // Auth or role still being resolved — show splash
          if (appState.authLoading || appState.roleLoading) {
            return const _SplashScreen();
          }
          // Not signed in → login screen
          if (!appState.isLoggedIn) return const LoginScreen();
          // Signed in but blocked → blocked screen
          if (appState.isBlocked) return const _BlockedScreen();
          // Active user → main app
          return const AppShellScreen();
        },
      ),
    );
  }
}

// ── Offline / syncing banners ─────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final msg = pendingCount > 0
        ? 'Offline — $pendingCount snag${pendingCount == 1 ? '' : 's'} queued for upload'
        : 'Offline — snags will sync when connected';
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFBF360C),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncingBanner extends StatelessWidget {
  const _SyncingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Uploading $count queued snag${count == 1 ? '' : 's'}...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blocked screen (shown when user.status == 'blocked') ─────────────────────
class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Account Blocked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account has been blocked by an administrator.\n'
                  'Please contact your project supervisor for assistance.',
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
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Splash screen (shown briefly while Firebase checks auth state) ─────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.domain_verification,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PPQA Snag Logger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Shell (bottom nav + IndexedStack) ─────────────────────────────────────
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

/// State is public so [MainDashboardScreen] can find it via
/// [context.findAncestorStateOfType<AppShellScreenState>()].
class AppShellScreenState extends State<AppShellScreen> {
  int _currentIndex = 0;

  // Full screen list (inspector / supervisor)
  static const List<Widget> _fullScreens = [
    MainDashboardScreen(),
    OpenSnagsScreen(),
    LogSnagScreen(),
    ReportScreen(),
  ];

  // Reduced screen list for viewers (no Log Snag tab)
  static const List<Widget> _viewerScreens = [
    MainDashboardScreen(),
    OpenSnagsScreen(),
    ReportScreen(),
  ];

  void switchTo(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isViewer = appState.isViewOnly;

    final screens = isViewer ? _viewerScreens : _fullScreens;

    // Clamp index in case role changes while app is open
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Column(
        children: [
          // ── Network status banners ─────────────────────────────────────
          if (!appState.isOnline)
            _OfflineBanner(pendingCount: appState.pendingUploadCount)
          else if (appState.isSyncingPending)
            _SyncingBanner(count: appState.pendingUploadCount),

          // ── Main screen content ────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Open Snags',
          ),
          if (!isViewer)
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Log Snag',
            ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
