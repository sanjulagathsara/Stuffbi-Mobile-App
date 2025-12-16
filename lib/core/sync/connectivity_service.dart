import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity status
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isConnected = true;
  bool _isInitialized = false;

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check initial status
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
    _isInitialized = true;
    debugPrint('[ConnectivityService] Initialized. Connected: $_isConnected');
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    
    // Connected if any result is not 'none'
    _isConnected = results.any((r) => r != ConnectivityResult.none);
    
    if (wasConnected != _isConnected) {
      debugPrint('[ConnectivityService] Connection changed: $_isConnected');
      notifyListeners();
    }
  }

  /// Check connectivity status right now
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    return _isConnected;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
