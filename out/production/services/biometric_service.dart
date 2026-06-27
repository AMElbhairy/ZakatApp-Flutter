import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';

class BiometricService {
  BiometricService._();
  static final LocalAuthentication _auth = LocalAuthentication();
  static DateTime? _lastSensitiveUnlock;

  /// Returns true if a sensitive action was authenticated successfully in the last 60 seconds.
  static bool get isSensitiveSessionUnlocked {
    if (_lastSensitiveUnlock == null) return false;
    final diff = DateTime.now().difference(_lastSensitiveUnlock!);
    return diff.inSeconds < 60;
  }

  /// Mark the sensitive action session as unlocked right now.
  static void markSensitiveSessionUnlocked() {
    _lastSensitiveUnlock = DateTime.now();
  }

  /// Reset the sensitive action session lock.
  static void lockSensitiveSession() {
    _lastSensitiveUnlock = null;
  }

  /// Check if biometrics are supported and enrolled.
  static Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Dynamically get the system biometric name (e.g. Face ID, Touch ID, Fingerprint, Biometrics).
  static Future<String> getBiometricTypeLabel() async {
    try {
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      if (Platform.isIOS) {
        if (types.contains(BiometricType.face)) {
          return 'Face ID';
        } else if (types.contains(BiometricType.fingerprint)) {
          return 'Touch ID';
        }
        return 'Face ID / Touch ID';
      } else {
        if (types.contains(BiometricType.fingerprint) || types.contains(BiometricType.weak) || types.contains(BiometricType.strong)) {
          return 'Fingerprint';
        } else if (types.contains(BiometricType.face)) {
          return 'Face Unlock';
        }
        return 'Biometrics';
      }
    } catch (_) {
      return 'Biometrics';
    }
  }

  /// Authenticate the user. If isSensitiveAction is true, checks and updates the 60-second sensitive cache window.
  static Future<bool> authenticate({
    required String reason,
    bool isSensitiveAction = false,
  }) async {
    if (isSensitiveAction && isSensitiveSessionUnlocked) {
      return true;
    }

    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && isSensitiveAction) {
        markSensitiveSessionUnlocked();
      }
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
