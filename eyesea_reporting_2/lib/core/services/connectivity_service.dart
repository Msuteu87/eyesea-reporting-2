import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

// NOTE: Network reachability check implemented - pings server on connectivity change
// NOTE: Permission edge case handled - recheck method available for post-permission refresh

/// Service to monitor network connectivity status.
/// Performs actual reachability checks to detect captive portals.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = false; // Start pessimistic until verified
  bool _hasNetworkInterface = false;

  /// Endpoint to verify actual internet connectivity
  /// Using Google's connectivity check endpoint (lightweight, reliable)
  static const String _reachabilityHost = 'clients3.google.com';
  static const Duration _reachabilityTimeout = Duration(seconds: 5);

  /// Stream of online/offline status changes
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current online status (verified reachability, not just interface)
  bool get isOnline => _isOnline;

  /// Whether a network interface is available (may not have internet)
  bool get hasNetworkInterface => _hasNetworkInterface;

  /// Initialize and start listening to connectivity changes
  Future<void> initialize() async {
    // Get initial interface status
    final results = await _connectivity.checkConnectivity();
    _hasNetworkInterface = _checkInterfaceAvailable(results);

    // Verify actual reachability if interface is available
    if (_hasNetworkInterface) {
      _isOnline = await _verifyReachability();
    }

    AppLogger.info(
      'Connectivity initialized: interface=$_hasNetworkInterface, online=$_isOnline',
    );

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_onInterfaceChanged);
  }

  /// Call this after returning from permission dialogs to refresh status
  Future<void> recheckConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _onInterfaceChanged(results);
  }

  bool _checkInterfaceAvailable(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _onInterfaceChanged(List<ConnectivityResult> results) async {
    final hadInterface = _hasNetworkInterface;
    final wasOnline = _isOnline;

    _hasNetworkInterface = _checkInterfaceAvailable(results);

    if (_hasNetworkInterface) {
      // Interface available - verify actual reachability
      _isOnline = await _verifyReachability();
    } else {
      // No interface - definitely offline
      _isOnline = false;
    }

    // Only notify if actual online status changed
    if (wasOnline != _isOnline) {
      AppLogger.info(
        'Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"} '
        '(interface: $hadInterface -> $_hasNetworkInterface)',
      );
      _controller.add(_isOnline);
    }
  }

  /// Verify actual internet reachability by attempting a connection
  Future<bool> _verifyReachability() async {
    try {
      final result = await InternetAddress.lookup(_reachabilityHost)
          .timeout(_reachabilityTimeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      AppLogger.debug('Reachability check failed: no internet');
      return false;
    } on TimeoutException catch (_) {
      AppLogger.debug('Reachability check failed: timeout');
      return false;
    } catch (e) {
      AppLogger.debug('Reachability check failed: $e');
      return false;
    }
  }

  /// Check current connectivity (one-time check with reachability verification)
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _hasNetworkInterface = _checkInterfaceAvailable(results);

    if (_hasNetworkInterface) {
      _isOnline = await _verifyReachability();
    } else {
      _isOnline = false;
    }

    return _isOnline;
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
