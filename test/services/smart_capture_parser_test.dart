import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('SmartCaptureParser merchant extraction', () {
    test('arabic purchase uses من field and strips safe country suffix', () {
      final parsed = SmartCaptureParser.parse(
        'شراء إنترنت 38.00 SAR - Apple Pay\n'
        'بطاقة ائتمانية *0973\n'
        'من: LikeCard SA - SA\n'
        'في 10:02 26-06-26\n'
        'الرصيد 19,584.33',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 38.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'LikeCard SA');
      expect(parsed.paymentMethod, 'Apple Pay');
      expect(parsed.cardReference, '*0973');
      expect(parsed.accountReference, isNull);
      expect(parsed.balance, 19584.33);
      expect(parsed.remainingAmount, isNull);
      _expectDateTime(parsed.capturedAt, 2026, 6, 26, 10, 2);
    });

    test('arabic purchase removes country code prefix (e.g., SA/Tamara)', () {
      final parsed = SmartCaptureParser.parse(
        'شراء إنترنت ApplePay\n'
        'بـ 9.81 SAR\n'
        'بطاقة ائتمانية *0973\n'
        'لدى SA/Tamara\n'
        'في 19:36 26-08-21\n'
        'رصيد 13,874.59',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 9.81);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'SA/Tamara');
      expect(parsed.paymentMethod, 'Apple Pay');
      expect(parsed.cardReference, '*0973');
      expect(parsed.balance, 13874.59);
    });

    test('arabic purchase with country prefix in merchant line extracts merchant cleanly', () {
      final parsed = SmartCaptureParser.parse(
        'شراء POS-ApplePay\n'
        'بـ SAR 45.00\n'
        'بطاقة ائتمانية *0973\n'
        'لدى SA /tashkilat *\n'
        'في 26-08-21 18:13\n'
        'الرصيد 11,355.40',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 45.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'SA /tashkilat *');
      expect(parsed.paymentMethod, 'Apple Pay');
      expect(parsed.cardReference, '*0973');
      expect(parsed.balance, 11355.4);
    });

    test('arabic purchase code message is recognized as OTP and ignored', () {
      final parsed = SmartCaptureParser.parse(
        'رمز شراء أونلاين 6528\n'
        'للبطاقة *0973\n'
        'بـ 25 SAR\n'
        'من Amazon SA\n'
        'في 11:32 26-08-21',
      );

      expect(parsed.isValid, false);
      expect(parsed.ignoreReason, 'Verification Code Message');
    });

    test('arabic Apple Pay purchase keeps merchant clean and ignores date line', () {
      final parsed = SmartCaptureParser.parse(
        'شراء 33.00 SAR POS - Apple Pay\n'
        'بطاقة ائتمانية *0973\n'
        'من tashkilat juha - SA\n'
        'في 20:02 26-07-15\n'
        'الرصيد 18,334.39',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 33.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Tashkilat Juha');
      expect(parsed.paymentMethod, 'Apple Pay');
      expect(parsed.cardReference, '*0973');
      expect(parsed.balance, 18334.39);
      _expectDateTime(parsed.capturedAt, 2015, 7, 26, 20, 2);
    });

    test('english credit card payment maps to explicit merchant intent', () {
      final parsed = SmartCaptureParser.parse(
        'Credit Card:Payment\n'
        'Card:Visa 1200\n'
        'Amount:SR 45\n'
        'Balance:46 SR\n'
        '27/6/26 1:35',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 45.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Credit Card Payment');
      expect(parsed.paymentMethod, 'Visa');
      expect(parsed.cardReference, 'Visa 1200');
      expect(parsed.accountReference, isNull);
      expect(parsed.balance, 46.0);
      expect(parsed.remainingAmount, isNull);
      _expectDateTime(parsed.capturedAt, 2026, 6, 27, 1, 35);
    });

    test('english loan instalment maps to explicit merchant intent', () {
      final parsed = SmartCaptureParser.parse(
        'Debit: Loan Instalment\n'
        'Instalment: SAR 1755.06\n'
        'From: 3366\n'
        'Remaining Amount: SAR 122289.94\n'
        '25/6/26 21:01',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 1755.06);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Loan Instalment');
      expect(parsed.paymentMethod, isNull);
      expect(parsed.cardReference, isNull);
      expect(parsed.accountReference, '3366');
      expect(parsed.balance, isNull);
      expect(parsed.remainingAmount, 122289.94);
      _expectDateTime(parsed.capturedAt, 2026, 6, 25, 21, 1);
    });

    test('arabic credit card repayment maps to explicit merchant intent', () {
      final parsed = SmartCaptureParser.parse(
        'تم سداد البطاقة الائتمانية **3367\n'
        'مبلغ 888.47 SAR\n'
        'حساب **5000\n'
        'في 2026-06-24 22:13\n'
        'حد الصرف المتبقي 20,000 SAR',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 888.47);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'سداد البطاقة الائتمانية');
      expect(parsed.cardReference, '**3367');
      expect(parsed.accountReference, '**5000');
      expect(parsed.remainingAmount, 20000.0);
      _expectDateTime(parsed.capturedAt, 2026, 6, 24, 22, 13);
    });

    test(
      'debit transfer intl uses recipient as payee and sender as metadata',
      () {
        final parsed = SmartCaptureParser.parse(
          'Debit Transfer Intl\n'
          'Amount: 3413.176306 SAR\n'
          'Sender: AHMED ELBHAIRY\n'
          'To: Niura agriculture\n'
          '6/25/2026 at 10:13:59 AM',
          currentUserName: 'AHMED ELBHAIRY',
        );

        expect(parsed.type, 'expense');
        expect(parsed.direction, 'out');
        expect(parsed.amount, 3413.176306);
        expect(parsed.currency, 'SAR');
        expect(parsed.merchantName, 'Niura agriculture');
        expect(parsed.senderName, 'AHMED ELBHAIRY');
        expect(parsed.recipientName, 'Niura agriculture');
        expect(parsed.paymentMethod, isNull);
        _expectDateTime(parsed.capturedAt, 2026, 6, 25, 10, 13, 59);
      },
    );

    test('credit transfer uses sender as source and income direction', () {
      final parsed = SmartCaptureParser.parse(
        'Credit Transfer\n'
        'Amount: SAR 1200.00\n'
        'From: Sarah Ali\n'
        'To: AHMED ELBHAIRY\n'
        '6/25/2026 at 10:13:59 AM',
        currentUserName: 'AHMED ELBHAIRY',
      );

      expect(parsed.type, 'income');
      expect(parsed.direction, 'in');
      expect(parsed.amount, 1200.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Sarah Ali');
      expect(parsed.senderName, 'Sarah Ali');
      expect(parsed.recipientName, 'AHMED ELBHAIRY');
      _expectDateTime(parsed.capturedAt, 2026, 6, 25, 10, 13, 59);
    });

    test('arabic outgoing transfer extracts recipient and expense type', () {
      final parsed = SmartCaptureParser.parse(
        'تحويل صادر\n'
        'المبلغ: SAR 99.50\n'
        'المرسل: AHMED ELBHAIRY\n'
        'إلى: Niura agriculture\n'
        '25/6/26 21:01',
        currentUserName: 'AHMED ELBHAIRY',
      );

      expect(parsed.type, 'expense');
      expect(parsed.direction, 'out');
      expect(parsed.amount, 99.50);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Niura agriculture');
      expect(parsed.senderName, 'AHMED ELBHAIRY');
      expect(parsed.recipientName, 'Niura agriculture');
      _expectDateTime(parsed.capturedAt, 2026, 6, 25, 21, 1);
    });

    test('arabic incoming transfer extracts sender and income type', () {
      final parsed = SmartCaptureParser.parse(
        'تحويل وارد\n'
        'المبلغ: SAR 125.00\n'
        'المرسل: Mona Saleh\n'
        'إلى: AHMED ELBHAIRY\n'
        '25/6/26 21:01',
        currentUserName: 'AHMED ELBHAIRY',
      );

      expect(parsed.type, 'income');
      expect(parsed.direction, 'in');
      expect(parsed.amount, 125.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Mona Saleh');
      expect(parsed.senderName, 'Mona Saleh');
      expect(parsed.recipientName, 'AHMED ELBHAIRY');
      _expectDateTime(parsed.capturedAt, 2026, 6, 25, 21, 1);
    });

    test('arabic incoming internal transfer with custom labels extracts sender and income type', () {
      final parsed = SmartCaptureParser.parse(
        'حوالة واردة داخلية\n'
        'مبلغ:10000 SAR\n'
        'مرسل:محمد احمد\n'
        'من:6406*\n'
        'إلى:6403*\n'
        'في:21/07/26 18:23',
      );

      expect(parsed.type, 'income');
      expect(parsed.direction, 'in');
      expect(parsed.amount, 10000.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'محمد احمد');
      expect(parsed.senderName, 'محمد احمد');
    });

    test('arabic incoming internal transfer notification omitting remittance keyword extracts sender and income type', () {
      final parsed = SmartCaptureParser.parse(
        'واردة داخلية\n'
        'مبلغ:10000 SAR\n'
        'مرسل:محمد احمد\n'
        'من:6406*\n'
        'إلى:6403*\n'
        'في:21/07/26 18:23',
      );

      expect(parsed.type, 'income');
      expect(parsed.direction, 'in');
      expect(parsed.amount, 10000.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'محمد احمد');
      expect(parsed.senderName, 'محمد احمد');
    });

    test('internal transfer between own accounts stays transfer', () {
      final parsed = SmartCaptureParser.parse(
        'Internal Transfer\n'
        'From account **1234\n'
        'To account **5678\n'
        'Amount: SAR 100.00\n'
        '25/6/26 21:01',
      );

      expect(parsed.type, 'expense');
      expect(parsed.direction, 'internal');
      expect(parsed.amount, 100.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, isNull);
      expect(parsed.senderName, '**1234');
      expect(parsed.recipientName, '**5678');
    });

    test('generic transfer with unknown direction requires review', () {
      final parsed = SmartCaptureParser.parse(
        'Transfer\n'
        'Amount: SAR 100.00\n'
        'Sender: Ahmed\n'
        'Recipient: Niura agriculture\n'
        '25/6/26 21:01',
      );

      expect(parsed.type, 'unknown');
      expect(parsed.direction, 'unknown');
      expect(parsed.amount, 100.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, isNull);
      expect(parsed.senderName, 'Ahmed');
      expect(parsed.recipientName, 'Niura agriculture');
    });

    test('To label is never included in merchant string', () {
      final parsed = SmartCaptureParser.parse(
        'Debit Transfer Intl\n'
        'Amount: 100 SAR\n'
        'Sender: Ahmed\n'
        'To: Niura agriculture\n'
        '25/6/26 21:01',
      );

      expect(parsed.merchantName, 'Niura agriculture');
      expect(parsed.recipientName, 'Niura agriculture');
    });

    test('Sender label is never included in merchant string', () {
      final parsed = SmartCaptureParser.parse(
        'Credit Transfer\n'
        'Amount: SAR 100\n'
        'Sender: Ahmed\n'
        'To: Niura agriculture\n'
        '25/6/26 21:01',
      );

      expect(parsed.merchantName, 'Ahmed');
      expect(parsed.senderName, 'Ahmed');
      expect(parsed.recipientName, 'Niura agriculture');
    });

    test('sender equal to current user confirms outgoing direction', () {
      final parsed = SmartCaptureParser.parse(
        'Transfer\n'
        'Amount: SAR 100\n'
        'Sender: AHMED ELBHAIRY\n'
        'To: Niura agriculture\n'
        '25/6/26 21:01',
        currentUserName: 'AHMED ELBHAIRY',
      );

      expect(parsed.direction, 'out');
      expect(parsed.type, 'expense');
      expect(parsed.merchantName, 'Niura agriculture');
    });

    test('Apple Pay is captured as payment method not merchant', () {
      final parsed = SmartCaptureParser.parse(
        'شراء إنترنت 38.00 SAR - Apple Pay\n'
        'بطاقة ائتمانية *0973\n'
        'من: LikeCard SA - SA',
      );

      expect(parsed.merchantName, 'LikeCard SA');
      expect(parsed.paymentMethod, 'Apple Pay');
      expect(parsed.cardReference, '*0973');
    });

    test(
      'wallet top up phrases stay transfer even when Apple Pay and apple.com appear',
      () {
        final cases = <Map<String, Object>>[
          <String, Object>{
            'message':
                'Wallet top up via Apple Pay\n'
                'Amount: SAR 2,490\n'
                'Date: 2026-07-08 11:01\n'
                'apple.com',
            'amount': 2490.0,
          },
          <String, Object>{
            'message':
                'Top up wallet with Apple Pay\n'
                'Amount: 2,490 SAR\n'
                'Date: 2026-07-08 11:01',
            'amount': 2490.0,
          },
          <String, Object>{
            'message':
                'Load wallet using Apple Pay\n'
                'Amount: SAR 2490\n'
                'Date: 2026-07-08 11:01',
            'amount': 2490.0,
          },
          <String, Object>{
            'message':
                'شحن المحفظة عبر Apple Pay\n'
                'المبلغ: 2,490 SAR\n'
                'التاريخ: 2026-07-08 11:01',
            'amount': 2490.0,
          },
          <String, Object>{
            'message':
                'إعادة شحن المحفظة عبر Apple Pay\n'
                'المبلغ: SAR 2490\n'
                'التاريخ: 2026-07-08 11:01',
            'amount': 2490.0,
          },
        ];

        for (final caseData in cases) {
          final parsed = SmartCaptureParser.parse(
            caseData['message']! as String,
          );

          expect(parsed.type, 'expense');
          expect(parsed.direction, 'out');
          expect(parsed.amount, caseData['amount'] as double);
          expect(parsed.currency, 'SAR');
          expect(parsed.merchantName, isNull);
          expect(parsed.paymentMethod, 'Apple Pay');
          expect(parsed.description, 'Wallet Top Up');
        }
      },
    );

    test(
      'account funding via Apple Pay is treated like wallet funding and not as apple.com',
      () {
        final parsed = SmartCaptureParser.parse(
          'Account Funding via Apple Pay\n'
          'Amount: SAR 58.50\n'
          'Card: *6011 - mada\n'
          'To: *8190\n'
          'On: 08/07/2026 11:32:35',
        );

        expect(parsed.type, 'expense');
        expect(parsed.direction, 'out');
        expect(parsed.amount, 58.5);
        expect(parsed.currency, 'SAR');
        expect(parsed.merchantName, isNull);
        expect(parsed.paymentMethod, 'Apple Pay');
        expect(parsed.cardReference, '*6011 - mada');
        expect(parsed.recipientName, '*8190');
        expect(parsed.description, 'Wallet Top Up');
      },
    );

    test('Visa 1200 is captured as card and payment method not merchant', () {
      final parsed = SmartCaptureParser.parse(
        'Credit Card:Payment\n'
        'Card:Visa 1200\n'
        'Amount:SR 45\n'
        'Balance:46 SR\n'
        '27/6/26 1:35',
      );

      expect(parsed.merchantName, 'Credit Card Payment');
      expect(parsed.paymentMethod, 'Visa');
      expect(parsed.cardReference, 'Visa 1200');
    });

    test('Arabic من field is used for purchase merchant extraction', () {
      final parsed = SmartCaptureParser.parse(
        'شراء عبر الإنترنت\n'
        'Amount: SAR 100\n'
        'من: LikeCard SA - SA',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 100.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'LikeCard SA');
    });

    test('longer merchant phrase wins over shorter Mobily rule', () {
      final parsed = SmartCaptureParser.parse(
        'Mobily Pay Wallet Top-up\n'
        'Amount:2000.00 SAR\n'
        'From Card:1897*MADA\n'
        'On:04/19/2026 10:48:03\n'
        'Current Balance:2000.00 SAR',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 2000.0);
      expect(parsed.currency, 'SAR');
      expect(parsed.merchantName, 'Mobily Pay');
      expect(parsed.paymentMethod, 'MADA');
      expect(parsed.cardReference, '1897*MADA');
      expect(parsed.balance, 2000.0);
      _expectDateTime(parsed.capturedAt, 2026, 4, 19, 10, 48, 3);
    });

    test('bank sms captures the charged amount and merchant inline', () {
      final parsed = SmartCaptureParser.parse(
        'شكرًا لاستخدامك بطاقة بنك مصر ****8799، تم الآن خصم EGP 105.06 عند MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي https://bnkmsr.com/online.',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 105.06);
      expect(parsed.currency, 'EGP');
      expect(parsed.merchantName, 'MY FAWRY');
    });

    test('bank sms captures merchant even when the label is glued to amount', () {
      final parsed = SmartCaptureParser.parse(
        'شكرًا لاستخدامك بطاقة بنك مصر ****8799، تم الآن خصم EGP 105.06عند  MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي https://bnkmsr.com/online.',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 105.06);
      expect(parsed.currency, 'EGP');
      expect(parsed.merchantName, 'MY FAWRY');
    });

    test(
      'merchant rules stay type-specific when the captured type differs',
      () {
        final parsed = SmartCaptureParser.parse(
          'Amazon refund processed\n'
          'Amount: EGP 99.00\n'
          'Refund to card',
          merchantRules: <String, MerchantRule>{
            'amazon': MerchantRule(
              merchantName: 'Amazon',
              categoryId: 'Shopping',
              defaultType: 'expense',
              autoApprove: true,
              usageCount: 1,
              confidence: 1.0,
              source: 'custom',
              aliases: const <String>['amazon'],
              enabled: true,
            ),
          },
        );

        expect(parsed.type, 'income');
        expect(parsed.merchantName, 'Amazon');
        expect(parsed.suggestedCategory, isNull);
        expect(parsed.merchantRuleSource, isNull);
      },
    );

    test(
      'does not extract Atheer card name as Heer, and handles ampersand in merchant name',
      () {
        final parsed = SmartCaptureParser.parse(
          'Local POS Purchase\n'
          'Amount: SAR 6.00\n'
          'Card: *1551 - mada (Atheer)\n'
          'At: Thamara & Resha Establish\n'
          'On: 2026-07-05 19:17',
        );

        expect(parsed.type, 'expense');
        expect(parsed.amount, 6.0);
        expect(parsed.currency, 'SAR');
        expect(parsed.merchantName, 'Thamara & Resha Establish');
      },
    );

    test(
      'investment account deposit in Arabic is treated as account funding and suppresses merchant extraction',
      () {
        final parsed = SmartCaptureParser.parse(
          'إيداع إلى حساب استثماري\n'
          'رقم: 4454\n'
          'SAR المبلغ: 10000\n'
          'في: 2026-08-03 12:36:05\n'
          'أويس المالية',
        );

        expect(parsed.type, 'expense');
        expect(parsed.amount, 10000.0);
        expect(parsed.currency, 'SAR');
        expect(parsed.merchantName, isNull);
        expect(parsed.description, 'Account Deposit');
      },
    );

    test('subscription activation messages are rejected before parsing', () {
      final parsed = SmartCaptureParser.parse(
        'مرحبا احمد البحيرى،\n'
        'تم تفعيل اشتراكك في Mobily Welcome Prepaid بنجاح.\n'
        'سعر الباقة: 0 ريال (تم احتساب الضريبة عند شحن الرصيد).\n'
        'Dear Ahmed,\n'
        'You have successfully subscribed to Mobily Welcome Prepaid.\n'
        'Bundle price: SAR 0 (VAT has already been paid upon recharging).',
      );

      expect(parsed.isValid, isFalse);
      expect(parsed.ignoreReason, 'Subscription Activation Message');
      expect(parsed.description, 'Subscription Activation Message');
      expect(parsed.amount, isNull);
      expect(parsed.currency, isNull);
      expect(parsed.merchantName, isNull);
    });

    test(
      'instapay instant transfer in Arabic is captured as income',
      () {
        final parsed = SmartCaptureParser.parse(
          'تم اضافة مبلغ 30000EGP      الى حساب رقم xxx7127      فى 26-JUL-2026  عن طريق التحويل اللحظي',
        );

        expect(parsed.type, 'income');
        expect(parsed.amount, 30000.0);
        expect(parsed.currency, 'EGP');
      },
    );

    group('Phase 2A canonical parser accuracy regressions', () {
      test('recognizes all ApplePay variations and normalizes to Apple Pay without making ApplePay merchant', () {
        final variations = <String>[
          'شراء إنترنت Apple Pay\nبـ 50 SAR\nلدى Jarir Bookstore',
          'شراء إنترنت ApplePay\nبـ 50 SAR\nلدى Jarir Bookstore',
          'شراء إنترنت apple pay\nبـ 50 SAR\nلدى Jarir Bookstore',
          'شراء إنترنت applepay\nبـ 50 SAR\nلدى Jarir Bookstore',
        ];

        for (final msg in variations) {
          final parsed = SmartCaptureParser.parse(msg);
          expect(parsed.paymentMethod, 'Apple Pay', reason: 'Failed for: $msg');
          expect(parsed.merchantName, 'Jarir', reason: 'Failed for: $msg');
          expect(parsed.type, 'expense');
          expect(parsed.amount, 50.0);
        }
      });

      test('recognizes POS-ApplePay separator variations as Apple Pay and does not treat POS as merchant', () {
        final variations = <String>[
          'شراء POS-ApplePay\nبـ 75 SAR\nلدى Al Baik',
          'شراء POS ApplePay\nبـ 75 SAR\nلدى Al Baik',
          'شراء POS Apple Pay\nبـ 75 SAR\nلدى Al Baik',
          'شراء POS - Apple Pay\nبـ 75 SAR\nلدى Al Baik',
        ];

        for (final msg in variations) {
          final parsed = SmartCaptureParser.parse(msg);
          expect(parsed.paymentMethod, 'Apple Pay', reason: 'Failed for: $msg');
          expect(parsed.merchantName, 'Al Baik', reason: 'Failed for: $msg');
          expect(parsed.type, 'expense');
          expect(parsed.amount, 75.0);
        }
      });

      test('recognizes Arabic purchase OTP phrases as verification messages and ignores them', () {
        final otpMessages = <String>[
          'رمز شراء أونلاين 6528\nللبطاقة *0973\nبـ 25 SAR',
          'رمز شراء 1234 لبطاقتك *5678 بمبلغ 100 SAR',
          'Purchase code: 9988 for your card ending 1234',
        ];

        for (final msg in otpMessages) {
          final parsed = SmartCaptureParser.parse(msg);
          expect(parsed.isValid, isFalse, reason: 'Should be ignored: $msg');
          expect(parsed.ignoreReason, 'Verification Code Message');
        }
      });

      test('negative test: ordinary online purchases containing شراء أونلاين remain valid transactions', () {
        final purchaseMsg = 'شراء أونلاين بمبلغ 150 SAR\nلدى Amazon SA\nبطاقة *1234';
        final parsed = SmartCaptureParser.parse(purchaseMsg);

        expect(parsed.isValid, isTrue);
        expect(parsed.type, 'expense');
        expect(parsed.amount, 150.0);
        expect(parsed.currency, 'SAR');
        expect(parsed.merchantName, 'Amazon');
      });

      test('extracts merchant with glued Arabic preposition عند (spaced and glued, Arabic and English merchant)', () {
        // Glued عند with English merchant
        final gluedEnglish = SmartCaptureParser.parse(
          'تم الآن خصم EGP 105.06عند  MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88',
        );
        expect(gluedEnglish.amount, 105.06);
        expect(gluedEnglish.currency, 'EGP');
        expect(gluedEnglish.merchantName, 'MY FAWRY');

        // Spaced عند with English merchant
        final spacedEnglish = SmartCaptureParser.parse(
          'تم الآن خصم EGP 105.06 عند MY FAWRY يوم 30/06 ، الرصيد المتاح EGP 1614.88',
        );
        expect(spacedEnglish.amount, 105.06);
        expect(spacedEnglish.currency, 'EGP');
        expect(spacedEnglish.merchantName, 'MY FAWRY');

        // Glued عند with Arabic merchant
        final gluedArabic = SmartCaptureParser.parse(
          'تم الآن خصم EGP 105.06عند فوري يوم 30/06 ، الرصيد المتاح EGP 1614.88',
        );
        expect(gluedArabic.amount, 105.06);
        expect(gluedArabic.currency, 'EGP');
        expect(gluedArabic.merchantName, 'فوري');

        // Glued لدى with Arabic merchant
        final gluedLada = SmartCaptureParser.parse(
          'تم الآن خصم SAR 50.00لدى جرير يوم 30/06',
        );
        expect(gluedLada.amount, 50.00);
        expect(gluedLada.currency, 'SAR');
        expect(gluedLada.merchantName, 'جرير');
      });
    });
  });
}

void _expectDateTime(
  DateTime? actual,
  int year,
  int month,
  int day,
  int hour,
  int minute, [
  int second = 0,
]) {
  expect(actual, isNotNull);
  expect(actual!.year, year);
  expect(actual.month, month);
  expect(actual.day, day);
  expect(actual.hour, hour);
  expect(actual.minute, minute);
  expect(actual.second, second);
}
