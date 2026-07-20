import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NetworkStatusController extends ChangeNotifier {
  NetworkStatusController({
    Future<bool> Function()? connectivityProbe,
    this.refreshInterval = const Duration(seconds: 20),
    this.probeTimeout = const Duration(seconds: 3),
  }) : _connectivityProbe = connectivityProbe ?? _defaultConnectivityProbe;

  final Future<bool> Function() _connectivityProbe;
  final Duration refreshInterval;
  final Duration probeTimeout;

  bool _isOffline = false;
  bool _isChecking = false;
  int _consecutiveFailures = 0;
  Timer? _timer;
  bool _started = false;

  bool get isOffline => _isOffline;
  bool get isChecking => _isChecking;

  Future<void> start({
    Duration initialDelay = Duration.zero,
  }) async {
    if (_started) return;
    _started = true;
    if (initialDelay > Duration.zero) {
      await Future<void>.delayed(initialDelay);
    }
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
      if (online) {
        _consecutiveFailures = 0;
        _setOffline(false);
      } else {
        _registerFailure();
      }
    } catch (_) {
      _registerFailure();
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void _registerFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 2) {
      _setOffline(true);
    }
  }

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    if (!value) {
      _consecutiveFailures = 0;
    }
    _isOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Future<bool> _defaultConnectivityProbe() async {
    final List<Future<bool> Function()> probes = <Future<bool> Function()>[
      () async {
        final http.Response response = await http
            .head(Uri.parse('https://clients3.google.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        return response.statusCode >= 200 && response.statusCode < 400;
      },
      () async {
        final InternetAddress address =
            await InternetAddress.lookup('example.com')
                .timeout(const Duration(seconds: 3))
                .then((List<InternetAddress> result) => result.first);
        final Socket socket = await Socket.connect(
          address.address,
          53,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
        return true;
      },
    ];

    for (final Future<bool> Function() probe in probes) {
      try {
        if (await probe()) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }
}
