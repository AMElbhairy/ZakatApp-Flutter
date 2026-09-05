import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/pending_transaction.dart';
import '../models/raw_capture_payload.dart';
import '../models/transaction.dart';
import 'canonical_capture_normalizer.dart';
import 'smart_capture_parser.dart';

enum DeduplicationClassification {
  definiteDuplicate,
  possibleDuplicate,
  notDuplicate,
}

enum DeduplicationTier {
  tier1ExactIdentity,
  tier2StrongSemantic,
  tier3WeakSemantic,
  none,
}

class DeduplicationDecision {
  const DeduplicationDecision({
    required this.classification,
    required this.tier,
    this.matchedRecordId,
    this.matchedRecordType,
    this.reason,
    this.timeDifferenceSeconds,
    required this.amount,
    required this.currency,
    required this.normalizedMerchant,
    required this.source,
    this.senderHeader,
    this.capturedAt,
    required this.receivedAt,
    this.cardLast4,
    this.accountLast4,
    required this.rawMessageFingerprint,
    this.matchedSignals = const <String>[],
    this.conflictingSignals = const <String>[],
  });

  final DeduplicationClassification classification;
  final DeduplicationTier tier;
  final String? matchedRecordId;
  final String? matchedRecordType; // 'pendingTransaction' or 'transaction'
  final String? reason;
  final int? timeDifferenceSeconds;
  final double? amount;
  final String? currency;
  final String normalizedMerchant;
  final String source;
  final String? senderHeader;
  final DateTime? capturedAt;
  final DateTime receivedAt;
  final String? cardLast4;
  final String? accountLast4;
  final String rawMessageFingerprint;
  final List<String> matchedSignals;
  final List<String> conflictingSignals;

  /// Backward-compatible getters
  bool get isDuplicate =>
      classification == DeduplicationClassification.definiteDuplicate;

  int? get timeDifferenceMinutes =>
      timeDifferenceSeconds != null ? timeDifferenceSeconds! ~/ 60 : null;

  String? get cardOrAccountLast4 => cardLast4 ?? accountLast4;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'classification': classification.name,
      'tier': tier.name,
      'isDuplicate': isDuplicate,
      if (matchedRecordId != null) 'matchedRecordId': matchedRecordId,
      if (matchedRecordType != null) 'matchedRecordType': matchedRecordType,
      if (reason != null) 'reason': reason,
      if (timeDifferenceSeconds != null)
        'timeDifferenceSeconds': timeDifferenceSeconds,
      if (timeDifferenceMinutes != null)
        'timeDifferenceMinutes': timeDifferenceMinutes,
      'amount': amount,
      'currency': currency,
      'normalizedMerchant': normalizedMerchant,
      'source': source,
      if (senderHeader != null) 'senderHeader': senderHeader,
      if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
      'receivedAt': receivedAt.toIso8601String(),
      if (cardLast4 != null) 'cardLast4': cardLast4,
      if (accountLast4 != null) 'accountLast4': accountLast4,
      if (cardOrAccountLast4 != null) 'cardOrAccountLast4': cardOrAccountLast4,
      'rawMessageFingerprint': rawMessageFingerprint,
      if (matchedSignals.isNotEmpty) 'matchedSignals': matchedSignals,
      if (conflictingSignals.isNotEmpty)
        'conflictingSignals': conflictingSignals,
    };
  }
}

typedef DeduplicationDiagnostics = DeduplicationDecision;

class SmartCaptureDeduplicator {
  SmartCaptureDeduplicator._();

  static const int currentWindowMinutes = 5;
  static const int tier1AnchoredWindowSeconds = 3600; // 60 minutes
  static const int tier1BareWindowSeconds = 60; // 60 seconds
  static const int tier2WindowSeconds = 300; // 5 minutes exact
  static const int tier3WindowSeconds = 60; // 60 seconds exact

