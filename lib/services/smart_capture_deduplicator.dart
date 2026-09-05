import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/pending_transaction.dart';
import '../models/raw_capture_payload.dart';
import '../models/transaction.dart';
import 'smart_capture_parser.dart';

class DeduplicationDiagnostics {
  const DeduplicationDiagnostics({
    required this.isDuplicate,
    this.matchedRecordId,
    this.matchedRecordType,
    this.timeDifferenceMinutes,
    required this.amount,
    required this.currency,
    required this.normalizedMerchant,
    required this.source,
    this.senderHeader,
    this.capturedAt,
    required this.receivedAt,
    this.cardOrAccountLast4,
    required this.rawMessageFingerprint,
  });

  final bool isDuplicate;
  final String? matchedRecordId;
  final String? matchedRecordType; // 'pendingTransaction' or 'transaction'
  final int? timeDifferenceMinutes;
  final double? amount;
  final String? currency;
  final String normalizedMerchant;
  final String source;
  final String? senderHeader;
  final DateTime? capturedAt;
  final DateTime receivedAt;
  final String? cardOrAccountLast4;
  final String rawMessageFingerprint;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isDuplicate': isDuplicate,
      if (matchedRecordId != null) 'matchedRecordId': matchedRecordId,
      if (matchedRecordType != null) 'matchedRecordType': matchedRecordType,
      if (timeDifferenceMinutes != null)
        'timeDifferenceMinutes': timeDifferenceMinutes,
      'amount': amount,
      'currency': currency,
      'normalizedMerchant': normalizedMerchant,
      'source': source,
      if (senderHeader != null) 'senderHeader': senderHeader,
      if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
      'receivedAt': receivedAt.toIso8601String(),
      if (cardOrAccountLast4 != null) 'cardOrAccountLast4': cardOrAccountLast4,
      'rawMessageFingerprint': rawMessageFingerprint,
    };
  }
}

class SmartCaptureDeduplicator {
  SmartCaptureDeduplicator._();

  static const int currentWindowMinutes = 5;

  /// Generates a stable deterministic fingerprint of the raw message content.
  static String computeMessageFingerprint(String rawMessage) {
    final String clean = rawMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    final List<int> bytes = utf8.encode(clean);
    int hash = 0x811c9dc5;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Evaluates whether an incoming parsed transaction is a duplicate of an
  /// existing pending or final transaction.
  ///
  /// Preserves the existing behavior-preserving 5-minute evaluation rule while
  /// capturing rich diagnostic information.
  static DeduplicationDiagnostics evaluate({
    required SmartCaptureParseResult parsed,
    required RawCapturePayload payload,
    required List<PendingTransaction> pendingTransactions,
    required List<Transaction> transactions,
    DateTime? referenceNow,
  }) {
    final DateTime now = referenceNow?.toUtc() ?? DateTime.now().toUtc();
    final String normMerchant = parsed.merchantName != null
        ? SmartCaptureParser.normalizeMerchantName(parsed.merchantName!).trim()
        : '';
    final String merchantKey = normMerchant.toLowerCase();

    final String? cardOrAccount = parsed.cardReference ?? parsed.accountReference;
    final String fingerprint = computeMessageFingerprint(payload.rawText);

    // 1. Check against existing pending transactions
    for (final PendingTransaction pt in pendingTransactions) {
      if (pt.status == CaptureStatus.ignored) continue;
      final String ptM = pt.merchantName != null
          ? SmartCaptureParser.normalizeMerchantName(
              pt.merchantName!,
            ).trim().toLowerCase()
          : '';

      if (pt.suggestedType == parsed.type &&
          pt.suggestedCurrency == parsed.currency &&
          pt.suggestedAmount == parsed.amount &&
          ptM == merchantKey) {
        try {
          final DateTime ptTime = DateTime.parse(pt.createdAt).toUtc();
          final int diffMinutes = now.difference(ptTime).abs().inMinutes;
          if (diffMinutes <= currentWindowMinutes) {
            final diag = DeduplicationDiagnostics(
              isDuplicate: true,
              matchedRecordId: pt.id,
              matchedRecordType: 'pendingTransaction',
              timeDifferenceMinutes: diffMinutes,
              amount: parsed.amount,
              currency: parsed.currency,
              normalizedMerchant: normMerchant,
              source: payload.sourceString,
              senderHeader: payload.senderHeader,
              capturedAt: parsed.capturedAt,
              receivedAt: payload.receivedAt,
              cardOrAccountLast4: cardOrAccount,
              rawMessageFingerprint: fingerprint,
            );
            if (kDebugMode) {
              debugPrint('[SmartCaptureDeduplicator] Matched Pending: ${diag.toJson()}');
            }
            return diag;
          }
        } catch (_) {}
      }
    }

    // 2. Check against existing final transactions
    for (final Transaction t in transactions) {
      final String tM = _normalizedTransactionMerchantKey(t);
      if (t.type == parsed.type &&
          t.currency == parsed.currency &&
          t.amount == parsed.amount &&
          tM == merchantKey) {
        try {
          final DateTime tTime = DateTime.parse(t.createdAt).toUtc();
          final int diffMinutes = now.difference(tTime).abs().inMinutes;
          if (diffMinutes <= currentWindowMinutes) {
            final diag = DeduplicationDiagnostics(
              isDuplicate: true,
              matchedRecordId: t.id,
              matchedRecordType: 'transaction',
              timeDifferenceMinutes: diffMinutes,
              amount: parsed.amount,
              currency: parsed.currency,
              normalizedMerchant: normMerchant,
              source: payload.sourceString,
              senderHeader: payload.senderHeader,
              capturedAt: parsed.capturedAt,
              receivedAt: payload.receivedAt,
              cardOrAccountLast4: cardOrAccount,
              rawMessageFingerprint: fingerprint,
            );
            if (kDebugMode) {
              debugPrint('[SmartCaptureDeduplicator] Matched Transaction: ${diag.toJson()}');
            }
            return diag;
          }
        } catch (_) {}
      }
    }

    return DeduplicationDiagnostics(
      isDuplicate: false,
      amount: parsed.amount,
      currency: parsed.currency,
      normalizedMerchant: normMerchant,
      source: payload.sourceString,
      senderHeader: payload.senderHeader,
      capturedAt: parsed.capturedAt,
      receivedAt: payload.receivedAt,
      cardOrAccountLast4: cardOrAccount,
      rawMessageFingerprint: fingerprint,
    );
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
