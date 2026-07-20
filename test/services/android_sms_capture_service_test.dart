import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/android_sms_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'com.zakahwealth.smartcapture.native',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('permission denied returns false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'requestSmsPermission') return false;
          return null;
        });

    expect(await AndroidSmsCaptureService.requestSmsPermission(), isFalse);
  });

  test('permission granted returns true', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'requestSmsPermission') return true;
          return null;
        });

    expect(await AndroidSmsCaptureService.requestSmsPermission(), isTrue);
  });

  test('open battery settings returns true from native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'openAndroidBatteryOptimizationSettings') {
            return true;
          }
          return null;
        });

    expect(
      await AndroidSmsCaptureService.openBatteryOptimizationSettings(),
      isTrue,
    );
  });

  test('open app settings returns true from native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'openAndroidAppSettings') return true;
          return null;
        });

    expect(await AndroidSmsCaptureService.openAppSettings(), isTrue);
  });
}
