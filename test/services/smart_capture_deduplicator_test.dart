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

    test('Tier 1: detects exact raw message fingerprint duplicate within 60 minutes', () {
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-1',
          source: 'sms',
          rawMessage: 'Purchase of SAR 150.00 at Amazon SA using card *1234',
          createdAt: now.subtract(const Duration(minutes: 30)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '1234',
          receivedAt: now.subtract(const Duration(minutes: 30)).toIso8601String(),
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
      expect(diag.classification, DeduplicationClassification.definiteDuplicate);
      expect(diag.tier, DeduplicationTier.tier1ExactIdentity);
      expect(diag.matchedRecordId, 'pt-1');
      expect(diag.matchedRecordType, 'pendingTransaction');
      expect(diag.senderHeader, 'AlRajhiBank');
    });

    test('Tier 2: detects strong semantic duplicate with matching cardLast4 within 300s', () {
      // Different message formatting but matching amount, merchant, and cardLast4
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-2',
          source: 'sms',
          rawMessage: 'Online POS: Amazon SA - 150 SAR - Card Ending 1234',
          createdAt: now.subtract(const Duration(seconds: 180)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '1234',
          receivedAt: now.subtract(const Duration(seconds: 180)).toIso8601String(),
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
      expect(diag.classification, DeduplicationClassification.definiteDuplicate);
      expect(diag.tier, DeduplicationTier.tier2StrongSemantic);
      expect(diag.matchedRecordId, 'pt-2');
      expect(diag.timeDifferenceSeconds, 180);
    });

    test('Tier 2: card conflict (*1234 vs *5678) prevents false duplicate rejection', () {
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-diff-card',
          source: 'sms',
          rawMessage: 'Purchase of SAR 150.00 at Amazon SA using card *5678',
          createdAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '5678',
          receivedAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed, // has card *1234
        payload: mockPayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isFalse);
      expect(diag.classification, DeduplicationClassification.notDuplicate);
      expect(diag.matchedRecordId, isNull);
    });

    test('Tier 2: detects duplicate in final transactions with matching card within 300s', () {
      final existingTx = <Transaction>[
        Transaction(
          id: 'tx-1',
          type: 'expense',
          date: '2026-06-15',
          amount: 150.0,
          currency: 'SAR',
          category: 'Shopping',
          description: 'purchase at Amazon SA card *1234',
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
      expect(diag.classification, DeduplicationClassification.definiteDuplicate);
      expect(diag.tier, DeduplicationTier.tier2StrongSemantic);
      expect(diag.matchedRecordId, 'tx-1');
      expect(diag.matchedRecordType, 'transaction');
      expect(diag.timeDifferenceMinutes, 2);
    });

    test('Tier 3: weak semantic match without card within 60s is possibleDuplicate', () {
      const bareMsg = 'Purchase of SAR 50.00 at Local Cafe';
      final barePayload = RawCapturePayload(
        rawText: bareMsg,
        source: CaptureSource.sms,
        receivedAt: now,
      );
      final bareParsed = SmartCaptureParseResult(
        type: 'expense',
        amount: 50.0,
        currency: 'SAR',
        confidence: 0.9,
        merchantName: 'Local Cafe',
        description: 'Purchase at Local Cafe',
      );

      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-bare-1',
          source: 'sms',
          rawMessage: 'POS Purchase: Local Cafe 50 SAR',
          createdAt: now.subtract(const Duration(seconds: 45)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 50.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Local Cafe',
          confidence: 0.9,
          status: CaptureStatus.pendingReview,
          receivedAt: now.subtract(const Duration(seconds: 45)).toIso8601String(),
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: bareParsed,
        payload: barePayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isFalse);
      expect(diag.classification, DeduplicationClassification.possibleDuplicate);
      expect(diag.tier, DeduplicationTier.tier3WeakSemantic);
      expect(diag.matchedRecordId, 'pt-bare-1');
    });

    test('Tier 3: weak semantic match outside 60s is NOT duplicate', () {
      const bareMsg = 'Purchase of SAR 50.00 at Local Cafe';
      final barePayload = RawCapturePayload(
        rawText: bareMsg,
        source: CaptureSource.sms,
        receivedAt: now,
      );
      final bareParsed = SmartCaptureParseResult(
        type: 'expense',
        amount: 50.0,
        currency: 'SAR',
        confidence: 0.9,
        merchantName: 'Local Cafe',
        description: 'Purchase at Local Cafe',
      );

      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-bare-2',
          source: 'sms',
          rawMessage: 'POS Purchase: Local Cafe 50 SAR',
          createdAt: now.subtract(const Duration(seconds: 90)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 50.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Local Cafe',
          confidence: 0.9,
          status: CaptureStatus.pendingReview,
          receivedAt: now.subtract(const Duration(seconds: 90)).toIso8601String(),
        ),
      ];

      final diag = SmartCaptureDeduplicator.evaluate(
        parsed: bareParsed,
        payload: barePayload,
        pendingTransactions: existingPending,
        transactions: const <Transaction>[],
        referenceNow: now,
      );

      expect(diag.isDuplicate, isFalse);
      expect(diag.classification, DeduplicationClassification.notDuplicate);
      expect(diag.matchedRecordId, isNull);
    });

    test('Exact 300s boundary: 300s is duplicate, 301s is NOT duplicate', () {
      final existingAt300s = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-300s',
          source: 'sms',
          rawMessage: 'Amazon SA SAR 150 card *1234',
          createdAt: now.subtract(const Duration(seconds: 300)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '1234',
          receivedAt: now.subtract(const Duration(seconds: 300)).toIso8601String(),
        ),
      ];

      final diag300 = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: existingAt300s,
        transactions: const <Transaction>[],
        referenceNow: now,
      );
      expect(diag300.isDuplicate, isTrue);

      final existingAt301s = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-301s',
          source: 'sms',
          rawMessage: 'Amazon SA SAR 150 card *1234',
          createdAt: now.subtract(const Duration(seconds: 301)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 150.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '1234',
          receivedAt: now.subtract(const Duration(seconds: 301)).toIso8601String(),
        ),
      ];

      final diag301 = SmartCaptureDeduplicator.evaluate(
        parsed: mockParsed,
        payload: mockPayload,
        pendingTransactions: existingAt301s,
        transactions: const <Transaction>[],
        referenceNow: now,
      );
      expect(diag301.isDuplicate, isFalse);
    });

    test('allows transaction when amount differs', () {
      final existingPending = <PendingTransaction>[
        PendingTransaction(
          id: 'pt-diff-amt',
          source: 'sms',
          rawMessage: 'Purchase of SAR 200.00 at Amazon SA using card *1234',
          createdAt: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          suggestedType: 'expense',
          suggestedAmount: 200.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Amazon SA',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
          cardLast4: '1234',
          receivedAt: now.subtract(const Duration(minutes: 1)).toIso8601String(),
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
      const msg2 = '  Purchase   50 SAR  at  Starbucks  \r\n';
      expect(
        SmartCaptureDeduplicator.computeMessageFingerprint(msg1),
        equals(SmartCaptureDeduplicator.computeMessageFingerprint(msg2)),
      );
    });
  });
}
