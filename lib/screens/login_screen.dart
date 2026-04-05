import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AppState>().signInWithGoogle();
      // Navigation is handled automatically by authStateChanges() in main.dart
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('network')) return 'No internet connection. Please try again.';
    if (raw.contains('cancelled') || raw.contains('canceled')) return 'Sign-in was cancelled.';
    if (raw.contains('sign_in_failed')) return 'Google Sign-In failed. Check your internet and try again.';
    return 'Sign-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── CRC Brand bar ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppTheme.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset(
                      'assets/images/crc_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'CRC',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Login content ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // App icon
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.domain_verification,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'PPQA Snag Logger',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pre-Possession Quality Audit',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6C757D)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Sign-in label
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use your company Google Workspace account',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6C757D)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFB00020), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB00020),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Google Sign-In button
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              side: const BorderSide(
                                  color: Color(0xFFDADCE0), width: 1.5),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G logo
                                _GoogleLogo(),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3C4043),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 32),

                    // Footer
                    const Text(
                      'Access is restricted to authorised\nCRC team members only.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFADB5BD),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google G logo ─────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the four-colour arcs of the Google G
    final segments = [
      // Blue (top-right)
      _GSegment(
          startAngle: -0.52, sweepAngle: 1.57, color: const Color(0xFF4285F4)),
      // Red (top-left + bottom-left)
      _GSegment(
          startAngle: 1.05, sweepAngle: 2.09, color: const Color(0xFFEA4335)),
      // Yellow (bottom)
      _GSegment(
          startAngle: 3.14, sweepAngle: 0.97, color: const Color(0xFFFBBC05)),
      // Green (bottom-right)
      _GSegment(
          startAngle: 4.11, sweepAngle: 1.74, color: const Color(0xFF34A853)),
    ];

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.color
        ..strokeWidth = size.width * 0.22
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        seg.startAngle,
        seg.sweepAngle,
        false,
        paint,
      );
    }

    // White cutout rectangle for the horizontal bar of the G
    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - size.height * 0.18,
        size.width * 0.96,
        center.dy + size.height * 0.18,
      ),
      barPaint,
    );

    // Blue fill for the bar
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - size.height * 0.13,
        size.width * 0.90,
        center.dy + size.height * 0.13,
      ),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GSegment {
  final double startAngle;
  final double sweepAngle;
  final Color color;
  const _GSegment(
      {required this.startAngle,
      required this.sweepAngle,
      required this.color});
}
