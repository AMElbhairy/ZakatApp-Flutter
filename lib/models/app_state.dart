import 'financial_plan.dart';
import 'investment_asset.dart';
import 'recurring_transaction.dart';
import 'saving.dart';
import 'transaction.dart';
import 'pending_transaction.dart';
import 'merchant_rule.dart';
import 'merchant_confirmation.dart';
import 'capture_analytics.dart';
import 'correction_feedback.dart';

class AppStateModel {
  const AppStateModel({
    required this.transactions,
    required this.savings,
    required this.recurringTransactions,
    required this.investments,
    required this.financialPlans,
    required this.pendingTransactions,
    required this.lastRollover,
    required this.categories,
    required this.zakatPaidMonths,
    required this.processedExpenseIds,
    required this.mainCurrency,
    required this.defaultEntryCurrency,
    required this.zakatExpenseIds,
    required this.zakatMethod,
    required this.zakatAnnualDate,
    required this.zakatNisabBasis,
    required this.zakatScheduleFilter,
    required this.marketData,
    required this.marketHistory,
    required this.syncHealth,
    required this.lastModifiedAt,
    this.userId,
    this.userEmail,
    this.userDisplayName,
    this.userPhotoUrl,
    this.userProvider,
    required this.languagePreference,
    required this.themeMode,
    this.aiSettings,
    this.cloudHydrated,
    this.hasUnsyncedAuthChanges,
    this.loadedUserId,
    required this.biometricLockEnabled,
    required this.biometricHideWealthEnabled,
    required this.biometricExportEnabled,
    required this.biometricRestoreEnabled,
    required this.biometricAutoLockDelay,
    required this.merchantRules,
    required this.merchantAliases,
    required this.captureAnalytics,
    required this.correctionFeedback,
    required this.merchantConfirmations,
    required this.smartCaptureEnabled,
    required this.smartCaptureAutoApproveEnabled,
  });

  final List<Transaction> transactions;
  final List<Saving> savings;
  final List<RecurringTransaction> recurringTransactions;
  final List<InvestmentAsset> investments;
  final List<FinancialPlan> financialPlans;
  final List<PendingTransaction> pendingTransactions;
  final String lastRollover;
  final AppCategories categories;
  final List<String> zakatPaidMonths;
  final List<String> processedExpenseIds;
  final String mainCurrency;
  final String defaultEntryCurrency;
  final Map<String, dynamic> zakatExpenseIds;
  final String zakatMethod;
  final String zakatAnnualDate;
  final String zakatNisabBasis;
  final String zakatScheduleFilter;
  final Map<String, dynamic> marketData;
  final List<Map<String, dynamic>> marketHistory;
  final SyncHealth syncHealth;
  final String lastModifiedAt;
  final String? userId;
  final String? userEmail;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final String? userProvider;
  final String languagePreference;
  final String themeMode;
  final Map<String, dynamic>? aiSettings;
  final bool? cloudHydrated;
  final bool? hasUnsyncedAuthChanges;
  final String? loadedUserId;
  final bool biometricLockEnabled;
  final bool biometricHideWealthEnabled;
  final bool biometricExportEnabled;
  final bool biometricRestoreEnabled;
  final String biometricAutoLockDelay;

  final Map<String, MerchantRule> merchantRules;
  final Map<String, String> merchantAliases;
  final CaptureAnalytics captureAnalytics;
  final List<CorrectionFeedback> correctionFeedback;
  final List<MerchantConfirmation> merchantConfirmations;
  final bool smartCaptureEnabled;
  final bool smartCaptureAutoApproveEnabled;

