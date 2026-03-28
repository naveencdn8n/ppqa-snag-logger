import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/defects_list_screen.dart';
import 'screens/log_snag_screen.dart';
import 'screens/report_screen.dart';

void main() {
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
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home':  (_) => const AppShellScreen(),
      },
    );
  }
}

// ─── App Shell (bottom nav + IndexedStack) ────────────────────────────────────
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

/// State is public so MainDashboardScreen can find it via
/// [context.findAncestorStateOfType<AppShellScreenState>()].
class AppShellScreenState extends State<AppShellScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    MainDashboardScreen(),
    DefectsListScreen(),
    LogSnagScreen(),
    ReportScreen(),
  ];

  void switchTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
            label: 'Defect List',
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
