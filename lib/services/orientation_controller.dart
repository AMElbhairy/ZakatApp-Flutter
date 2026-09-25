import 'package:flutter/services.dart';

abstract interface class OrientationController {
  Future<void> enterLandscape();
  Future<void> restorePortrait();
}

class SystemOrientationController implements OrientationController {
  const SystemOrientationController();

  @override
  Future<void> enterLandscape() {
    return SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Future<void> restorePortrait() {
    return SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
}
