import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/market_snapshot.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import '../repositories/app_state_repository.dart';
import 'market_data_api_service.dart';
import 'reconciliation_service.dart';

class AppStateController extends ChangeNotifier {
  AppStateController({
    required this.repository,
    MarketDataApiService? marketDataApiService,
    ReconciliationService? reconciliationService,
  })  : _state = AppStateDefaults.create(),
        marketDataApiService =
            marketDataApiService ?? MarketDataApiServiceImpl(),
        reconciliationService =
            reconciliationService ?? ReconciliationService();

  final AppStateRepository repository;
  final MarketDataApiService marketDataApiService;
  final ReconciliationService reconciliationService;
  AppStateModel _state;
  Timer? _marketRefreshTimer;
  bool _marketAutoRefreshStarted = false;
  Future<MarketRefreshResult>? _marketRefreshInFlight;
  static const Duration marketRefreshInterval = Duration(minutes: 5);

  AppStateModel get state => _state;
  MarketSnapshot get currentMarketSnapshot =>
      MarketSnapshot.fromAppStateJson(_state.marketData);

  Future<void> load() async {
    try {
      _state = await repository.loadAppState();
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: unexpected error while loading local app state. '
        'Using default state. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _state = AppStateDefaults.create();
    }
    final ReconciliationResult reconciled =
        reconciliationService.reconcileExpensesWithSavings(_state);
    _state = reconciled.state;
    if (reconciled.modified) {
      await save();
    }
    notifyListeners();
  }

  Future<void> startMarketAutoRefresh() async {
    if (_marketAutoRefreshStarted) return;
    _marketAutoRefreshStarted = true;
    await refreshMarketData(respectCooldown: true);
    _marketRefreshTimer?.cancel();
    _marketRefreshTimer = Timer.periodic(
      marketRefreshInterval,
      (_) => refreshMarketData(respectCooldown: true),
    );
  }

