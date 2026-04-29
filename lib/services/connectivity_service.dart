import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [connectivity_plus] and adds a real internet probe so the app
/// can distinguish between "has a network interface" and "has actual internet".
///
/// Why two checks?
/// [connectivity_plus] only inspects the network interface (WiFi card on =
/// online). It returns "online" even when the user has turned off mobile data
/// but WiFi is connected, or when the WiFi has no internet access. A Storage
/// upload attempted in that state hangs indefinitely. The [isReallyOnline]
/// probe catches this in ≤ 3 s and routes the snag to the offline queue
/// instead of waiting on a stalled upload.
class ConnectivityService {
  final _connectivity = Connectivity();

  /// Fast interface-level check — returns true if ANY network interface is up.
  /// Used by the connectivity stream listener (must be fast / non-blocking).
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Deep internet check — verifies actual internet access by opening a TCP
  /// connection to Google's public DNS (8.8.8.8:53, hardcoded IP so no DNS
  /// resolution is needed). Times out in 3 seconds.
  ///
  /// Use this before attempting Storage uploads so the app doesn't hang on a
  /// network that has a physical interface but no route to the internet
  /// (e.g. mobile data off while WiFi is connected to a local-only router).
  Future<bool> isReallyOnline() async {
    // Quick interface check first — if no interface, skip the probe
    if (!await isOnline) return false;

    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stream that emits true when online, false when offline.
  /// Reflects network interface changes only (fast, event-driven).
  Stream<bool> get onStatusChanged => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
}
