import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkStatusController extends ChangeNotifier {
  NetworkStatusController({
    Future<bool> Function()? connectivityProbe,
    this.refreshInterval = const Duration(seconds: 20),
    this.probeTimeout = const Duration(seconds: 2),
  }) : _connectivityProbe = connectivityProbe ?? _defaultConnectivityProbe;

  final Future<bool> Function() _connectivityProbe;
  final Duration refreshInterval;
  final Duration probeTimeout;

  bool _isOffline = false;
  bool _isChecking = false;
  Timer? _timer;
  bool _started = false;

  bool get isOffline => _isOffline;
  bool get isChecking => _isChecking;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _timer = Timer.periodic(refreshInterval, (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    _isChecking = true;
    notifyListeners();
    try {
      final bool online = await _connectivityProbe().timeout(probeTimeout);
      _setOffline(!online);
    } catch (_) {
      _setOffline(true);
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Future<bool> _defaultConnectivityProbe() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