  @override
  void dispose() {
    _marketRefreshTimer?.cancel();
    super.dispose();
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
    final ReconciliationResult reconciled =
        reconciliationService.reconcileExpensesWithSavings(newState);
    _state = reconciled.state;
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

  Future<void> updateFinancialPlan(FinancialPlan plan) async {
    final List<FinancialPlan> next = _state.financialPlans
        .map((FinancialPlan entry) => entry.id == plan.id ? plan : entry)
        .toList(growable: false);
    await updateState(_state.copyWith(financialPlans: next));
  }

  Future<void> deleteFinancialPlan(String planId) async {
    final List<FinancialPlan> next = _state.financialPlans
        .where((FinancialPlan entry) => entry.id != planId)
        .toList(growable: false);
    await updateState(_state.copyWith(financialPlans: next));
  }

  Future<void> updateMainCurrency(String currency) async {
    await updateState(_state.copyWith(mainCurrency: currency));
  }

  Future<void> updateDefaultEntryCurrency(String currency) async {
    await updateState(_state.copyWith(defaultEntryCurrency: currency));
  }

  Future<void> updateZakatMethod(String method) async {
    await updateState(_state.copyWith(zakatMethod: method));
  }

  Future<void> updateZakatAnnualDate(String annualDate) async {
    await updateState(_state.copyWith(zakatAnnualDate: annualDate));
  }

  Future<void> updateLanguagePreference(String languageCode) async {
    await updateState(_state.copyWith(languagePreference: languageCode));
  }

  Future<void> updateMarketSnapshot(MarketSnapshot snapshot) async {
    await updateState(_state.copyWith(marketData: snapshot.toAppStateJson()));
  }

  Future<MarketRefreshResult> refreshMarketData({
    bool force = false,
    bool respectCooldown = false,
  }) {
    if (_marketRefreshInFlight != null) {
      return _marketRefreshInFlight!;
    }
    final Future<MarketRefreshResult> run = _refreshMarketDataInternal(
      force: force,
      respectCooldown: respectCooldown,
    );
    _marketRefreshInFlight = run;
    run.whenComplete(() => _marketRefreshInFlight = null);
    return run;
  }

  Future<MarketRefreshResult> _refreshMarketDataInternal({
    required bool force,
    required bool respectCooldown,
  }) async {
    final MarketSnapshot before = currentMarketSnapshot;
    if (!force && respectCooldown && _isWithinMarketCooldown(before.lastUpdated)) {
      return const MarketRefreshResult(
        success: true,
        updatedFields: 0,
        message: 'Using last saved market data',
      );
    }
    Map<String, double>? fxRates;

    try {
      fxRates = await marketDataApiService.fetchFxRatesToEgp();
    } catch (error, stackTrace) {
      debugPrint('AppStateController.refreshMarketData: FX refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      fxRates = null;
    }

    int updated = 0;
    MarketSnapshot after = before;

    if (fxRates != null && fxRates.isNotEmpty) {
      after = after.copyWith(
        usdToEgp: fxRates['USD'] ?? after.usdToEgp,
        sarToEgp: fxRates['SAR'] ?? after.sarToEgp,
        aedToEgp: fxRates['AED'] ?? after.aedToEgp,
        kwdToEgp: fxRates['KWD'] ?? after.kwdToEgp,
        qarToEgp: fxRates['QAR'] ?? after.qarToEgp,
        eurToEgp: fxRates['EUR'] ?? after.eurToEgp,
        gbpToEgp: fxRates['GBP'] ?? after.gbpToEgp,
        bhdToEgp: fxRates['BHD'] ?? after.bhdToEgp,
        omrToEgp: fxRates['OMR'] ?? after.omrToEgp,
        jodToEgp: fxRates['JOD'] ?? after.jodToEgp,
        tryToEgp: fxRates['TRY'] ?? after.tryToEgp,
        myrToEgp: fxRates['MYR'] ?? after.myrToEgp,
        pkrToEgp: fxRates['PKR'] ?? after.pkrToEgp,
        idrToEgp: fxRates['IDR'] ?? after.idrToEgp,
      );
      updated += fxRates.length;
    }

    final double usdToEgpForMetals =
        after.usdToEgp > 0 ? after.usdToEgp : before.usdToEgp;
    double? goldPrice;
    double? silverPrice;
    try {
      goldPrice = await marketDataApiService.fetchGold24kPerGramEgp(
        usdToEgp: usdToEgpForMetals,
      );
    } catch (error, stackTrace) {
      debugPrint('AppStateController.refreshMarketData: gold refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      goldPrice = null;
    }
    try {
      silverPrice = await marketDataApiService.fetchSilverPerGramEgp(
        usdToEgp: usdToEgpForMetals,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.refreshMarketData: silver refresh failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      silverPrice = null;
    }

    if (goldPrice != null && goldPrice > 0) {
      after = after.copyWith(gold24kPricePerGramEgp: goldPrice);
      updated += 1;
    }
    if (silverPrice != null && silverPrice > 0) {
      after = after.copyWith(silverPricePerGramEgp: silverPrice);
      updated += 1;
    }

    if (updated > 0) {
      after = after.copyWith(lastUpdated: DateTime.now().toUtc().toIso8601String());
      await updateMarketSnapshot(after);
      return MarketRefreshResult(
        success: true,
        updatedFields: updated,
        message: 'Market data refreshed.',
      );
    }

    if (before.lastUpdated.trim().isNotEmpty) {
      return const MarketRefreshResult(
        success: true,
        updatedFields: 0,
        message: 'Using last saved market data',
      );
    }
    return const MarketRefreshResult(
      success: false,
      updatedFields: 0,
      message: 'No market data refreshed. Manual prices required.',
    );
  }

  static bool _isWithinMarketCooldown(String lastUpdatedRaw) {
    final String value = lastUpdatedRaw.trim();
    if (value.isEmpty) return false;
    try {
      final DateTime last = DateTime.parse(value).toUtc();
      final Duration diff = DateTime.now().toUtc().difference(last);
      return diff.inSeconds >= 0 && diff < marketRefreshInterval;
    } catch (_) {
      return false;
    }
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
    String? languagePreference,
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
      languagePreference: languagePreference ?? this.languagePreference,
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
