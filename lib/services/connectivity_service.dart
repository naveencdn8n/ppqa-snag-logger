import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [connectivity_plus] to expose simple bool-based online/offline state.
class ConnectivityService {
  final _connectivity = Connectivity();

  /// Returns true if the device currently has any network access.
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream that emits true when online, false when offline.
  Stream<bool> get onStatusChanged => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
}
