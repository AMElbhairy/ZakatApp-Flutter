import 'package:flutter_test/flutter_test.dart';
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

    test('debit transfer intl uses recipient as payee and sender as metadata', () {
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
    });

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

    test('internal transfer between own accounts stays transfer', () {
      final parsed = SmartCaptureParser.parse(
        'Internal Transfer\n'
        'From account **1234\n'
        'To account **5678\n'
        'Amount: SAR 100.00\n'
        '25/6/26 21:01',
      );

      expect(parsed.type, 'transfer');
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
  });
}

void _expectDateTime(
  DateTime? actual,
  int year,
  int month,
  int day,
  int hour,
  int minute,
  [int second = 0]
) {
  expect(actual, isNotNull);
  expect(actual!.year, year);
  expect(actual.month, month);
  expect(actual.day, day);
  expect(actual.hour, hour);
  expect(actual.minute, minute);
  expect(actual.second, second);
}
