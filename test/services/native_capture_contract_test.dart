import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/raw_capture_payload.dart';
import 'package:zakatapp_flutter/services/canonical_capture_normalizer.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('Native Capture Contract Tests', () {
    group('Android SMS Contract', () {
      test('preserves sender address, raw text, and timestamp from native bridge', () {
        final Map<String, dynamic> nativeAndroidMap = {
          'text': 'شراء بمبلغ 55.00 SAR لدى تموينات النرجس',
          'source': 'sms',
          'sourceIdentifier': 'Android SMS',
          'senderHeader': 'AlRajhiBank',
          'receivedAt': '2026-06-25T14:30:00.000Z',
          'platform': 'android',
        };

        final payload = RawCapturePayload.fromMap(nativeAndroidMap);

        expect(payload.rawText, 'شراء بمبلغ 55.00 SAR لدى تموينات النرجس');
        expect(payload.source, CaptureSource.sms);
        expect(payload.sourceIdentifier, 'Android SMS');
        expect(payload.senderHeader, 'AlRajhiBank');
        expect(payload.receivedAt.toUtc().toIso8601String(), '2026-06-25T14:30:00.000Z');
        expect(payload.platform, 'android');
      });

      test('multipart SMS simulated concatenation preserves body and sender without duplication', () {
        // Multipart SMS messages arrive in parts with identical sender
        final parts = [
          'شراء إنترنت 120.00 SAR من متجر أبل ',
          'بطاقة مدى *5566 في 2026-06-25 15:00',
        ];
        const sender = 'SNB-AlAhli';

        // Native receiver joins parts with StringBuilder
        final joinedBody = parts.join('');

        final payload = RawCapturePayload(
          rawText: joinedBody,
          source: CaptureSource.sms,
          sourceIdentifier: 'Android SMS',
          senderHeader: sender,
          receivedAt: DateTime.parse('2026-06-25T15:00:00.000Z'),
          platform: 'android',
        );

        expect(payload.rawText, 'شراء إنترنت 120.00 SAR من متجر أبل بطاقة مدى *5566 في 2026-06-25 15:00');
        expect(payload.senderHeader, sender);

        final normalized = CanonicalCaptureNormalizer.normalize(payload.rawText);
        final parsed = SmartCaptureParser.parse(normalized);
        expect(parsed.amount, 120.0);
        expect(parsed.currency, 'SAR');
      });

      test('backward compatibility: legacy queued JSON without senderHeader, receivedAt, or platform', () {
        // Simulates a queue created before this refactor
        final legacyMap = {
          'text': 'شراء 40.00 SAR من كافيه أروما',
          'source': 'sms',
        };

        final payload = RawCapturePayload.fromMap(
          legacyMap,
          fallbackSource: CaptureSource.sms,
          fallbackPlatform: 'android',
        );

        expect(payload.rawText, 'شراء 40.00 SAR من كافيه أروما');
        expect(payload.source, CaptureSource.sms);
        expect(payload.senderHeader, isNull);
        expect(payload.sourceIdentifier, isNull);
        expect(payload.platform, 'android');
        expect(payload.receivedAt, isNotNull);

        // Parsing works seamlessly
        final normalized = CanonicalCaptureNormalizer.normalize(payload.rawText);
        final parsed = SmartCaptureParser.parse(normalized);
        expect(parsed.amount, 40.0);
        expect(parsed.currency, 'SAR');
      });

      test('serialization/deserialization across process restarts preserves all fields', () {
        final original = RawCapturePayload(
          rawText: 'Purchase of 15.00 SAR at Costa Coffee',
          source: CaptureSource.sms,
          sourceIdentifier: 'Android SMS',
          senderHeader: 'RiyadBank',
          receivedAt: DateTime.parse('2026-06-25T16:00:00.000Z'),
          platform: 'android',
          nativeMessageId: 'sms-msg-9921',
        );

        final jsonString = jsonEncode(original.toMap());
        final restoredMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = RawCapturePayload.fromMap(restoredMap);

        expect(restored.rawText, original.rawText);
        expect(restored.source, original.source);
        expect(restored.sourceIdentifier, original.sourceIdentifier);
        expect(restored.senderHeader, original.senderHeader);
        expect(restored.receivedAt, original.receivedAt);
        expect(restored.platform, original.platform);
        expect(restored.nativeMessageId, original.nativeMessageId);
      });
    });

    group('iOS Shortcut Contract', () {
      test('preserves shortcut raw text, source, and timestamp from native bridge', () {
        final Map<String, dynamic> nativeIosMap = {
          'text': 'شراء إنترنت 29.00 SAR - Apple Pay\nمن: Jarir\nفي 12:00',
          'source': 'shortcut',
          'sourceIdentifier': 'Apple Automation',
          'receivedAt': '2026-06-25T12:00:00.000Z',
          'platform': 'ios',
        };

        final payload = RawCapturePayload.fromMap(nativeIosMap);

        expect(payload.rawText, nativeIosMap['text']);
        expect(payload.source, CaptureSource.shortcut);
        expect(payload.sourceIdentifier, 'Apple Automation');
        expect(payload.senderHeader, isNull);
        expect(payload.platform, 'ios');
        expect(payload.receivedAt.toUtc().toIso8601String(), '2026-06-25T12:00:00.000Z');
      });

      test('Invariant: native preview never determines persisted financial data', () {
        // If native preview had guessed wrong merchant or amount,
        // canonical Dart SmartCaptureParser is the SOLE authority.
        const bankMessage = 'شراء 75.00 SAR - Apple Pay\nمن: Bookstore ABC';
        final payload = RawCapturePayload(
          rawText: bankMessage,
          source: CaptureSource.shortcut,
          receivedAt: DateTime.now(),
          platform: 'ios',
        );

        // Native preview might have guessed something generic
        const simulatedNativePreviewMerchant = 'Unknown Merchant';
        const simulatedNativePreviewAmount = 0.0;

        // Canonical parse must run independently and be authoritative
        final normalized = CanonicalCaptureNormalizer.normalize(payload.rawText);
        final canonicalResult = SmartCaptureParser.parse(normalized);

        expect(canonicalResult.amount, 75.0);
        expect(canonicalResult.merchantName, 'Bookstore ABC');
        expect(canonicalResult.amount, isNot(simulatedNativePreviewAmount));
        expect(canonicalResult.merchantName, isNot(simulatedNativePreviewMerchant));
      });
    });

    group('Shared OTP and Security Filtering Consistency', () {
      final List<String> otpFixtures = [
        'رمز التحقق لمرة واحدة هو: 482910 لإتمام العملية',
        'كود التحقق الخاص بك هو: 9988 لا تشاركه مع أحد',
        'كلمة مرور لمرة واحدة: 4433',
        'Your OTP is 123456 to verify purchase of SAR 100',
        'Your verification code is: 9876. Do not share this with anyone.',
        'Use one-time password 554433 to authorize your card login.',
      ];

      for (final fixture in otpFixtures) {
        final title = fixture.length > 20 ? fixture.substring(0, 20) : fixture;
        test('OTP filter rejects sensitive security message: "$title..."', () {
          // Both native regex and Dart parser must agree this is not a valid financial transaction
          final normalized = CanonicalCaptureNormalizer.normalize(fixture);
          final parsed = SmartCaptureParser.parse(normalized);

          expect(parsed.isValid, isFalse, reason: 'OTP should not be treated as valid transaction');
          expect(
            parsed.ignoreReason,
            anyOf(
              equals('Verification Code Message'),
              contains('Code'),
              contains('OTP'),
            ),
          );
        });
      }
    });
  });
}
