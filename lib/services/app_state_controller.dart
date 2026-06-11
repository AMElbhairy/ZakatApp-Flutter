import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/market_snapshot.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import '../models/currency_exchange_edit_request.dart';
import '../repositories/app_state_repository.dart';
import 'market_data_api_service.dart';
import 'reconciliation_service.dart';
import '../core/services/zakat_engine.dart';

class AppStateController extends ChangeNotifier {
  AppStateController({
    required this.repository,
    MarketDataApiService? marketDataApiService,
    ReconciliationService? reconciliationService,
  }) : _state = AppStateDefaults.create(),
       marketDataApiService =
           marketDataApiService ?? MarketDataApiServiceImpl(),
       reconciliationService = reconciliationService ?? ReconciliationService();

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
    final ReconciliationResult reconciled = reconciliationService
        .reconcileExpensesWithSavings(_state);
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
    final ReconciliationResult reconciled = reconciliationService
        .reconcileExpensesWithSavings(newState);
    _state = reconciled.state.copyWith(
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, transaction],
      ),
    );
  }

  Future<void> addTransactions(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;
    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, ...transactions],
      ),
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final List<Transaction> next = _state.transactions
        .map((Transaction tx) => tx.id == transaction.id ? transaction : tx)
        .toList(growable: false);
    await updateState(_state.copyWith(transactions: next));
  }

  Future<void> deleteTransaction(String transactionId) async {
    Transaction? target;
    for (final tx in _state.transactions) {
      if (tx.id == transactionId) {
        target = tx;
        break;
      }
    }
    if (target == null) return;
    final Transaction txTarget = target;

    List<Saving> nextSavings = List<Saving>.from(_state.savings);

    if (txTarget.category == 'Gold Sale' || txTarget.category == 'Silver Sale') {
      final String? metalSavingId = txTarget.exchangePairId;
      if (metalSavingId != null && metalSavingId.isNotEmpty) {
        double soldWeight = 0.0;
        final RegExp regex = RegExp(r'([0-9.]+)\s*g');
        final Match? match = regex.firstMatch(txTarget.description);
        if (match != null) {
          soldWeight = double.tryParse(match.group(1) ?? '') ?? 0.0;
        }
        if (soldWeight > 0.0) {
          nextSavings = nextSavings.map((Saving s) {
            if (s.id == metalSavingId) {
              return s.copyWith(remainingAmount: s.remainingAmount + soldWeight);
            }
            return s;
          }).toList();
        }
      }
      nextSavings.removeWhere(
        (Saving s) =>
            s.transferActivityId == txTarget.id &&
            ZakatEngineService.normaliseAssetType(s.assetType) == 'cash',
      );
    }

    final String? pairId = txTarget.exchangePairId;
    final List<Transaction> nextTransactions = _state.transactions
        .where((Transaction tx) {
          if (txTarget.category == 'Gold Sale' || txTarget.category == 'Silver Sale') {
            return tx.id != transactionId;
          }
          if (pairId != null && pairId.isNotEmpty) {
            return tx.exchangePairId != pairId;
          }
          return tx.id != transactionId;
        })
        .toList(growable: false);

    await updateState(
      _state.copyWith(savings: nextSavings, transactions: nextTransactions),
    );
  }

  Future<void> addSaving(Saving saving) async {
    await updateState(
      _state.copyWith(savings: <Saving>[..._state.savings, saving]),
    );
  }

  Future<void> addSavingWithFundingAllocations(Saving saving) async {
    final List<Transaction> fundingExpenses = saving.fundingAllocations
        .where(
          (Map<String, dynamic> allocation) =>
              (allocation['sourceType'] ?? '').toString() == 'income',
        )
        .map((Map<String, dynamic> allocation) {
          final String sourceId = (allocation['sourceId'] ?? '').toString();
          final String currency = (allocation['currency'] ?? '').toString();
          final double amount = _asDouble(allocation['amount']);
          return Transaction(
            id: 'tx_${DateTime.now().microsecondsSinceEpoch}_${sourceId}_metal',
            type: 'expense',
            date: saving.dateAcquired,
            amount: amount,
            currency: currency,
            category: 'Precious Metals Purchase',
            description:
                '${saving.assetType} purchase funding from income $sourceId',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            rolledOver: false,
            sourceIncomeId: sourceId,
            exchangePairId: saving.id,
            activityType: 'transfer',
          );
        })
        .where((Transaction tx) => tx.amount > 0 && tx.sourceIncomeId != null)
        .toList(growable: false);

    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, ...fundingExpenses],
        savings: <Saving>[..._state.savings, saving],
      ),
    );
  }

  Future<void> updateSaving(Saving saving) async {
    final List<Saving> next = _state.savings
        .map((Saving entry) => entry.id == saving.id ? saving : entry)
        .toList(growable: false);
    await updateState(_state.copyWith(savings: next));
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> deleteSaving(String savingId) async {
    Saving? target;
    for (final s in _state.savings) {
      if (s.id == savingId) {
        target = s;
        break;
      }
    }
    List<Saving> nextSavings = _state.savings
        .where((Saving entry) => entry.id != savingId)
        .toList(growable: false);

    if (target != null &&
        target.exchangeSourceSavingId != null &&
        target.exchangeSourceSavingId!.isNotEmpty) {
      final String srcId = target.exchangeSourceSavingId!;
      double deducted = 0.0;
      final RegExp regExp = RegExp(r'Savings exchange:\s*([0-9.]+)\s');
      final Match? match = regExp.firstMatch(target.description);
      if (match != null) {
        deducted = double.tryParse(match.group(1) ?? '') ?? 0.0;
      }
      if (deducted > 0) {
        nextSavings = nextSavings.map((Saving s) {
          if (s.id == srcId) {
            return s.copyWith(
              amount: s.amount + deducted,
              remainingAmount: s.remainingAmount + deducted,
            );
          }
          return s;
        }).toList();
      }
    }

    final List<Transaction> nextTransactions = _state.transactions
        .where(
          (Transaction tx) =>
              tx.exchangePairId != savingId ||
              tx.category != 'Precious Metals Purchase',
        )
        .toList(growable: false);
    await updateState(
      _state.copyWith(savings: nextSavings, transactions: nextTransactions),
    );
  }

  Future<void> updateCurrencyExchange(
    CurrencyExchangeEditRequest request,
  ) async {
    List<Transaction> nextTransactions = _state.transactions;
    List<Saving> nextSavings = _state.savings;
    final Set<String> targetSavingIds = request.oldTargetSavingIds.toSet();
    final List<Saving> removedTargetSavings = <Saving>[];

    if (request.oldActivityId.isNotEmpty) {
      nextTransactions = nextTransactions
          .where((Transaction tx) => tx.exchangePairId != request.oldActivityId)
          .toList(growable: false);
      removedTargetSavings.addAll(
        _state.savings.where(
          (Saving saving) =>
              saving.transferActivityId == request.oldActivityId &&
              saving.internalTransferType == 'savings_currency_exchange',
        ),
      );
      targetSavingIds.addAll(
        removedTargetSavings.map((Saving saving) => saving.id),
      );
    }

    if (targetSavingIds.isNotEmpty) {
      removedTargetSavings.addAll(
        _state.savings.where(
          (Saving saving) =>
              targetSavingIds.contains(saving.id) &&
              !removedTargetSavings.any(
                (Saving existing) => existing.id == saving.id,
              ),
        ),
      );
    }

    if (targetSavingIds.isNotEmpty) {
      nextSavings = nextSavings
          .where((Saving saving) => !targetSavingIds.contains(saving.id))
          .toList(growable: false);
    }

    if (request.oldSourceSavingDeductions.isNotEmpty) {
      nextSavings = nextSavings
          .map((Saving saving) {
            final double restoredAmount =
                request.oldSourceSavingDeductions[saving.id] ?? 0;
            if (restoredAmount <= 0) return saving;
            return saving.copyWith(
              amount: saving.amount + restoredAmount,
              remainingAmount: saving.remainingAmount + restoredAmount,
            );
          })
          .toList(growable: false);

      for (final MapEntry<String, double> entry
          in request.oldSourceSavingDeductions.entries) {
        final bool exists = nextSavings.any(
          (Saving saving) => saving.id == entry.key,
        );
        if (exists || entry.value <= 0) continue;

        final Saving? sourceTemplate = removedTargetSavings
            .where(
              (Saving saving) => saving.exchangeSourceSavingId == entry.key,
            )
            .firstOrNull;
        nextSavings = <Saving>[
          ...nextSavings,
          Saving(
            id: entry.key,
            assetType: 'cash',
            dateAcquired: sourceTemplate?.dateAcquired ?? request.date,
            amount: entry.value,
            remainingAmount: entry.value,
            unit: request.sourceCurrency,
            description: 'Restored exchange source',
            purchaseCurrency: request.sourceCurrency,
            purchaseAmount: entry.value,
            createdAt:
                sourceTemplate?.createdAt ??
                DateTime.now().toUtc().toIso8601String(),
            sourceIncomeId: sourceTemplate?.sourceIncomeId,
          ),
        ];
      }
    }

    final AppStateModel revertedState = _state.copyWith(
      transactions: nextTransactions,
      savings: nextSavings,
    );

    final ReconciliationResult out = reconciliationService
        .executeCurrencyExchange(
          input: revertedState,
          date: request.date,
          sourceCurrency: request.sourceCurrency,
          targetCurrency: request.targetCurrency,
          sourceAmount: request.sourceAmount,
          targetAmount: request.targetAmount,
        );

    if (out.modified) {
      await updateState(out.state);
    }
  }

  Future<void> addInvestment(InvestmentAsset investment) async {
    await updateState(
      _state.copyWith(
        investments: <InvestmentAsset>[..._state.investments, investment],
      ),
    );
  }

  Future<void> updateInvestment(InvestmentAsset investment) async {
    final List<InvestmentAsset> next = _state.investments
        .map(
          (InvestmentAsset entry) =>
              entry.id == investment.id ? investment : entry,
        )
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
    await updateState(
      _state.copyWith(
        recurringTransactions: <RecurringTransaction>[
          ..._state.recurringTransactions,
          recurring,
        ],
      ),
    );
  }

  Future<void> updateRecurringTransaction(
    RecurringTransaction recurring,
  ) async {
    final List<RecurringTransaction> next = _state.recurringTransactions
        .map(
          (RecurringTransaction entry) =>
              entry.id == recurring.id ? recurring : entry,
        )
        .toList(growable: false);
    await updateState(_state.copyWith(recurringTransactions: next));
  }

  Future<void> deleteRecurringTransaction(String recurringId) async {
    final List<RecurringTransaction> next = _state.recurringTransactions
        .where((RecurringTransaction entry) => entry.id != recurringId)
        .toList(growable: false);
    await updateState(_state.copyWith(recurringTransactions: next));
  }

  Future<void> addCategory({required String type, required String name}) async {
    final String clean = name.trim();
    if (clean.isEmpty) return;
    final bool income = type == 'income';
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    if (source.any((String c) => c.toLowerCase() == clean.toLowerCase())) {
      return;
    }
    final AppCategories nextCategories = AppCategories(
      income: income ? <String>[...source, clean] : _state.categories.income,
      expense: income ? _state.categories.expense : <String>[...source, clean],
    );
    await updateState(_state.copyWith(categories: nextCategories));
  }

  Future<void> renameCategory({
    required String type,
    required String from,
    required String to,
  }) async {
    final String cleanFrom = from.trim();
    final String cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty || cleanFrom == cleanTo) return;
    final bool income = type == 'income';
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    if (!source.contains(cleanFrom)) return;
    if (source.any((String c) => c.toLowerCase() == cleanTo.toLowerCase())) {
      return;
    }
    final List<String> updatedCategories = source
        .map((String c) => c == cleanFrom ? cleanTo : c)
        .toList(growable: false);
    final List<Transaction> updatedTransactions = _state.transactions
        .map(
          (Transaction tx) => tx.category == cleanFrom
              ? Transaction(
                  id: tx.id,
                  type: tx.type,
                  date: tx.date,
                  amount: tx.amount,
                  currency: tx.currency,
                  category: cleanTo,
                  description: tx.description,
                  createdAt: tx.createdAt,
                  rolledOver: tx.rolledOver,
                  rolledAmount: tx.rolledAmount,
                  sourceIncomeId: tx.sourceIncomeId,
                  exchangePairId: tx.exchangePairId,
                  exchangeSourceIncomeId: tx.exchangeSourceIncomeId,
                  remainingAmount: tx.remainingAmount,
                )
              : tx,
        )
        .toList(growable: false);
    final AppCategories nextCategories = AppCategories(
      income: income ? updatedCategories : _state.categories.income,
      expense: income ? _state.categories.expense : updatedCategories,
    );
    await updateState(
      _state.copyWith(
        categories: nextCategories,
        transactions: updatedTransactions,
      ),
    );
  }

  Future<bool> deleteCategory({
    required String type,
    required String name,
  }) async {
    final String clean = name.trim();
    final bool income = type == 'income';
    final bool inUse = _state.transactions.any(
      (Transaction tx) =>
          tx.category == clean &&
          (income ? tx.type == 'income' : tx.type == 'expense'),
    );
    if (inUse) return false;
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    final List<String> updated = source
        .where((String c) => c != clean)
        .toList(growable: false);
    final AppCategories nextCategories = AppCategories(
      income: income ? updated : _state.categories.income,
      expense: income ? _state.categories.expense : updated,
    );
    await updateState(_state.copyWith(categories: nextCategories));
    return true;
  }

  Future<void> addFinancialPlan(FinancialPlan plan) async {
    await updateState(
      _state.copyWith(
        financialPlans: <FinancialPlan>[..._state.financialPlans, plan],
      ),
    );
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

  Future<void> updateZakatNisabBasis(String basis) async {
    final String normalized = basis == 'silver595' ? 'silver595' : 'gold85';
    await updateState(_state.copyWith(zakatNisabBasis: normalized));
  }

  Future<void> updateLanguagePreference(String languageCode) async {
    await updateState(_state.copyWith(languagePreference: languageCode));
  }

  Future<void> updateThemeMode(String mode) async {
    final String normalized = switch (mode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    await updateState(_state.copyWith(themeMode: normalized));
  }

  Future<void> togglePrivacyMode() async {
    final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
      _state.aiSettings ?? <String, dynamic>{},
    );
    final bool isCurrentlyHidden =
        aiSettings['privacyMode'] == true ||
        aiSettings['hideBalances'] == true ||
        aiSettings['balancesHidden'] == true;
    aiSettings['privacyMode'] = !isCurrentlyHidden;
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  Future<void> updateAiSettings(Map<String, dynamic> aiSettings) async {
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  double getAvailableBalance({required String currency}) {
    return reconciliationService.getAvailableCashBalance(
      state: _state,
      currency: currency,
    );
  }

  List<CashSource> getAvailableCashSources({
    required String currency,
    bool newestFirst = false,
  }) {
    return reconciliationService.getAvailableCashSources(
      state: _state,
      currency: currency,
      newestFirst: newestFirst,
    );
  }

  Map<String, double> get cashByCurrency {
    return reconciliationService.getCashByCurrency(_state);
  }

  Future<void> updateMarketSnapshot(MarketSnapshot snapshot) async {
    await updateState(_state.copyWith(marketData: snapshot.toAppStateJson()));
  }

  Future<void> toggleInstallmentPaid({
    required String assetId,
    required int installmentIndex,
    required String paymentCategory,
  }) async {
    final MarketData market = MarketData.fromJson(_state.marketData);
    final ReconciliationResult out = reconciliationService
        .toggleInstallmentPaid(
          input: _state,
          assetId: assetId,
          installmentIndex: installmentIndex,
          paymentCategory: paymentCategory,
          marketData: market,
        );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> toggleZakatPaid({
    required String monthKey,
    required double zakatAmountMainCurrency,
    required String paymentDate,
  }) async {
    final ReconciliationResult out = reconciliationService.toggleZakatPaid(
      input: _state,
      monthKey: monthKey,
      zakatAmountMainCurrency: zakatAmountMainCurrency,
      mainCurrency: _state.mainCurrency.trim().isEmpty
          ? 'EGP'
          : _state.mainCurrency,
      paymentDate: paymentDate,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> executeCurrencyExchange({
    required String date,
    required String sourceCurrency,
    required String targetCurrency,
    required double sourceAmount,
    required double targetAmount,
  }) async {
    final ReconciliationResult out = reconciliationService
        .executeCurrencyExchange(
          input: _state,
          date: date,
          sourceCurrency: sourceCurrency,
          targetCurrency: targetCurrency,
          sourceAmount: sourceAmount,
          targetAmount: targetAmount,
        );
    if (!out.modified) return;
    await updateState(out.state);
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
    if (!force &&
        respectCooldown &&
        _isWithinMarketCooldown(before.lastUpdated)) {
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
      debugPrint(
        'AppStateController.refreshMarketData: FX refresh failed: $error',
      );
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

    final double usdToEgpForMetals = after.usdToEgp > 0
        ? after.usdToEgp
        : before.usdToEgp;
    double? goldPrice;
    double? silverPrice;
    try {
      goldPrice = await marketDataApiService.fetchGold24kPerGramEgp(
        usdToEgp: usdToEgpForMetals,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.refreshMarketData: gold refresh failed: $error',
      );
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
      after = after.copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
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
    String? zakatNisabBasis,
    String? languagePreference,
    String? themeMode,
    String? zakatScheduleFilter,
    Map<String, dynamic>? marketData,
    List<Map<String, dynamic>>? marketHistory,
    SyncHealth? syncHealth,
    String? lastModifiedAt,
    Map<String, dynamic>? aiSettings,
    bool? cloudHydrated,
    bool? hasUnsyncedAuthChanges,
    String? loadedUserId,
  }) {
    return AppStateModel(
      transactions: transactions ?? this.transactions,
      savings: savings ?? this.savings,
      recurringTransactions:
          recurringTransactions ?? this.recurringTransactions,
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
      zakatNisabBasis: zakatNisabBasis ?? this.zakatNisabBasis,
      languagePreference: languagePreference ?? this.languagePreference,
      themeMode: themeMode ?? this.themeMode,
      zakatScheduleFilter: zakatScheduleFilter ?? this.zakatScheduleFilter,
      marketData: marketData ?? this.marketData,
      marketHistory: marketHistory ?? this.marketHistory,
      syncHealth: syncHealth ?? this.syncHealth,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      aiSettings: aiSettings ?? this.aiSettings,
      cloudHydrated: cloudHydrated ?? this.cloudHydrated,
      hasUnsyncedAuthChanges:
          hasUnsyncedAuthChanges ?? this.hasUnsyncedAuthChanges,
      loadedUserId: loadedUserId ?? this.loadedUserId,
    );
  }
}
