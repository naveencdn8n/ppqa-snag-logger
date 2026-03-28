import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable AppBar used on every screen.
///
/// Displays the CRC company logo on the top-left, the [title] text
/// centre-left, and optional [actions] on the right.
/// If [showBack] is true (default for sub-screens), a white back
/// button is shown between the logo and the title.
class PPQAAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PPQAAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;

  /// Whether to show a back/close button (use on push-navigated screens).
  final bool showBack;

  /// Override the back-button behaviour (defaults to Navigator.pop).
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primary,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),

          // ── CRC Logo ─────────────────────────────────────────────────────
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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

          // ── Back button (sub-screens only) ────────────────────────────────
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              tooltip: 'Back',
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )
          else
            const SizedBox(width: 12),

          // ── Screen title ──────────────────────────────────────────────────
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
