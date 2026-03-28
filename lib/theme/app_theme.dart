import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF1A3A5C); // Deep Navy Blue
  static const Color secondary      = Color(0xFF2C6FAC); // Steel Blue
  static const Color tertiary       = Color(0xFF4A7C94); // Slate Blue-Grey
  static const Color surface        = Color(0xFFF5F7FA); // Cool Off-White
  static const Color background     = Color(0xFFECEFF4); // Light Blue-Grey
  static const Color onPrimary      = Color(0xFFFFFFFF);

  // ─── Severity Colors ───────────────────────────────────────────────────────
  static const Color severityRedLine = Color(0xFFB71C1C);
  static const Color severityMajor   = Color(0xFFE65100);
  static const Color severityMinor   = Color(0xFFF9A825);

  // ─── Status Colors ─────────────────────────────────────────────────────────
  static const Color statusOpen       = Color(0xFFE65100);
  static const Color statusInProgress = Color(0xFF1565C0);
  static const Color statusClosed     = Color(0xFF2E7D32);

  // ─── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
      onPrimary: onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Cards — use CardThemeData (not CardTheme) for Flutter 3.19+
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFB00020)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFB00020), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6C757D)),
        floatingLabelStyle: const TextStyle(color: secondary),
      ),

      // Filled Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // NavigationBar (bottom nav) — use WidgetStateProperty (Flutter 3.19+)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: Color(0xFF6C757D));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: Color(0xFF6C757D),
            fontSize: 12,
          );
        }),
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // Text
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212529),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF495057),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Color(0xFF6C757D),
        ),
      ),
    );
  }
}
