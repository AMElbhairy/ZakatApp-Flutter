import 'financial_plan.dart';
import 'investment_asset.dart';
import 'recurring_transaction.dart';
import 'saving.dart';
import 'transaction.dart';

class AppStateModel {
  const AppStateModel({
    required this.transactions,
    required this.savings,
    required this.recurringTransactions,
    required this.investments,
    required this.financialPlans,
    required this.lastRollover,
    required this.categories,
    required this.zakatPaidMonths,
    required this.processedExpenseIds,
    required this.mainCurrency,
    required this.defaultEntryCurrency,
    required this.zakatExpenseIds,
    required this.zakatMethod,
    required this.zakatAnnualDate,
    required this.zakatScheduleFilter,
    required this.marketData,
    required this.marketHistory,
    required this.syncHealth,
    this.aiSettings,
    this.cloudHydrated,
    this.hasUnsyncedAuthChanges,
    this.loadedUserId,
  });

  final List<Transaction> transactions;
  final List<Saving> savings;
  final List<RecurringTransaction> recurringTransactions;
  final List<InvestmentAsset> investments;
  final List<FinancialPlan> financialPlans;
  final String lastRollover;
  final AppCategories categories;
  final List<String> zakatPaidMonths;
  final List<String> processedExpenseIds;
  final String mainCurrency;
  final String defaultEntryCurrency;
  final Map<String, dynamic> zakatExpenseIds;
  final String zakatMethod;
  final String zakatAnnualDate;
  final String zakatScheduleFilter;
  final Map<String, dynamic> marketData;
  final List<Map<String, dynamic>> marketHistory;
  final SyncHealth syncHealth;
  final Map<String, dynamic>? aiSettings;
  final bool? cloudHydrated;
  final bool? hasUnsyncedAuthChanges;
  final String? loadedUserId;

  factory AppStateModel.fromJson(Map<String, dynamic> json) {
    return AppStateModel(
      transactions: (json['transactions'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => Transaction.fromJson(
              Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{})))
          .toList(growable: false),
      savings: (json['savings'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => Saving.fromJson(
              Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{})))
          .toList(growable: false),
      recurringTransactions:
          (json['recurringTransactions'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic e) => RecurringTransaction.fromJson(Map<String, dynamic>.from(
                  (e as Map?) ?? const <String, dynamic>{})))
              .toList(growable: false),
      investments: (json['investments'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => InvestmentAsset.fromJson(
              Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{})))
          .toList(growable: false),
      financialPlans:
          (json['financialPlans'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic e) => FinancialPlan.fromJson(
                  Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{})))
              .toList(growable: false),
      lastRollover: (json['lastRollover'] ?? '').toString(),
      categories: AppCategories.fromJson(
          Map<String, dynamic>.from((json['categories'] as Map?) ?? const <String, dynamic>{})),
      zakatPaidMonths: (json['zakatPaidMonths'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      processedExpenseIds:
          (json['processedExpenseIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(growable: false),
      mainCurrency: (json['mainCurrency'] ?? '').toString(),
      defaultEntryCurrency: (json['defaultEntryCurrency'] ?? '').toString(),
      zakatExpenseIds:
          Map<String, dynamic>.from((json['zakatExpenseIds'] as Map?) ?? const <String, dynamic>{}),
      zakatMethod: (json['zakatMethod'] ?? '').toString(),
      zakatAnnualDate: (json['zakatAnnualDate'] ?? '').toString(),
      zakatScheduleFilter: (json['zakatScheduleFilter'] ?? '').toString(),
      marketData: Map<String, dynamic>.from((json['marketData'] as Map?) ?? const <String, dynamic>{}),
      marketHistory: (json['marketHistory'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => Map<String, dynamic>.from((e as Map?) ?? const <String, dynamic>{}))
          .toList(growable: false),
      syncHealth: SyncHealth.fromJson(
          Map<String, dynamic>.from((json['syncHealth'] as Map?) ?? const <String, dynamic>{})),
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
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'transactions': transactions.map((Transaction e) => e.toJson()).toList(),
      'savings': savings.map((Saving e) => e.toJson()).toList(),
      'recurringTransactions':
          recurringTransactions.map((RecurringTransaction e) => e.toJson()).toList(),
      'investments': investments.map((InvestmentAsset e) => e.toJson()).toList(),
      'financialPlans': financialPlans.map((FinancialPlan e) => e.toJson()).toList(),
      'lastRollover': lastRollover,
      'categories': categories.toJson(),
      'zakatPaidMonths': zakatPaidMonths,
      'processedExpenseIds': processedExpenseIds,
      'mainCurrency': mainCurrency,
      'defaultEntryCurrency': defaultEntryCurrency,
      'zakatExpenseIds': zakatExpenseIds,
      'zakatMethod': zakatMethod,
      'zakatAnnualDate': zakatAnnualDate,
      'zakatScheduleFilter': zakatScheduleFilter,
      'marketData': marketData,
      'marketHistory': marketHistory,
      'syncHealth': syncHealth.toJson(),
      if (aiSettings != null) 'aiSettings': aiSettings,
      if (cloudHydrated != null) 'cloudHydrated': cloudHydrated,
      if (hasUnsyncedAuthChanges != null)
        'hasUnsyncedAuthChanges': hasUnsyncedAuthChanges,
      if (loadedUserId != null) '_loadedUserId': loadedUserId,
    };
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }
}

class AppCategories {
  const AppCategories({
    required this.income,
    required this.expense,
  });

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
    return <String, dynamic>{
      'income': income,
      'expense': expense,
    };
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
