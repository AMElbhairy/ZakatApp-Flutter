import 'dart:convert';
import 'dart:math' as math;

import '../models/app_state.dart';
import 'launch_diagnostics.dart';

class BackupIntegritySummary {
  const BackupIntegritySummary({
    required this.userIdHash,
    required this.profileIdHash,
    required this.stateRevision,
    required this.collectionCounts,
    required this.collectionSources,
    required this.signature,
  });

  final String userIdHash;
  final String profileIdHash;
  final String stateRevision;
  final Map<String, int> collectionCounts;
  final Map<String, String> collectionSources;
  final String signature;

  factory BackupIntegritySummary.fromState(
    AppStateModel state, {
    Map<String, String> collectionSources = const <String, String>{},
  }) {
    final Map<String, int> counts = <String, int>{
      'transactions': state.transactions.length,
      'credit_cards': state.creditCards.length,
      'savings': state.savings.length,
      'pending_transactions': state.pendingTransactions.length,
      'financial_plans': state.financialPlans.length,
      'investments': state.investments.length,
      'recurring_transactions': state.recurringTransactions.length,
      'merchant_rules': state.merchantRules.length,
      'merchant_confirmations': state.merchantConfirmations.length,
      'correction_feedback': state.correctionFeedback.length,
      'app_settings': _deriveSettingsCount(state),
    };
    final Map<String, String> normalizedSources = <String, String>{
      ...collectionSources,
    };
    final String signature = _computeSignature(
      stateRevision: state.lastModifiedAt,
      counts: counts,
      collectionSources: normalizedSources,
    );
    return BackupIntegritySummary(
      userIdHash: LaunchDiagnostics.fingerprint(state.userId),
      profileIdHash: LaunchDiagnostics.fingerprint(state.loadedUserId),
      stateRevision: state.lastModifiedAt,
      collectionCounts: counts,
      collectionSources: normalizedSources,
      signature: signature,
    );
  }

  factory BackupIntegritySummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawCounts = json['collectionCounts'] is Map
        ? Map<String, dynamic>.from(json['collectionCounts'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> rawSources = json['collectionSources'] is Map
        ? Map<String, dynamic>.from(json['collectionSources'] as Map)
        : <String, dynamic>{};
    final Map<String, int> counts = rawCounts.map(
      (String key, dynamic value) => MapEntry<String, int>(key, _asInt(value)),
    );
    final Map<String, String> sources = rawSources.map(
      (String key, dynamic value) =>
          MapEntry<String, String>(key, value.toString()),
    );
    final String stateRevision = (json['stateRevision'] ?? '').toString();
    return BackupIntegritySummary(
      userIdHash: (json['userIdHash'] ?? '').toString(),
      profileIdHash: (json['profileIdHash'] ?? '').toString(),
      stateRevision: stateRevision,
      collectionCounts: counts,
      collectionSources: sources,
      signature:
          (json['signature'] ??
                  _computeSignature(
                    stateRevision: stateRevision,
                    counts: counts,
                    collectionSources: sources,
                  ))
              .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userIdHash': userIdHash,
      'profileIdHash': profileIdHash,
      'stateRevision': stateRevision,
      'collectionCounts': collectionCounts,
      'collectionSources': collectionSources,
      'signature': signature,
    };
  }

  bool get hasData =>
      collectionCounts.values.fold<int>(
        0,
        (int sum, int value) => sum + value,
      ) >
      0;

  List<String> suspiciousMissingCollections({
    required BackupIntegritySummary baseline,
  }) {
    final List<String> suspect = <String>[];
    for (final MapEntry<String, int> entry
        in baseline.collectionCounts.entries) {
      if (entry.value <= 0) continue;
      final int currentCount = collectionCounts[entry.key] ?? 0;
      if (currentCount > 0) continue;
      final String source =
          collectionSources[entry.key]?.trim().toLowerCase() ?? '';
      if (source == 'empty default') {
        suspect.add(entry.key);
      }
    }
    return suspect;
  }

  bool isLikelyPartialCandidate({required BackupIntegritySummary baseline}) {
    final List<String> suspect = suspiciousMissingCollections(
      baseline: baseline,
    );
    if (suspect.isNotEmpty) return true;

    final int baselineTotal = baseline.collectionCounts.values.fold<int>(
      0,
      (int sum, int value) => sum + value,
    );
    if (baselineTotal <= 0) return false;

    final int currentTotal = collectionCounts.values.fold<int>(
      0,
      (int sum, int value) => sum + value,
    );
    final int reducedBy = math.max(0, baselineTotal - currentTotal);
    if (reducedBy <= 0) return false;

    final String sourceSummary = collectionSources.entries
        .map(
          (MapEntry<String, String> entry) =>
              '${entry.key}:${entry.value.toLowerCase()}',
        )
        .join('|');
    return sourceSummary.contains('empty default');
  }

  static String _computeSignature({
    required String stateRevision,
    required Map<String, int> counts,
    required Map<String, String> collectionSources,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'stateRevision': stateRevision,
      'counts': <String, dynamic>{
        for (final String key in counts.keys.toList(growable: false)..sort())
          key: counts[key],
      },
      'sources': <String, dynamic>{
        for (final String key in collectionSources.keys.toList(
          growable: false,
        )..sort())
          key: collectionSources[key],
      },
    };
    return jsonEncode(payload);
  }

  static int _deriveSettingsCount(AppStateModel state) {
    return <int>[
      state.categories.income.length,
      state.categories.expense.length,
      state.zakatPaidMonths.length,
      state.processedExpenseIds.length,
      state.merchantAliases.length,
      state.marketHistory.length,
    ].fold<int>(0, (int sum, int value) => sum + value);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

abstract class BackupEligibilityResult {
  const BackupEligibilityResult();

  bool get allowed;
  String get reason;
}

class BackupEligibilityAllowed extends BackupEligibilityResult {
  const BackupEligibilityAllowed({required this.summary});

  final BackupIntegritySummary summary;

  @override
  bool get allowed => true;

  @override
  String get reason => 'allowed';
}

class BackupEligibilityBlocked extends BackupEligibilityResult {
  const BackupEligibilityBlocked({
    required this.reason,
    required this.summary,
    required this.baseline,
    required this.suspiciousCollections,
  });

  @override
  final String reason;
  final BackupIntegritySummary summary;
  final BackupIntegritySummary? baseline;
  final List<String> suspiciousCollections;

  @override
  bool get allowed => false;
}
