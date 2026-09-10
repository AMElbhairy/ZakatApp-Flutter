import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/errors/user_facing_error_mapper.dart';
import 'package:zakatapp_flutter/core/i18n/app_localizations.dart';
import 'package:zakatapp_flutter/features/smart_capture/smart_capture_display_messages.dart';

void main() {
  const AppLocalizations english = AppLocalizations(Locale('en'));
  const AppLocalizations arabic = AppLocalizations(Locale('ar'));

  test('maps network failures without exposing the cause', () {
    final String message = UserFacingErrorMapper.message(
      english,
      const SocketException('Bearer abc123 /path/to/database.sqlite'),
    );
    expect(message, english.tr('error_network_offline'));
    expect(message, isNot(contains('Bearer')));
    expect(message, isNot(contains('database.sqlite')));
  });

  test('maps timeouts to a localized safe message', () {
    expect(
      UserFacingErrorMapper.message(
        arabic,
        TimeoutException('SQLITE_CONSTRAINT: secret'),
      ),
      arabic.tr('error_network_timeout'),
    );
  });

  test('maps platform/provider errors to safe messages', () {
    final String message = UserFacingErrorMapper.message(
      english,
      PlatformException(
        code: 'sign_in_failed',
        message: '[firebase_auth/network-request-failed] raw',
      ),
    );
    expect(message, isNot(contains('firebase')));
    expect(message, isNot(contains('raw')));
  });

  test('maps Smart Capture reasons without exposing internal wording', () {
    expect(
      SmartCaptureDisplayMessages.reason(
        english,
        'Duplicate: exact payload match',
      ),
      english.tr('smart_capture_reason_duplicate'),
    );
    expect(
      SmartCaptureDisplayMessages.reason(arabic, 'Verification Code Message'),
      arabic.tr('smart_capture_reason_security'),
    );
    expect(
      SmartCaptureDisplayMessages.reason(english, 'internal parser diagnostic'),
      english.tr('smart_capture_reason_unknown'),
    );
  });
}
