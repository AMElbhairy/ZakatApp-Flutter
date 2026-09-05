import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/raw_capture_payload.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/smart_capture_deduplicator.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('SmartCaptureDeduplicator', () {
    final now = DateTime.utc(2026, 6, 15, 12, 0, 0);

    final mockParsed = SmartCaptureParseResult(
      type: 'expense',
      amount: 150.0,
      currency: 'SAR',
      confidence: 0.95,
      merchantName: 'Amazon SA',
      description: 'Purchase at Amazon SA',
      cardReference: '*1234',
    );

    final mockPayload = RawCapturePayload(
      rawText: 'Purchase of SAR 150.00 at Amazon SA using card *1234',
      source: CaptureSource.sms,
      senderHeader: 'AlRajhiBank',
      receivedAt: now,
    );

    test('detects duplicate in pending transactions within 5-minute window', () {
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-1',
          source: 'sms',
          rawMessage: 'Purchase of SAR 150.00 at Amazon SA',
          createdAt: now.subtract(const Duration(minutes: 3)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isTrue);
      expect(diag.matchedRecordId, 'pt-1');
      expect(diag.matchedRecordType, 'pendingTransaction');
      expect(diag.timeDifferenceMinutes, 3);
      expect(diag.senderHeader, 'AlRajhiBank');
    });

    test('detects duplicate in final transactions within 5-minute window', () {
      final existingTx = <Transaction>[
        Transaction(
          id: 'tx-1',
          type: 'expense',
          date: '2026-06-15',
          amount: 150.0,
          currency: 'SAR',
          category: 'Shopping',
          description: 'purchase at Amazon SA',
          createdAt: now.subtract(const Duration(minutes: 2)).toIso8601String(),
          rolledOver: false,
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: const <PendingTransaction>[],
        transactions: existingTx,
        referenceNow: now,
      );

      expect(diag.isDuplicate, isTrue);
      expect(diag.matchedRecordId, 'tx-1');
      expect(diag.matchedRecordType, 'transaction');
      expect(diag.timeDifferenceMinutes, 2);
    });

    test('allows repeated legitimate transaction outside 5-minute window', () {
      // 10 minutes later, user buys again for 150 SAR at same store
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-early',
          source: 'sms',
          rawMessage: 'Purchase of SAR 150.00 at Amazon SA',
          createdAt: now.subtract(const Duration(minutes: 10)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isFalse);
    });

    test('allows transaction when amount differs', () {
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-diff-amt',
          source: 'sms',
          rawMessage: 'Purchase of SAR 200.00 at Amazon SA',
          createdAt: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 200.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isFalse);
    });

    test('computes deterministic message fingerprint', () {
      const msg1 = 'Purchase 50 SAR at Starbucks';
      const msg2 = '  Purchase   50 SAR  at  Starbucks  ';
      expect(
        SmartCaptureDeduplicator.computeMessageFingerprint(msg1),
        equals(SmartCaptureDeduplicator.computeMessageFingerprint(msg2)),
      );
    });
  });
}
