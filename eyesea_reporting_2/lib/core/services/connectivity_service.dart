import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity status.
/// Triggers callbacks when connectivity changes.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  /// Stream of online/offline status changes
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize and start listening to connectivity changes
  Future<void> initialize() async {
    // Get initial status
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // We're online if we have any connectivity that's not 'none'
    _isOnline = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      debugPrint(
          '📶 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      _controller.add(_isOnline);
    }
  }

  /// Check current connectivity (one-time check)
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _isOnline;
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
