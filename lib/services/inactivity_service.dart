import 'dart:async';

import 'package:flutter/foundation.dart';

/// Manages a 15-minute inactivity auto-logout timer.
///
/// Intended usage:
///   1. Call [resetTimer] on any user interaction (pointer-down).
///   2. Call [stopTimer] when the user signs out or the app is backgrounded.
///   3. Provide [onTimeout] — it fires when 15 minutes pass without activity,
///      and the caller should trigger [AppState.signOut()] inside it.
class InactivityService {
  static const Duration kTimeout = Duration(minutes: 15);

  final VoidCallback onTimeout;
  Timer? _timer;

  InactivityService({required this.onTimeout});

  /// True while the countdown is running.
  bool get isRunning => _timer?.isActive ?? false;

  /// Starts (or restarts) the 15-minute countdown from now.
  void resetTimer() {
    _timer?.cancel();
    _timer = Timer(kTimeout, () {
      _timer = null;
      onTimeout();
    });
  }

  /// Cancels any running countdown.
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stopTimer();
}
