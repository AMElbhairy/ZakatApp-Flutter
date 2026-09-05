import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/raw_capture_payload.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/canonical_capture_normalizer.dart';
import 'package:zakatapp_flutter/services/smart_capture_deduplicator.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('Phase 3 Deduplication Stress Testing and Calibration Audit', () {
    final baseTime = DateTime.utc(2026, 9, 5, 12, 0, 0);

    RawCapturePayload createPayload({
      required String text,
      CaptureSource source = CaptureSource.sms,
      String? sender,
      DateTime? receivedAt,
    }) {
      return RawCapturePayload(
        rawText: text,
        source: source,
        senderHeader: sender,
        receivedAt: receivedAt ?? baseTime,
      );
    }

    SmartCaptureParseResult parsePayload(
      RawCapturePayload payload, {
      Map<String, String>? aliases,
      Map<String, MerchantRule>? rules,
    }) {
      final normalized = CanonicalCaptureNormalizer.normalize(payload.rawText);
      return SmartCaptureParser.parse(
        normalized,
        merchantAliases: aliases ?? const <String, String>{},
        merchantRules: rules ?? const <String, MerchantRule>{},
      );
    }

    PendingTransaction createPendingFromParsed({
      required String id,
      required SmartCaptureParseResult parsed,
      required RawCapturePayload payload,
      required DateTime createdAt,
      CaptureStatus status = CaptureStatus.pendingReview,
      String? ignoreReason,
    }) {
      return PendingTransaction(
        id: id,
        source: payload.sourceString,
        sourceIdentifier: payload.senderHeader,
        rawMessage: payload.rawText,
        createdAt: createdAt.toIso8601String(),
        suggestedType: parsed.type,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: parsed.suggestedCategory,
        confidence: parsed.confidence,
        status: status,
        ignoreReason: ignoreReason,
      );
    }

    Transaction createSettledFromParsed({
      required String id,
      required SmartCaptureParseResult parsed,
      required DateTime createdAt,
    }) {
      return Transaction(
        id: id,
        type: parsed.type,
        date: createdAt.toIso8601String().substring(0, 10),
        amount: parsed.amount ?? 0.0,
        currency: parsed.currency ?? 'SAR',
        category: parsed.suggestedCategory ?? 'Shopping',
        description: parsed.description,
        createdAt: createdAt.toIso8601String(),
        rolledOver: false,
      );
    }

    // =========================================================================
    // Scenario A: Exact Same Message Twice Immediately
    // =========================================================================
    group('Scenario A: Exact Same Message Twice Immediately', () {
      const msg = 'Purchase of SAR 150.00 at Amazon SA';

      test('Android SMS duplicate delivery simulation', () {
        final payload1 = createPayload(text: msg, source: CaptureSource.sms, sender: 'Bank');
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-sms-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 5 seconds later, duplicate SMS arrives
        final payload2 = createPayload(
          text: msg,
          source: CaptureSource.sms,
          sender: 'Bank',
          receivedAt: baseTime.add(const Duration(seconds: 5)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 5)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'pt-sms-1');
        expect(diag.timeDifferenceMinutes, 0);
      });

      test('iOS Shortcut accidentally triggered twice', () {
        final payload1 = createPayload(text: msg, source: CaptureSource.shortcut);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-sc-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 2 seconds later, shortcut triggered again
        final payload2 = createPayload(
          text: msg,
          source: CaptureSource.shortcut,
          receivedAt: baseTime.add(const Duration(seconds: 2)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 2)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'pt-sc-1');
      });

      test('Manual paste twice', () {
        final payload1 = createPayload(text: msg, source: CaptureSource.manual);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-mp-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 10 seconds later, user pastes same text again
        final payload2 = createPayload(
          text: msg,
          source: CaptureSource.manual,
          receivedAt: baseTime.add(const Duration(seconds: 10)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 10)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'pt-mp-1');
      });
    });

    // =========================================================================
    // Scenario B: Same Parsed Transaction, Different Formatting
    // =========================================================================
    group('Scenario B: Same Parsed Transaction, Different Formatting', () {
      test('Different whitespace, comma formatting, and line breaks detect duplicate', () {
        const msg1 = 'Online Purchase\nBy:0669\nAmount:4200 SR\nAt:AlinmaPay';
        const msg2 = 'Online Purchase\nBy:0669\nAmount: 4,200 SAR\nAt: AlinmaPay';

        final payload1 = createPayload(text: msg1);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-fmt-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg2,
          receivedAt: baseTime.add(const Duration(seconds: 30)),
        );
        final parsed2 = parsePayload(payload2);

        // Financial values match: amount=4200.0, currency=SAR, merchant=AlinmaPay
        expect(parsed2.amount, equals(parsed1.amount));
        expect(parsed2.currency, equals(parsed1.currency));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 30)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'pt-fmt-1');
      });
    });

    // =========================================================================
    // Scenario C: Same Transaction After Pending Approval
    // =========================================================================
    group('Scenario C: Same Transaction After Pending Approval', () {
      test('Matches against settled/final transaction after user approved pending', () {
        const msg = 'Debit Card Purchase at Talabat SAR 45.50';
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);

        // Transaction was approved and moved to settled transactions
        final settledTx = createSettledFromParsed(
          id: 'tx-settled-1',
          parsed: parsed1,
          createdAt: baseTime,
        );

        // Same message arrives 1 minute later
        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: const [], // pending is now empty because it was approved
          transactions: [settledTx],     // now in settled transactions
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'tx-settled-1');
        expect(diag.matchedRecordType, 'transaction');
        expect(diag.timeDifferenceMinutes, 1);
      });
    });

    // =========================================================================
    // Scenario D: Same Transaction After Auto Approval
    // =========================================================================
    group('Scenario D: Same Transaction After Auto Approval', () {
      test('Matches against auto-approved final transaction', () {
        const msg =
            'شكرًا لاستخدامك بطاقة بنك مصر ***8799، تم الآن خصم 99.00 EGPعند Talabat Pro يوم 05/09/2026 ، الرصيد المتاح EGP 5378.54';
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);

        final autoApprovedTx = createSettledFromParsed(
          id: 'tx-auto-1',
          parsed: parsed1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: const [],
          transactions: [autoApprovedTx],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'tx-auto-1');
        expect(diag.matchedRecordType, 'transaction');
      });
    });

    // =========================================================================
    // Scenario E: Same Amount + Same Merchant, Legitimate Second Purchase
    // CRITICAL FALSE POSITIVE SCENARIO
    // =========================================================================
    group('Scenario E: Same Amount + Same Merchant, Legitimate Second Purchase', () {
      test('Current implementation incorrectly collapses two distinct purchases within 5m', () {
        const msg1 = 'Purchase of SAR 25.00 at Starbucks';
        const msg2 = 'Purchase of SAR 25.00 at Starbucks';

        final payload1 = createPayload(text: msg1);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-sbux-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 2 minutes later, user buys another coffee for a colleague
        final payload2 = createPayload(
          text: msg2,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        // AUDIT OBSERVATION:
        // Expected ideal business behavior: Legitimate purchase #2 should NOT be rejected.
        // Current actual implementation: Treats it as duplicate because (type, amount, currency, merchant) match!
        expect(diag.isDuplicate, isTrue,
            reason: 'Documents that current 5-minute heuristic produces a FALSE POSITIVE for repeated coffee purchase');
        expect(diag.matchedRecordId, 'pt-sbux-1');
      });
    });

    // =========================================================================
    // Scenario F: Same Amount + Same Merchant + Different Card
    // =========================================================================
    group('Scenario F: Same Amount + Same Merchant + Different Card', () {
      test('Current implementation ignores cardReference and falsely flags as duplicate', () {
        const msgCard1 = 'Purchase of SAR 100.00 at Amazon with card *1234';
        const msgCard2 = 'Purchase of SAR 100.00 at Amazon with card *5678';

        final payload1 = createPayload(text: msgCard1);
        final parsed1 = parsePayload(payload1);
        expect(parsed1.cardReference, equals('*1234'));

        final pending1 = createPendingFromParsed(
          id: 'pt-card-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msgCard2,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsed2 = parsePayload(payload2);
        expect(parsed2.cardReference, equals('*5678'));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        // AUDIT OBSERVATION:
        // Diagnostic captures cardOrAccountLast4 (*5678), but the comparison logic in
        // SmartCaptureDeduplicator ignores cardReference.
        // Thus, it flags card *5678 as duplicate of *1234!
        expect(diag.cardOrAccountLast4, equals('*5678'));
        expect(diag.isDuplicate, isTrue,
            reason: 'Documents that different card is ignored by current matching key');
      });
    });

    // =========================================================================
    // Scenario G: Same Amount + Same Merchant Outside 5 Minutes (Boundary Audit)
    // =========================================================================
    group('Scenario G: Same Amount + Same Merchant Outside 5 Minutes (Boundary Audit)', () {
      const msg = 'Purchase of SAR 50.00 at Starbucks';

      test('Boundary at 5:00 (300 seconds) -> inMinutes == 5 -> duplicate', () {
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-bound-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final diag5m00s = SmartCaptureDeduplicator.evaluate(
          parsed: parsed1,
          payload: payload1,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 5)),
        );
        expect(diag5m00s.timeDifferenceMinutes, equals(5));
        expect(diag5m00s.isDuplicate, isTrue);
      });

      test('Boundary at 5:59 (359 seconds) -> inMinutes == 5 -> STILL treated as duplicate!', () {
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-bound-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 5 minutes and 59 seconds later:
        // Duration(minutes: 5, seconds: 59).inMinutes evaluates to 5 in Dart!
        // Because diffMinutes <= 5, 5 <= 5 is TRUE!
        final diag5m59s = SmartCaptureDeduplicator.evaluate(
          parsed: parsed1,
          payload: payload1,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 5, seconds: 59)),
        );
        expect(diag5m59s.timeDifferenceMinutes, equals(5));
        expect(diag5m59s.isDuplicate, isTrue,
            reason: 'Dart .inMinutes truncates seconds, widening effective window to 5m59s');
      });

      test('Boundary at 6:00 (360 seconds) -> inMinutes == 6 -> NOT duplicate', () {
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-bound-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final diag6m00s = SmartCaptureDeduplicator.evaluate(
          parsed: parsed1,
          payload: payload1,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 6)),
        );
        expect(diag6m00s.isDuplicate, isFalse);
        expect(diag6m00s.matchedRecordId, isNull);
      });

      test('Boundary at 10:00 (600 seconds) -> NOT duplicate', () {
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-bound-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final diag10m = SmartCaptureDeduplicator.evaluate(
          parsed: parsed1,
          payload: payload1,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 10)),
        );
        expect(diag10m.isDuplicate, isFalse);
        expect(diag10m.matchedRecordId, isNull);
      });
    });

    // =========================================================================
    // Scenario H: Delayed Queue Processing
    // =========================================================================
    group('Scenario H: Delayed Queue Processing', () {
      test('Deduplication compares referenceNow/DateTime.now against createdAt, ignoring receivedAt', () {
        const msg = 'Debit Card Purchase at Talabat SAR 45.50';

        // 1. First transaction captured and settled at 12:00
        final payload1 = createPayload(
          text: msg,
          receivedAt: baseTime, // 12:00
        );
        final parsed1 = parsePayload(payload1);
        final settledTx = createSettledFromParsed(
          id: 'tx-queue-1',
          parsed: parsed1,
          createdAt: baseTime, // 12:00
        );

        // 2. Second capture occurred natively at 12:01 (receivedAt: 12:01)
        // But the queue was blocked and Flutter only evaluates it at 12:10 (referenceNow: 12:10)
        final delayedReceivedTime = baseTime.add(const Duration(minutes: 1)); // 12:01
        final queueEvaluationTime = baseTime.add(const Duration(minutes: 10)); // 12:10

        final payload2 = createPayload(
          text: msg,
          receivedAt: delayedReceivedTime, // captured 1 minute after tx1
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: const [],
          transactions: [settledTx],
          referenceNow: queueEvaluationTime, // evaluation time is 10 min later
        );

        // AUDIT OBSERVATION:
        // Because evaluation uses `referenceNow` (DateTime.now() in production) rather than
        // `payload.receivedAt`, `diffMinutes` = |12:10 - 12:00| = 10 minutes > 5 minutes.
        // Result: The duplicate was MISSED (FALSE NEGATIVE)!
        expect(diag.isDuplicate, isFalse,
            reason: 'Delayed processing causes false negative because receivedAt is not used');
        expect(diag.matchedRecordId, isNull);
      });
    });

    // =========================================================================
    // Scenario I: Same Message After App Restart (Persisted State)
    // =========================================================================
    group('Scenario I: Same Message After App Restart', () {
      test('Deduplication operates correctly over reconstituted persisted models', () {
        const msg = 'Purchase of SAR 300.00 at Noon';
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-restart-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // Simulate app restart: JSON serialization and re-instantiation
        final serializedPendingJson = pending1.toJson();
        final reconstitutedPending = PendingTransaction.fromJson(serializedPendingJson);

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [reconstitutedPending],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.matchedRecordId, 'pt-restart-1');
      });
    });

    // =========================================================================
    // Scenario J: Merchant Normalization Variations
    // =========================================================================
    group('Scenario J: Merchant Normalization Variations', () {
      test('Equivalent merchants: Talabat Pro vs TALABAT PRO vs talabat pro match as duplicate', () {
        const msg1 = 'Purchase at Talabat Pro EGP 99.00';
        const msg2 = 'Purchase at TALABAT PRO EGP 99.00';
        const msg3 = 'Purchase at talabat pro EGP 99.00';

        final parsed1 = parsePayload(createPayload(text: msg1));
        final pending1 = createPendingFromParsed(
          id: 'pt-talabat-1',
          parsed: parsed1,
          payload: createPayload(text: msg1),
          createdAt: baseTime,
        );

        final parsed2 = parsePayload(createPayload(text: msg2));
        final diag2 = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: createPayload(text: msg2),
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 15)),
        );
        expect(diag2.isDuplicate, isTrue);

        final parsed3 = parsePayload(createPayload(text: msg3));
        final diag3 = SmartCaptureDeduplicator.evaluate(
          parsed: parsed3,
          payload: createPayload(text: msg3),
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(seconds: 30)),
        );
        expect(diag3.isDuplicate, isTrue);
      });

      test('Amazon vs Amazon SA: audit behavior', () {
        const msg1 = 'Purchase of SAR 100.00 at Amazon';
        const msg2 = 'Purchase of SAR 100.00 at Amazon SA';

        final parsed1 = parsePayload(createPayload(text: msg1));
        final parsed2 = parsePayload(createPayload(text: msg2));

        final pending1 = createPendingFromParsed(
          id: 'pt-amz-1',
          parsed: parsed1,
          payload: createPayload(text: msg1),
          createdAt: baseTime,
        );

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: createPayload(text: msg2),
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        // AUDIT OBSERVATION:
        // In SmartCaptureParser, "Amazon SA" strips safe country suffix "SA" and normalizes to "Amazon".
        // Therefore, both messages normalize to merchant "Amazon", and deduplicator treats them as DUPLICATES!
        expect(parsed1.merchantName, equals('Amazon'));
        expect(parsed2.merchantName, equals('Amazon'));
        expect(diag.isDuplicate, isTrue,
            reason: 'Current behavior: Amazon and Amazon SA normalize to Amazon and match as duplicate');
        expect(diag.matchedRecordId, 'pt-amz-1');
      });
    });

    // =========================================================================
    // Scenario K: Merchant Alias / Rule Difference
    // =========================================================================
    group('Scenario K: Merchant Alias / Rule Difference', () {
      test('Audit: capture before alias exists vs capture after alias maps to canonical', () {
        const rawMsg = 'Purchase of SAR 50.00 at LocalCafe';

        // 1. First capture without alias: stored merchant is "LocalCafe"
        final payload1 = createPayload(text: rawMsg);
        final parsed1 = parsePayload(payload1, aliases: null);
        expect(parsed1.merchantName, equals('LocalCafe'));
        final pending1 = createPendingFromParsed(
          id: 'pt-alias-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 2. User creates alias "localcafe" -> "Starbucks"
        final userAliases = {'localcafe': 'Starbucks'};

        // 3. Second capture of same message 1 minute later
        final payload2 = createPayload(
          text: rawMsg,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsed2 = parsePayload(payload2, aliases: userAliases);
        expect(parsed2.merchantName, equals('Starbucks'));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        // AUDIT OBSERVATION:
        // pending1 has merchant "LocalCafe", parsed2 has merchant "Starbucks".
        // Deduplication fails because merchant strings differ!
        expect(diag.isDuplicate, isFalse,
            reason: 'Alias introduction changes parsed merchant, causing deduplication mismatch');
      });
    });

    // =========================================================================
    // Scenario L: Pending vs Ignored
    // =========================================================================
    group('Scenario L: Pending vs Ignored', () {
      test('If earlier identical message was CaptureStatus.ignored, next valid capture is NOT blocked', () {
        const msg = 'Purchase of SAR 80.00 at Noon';
        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);

        // Earlier message was ignored (e.g. user rejected or flagged as duplicate earlier)
        final ignoredPending = createPendingFromParsed(
          id: 'pt-ignored-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
          status: CaptureStatus.ignored,
          ignoreReason: 'User rejected',
        );

        // Next capture arrives 2 minutes later
        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [ignoredPending],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        // In SmartCaptureDeduplicator.dart line 99:
        // `if (pt.status == CaptureStatus.ignored) continue;`
        // So ignored items do NOT block future incoming captures!
        expect(diag.isDuplicate, isFalse);
      });
    });

    // =========================================================================
    // Scenario M: Declined Transaction Followed by Successful Purchase
    // =========================================================================
    group('Scenario M: Declined Transaction Followed by Successful Purchase', () {
      test('Successful transaction is not blocked by earlier declined message', () {
        const declinedMsg = 'Declined transaction SAR 100.00 at Amazon SA';
        const successMsg = 'Purchase of SAR 100.00 at Amazon SA';

        // 1. Declined message is parsed as verification/ignored by Canonical parser
        final declinedPayload = createPayload(text: declinedMsg);
        final parsedDeclined = parsePayload(declinedPayload);
        // Canonical parser recognizes declined/rejected messages
        expect(parsedDeclined.isValid, isFalse);

        // Even if it were stored as ignored pending:
        final ignoredDeclined = createPendingFromParsed(
          id: 'pt-declined-1',
          parsed: parsedDeclined,
          payload: declinedPayload,
          createdAt: baseTime,
          status: CaptureStatus.ignored,
          ignoreReason: 'Declined transaction',
        );

        // 2. Successful purchase 2 minutes later
        final successPayload = createPayload(
          text: successMsg,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsedSuccess = parsePayload(successPayload);
        expect(parsedSuccess.isValid, isTrue);
        expect(parsedSuccess.type, equals('expense'));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsedSuccess,
          payload: successPayload,
          pendingTransactions: [ignoredDeclined],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        expect(diag.isDuplicate, isFalse);
      });
    });

    // =========================================================================
    // Scenario N: Refund vs Purchase Same Amount
    // =========================================================================
    group('Scenario N: Refund vs Purchase Same Amount', () {
      test('Refund (income) and Purchase (expense) within 5 minutes do NOT collide', () {
        const purchaseMsg = 'Purchase of SAR 100.00 at Amazon SA';
        const refundMsg = 'Refund of SAR 100.00 from Amazon SA';

        final payloadPurchase = createPayload(text: purchaseMsg);
        final parsedPurchase = parsePayload(payloadPurchase);
        expect(parsedPurchase.type, equals('expense'));

        final pendingPurchase = createPendingFromParsed(
          id: 'pt-purchase-1',
          parsed: parsedPurchase,
          payload: payloadPurchase,
          createdAt: baseTime,
        );

        final payloadRefund = createPayload(
          text: refundMsg,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsedRefund = parsePayload(payloadRefund);
        expect(parsedRefund.type, equals('income'));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsedRefund,
          payload: payloadRefund,
          pendingTransactions: [pendingPurchase],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        expect(diag.isDuplicate, isFalse);
      });
    });

    // =========================================================================
    // Scenario O: Incoming and Outgoing Transfer Same Amount
    // =========================================================================
    group('Scenario O: Incoming and Outgoing Transfer Same Amount', () {
      test('Incoming SAR 500 and Outgoing SAR 500 do not collide due to direction/type', () {
        const incomingMsg =
            'حوالة واردة محلية\nمبلغ:500 SAR\nمن:AHMED MOSTAFA ELBHAIRY\nفي:26/07/26 12:52';
        const outgoingMsg =
            'Debit Transfer Local\nAmount:500 SAR\nTo: Ahmed Elbhairy\nOn :2026-09-03 22:20';

        final payloadIn = createPayload(text: incomingMsg);
        final parsedIn = parsePayload(payloadIn);
        expect(parsedIn.type, equals('income'));

        final pendingIn = createPendingFromParsed(
          id: 'pt-transfer-in',
          parsed: parsedIn,
          payload: payloadIn,
          createdAt: baseTime,
        );

        final payloadOut = createPayload(
          text: outgoingMsg,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsedOut = parsePayload(payloadOut);
        expect(parsedOut.type, equals('expense'));

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsedOut,
          payload: payloadOut,
          pendingTransactions: [pendingIn],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        expect(diag.isDuplicate, isFalse);
      });
    });

    // =========================================================================
    // Scenario P: Two Transfers to Same Person Same Amount
    // FALSE POSITIVE RISK SCENARIO
    // =========================================================================
    group('Scenario P: Two Transfers to Same Person Same Amount', () {
      test('Two legitimate transfers to same recipient within 5m are flagged as duplicate', () {
        const outgoingMsg =
            'Debit Transfer Local\nAmount:500 SAR\nTo: Ahmed Elbhairy\nOn :2026-09-03 22:20';

        final payload1 = createPayload(text: outgoingMsg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-transfer-out-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        // 3 minutes later, user sends another 500 SAR to Ahmed Elbhairy
        final payload2 = createPayload(
          text: outgoingMsg,
          receivedAt: baseTime.add(const Duration(minutes: 3)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 3)),
        );

        // AUDIT OBSERVATION:
        // Current logic treats this as duplicate because amount, currency, merchant/counterparty, and type match.
        // If these were two separate transfers (e.g. splitting bills or two separate rent tranches),
        // the second transfer is erroneously blocked!
        expect(diag.isDuplicate, isTrue,
            reason: 'Documents false positive risk for legitimate back-to-back transfers');
      });
    });

    // =========================================================================
    // Real Regression Messages Deduplication
    // =========================================================================
    group('Real Verified Messages Deduplication', () {
      test('Banque Misr / Talabat duplicate within 5 minutes', () {
        const msg =
            'شكرًا لاستخدامك بطاقة بنك مصر ***8799، تم الآن خصم 99.00 EGPعند Talabat Pro يوم 05/09/2026 ، الرصيد المتاح EGP 5378.54 لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي';

        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-bm-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 3)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 3)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.amount, equals(99.00));
        expect(diag.currency, equals('EGP'));
        expect(diag.matchedRecordId, 'pt-bm-1');
      });

      test('AlinmaPay duplicate within 5 minutes', () {
        const msg =
            'Online Purchase\nBy:0669 ;Visa-Apple Pay\nAmount:4200 SR\nAt:AlinmaPay\nBalance:1225 SR\n2/9/26 22:19';

        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-alinma-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 1)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 1)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.amount, equals(4200.0));
        expect(diag.currency, equals('SAR'));
        expect(diag.matchedRecordId, 'pt-alinma-1');
      });

      test('Incoming transfer duplicate within 5 minutes', () {
        const msg =
            'حوالة واردة محلية\nإلى:6403*\nمبلغ:500 SAR\nمن:AHMED MOSTAFA ELBHAIRY\nعبر:D360 bank\nفي:26/07/26 12:52';

        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-trans-in-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 2)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 2)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.amount, equals(500.0));
        expect(diag.currency, equals('SAR'));
        expect(diag.normalizedMerchant, equals('AHMED MOSTAFA ELBHAIRY'));
      });

      test('Outgoing transfer duplicate within 5 minutes', () {
        const msg =
            'Debit Transfer Local\nAmount:5,000 SAR\nTo: Ahmed Elbhairy\nFrom:**4870\nFees:0 SAR\nOn :2026-09-03 22:20';

        final payload1 = createPayload(text: msg);
        final parsed1 = parsePayload(payload1);
        final pending1 = createPendingFromParsed(
          id: 'pt-trans-out-1',
          parsed: parsed1,
          payload: payload1,
          createdAt: baseTime,
        );

        final payload2 = createPayload(
          text: msg,
          receivedAt: baseTime.add(const Duration(minutes: 4)),
        );
        final parsed2 = parsePayload(payload2);

        final diag = SmartCaptureDeduplicator.evaluate(
          parsed: parsed2,
          payload: payload2,
          pendingTransactions: [pending1],
          transactions: const [],
          referenceNow: baseTime.add(const Duration(minutes: 4)),
        );

        expect(diag.isDuplicate, isTrue);
        expect(diag.amount, equals(5000.0));
        expect(diag.currency, equals('SAR'));
        expect(diag.normalizedMerchant, equals('Ahmed Elbhairy'));
      });
    });
  });
}
