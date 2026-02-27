import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight connectivity check using DNS lookup.
///
/// No third-party dependency required — uses [InternetAddress.lookup].
/// Returns `true` only if the device can actually reach the public internet,
/// not just whether Wi-Fi / mobile data is enabled.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  /// Cache to avoid hammering DNS on rapid successive checks.
  DateTime? _lastCheck;
  bool _lastResult = true;
  static const _cacheDuration = Duration(seconds: 3);

  /// Returns `true` if the device can reach the internet.
  Future<bool> get isConnected async {
    // Use cached result if fresh enough.
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cacheDuration) {
      return _lastResult;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      _lastResult = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      _lastResult = false;
    } on Exception {
      _lastResult = false;
    }

    _lastCheck = DateTime.now();

    if (kDebugMode) {
      debugPrint('[Connectivity] isConnected=$_lastResult');
    }
    return _lastResult;
  }

  /// Throw a user-friendly [SocketException] if offline.
  ///
  /// Call at the start of a request pipeline to fail fast with a clear
  /// message instead of waiting for a TCP timeout.
  Future<void> requireConnectivity() async {
    if (!await isConnected) {
      throw const SocketException(
        'No internet connection. Please check your network.',
      );
    }
  }
}
