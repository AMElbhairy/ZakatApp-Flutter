import 'dart:async';

import 'biometric_auth_result.dart';


import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();
  static final LocalAuthentication _auth = LocalAuthentication();
  static DateTime? _lastSensitiveUnlock;
  static const String _sensitiveUnlockTimestampKey =
      'biometric_sensitive_unlock_at_ms';

  /// Returns true if a sensitive action was authenticated successfully in the last 60 seconds.
  static bool get isSensitiveSessionUnlocked {
    if (_lastSensitiveUnlock == null) return false;
    final diff = DateTime.now().difference(_lastSensitiveUnlock!);
    return diff.inSeconds < 60;
  }

  /// Restore the in-memory sensitive-session cache from persisted storage.
  static Future<void> restoreSensitiveSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? timestamp = prefs.getInt(_sensitiveUnlockTimestampKey);
      if (timestamp == null) {
        return;
      }
      final DateTime restoredAt = DateTime.fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      ).toLocal();
      if (DateTime.now().difference(restoredAt).inSeconds < 60) {
        _lastSensitiveUnlock = restoredAt;
      } else {
        await prefs.remove(_sensitiveUnlockTimestampKey);
      }
    } catch (_) {
      // Ignore persistence issues; the in-memory cache still handles the active session.
    }
  }

  /// Mark the sensitive action session as unlocked right now.
  static void markSensitiveSessionUnlocked() {
    final DateTime now = DateTime.now();
    _lastSensitiveUnlock = now;
    unawaited(() async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _sensitiveUnlockTimestampKey,
          now.toUtc().millisecondsSinceEpoch,
        );
      } catch (_) {
        // Ignore persistence errors.
      }
    }());
  }

  /// Reset the sensitive action session lock.
  static void lockSensitiveSession() {
    _lastSensitiveUnlock = null;
    unawaited(() async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sensitiveUnlockTimestampKey);
      } catch (_) {
        // Ignore persistence errors.
      }
    }());
  }

  /// Check if biometrics are supported and enrolled.
  static Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();
      return availableBiometrics.isNotEmpty || (canCheck && isSupported);
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
        if (types.contains(BiometricType.fingerprint) ||
            types.contains(BiometricType.weak) ||
            types.contains(BiometricType.strong)) {
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
    bool biometricOnly = false,
  }) async {
    if (isSensitiveAction && isSensitiveSessionUnlocked) {
      return true;
    }

    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
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

  /// Authenticate the user and return a rich BiometricAuthResult.
  static Future<BiometricAuthResult> authenticateWithResult({
    required String reason,
    required BiometricAuthPurpose purpose,
    bool biometricOnly = false,
    bool allowSensitiveSessionReuse = false,
  }) async {
    if (purpose == BiometricAuthPurpose.sensitiveAction &&
        allowSensitiveSessionReuse &&
        isSensitiveSessionUnlocked) {
      return BiometricAuthResult.success;
    }
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        if (purpose == BiometricAuthPurpose.sensitiveAction) {
          markSensitiveSessionUnlocked();
        }
        return BiometricAuthResult.success;
      }
      return BiometricAuthResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled => BiometricAuthResult.cancelled,
        LocalAuthExceptionCode.systemCanceled => BiometricAuthResult.systemCancelled,
        LocalAuthExceptionCode.timeout => BiometricAuthResult.timedOut,
        LocalAuthExceptionCode.authInProgress => BiometricAuthResult.authInProgress,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled => BiometricAuthResult.notEnrolled,
        LocalAuthExceptionCode.temporaryLockout => BiometricAuthResult.lockedOut,
        LocalAuthExceptionCode.biometricLockout => BiometricAuthResult.permanentlyLockedOut,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.uiUnavailable => BiometricAuthResult.unavailable,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable => BiometricAuthResult.temporarilyUnavailable,
        _ => BiometricAuthResult.error,
      };
    } on PlatformException catch (e) {
      final String code = e.code.toLowerCase();
      if (code == 'notavailable' || code == 'not_available') {
        return BiometricAuthResult.unavailable;
      } else if (code == 'notenrolled' || code == 'not_enrolled') {
        return BiometricAuthResult.notEnrolled;
      } else if (code == 'lockedout' || code == 'locked_out') {
        return BiometricAuthResult.lockedOut;
      } else if (code == 'permanentlylockedout' || code == 'permanently_locked_out') {
        return BiometricAuthResult.permanentlyLockedOut;
      }
      if (code == 'canceled' || code == 'cancel' || code == 'usercanceled') {
        return BiometricAuthResult.cancelled;
      }
      return BiometricAuthResult.error;
    } catch (_) {
      return BiometricAuthResult.error;
    }
  }
}