  factory AppStateModel.fromJson(Map<String, dynamic> json) {
    return AppStateModel(
      transactions: _asList(json['transactions'])
          .map((dynamic e) => Transaction.fromJson(_asMap(e)))
          .toList(growable: false),
      savings: _asList(
        json['savings'],
      ).map((dynamic e) => Saving.fromJson(_asMap(e))).toList(growable: false),
      recurringTransactions: _asList(json['recurringTransactions'])
          .map((dynamic e) => RecurringTransaction.fromJson(_asMap(e)))
          .toList(growable: false),
      investments: _asList(json['investments'])
          .map((dynamic e) => InvestmentAsset.fromJson(_asMap(e)))
          .toList(growable: false),
      financialPlans: _asList(json['financialPlans'])
          .map((dynamic e) => FinancialPlan.fromJson(_asMap(e)))
          .toList(growable: false),
      pendingTransactions: _asList(json['pendingTransactions'])
          .map((dynamic e) => PendingTransaction.fromJson(_asMap(e)))
          .toList(growable: false),
      lastRollover: (json['lastRollover'] ?? '').toString(),
      categories: AppCategories.fromJson(_asMap(json['categories'])),
      zakatPaidMonths: _asList(
        json['zakatPaidMonths'],
      ).map((dynamic e) => e.toString()).toList(growable: false),
      processedExpenseIds: _asList(
        json['processedExpenseIds'],
      ).map((dynamic e) => e.toString()).toList(growable: false),
      mainCurrency: (json['mainCurrency'] ?? '').toString(),
      defaultEntryCurrency: (json['defaultEntryCurrency'] ?? '').toString(),
      zakatExpenseIds: _asMap(json['zakatExpenseIds']),
      zakatMethod: (json['zakatMethod'] ?? '').toString(),
      zakatAnnualDate: (json['zakatAnnualDate'] ?? '').toString(),
      zakatNisabBasis: _normalizeZakatNisabBasis(json['zakatNisabBasis']),
      zakatScheduleFilter: (json['zakatScheduleFilter'] ?? '').toString(),
      marketData: _asMap(json['marketData']),
      marketHistory: _asList(
        json['marketHistory'],
      ).map((dynamic e) => _asMap(e)).toList(growable: false),
      syncHealth: SyncHealth.fromJson(_asMap(json['syncHealth'])),
      lastModifiedAt: (json['lastModifiedAt'] ?? '').toString(),
      userId: json['userId']?.toString(),
      userEmail: json['email']?.toString(),
      userDisplayName: json['displayName']?.toString(),
      userPhotoUrl: json['photoUrl']?.toString(),
      userProvider: json['provider']?.toString(),
      languagePreference: (json['languagePreference'] ?? 'en').toString(),
      themeMode: (json['themeMode'] ?? 'system').toString(),
      aiSettings: json['aiSettings'] is Map
          ? Map<String, dynamic>.from(json['aiSettings'] as Map)
          : null,
      cloudHydrated: json.containsKey('cloudHydrated')
          ? _asBool(json['cloudHydrated'])
          : null,
      hasUnsyncedAuthChanges: json.containsKey('hasUnsyncedAuthChanges')
          ? _asBool(json['hasUnsyncedAuthChanges'])
          : null,
      loadedUserId: json['_loadedUserId']?.toString(),
      biometricLockEnabled: _asBool(json['biometricLockEnabled']),
      biometricHideWealthEnabled: _asBool(json['biometricHideWealthEnabled']),
      biometricExportEnabled: _asBool(json['biometricExportEnabled']),
      biometricRestoreEnabled: _asBool(json['biometricRestoreEnabled']),
      biometricAutoLockDelay: (json['biometricAutoLockDelay'] ?? '1_minute')
          .toString(),
      merchantRules: json['merchantRules'] is Map
          ? (json['merchantRules'] as Map).map(
              (dynamic k, dynamic v) => MapEntry<String, MerchantRule>(
                k.toString(),
                MerchantRule.fromJson(_asMap(v)),
              ),
            )
          : const <String, MerchantRule>{},
      merchantAliases: json['merchantAliases'] is Map
          ? (json['merchantAliases'] as Map).map(
              (dynamic k, dynamic v) =>
                  MapEntry<String, String>(k.toString(), v.toString()),
            )
          : const <String, String>{},
      captureAnalytics: json['captureAnalytics'] != null
          ? CaptureAnalytics.fromJson(_asMap(json['captureAnalytics']))
          : CaptureAnalytics.empty(),
      correctionFeedback: _asList(json['correctionFeedback'])
          .map((dynamic e) => CorrectionFeedback.fromJson(_asMap(e)))
          .toList(growable: false),
      merchantConfirmations: _asList(json['merchantConfirmations'])
          .map((dynamic e) => MerchantConfirmation.fromJson(_asMap(e)))
          .toList(growable: false),
      smartCaptureEnabled: json['smartCaptureEnabled'] != null
          ? _asBool(json['smartCaptureEnabled'])
          : true,
      smartCaptureAutoApproveEnabled:
          json['smartCaptureAutoApproveEnabled'] != null
          ? _asBool(json['smartCaptureAutoApproveEnabled'])
          : false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'transactions': transactions.map((Transaction e) => e.toJson()).toList(),
      'savings': savings.map((Saving e) => e.toJson()).toList(),
      'recurringTransactions': recurringTransactions
          .map((RecurringTransaction e) => e.toJson())
          .toList(),
      'investments': investments
          .map((InvestmentAsset e) => e.toJson())
          .toList(),
      'financialPlans': financialPlans
          .map((FinancialPlan e) => e.toJson())
          .toList(),
      'pendingTransactions': pendingTransactions
          .map((PendingTransaction e) => e.toJson())
          .toList(),
      'lastRollover': lastRollover,
      'categories': categories.toJson(),
      'zakatPaidMonths': zakatPaidMonths,
      'processedExpenseIds': processedExpenseIds,
      'mainCurrency': mainCurrency,
      'defaultEntryCurrency': defaultEntryCurrency,
      'zakatExpenseIds': zakatExpenseIds,
      'zakatMethod': zakatMethod,
      'zakatAnnualDate': zakatAnnualDate,
      'zakatNisabBasis': zakatNisabBasis,
      'zakatScheduleFilter': zakatScheduleFilter,
      'marketData': marketData,
      'marketHistory': marketHistory,
      'syncHealth': syncHealth.toJson(),
      'lastModifiedAt': lastModifiedAt,
      if (userId != null) 'userId': userId,
      if (userEmail != null) 'email': userEmail,
      if (userDisplayName != null) 'displayName': userDisplayName,
      if (userPhotoUrl != null) 'photoUrl': userPhotoUrl,
      if (userProvider != null) 'provider': userProvider,
      'languagePreference': languagePreference,
      'themeMode': themeMode,
      if (aiSettings != null) 'aiSettings': aiSettings,
      if (cloudHydrated != null) 'cloudHydrated': cloudHydrated,
      if (hasUnsyncedAuthChanges != null)
        'hasUnsyncedAuthChanges': hasUnsyncedAuthChanges,
      if (loadedUserId != null) '_loadedUserId': loadedUserId,
      'biometricLockEnabled': biometricLockEnabled,
      'biometricHideWealthEnabled': biometricHideWealthEnabled,
      'biometricExportEnabled': biometricExportEnabled,
      'biometricRestoreEnabled': biometricRestoreEnabled,
      'biometricAutoLockDelay': biometricAutoLockDelay,
      'merchantRules': merchantRules.map(
        (k, v) => MapEntry<String, dynamic>(k, v.toJson()),
      ),
      'merchantAliases': merchantAliases,
      'captureAnalytics': captureAnalytics.toJson(),
      'correctionFeedback': correctionFeedback.map((e) => e.toJson()).toList(),
      'merchantConfirmations': merchantConfirmations
          .map((e) => e.toJson())
          .toList(),
      'smartCaptureEnabled': smartCaptureEnabled,
      'smartCaptureAutoApproveEnabled': smartCaptureAutoApproveEnabled,
    };
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }

  static String _normalizeZakatNisabBasis(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    return raw == 'silver595' ? 'silver595' : 'gold85';
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}

class AppCategories {
  const AppCategories({required this.income, required this.expense});

  final List<String> income;
  final List<String> expense;

  factory AppCategories.fromJson(Map<String, dynamic> json) {
    return AppCategories(
      income: (json['income'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      expense: (json['expense'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'income': income, 'expense': expense};
  }
}

class SyncHealth {
  const SyncHealth({
    required this.lastSuccessAt,
    required this.lastFailureAt,
    required this.lastError,
    required this.pendingWrites,
  });

  final String lastSuccessAt;
  final String lastFailureAt;
  final String lastError;
  final int pendingWrites;

  factory SyncHealth.fromJson(Map<String, dynamic> json) {
    return SyncHealth(
      lastSuccessAt: (json['lastSuccessAt'] ?? '').toString(),
      lastFailureAt: (json['lastFailureAt'] ?? '').toString(),
      lastError: (json['lastError'] ?? '').toString(),
      pendingWrites: _asInt(json['pendingWrites']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lastSuccessAt': lastSuccessAt,
      'lastFailureAt': lastFailureAt,
      'lastError': lastError,
      'pendingWrites': pendingWrites,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
