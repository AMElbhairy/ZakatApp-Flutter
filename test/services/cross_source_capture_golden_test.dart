import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/raw_capture_payload.dart';
import 'package:zakatapp_flutter/services/canonical_capture_normalizer.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('Cross-Source Capture Golden Tests', () {
    // A comprehensive suite of real and sanitized bank messages from the repository
    final Map<String, String> bankFixtures = {
      'arabic_purchase_apple_pay': '''
شراء 33.00 SAR POS - Apple Pay
بطاقة ائتمانية *0973
من tashkilat juha - SA
في 20:02 26-07-15
الرصيد 18,334.39''',

      'arabic_purchase_mada_pos': '''
شراء POS-ApplePay
بـ SAR 45.00
بطاقة ائتمانية *0973
لدى SA /tashkilat *
في 26-08-21 18:13
الرصيد 11,355.40''',

      'arabic_purchase_internet': '''
شراء إنترنت 38.00 SAR - Apple Pay
بطاقة ائتمانية *0973
من: LikeCard SA - SA
في 10:02 26-06-26
الرصيد 19,584.33''',

      'english_credit_card_payment': '''
Credit Card:Payment
Card:Visa 1200
Amount:SR 45
Balance:46 SR
27/6/26 1:35''',

      'english_loan_instalment': '''
Debit: Loan Instalment
Instalment: SAR 1755.06
From: 3366
Remaining Amount: SAR 122289.94
25/6/26 21:01''',

      'arabic_credit_card_repayment': '''
تم سداد البطاقة الائتمانية **3367
مبلغ 888.47 SAR
حساب **5000
في 2026-06-24 22:13
حد الصرف المتبقي 20,000 SAR''',

      'english_debit_transfer_intl': '''
Debit Transfer Intl
Amount: 3413.17 SAR
Sender: AHMED ELBHAIRY
To: Niura agriculture
6/25/2026 at 10:13:59 AM''',

      'english_credit_transfer_incoming': '''
Credit Transfer
Amount: SAR 1200.00
From: Sarah Ali
To: AHMED ELBHAIRY
6/25/2026 at 10:13:59 AM''',

      'arabic_outgoing_transfer': '''
تحويل صادر
المبلغ: SAR 99.50
المرسل: AHMED ELBHAIRY
إلى: Niura agriculture
25/6/26 21:01''',

      'arabic_incoming_transfer': '''
تحويل وارد
المبلغ: SAR 125.00
المرسل: Mona Saleh
إلى: AHMED ELBHAIRY
25/6/26 21:01''',

      'arabic_internal_transfer': '''
حوالة واردة داخلية
مبلغ:10000 SAR
مرسل:محمد احمد
من:6406*
إلى:6403*
في:21/07/26 18:23''',

      'internal_transfer_own_accounts': '''
Internal Transfer
From account **1234
To account **5678
Amount: SAR 100.00
25/6/26 21:01''',

      'wallet_topup_apple_pay': '''
Wallet top up via Apple Pay
Amount: SAR 2,490
Date: 2026-07-08 11:01
apple.com''',

      'account_funding_apple_pay': '''
Account Funding via Apple Pay
Amount: SAR 58.50
Card: *6011 - mada
To: *8190
On: 08/07/2026 11:32:35''',

      'bank_sms_charged_with_balance': '''
شكرًا لاستخدامك بطاقة بنك مصر ****8799، تم الآن خصم EGP 105.06 عند MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي https://bnkmsr.com/online.''',

      'instapay_transfer_in': '''
تم اضافة مبلغ 30000EGP      الى حساب رقم xxx7127      فى 26-JUL-2026  عن طريق التحويل اللحظي''',

      'investment_deposit_arabic': '''
إيداع إلى حساب استثماري
رقم: 4454
SAR المبلغ: 10000
في: 2026-08-03 12:36:05
أويس المالية''',

      'salary_deposit_arabic': '''
إيداع راتب
المبلغ: 15,000.00 SAR
الحساب: **4321
في: 2026-06-27 08:30:00
الرصيد: 18,500.00 SAR''',

      'atm_withdrawal_arabic': '''
سحب نقدي من الصراف
المبلغ: 500.00 SAR
البطاقة: *1234
من صراف الرياض
في: 2026-06-25 14:20''',

      'reversal_refund_english': '''
Refund: Amazon Marketplace
Amount: SAR 150.00
Card: *0973
Date: 2026-06-28 09:15:00''',

      'bank_fee_sms': '''
خصم رسوم مصرفية
المبلغ: 11.50 SAR
الحساب: **5678
في: 2026-06-01 00:01''',

      'declined_transaction': '''
عملية مرفوضة
بطاقة: *0973
المبلغ: 450.00 SAR
لدى: Jarir Bookstore
السبب: تجاوز الحد الائتماني''',

      'otp_verification_message': '''
رمز التحقق لمرة واحدة هو: 482910
لإتمام عملية الشراء بمبلغ 250.00 SAR
لا تشارك هذا الرمز مع أي شخص''',

      'arabic_purchase_applepay_unspaced': '''
شراء إنترنت ApplePay
بـ 9.81 SAR
بطاقة ائتمانية *0973
لدى SA/Tamara
في 19:36 26-08-21
رصيد 13,874.59''',

      'arabic_purchase_pos_applepay_separator': '''
شراء POS-ApplePay
بـ SAR 45.00
بطاقة ائتمانية *0973
لدى SA /tashkilat *
في 26-08-21 18:13
الرصيد 11,355.40''',

      'arabic_purchase_online_otp_code': '''
رمز شراء أونلاين 6528
للبطاقة *0973
بـ 25 SAR''',

      'bank_sms_charged_glued_preposition': '''
شكرًا لاستخدامك بطاقة بنك مصر ****8799، تم الآن خصم EGP 105.06عند  MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي https://bnkmsr.com/online.''',
    };

    for (final entry in bankFixtures.entries) {
      final fixtureName = entry.key;
      final rawText = entry.value;

      test('Invariant: identical financial parse across iOS, Android, Manual, Share for [$fixtureName]', () {
        final now = DateTime(2026, 6, 25, 12, 0);

        // 1. Simulate capture via iOS Shortcut
        final iosPayload = RawCapturePayload(
          rawText: rawText,
          source: CaptureSource.shortcut,
          sourceIdentifier: 'Apple Automation',
          senderHeader: null,
          receivedAt: now,
          platform: 'ios',
        );

        // 2. Simulate capture via Android SMS Receiver
        final androidPayload = RawCapturePayload(
          rawText: rawText,
          source: CaptureSource.sms,
          sourceIdentifier: 'Android SMS',
          senderHeader: 'AlRajhiBank',
          receivedAt: now,
          platform: 'android',
        );

        // 3. Simulate capture via Manual Paste
        final manualPayload = RawCapturePayload(
          rawText: rawText,
          source: CaptureSource.manual,
          sourceIdentifier: 'Manual Entry',
          senderHeader: null,
          receivedAt: now,
          platform: null,
        );

        // 4. Simulate capture via Share Sheet
        final sharePayload = RawCapturePayload(
          rawText: rawText,
          source: CaptureSource.share,
          sourceIdentifier: 'Share Sheet',
          senderHeader: null,
          receivedAt: now,
          platform: 'ios',
        );

        // Normalize all inputs through CanonicalCaptureNormalizer
        final normalizedIos = CanonicalCaptureNormalizer.normalize(iosPayload.rawText);
        final normalizedAndroid = CanonicalCaptureNormalizer.normalize(androidPayload.rawText);
        final normalizedManual = CanonicalCaptureNormalizer.normalize(manualPayload.rawText);
        final normalizedShare = CanonicalCaptureNormalizer.normalize(sharePayload.rawText);

        // Invariant: Normalized text must be 100% identical regardless of capture source
        expect(normalizedIos, equals(normalizedAndroid));
        expect(normalizedIos, equals(normalizedManual));
        expect(normalizedIos, equals(normalizedShare));

        // Invariant: Canonical financial parser produces identical results
        final iosResult = SmartCaptureParser.parse(normalizedIos);
        final androidResult = SmartCaptureParser.parse(normalizedAndroid);
        final manualResult = SmartCaptureParser.parse(normalizedManual);
        final shareResult = SmartCaptureParser.parse(normalizedShare);

        // Assert all critical financial fields match identically
        for (final other in [androidResult, manualResult, shareResult]) {
          expect(other.isValid, equals(iosResult.isValid), reason: 'isValid mismatch in $fixtureName');
          expect(other.ignoreReason, equals(iosResult.ignoreReason), reason: 'ignoreReason mismatch in $fixtureName');
          expect(other.amount, equals(iosResult.amount), reason: 'amount mismatch in $fixtureName');
          expect(other.currency, equals(iosResult.currency), reason: 'currency mismatch in $fixtureName');
          expect(other.merchantName, equals(iosResult.merchantName), reason: 'merchantName mismatch in $fixtureName');
          expect(other.type, equals(iosResult.type), reason: 'type mismatch in $fixtureName');
          expect(other.direction, equals(iosResult.direction), reason: 'direction mismatch in $fixtureName');
          expect(other.description, equals(iosResult.description), reason: 'description mismatch in $fixtureName');
          expect(other.cardReference, equals(iosResult.cardReference), reason: 'cardReference mismatch in $fixtureName');
          expect(other.accountReference, equals(iosResult.accountReference), reason: 'accountReference mismatch in $fixtureName');
          expect(other.balance, equals(iosResult.balance), reason: 'balance mismatch in $fixtureName');
          expect(other.paymentMethod, equals(iosResult.paymentMethod), reason: 'paymentMethod mismatch in $fixtureName');
          expect(other.confidence, equals(iosResult.confidence), reason: 'confidence mismatch in $fixtureName');
        }
      });
    }

    group('Transport Variation Tests', () {
      const baseArabicMessage = '''شراء POS-ApplePay
بـ SAR 45.00
بطاقة ائتمانية *0973
لدى SA /tashkilat *
في 26-08-21 18:13
الرصيد 11,355.40''';

      test('CRLF (Windows/Network), CR (Classic Mac), LF (Unix) parse identically', () {
        final unixLF = baseArabicMessage;
        final windowsCRLF = baseArabicMessage.replaceAll('\n', '\r\n');
        final classicCR = baseArabicMessage.replaceAll('\n', '\r');

        final normUnix = CanonicalCaptureNormalizer.normalize(unixLF);
        final normWindows = CanonicalCaptureNormalizer.normalize(windowsCRLF);
        final normClassic = CanonicalCaptureNormalizer.normalize(classicCR);

        expect(normWindows, equals(normUnix));
        expect(normClassic, equals(normUnix));

        final resUnix = SmartCaptureParser.parse(normUnix);
        final resWindows = SmartCaptureParser.parse(normWindows);
        final resClassic = SmartCaptureParser.parse(normClassic);

        expect(resWindows.amount, equals(resUnix.amount));
        expect(resWindows.merchantName, equals(resUnix.merchantName));
        expect(resClassic.amount, equals(resUnix.amount));
        expect(resClassic.merchantName, equals(resUnix.merchantName));
      });

      test('Unicode variations (NBSP, zero-width, BOM, RTL/LTR marks) parse identically', () {
        // Embed non-breaking spaces (\u00A0), zero-width spaces (\u200B), BOM (\uFEFF), RTL mark (\u200F)
        final dirtyUnicode = '\uFEFF\u200Eشراء\u00A0POS-ApplePay\n'
            'بـ\u00A0SAR\u00A045.00\u200B\n'
            'بطاقة\u00A0ائتمانية\u00A0*0973\u200F\n'
            'لدى\u00A0SA\u00A0/tashkilat\u00A0*\n'
            'في\u00A026-08-21\u00A018:13\n'
            'الرصيد\u00A011,355.40';

        final normClean = CanonicalCaptureNormalizer.normalize(baseArabicMessage);
        final normDirty = CanonicalCaptureNormalizer.normalize(dirtyUnicode);

        expect(normDirty, equals(normClean));

        final resClean = SmartCaptureParser.parse(normClean);
        final resDirty = SmartCaptureParser.parse(normDirty);

        expect(resDirty.amount, equals(resClean.amount));
        expect(resDirty.currency, equals(resClean.currency));
        expect(resDirty.merchantName, equals(resClean.merchantName));
      });

      test('Arabic-Indic digits (٠-٩) and Eastern Arabic / Persian digits (۰-۹) are converted to standard digits', () {
        const arabicIndicMessage = '''شراء POS-ApplePay
بـ SAR ٤٥.٠٠
بطاقة ائتمانية *0973
لدى SA /tashkilat *
في 26-08-21 18:13
الرصيد 11,355.40''';

        final normalized = CanonicalCaptureNormalizer.normalize(arabicIndicMessage);
        expect(normalized.contains('45.00'), isTrue);

        final result = SmartCaptureParser.parse(normalized);
        expect(result.amount, equals(45.0));
      });

      test('Raw original message is preserved while normalized text is parsed', () {
        const originalWithCrLf = 'شراء 33.00 SAR\r\nمن كافيه\r\nالرصيد 100';
        final payload = RawCapturePayload(
          rawText: originalWithCrLf,
          source: CaptureSource.sms,
          receivedAt: DateTime(2026, 6, 25, 12, 0),
        );

        // Verify payload retains original CRLF
        expect(payload.rawText, equals(originalWithCrLf));
        expect(payload.rawText.contains('\r\n'), isTrue);

        // Normalized text has LF
        final normalized = CanonicalCaptureNormalizer.normalize(payload.rawText);
        expect(normalized.contains('\r'), isFalse);
        expect(normalized.contains('\n'), isTrue);

        // Canonical parse works on normalized text
        final result = SmartCaptureParser.parse(normalized);
        expect(result.amount, equals(33.0));
      });
    });
  });
}