  /// Extracts the last 4 digits from an arbitrary string reference.
  static String? extractLast4(String? input) {
    if (input == null) return null;
    final String normalized = CanonicalCaptureNormalizer.normalize(input);
    final String clean = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < 4) return null;
    return clean.substring(clean.length - 4);
  }

  /// Generates a stable deterministic fingerprint of the raw message content
  /// using canonical normalization and 64-bit FNV-1a.
  static String computeMessageFingerprint(String rawMessage) {
    final String clean = CanonicalCaptureNormalizer.normalize(rawMessage).trim();
    final List<int> bytes = utf8.encode(clean);
    BigInt hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final BigInt fnvPrime = BigInt.parse('100000001b3', radix: 16);
    final BigInt mask64 = (BigInt.one << 64) - BigInt.one;
    for (final int byte in bytes) {
      hash ^= BigInt.from(byte);
      hash = (hash * fnvPrime) & mask64;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Evaluates whether an incoming parsed transaction is a duplicate of an
  /// existing pending or final transaction using High-Precision Tiering.
  static DeduplicationDecision evaluate({
    required SmartCaptureParseResult parsed,
    required RawCapturePayload payload,
    required List<PendingTransaction> pendingTransactions,
    required List<Transaction> transactions,
    String? suggestedPaymentSourceId,
    DateTime? referenceNow,
  }) {
    final DateTime incomingTime = payload.receivedAt.toUtc();
    final String normMerchant = parsed.merchantName != null
        ? SmartCaptureParser.normalizeMerchantName(parsed.merchantName!).trim()
        : '';
    final String merchantKey = normMerchant.toLowerCase();

    final String? incomingCardLast4 = extractLast4(parsed.cardReference);
    final String? incomingAccountLast4 = extractLast4(parsed.accountReference);
    final String? paymentSourceId = suggestedPaymentSourceId;
    final String fingerprint = computeMessageFingerprint(payload.rawText);

    final bool isAnchored = parsed.capturedAt != null ||
        incomingCardLast4 != null ||
        incomingAccountLast4 != null;
    final int tier1Window = isAnchored
        ? tier1AnchoredWindowSeconds
        : tier1BareWindowSeconds;

    // -------------------------------------------------------------------------
    // Tier 1: Exact Capture Identity (Message Fingerprint)
    // -------------------------------------------------------------------------
    for (final PendingTransaction pt in pendingTransactions) {
      if (pt.status == CaptureStatus.ignored) continue;

      final String ptFingerprint = computeMessageFingerprint(pt.rawMessage);
      if (ptFingerprint == fingerprint) {
        final DateTime recordTime = _resolveRecordTime(pt);
        final int deltaSeconds =
            (incomingTime.difference(recordTime).inMilliseconds.abs() / 1000)
                .round();

        if (deltaSeconds <= tier1Window) {
          final decision = DeduplicationDecision(
            classification: DeduplicationClassification.definiteDuplicate,
            tier: DeduplicationTier.tier1ExactIdentity,
            matchedRecordId: pt.id,
            matchedRecordType: 'pendingTransaction',
            reason: 'Exact raw message fingerprint match within ${tier1Window}s',
            timeDifferenceSeconds: deltaSeconds,
            amount: parsed.amount,
            currency: parsed.currency,
            normalizedMerchant: normMerchant,
            source: payload.sourceString,
            senderHeader: payload.senderHeader,
            capturedAt: parsed.capturedAt,
            receivedAt: payload.receivedAt,
            cardLast4: incomingCardLast4,
            accountLast4: incomingAccountLast4,
            rawMessageFingerprint: fingerprint,
            matchedSignals: <String>['rawMessageFingerprint'],
          );
          if (kDebugMode) {
            debugPrint('[SmartCaptureDeduplicator] Matched Tier 1: ${decision.toJson()}');
          }
          return decision;
        }
      }
    }

    // -------------------------------------------------------------------------
    // Tier 2 & Tier 3: Semantic Evaluation
    // -------------------------------------------------------------------------
    DeduplicationDecision? possibleDuplicateCandidate;

    // 1. Check against Pending Transactions
    for (final PendingTransaction pt in pendingTransactions) {
      if (pt.status == CaptureStatus.ignored) continue;

      final decision = _evaluateSemanticMatch(
        incomingParsed: parsed,
        incomingPayload: payload,
        incomingTime: incomingTime,
        incomingCardLast4: incomingCardLast4,
        incomingAccountLast4: incomingAccountLast4,
        incomingPaymentSourceId: paymentSourceId,
        incomingFingerprint: fingerprint,
        normMerchant: normMerchant,
        merchantKey: merchantKey,
        recordId: pt.id,
        recordType: 'pendingTransaction',
        recordTypeField: pt.suggestedType,
        recordCurrency: pt.suggestedCurrency,
        recordAmount: pt.suggestedAmount,
        recordMerchantName: pt.merchantName,
        recordTime: _resolveRecordTime(pt),
        recordCardLast4: _getHistoricalCardLast4(pt),
        recordAccountLast4: _getHistoricalAccountLast4(pt),
        recordPaymentSourceId: pt.suggestedPaymentSourceId,
        recordDirection: null,
      );

      if (decision != null) {
        if (decision.classification ==
            DeduplicationClassification.definiteDuplicate) {
          return decision;
        }
        if (decision.classification ==
                DeduplicationClassification.possibleDuplicate &&
            possibleDuplicateCandidate == null) {
          possibleDuplicateCandidate = decision;
        }
      }
    }

    // 2. Check against Final Transactions
    for (final Transaction t in transactions) {
      final String tMerchant = _normalizedTransactionMerchantKey(t);
      final decision = _evaluateSemanticMatch(
        incomingParsed: parsed,
        incomingPayload: payload,
        incomingTime: incomingTime,
        incomingCardLast4: incomingCardLast4,
        incomingAccountLast4: incomingAccountLast4,
        incomingPaymentSourceId: paymentSourceId,
        incomingFingerprint: fingerprint,
        normMerchant: normMerchant,
        merchantKey: merchantKey,
        recordId: t.id,
        recordType: 'transaction',
        recordTypeField: t.type,
        recordCurrency: t.currency,
        recordAmount: t.amount,
        recordMerchantName: tMerchant,
        recordTime: DateTime.tryParse(t.createdAt)?.toUtc() ?? incomingTime,
        recordCardLast4: extractLast4(t.description),
        recordAccountLast4: extractLast4(t.description),
        recordPaymentSourceId: t.paymentSourceId,
        recordDirection: t.isTransferActivity ? t.activityType : null,
      );

      if (decision != null) {
        if (decision.classification ==
            DeduplicationClassification.definiteDuplicate) {
          return decision;
        }
        if (decision.classification ==
                DeduplicationClassification.possibleDuplicate &&
            possibleDuplicateCandidate == null) {
          possibleDuplicateCandidate = decision;
        }
      }
    }

    if (possibleDuplicateCandidate != null) {
      if (kDebugMode) {
        debugPrint(
          '[SmartCaptureDeduplicator] Matched Tier 3 (Possible): ${possibleDuplicateCandidate.toJson()}',
        );
      }
      return possibleDuplicateCandidate;
    }

    return DeduplicationDecision(
      classification: DeduplicationClassification.notDuplicate,
      tier: DeduplicationTier.none,
      amount: parsed.amount,
      currency: parsed.currency,
      normalizedMerchant: normMerchant,
      source: payload.sourceString,
      senderHeader: payload.senderHeader,
      capturedAt: parsed.capturedAt,
      receivedAt: payload.receivedAt,
      cardLast4: incomingCardLast4,
      accountLast4: incomingAccountLast4,
      rawMessageFingerprint: fingerprint,
    );
  }

  static DeduplicationDecision? _evaluateSemanticMatch({
    required SmartCaptureParseResult incomingParsed,
    required RawCapturePayload incomingPayload,
    required DateTime incomingTime,
    required String? incomingCardLast4,
    required String? incomingAccountLast4,
    required String? incomingPaymentSourceId,
    required String incomingFingerprint,
    required String normMerchant,
    required String merchantKey,
    required String recordId,
    required String recordType,
    required String? recordTypeField,
    required String? recordCurrency,
    required double? recordAmount,
    required String? recordMerchantName,
    required DateTime recordTime,
    required String? recordCardLast4,
    required String? recordAccountLast4,
    required String? recordPaymentSourceId,
    required String? recordDirection,
  }) {
    // 1. Base Requirements: Type, Amount, Currency
    if (recordTypeField != incomingParsed.type) return null;

    if (incomingParsed.amount == null || recordAmount == null) return null;
    if ((incomingParsed.amount! - recordAmount).abs() >= 0.001) return null;

    if (incomingParsed.currency != null && recordCurrency != null) {
      if (incomingParsed.currency!.trim().toUpperCase() !=
          recordCurrency.trim().toUpperCase()) {
        return null;
      }
    }

    // Transfer direction check
    if (incomingParsed.type == 'transfer') {
      if (incomingParsed.direction != null && recordDirection != null) {
        if (incomingParsed.direction!.toLowerCase() !=
            recordDirection.toLowerCase()) {
          return null; // Conflicting transfer direction
        }
      }
    }

    // Merchant check (for expense and income)
    if (incomingParsed.type != 'transfer') {
      final String recM = recordMerchantName != null
          ? SmartCaptureParser.normalizeMerchantName(recordMerchantName)
              .trim()
              .toLowerCase()
          : '';
      if (merchantKey.isNotEmpty && recM.isNotEmpty && merchantKey != recM) {
        return null;
      }
    }

    // 2. Conflict Checking (Typed Identity)
    final List<String> conflictingSignals = <String>[];
    if (incomingCardLast4 != null &&
        recordCardLast4 != null &&
        incomingCardLast4 != recordCardLast4) {
      conflictingSignals.add('cardLast4($incomingCardLast4 vs $recordCardLast4)');
    }
    if (incomingAccountLast4 != null &&
        recordAccountLast4 != null &&
        incomingAccountLast4 != recordAccountLast4) {
      conflictingSignals
          .add('accountLast4($incomingAccountLast4 vs $recordAccountLast4)');
    }
    if (incomingPaymentSourceId != null &&
        recordPaymentSourceId != null &&
        incomingPaymentSourceId != recordPaymentSourceId) {
      conflictingSignals.add('paymentSourceId');
    }

    if (conflictingSignals.isNotEmpty) {
      // Explicit conflict found: cannot be a duplicate
      return null;
    }

    // 3. Strong Identity Signals
    final List<String> matchedSignals = <String>[];
    if (incomingCardLast4 != null &&
        recordCardLast4 != null &&
        incomingCardLast4 == recordCardLast4) {
      matchedSignals.add('cardLast4');
    }
    if (incomingAccountLast4 != null &&
        recordAccountLast4 != null &&
        incomingAccountLast4 == recordAccountLast4) {
      matchedSignals.add('accountLast4');
    }
    if (incomingPaymentSourceId != null &&
        recordPaymentSourceId != null &&
        incomingPaymentSourceId == recordPaymentSourceId) {
      matchedSignals.add('paymentSourceId');
    }

    final int deltaSeconds =
        (incomingTime.difference(recordTime).inMilliseconds.abs() / 1000).round();

    // 4. Tier 2: Strong Semantic Duplicate (<= 300s)
    if (matchedSignals.isNotEmpty) {
      if (deltaSeconds <= tier2WindowSeconds) {
        return DeduplicationDecision(
          classification: DeduplicationClassification.definiteDuplicate,
          tier: DeduplicationTier.tier2StrongSemantic,
          matchedRecordId: recordId,
          matchedRecordType: recordType,
          reason:
              'Strong semantic match with matching ${matchedSignals.join(', ')} within ${tier2WindowSeconds}s',
          timeDifferenceSeconds: deltaSeconds,
          amount: incomingParsed.amount,
          currency: incomingParsed.currency,
          normalizedMerchant: normMerchant,
          source: incomingPayload.sourceString,
          senderHeader: incomingPayload.senderHeader,
          capturedAt: incomingParsed.capturedAt,
          receivedAt: incomingPayload.receivedAt,
          cardLast4: incomingCardLast4,
          accountLast4: incomingAccountLast4,
          rawMessageFingerprint: incomingFingerprint,
          matchedSignals: matchedSignals,
        );
      }
      return null; // Strong identity but outside 300s window -> not duplicate
    }

    // 5. Tier 3: Weak Semantic Similarity (<= 60s)
    if (deltaSeconds <= tier3WindowSeconds) {
      return DeduplicationDecision(
        classification: DeduplicationClassification.possibleDuplicate,
        tier: DeduplicationTier.tier3WeakSemantic,
        matchedRecordId: recordId,
        matchedRecordType: recordType,
        reason: 'Weak semantic similarity within ${tier3WindowSeconds}s',
        timeDifferenceSeconds: deltaSeconds,
        amount: incomingParsed.amount,
        currency: incomingParsed.currency,
        normalizedMerchant: normMerchant,
        source: incomingPayload.sourceString,
        senderHeader: incomingPayload.senderHeader,
        capturedAt: incomingParsed.capturedAt,
        receivedAt: incomingPayload.receivedAt,
        cardLast4: incomingCardLast4,
        accountLast4: incomingAccountLast4,
        rawMessageFingerprint: incomingFingerprint,
      );
    }

    return null; // Outside 60s window without strong identity -> not duplicate
  }

  static DateTime _resolveRecordTime(PendingTransaction pt) {
    if (pt.receivedAt != null && pt.receivedAt!.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(pt.receivedAt!)?.toUtc();
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(pt.createdAt)?.toUtc() ??
        DateTime.now().toUtc();
  }

  static String? _getHistoricalCardLast4(PendingTransaction pt) {
    if (pt.cardLast4 != null && pt.cardLast4!.trim().isNotEmpty) {
      return pt.cardLast4;
    }
    // Fallback derivation from rawMessage for legacy records
    final parsed = SmartCaptureParser.parse(pt.rawMessage);
    return extractLast4(parsed.cardReference);
  }

  static String? _getHistoricalAccountLast4(PendingTransaction pt) {
    if (pt.accountLast4 != null && pt.accountLast4!.trim().isNotEmpty) {
      return pt.accountLast4;
    }
    // Fallback derivation from rawMessage for legacy records
    final parsed = SmartCaptureParser.parse(pt.rawMessage);
    return extractLast4(parsed.accountReference);
  }

  static String _normalizedTransactionMerchantKey(Transaction transaction) {
    String merchant = transaction.description.trim().toLowerCase();
    merchant = merchant.replaceAll(
      RegExp(
        r'^(purchase at|income from|internal transfer to)\s+',
        caseSensitive: false,
      ),
      '',
    );
    merchant = merchant.replaceAll(
      RegExp(
        r'\s+(purchase|order|subscription|deposit|transfer|payment)$',
        caseSensitive: false,
      ),
      '',
    );
    merchant = merchant.trim();
    if (merchant.isEmpty ||
        merchant == 'bank transfer' ||
        merchant == 'account deposit' ||
        merchant == 'expense capture' ||
        merchant == 'salary deposit' ||
        merchant == 'captured message') {
      return '';
    }
    return SmartCaptureParser.normalizeMerchantName(
      merchant,
    ).trim().toLowerCase();
  }
}
