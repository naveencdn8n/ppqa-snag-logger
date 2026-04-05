import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // Stream-based routing — no manual Navigator.push needed for auth
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still checking auth state — show splash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          // Signed in → go to app
          if (snapshot.hasData) {
            return const AppShellScreen();
          }
          // Not signed in → go to login
          return const LoginScreen();
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

  static const List<Widget> _screens = [
    MainDashboardScreen(),
    OpenSnagsScreen(),
    LogSnagScreen(),
    ReportScreen(),
  ];

  void switchTo(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

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
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Open Snags',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Log Snag',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
