import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import '../repositories/app_state_repository.dart';

class AppStateController extends ChangeNotifier {
  AppStateController({required this.repository})
      : _state = AppStateDefaults.create();

  final AppStateRepository repository;
  AppStateModel _state;

  AppStateModel get state => _state;

  Future<void> load() async {
    _state = await repository.loadAppState();
    notifyListeners();
  }

  Future<void> save() async {
    await repository.saveAppState(_state);
  }

  Future<void> clearLocalData() async {
    await repository.clearLocalData();
    _state = AppStateDefaults.create();
    notifyListeners();
  }

  Future<void> updateState(AppStateModel newState) async {
    _state = newState;
    await save();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await updateState(_state.copyWith(
      transactions: <Transaction>[..._state.transactions, transaction],
    ));
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final List<Transaction> next = _state.transactions
        .map((Transaction tx) => tx.id == transaction.id ? transaction : tx)
        .toList(growable: false);
    await updateState(_state.copyWith(transactions: next));
  }

  Future<void> deleteTransaction(String transactionId) async {
    final List<Transaction> next = _state.transactions
        .where((Transaction tx) => tx.id != transactionId)
        .toList(growable: false);
    await updateState(_state.copyWith(transactions: next));
  }

  Future<void> addSaving(Saving saving) async {
    await updateState(_state.copyWith(
      savings: <Saving>[..._state.savings, saving],
    ));
  }

  Future<void> updateSaving(Saving saving) async {
    final List<Saving> next = _state.savings
        .map((Saving entry) => entry.id == saving.id ? saving : entry)
        .toList(growable: false);
    await updateState(_state.copyWith(savings: next));
  }

  Future<void> deleteSaving(String savingId) async {
    final List<Saving> next = _state.savings
        .where((Saving entry) => entry.id != savingId)
        .toList(growable: false);
    await updateState(_state.copyWith(savings: next));
  }

  Future<void> addInvestment(InvestmentAsset investment) async {
    await updateState(_state.copyWith(
      investments: <InvestmentAsset>[..._state.investments, investment],
    ));
  }

  Future<void> updateInvestment(InvestmentAsset investment) async {
    final List<InvestmentAsset> next = _state.investments
        .map((InvestmentAsset entry) =>
            entry.id == investment.id ? investment : entry)
        .toList(growable: false);
    await updateState(_state.copyWith(investments: next));
  }

  Future<void> deleteInvestment(String investmentId) async {
    final List<InvestmentAsset> next = _state.investments
        .where((InvestmentAsset entry) => entry.id != investmentId)
        .toList(growable: false);
    await updateState(_state.copyWith(investments: next));
  }

  Future<void> addRecurringTransaction(RecurringTransaction recurring) async {
    await updateState(_state.copyWith(
      recurringTransactions: <RecurringTransaction>[
        ..._state.recurringTransactions,
        recurring,
      ],
    ));
  }

  Future<void> addFinancialPlan(FinancialPlan plan) async {
    await updateState(_state.copyWith(
      financialPlans: <FinancialPlan>[..._state.financialPlans, plan],
    ));
  }
}

extension AppStateModelCopyWith on AppStateModel {
  AppStateModel copyWith({
    List<Transaction>? transactions,
    List<Saving>? savings,
    List<RecurringTransaction>? recurringTransactions,
    List<InvestmentAsset>? investments,
    List<FinancialPlan>? financialPlans,
    String? lastRollover,
    AppCategories? categories,
    List<String>? zakatPaidMonths,
    List<String>? processedExpenseIds,
    String? mainCurrency,
    String? defaultEntryCurrency,
    Map<String, dynamic>? zakatExpenseIds,
    String? zakatMethod,
    String? zakatAnnualDate,
    String? zakatScheduleFilter,
    Map<String, dynamic>? marketData,
    List<Map<String, dynamic>>? marketHistory,
    SyncHealth? syncHealth,
    Map<String, dynamic>? aiSettings,
    bool? cloudHydrated,
    bool? hasUnsyncedAuthChanges,
    String? loadedUserId,
  }) {
    return AppStateModel(
      transactions: transactions ?? this.transactions,
      savings: savings ?? this.savings,
      recurringTransactions: recurringTransactions ?? this.recurringTransactions,
      investments: investments ?? this.investments,
      financialPlans: financialPlans ?? this.financialPlans,
      lastRollover: lastRollover ?? this.lastRollover,
      categories: categories ?? this.categories,
      zakatPaidMonths: zakatPaidMonths ?? this.zakatPaidMonths,
      processedExpenseIds: processedExpenseIds ?? this.processedExpenseIds,
      mainCurrency: mainCurrency ?? this.mainCurrency,
      defaultEntryCurrency: defaultEntryCurrency ?? this.defaultEntryCurrency,
      zakatExpenseIds: zakatExpenseIds ?? this.zakatExpenseIds,
      zakatMethod: zakatMethod ?? this.zakatMethod,
      zakatAnnualDate: zakatAnnualDate ?? this.zakatAnnualDate,
      zakatScheduleFilter: zakatScheduleFilter ?? this.zakatScheduleFilter,
      marketData: marketData ?? this.marketData,
      marketHistory: marketHistory ?? this.marketHistory,
      syncHealth: syncHealth ?? this.syncHealth,
      aiSettings: aiSettings ?? this.aiSettings,
      cloudHydrated: cloudHydrated ?? this.cloudHydrated,
      hasUnsyncedAuthChanges:
          hasUnsyncedAuthChanges ?? this.hasUnsyncedAuthChanges,
      loadedUserId: loadedUserId ?? this.loadedUserId,
    );
  }
}
