import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidSmsCaptureService {
  AndroidSmsCaptureService._();

  static const MethodChannel _channel = MethodChannel(
    'com.zakahwealth.smartcapture.native',
  );

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<bool> hasSmsPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isAndroidBatteryOptimizationIgnored',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestSmsPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'setAndroidSmsAutoCaptureEnabled',
        <String, dynamic>{'enabled': enabled},
      );
    } catch (error) {
      debugPrint('AndroidSmsCaptureService.setEnabled failed: $error');
    }
  }

  static Future<void> syncSmartCaptureState(
    Map<String, dynamic> state,
  ) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'syncSmartCaptureState',
        <String, dynamic>{'state': state},
      );
    } catch (error) {
      debugPrint('AndroidSmsCaptureService.syncSmartCaptureState failed: $error');
    }
  }

  static Future<void> syncEnabled(bool enabled) async {
    await setEnabled(enabled);
  }

  static Future<bool> openBatteryOptimizationSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openAndroidBatteryOptimizationSettings',
          ) ??
          false;
    } catch (error) {
      debugPrint(
        'AndroidSmsCaptureService.openBatteryOptimizationSettings failed: $error',
      );
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAndroidAppSettings') ??
          false;
    } catch (error) {
      debugPrint('AndroidSmsCaptureService.openAppSettings failed: $error');
      return false;
    }
  }
}
