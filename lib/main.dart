import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/inactivity_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/open_snags_screen.dart';
import 'screens/log_snag_screen.dart';
import 'screens/project_selector_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics: catch all unhandled errors ───────────────────────────────
  // Only enable in non-debug builds to avoid noise during development.
  if (!kDebugMode) {
    // Pass Flutter framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass async/platform errors that fall outside the Flutter error zone
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

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

class PPQAApp extends StatefulWidget {
  const PPQAApp({super.key});

  @override
  State<PPQAApp> createState() => _PPQAAppState();
}

class _PPQAAppState extends State<PPQAApp> with WidgetsBindingObserver {
  // ── Inactivity & lifecycle ────────────────────────────────────────────────
  late final InactivityService _inactivity;

  /// Reference to AppState stored once in didChangeDependencies so we can
  /// safely add/remove the listener (and access it in dispose).
  AppState? _appState;

  /// Whether the user was logged-in the last time we checked.
  bool _wasLoggedIn = false;

  /// The time the app went into the background (paused state).
  /// Null while the app is in the foreground.
  DateTime? _pausedAt;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inactivity = InactivityService(onTimeout: _signOutDueToInactivity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Grab AppState once and subscribe — guards against repeated calls.
    if (_appState == null) {
      _appState = context.read<AppState>();
      _appState!.addListener(_onAuthChanged);
    }
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAuthChanged);
    _inactivity.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Auth-change listener ──────────────────────────────────────────────────

  /// Called whenever AppState notifies — start/stop the timer based on
  /// whether the user is currently logged in.
  void _onAuthChanged() {
    final appState = _appState;
    if (appState == null || !mounted) return;

    final loggedIn = appState.isLoggedIn;
    if (loggedIn && !_wasLoggedIn) {
      // User just logged in — begin the inactivity countdown.
      _inactivity.resetTimer();
    } else if (!loggedIn && _wasLoggedIn) {
      // User just logged out (manually or via auto-logout) — kill the timer.
      _inactivity.stopTimer();
    }
    _wasLoggedIn = loggedIn;
  }

  // ── Inactivity timeout ────────────────────────────────────────────────────

  void _signOutDueToInactivity() {
    if (!mounted) return;
    _appState?.signOut();
  }

  // ── App lifecycle (background / foreground / close) ───────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = _appState;
    if (appState == null || !mounted) return;

    switch (state) {
      case AppLifecycleState.paused:
        // App went to background — pause the inactivity timer and record when.
        if (appState.isLoggedIn) {
          _pausedAt = DateTime.now();
          _inactivity.stopTimer();
        }

      case AppLifecycleState.resumed:
        // App came back to the foreground.
        final paused = _pausedAt;
        _pausedAt = null;

        if (appState.isLoggedIn) {
          if (paused != null &&
              DateTime.now().difference(paused) >= InactivityService.kTimeout) {
            // User left the app for ≥ 15 minutes — treat as session expired.
            appState.signOut();
          } else {
            // Still within the window — resume the countdown fresh.
            _inactivity.resetTimer();
          }
        }

      case AppLifecycleState.detached:
        // App process is being torn down — sign out so next launch starts fresh.
        if (appState.isLoggedIn) {
          appState.signOut();
        }

      default:
        break;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Reset the inactivity timer on any touch anywhere in the app.
      // Listener fires on raw pointer events without consuming them,
      // so all gestures still reach their intended targets normally.
      onPointerDown: (_) {
        if (_appState?.isLoggedIn == true) {
          _inactivity.resetTimer();
        }
      },
      child: MaterialApp(
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
            // Waiting for project list from Firestore
            if (appState.projectsLoading) return const _SplashScreen();
            // No active project: show picker (handles both 0 and multiple projects)
            if (!appState.hasActiveProject) {
              return const ProjectSelectorScreen(showBack: false);
            }
            // Active project selected → main app
            return const AppShellScreen();
          },
        ),
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
