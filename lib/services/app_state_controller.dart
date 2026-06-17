// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/market_snapshot.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import '../models/pending_transaction.dart';
import '../models/currency_exchange_edit_request.dart';
import '../models/merchant_rule.dart';
import '../models/merchant_confirmation.dart';
import '../models/capture_analytics.dart';
import '../models/correction_feedback.dart';
import '../models/user_profile.dart';
import '../repositories/app_state_repository.dart';
import 'market_data_api_service.dart';
import 'reconciliation_service.dart';
import '../core/services/zakat_engine.dart';
import 'biometric_service.dart';
import 'smart_capture_parser.dart';

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

  Future<void> loadAuthenticated(String userId) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.loadAuthenticated requires a non-empty authenticated userId.',
    );
    await load(userId: userId);
  }

  Future<void> load({String? userId}) async {
    try {
      _state = await repository.loadAppState(userId: userId);
      if (_state.biometricHideWealthEnabled) {
        final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
          _state.aiSettings ?? <String, dynamic>{},
        );
        aiSettings['privacyMode'] = true;
        _state = _state.copyWith(aiSettings: aiSettings);
      }
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

  Future<void> attachCurrentUser({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
    required String provider,
  }) async {
    _state = _state.copyWith(
      userId: userId,
      userEmail: email,
      userDisplayName: displayName,
      userPhotoUrl: photoUrl,
      userProvider: provider,
      loadedUserId: userId,
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
  }

  Future<void> resetForCurrentUser(UserProfile user) async {
    _state = AppStateDefaults.create().copyWith(
      userId: user.id,
      userEmail: user.email,
      userDisplayName: user.displayName,
      userPhotoUrl: user.photoUrl,
      userProvider: user.provider,
      loadedUserId: user.id,
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
  }

  Future<void> resetForSignedOutUser() async {
    _state = AppStateDefaults.create();
    notifyListeners();
  }

  Future<void> markRestorePromptDismissedForCurrentUser({
    required String userId,
  }) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.markRestorePromptDismissedForCurrentUser requires userId.',
    );
    _state = _state.copyWith(restorePromptDismissedUserId: userId);
    await save();
    notifyListeners();
  }

  Future<void> clearRestorePromptDismissedForCurrentUser({
    required String userId,
  }) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.clearRestorePromptDismissedForCurrentUser requires userId.',
    );
    if (_state.restorePromptDismissedUserId == userId) {
      _state = _state.copyWith(restorePromptDismissedUserId: null);
      await save();
      notifyListeners();
    }
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
    await repository.saveAppState(_state, userId: _state.userId);
  }

  Future<void> clearLocalData() async {
    await repository.clearLocalData(userId: _state.userId);
    _state = AppStateDefaults.create();
    notifyListeners();
  }

  Future<void> clearLocalDataForUser({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.clearLocalDataForUser requires userId.',
    );
    await repository.clearLocalData(userId: userId);
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
    if (kDebugMode) {
      print('[ExchangeDebug][deleteTransaction] id=$transactionId');
    }
    Transaction? target;
    for (final tx in _state.transactions) {
      if (tx.id == transactionId) {
        target = tx;
        break;
      }
    }
    if (target == null) return;
    final Transaction txTarget = target;

    final String? exchangeActivityId =
        txTarget.exchangePairId != null &&
            txTarget.exchangePairId!.trim().isNotEmpty
        ? txTarget.exchangePairId!.trim()
        : null;
    if (exchangeActivityId != null &&
        txTarget.category != 'Gold Sale' &&
        txTarget.category != 'Silver Sale') {
      if (kDebugMode) {
        print(
          '[ExchangeDebug][deleteTransaction] deleting exchange activityId=$exchangeActivityId',
        );
      }
      await _deleteCurrencyExchangeActivity(exchangeActivityId);
      return;
    }

    List<Saving> nextSavings = List<Saving>.from(_state.savings);

    if (txTarget.category == 'Gold Sale' ||
        txTarget.category == 'Silver Sale') {
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
              return s.copyWith(
                remainingAmount: s.remainingAmount + soldWeight,
              );
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
          if (txTarget.category == 'Gold Sale' ||
              txTarget.category == 'Silver Sale') {
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
    if (kDebugMode) {
      print('[ExchangeDebug][deleteSaving] id=$savingId');
    }
    Saving? target;
    for (final s in _state.savings) {
      if (s.id == savingId) {
        target = s;
        break;
      }
    }
    if (target == null) return;

    final String? exchangeActivityId =
        target.transferActivityId != null &&
            target.transferActivityId!.trim().isNotEmpty
        ? target.transferActivityId!.trim()
        : null;
    if (exchangeActivityId != null) {
      if (kDebugMode) {
        print(
          '[ExchangeDebug][deleteSaving] deleting exchange activityId=$exchangeActivityId',
        );
      }
      await _deleteCurrencyExchangeActivity(exchangeActivityId);
      return;
    }

    List<Saving> nextSavings = _state.savings
        .where((Saving entry) => entry.id != savingId)
        .toList(growable: false);

    if (target.exchangeSourceSavingId != null &&
        target.exchangeSourceSavingId!.isNotEmpty) {
      final String srcId = target.exchangeSourceSavingId!;
      final double deducted = _parseSavingsExchangeAmount(target.description);
      if (deducted > 0) {
        nextSavings = nextSavings
            .map((Saving s) {
              if (s.id == srcId) {
                return s.copyWith(
                  amount: s.amount + deducted,
                  remainingAmount: s.remainingAmount + deducted,
                );
              }
              return s;
            })
            .toList(growable: false);
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

  Future<void> _deleteCurrencyExchangeActivity(String activityId) async {
    final List<Saving> exchangeSavings = _state.savings
        .where((Saving saving) => saving.transferActivityId == activityId)
        .toList(growable: false);

    final Map<String, double> sourceRestorations = <String, double>{};
    for (final Saving saving in exchangeSavings) {
      final String? sourceId = saving.exchangeSourceSavingId;
      if (sourceId == null || sourceId.trim().isEmpty) continue;
      final double restored = _parseSavingsExchangeAmount(saving.description);
      if (restored <= 0) continue;
      sourceRestorations[sourceId] =
          (sourceRestorations[sourceId] ?? 0) + restored;
    }

    final List<Saving> nextSavings = _state.savings
        .where((Saving saving) => saving.transferActivityId != activityId)
        .map((Saving saving) {
          final double restored = sourceRestorations[saving.id] ?? 0;
          if (restored <= 0) return saving;
          return saving.copyWith(
            amount: saving.amount + restored,
            remainingAmount: saving.remainingAmount + restored,
          );
        })
        .toList(growable: false);

    final List<Transaction> nextTransactions = _state.transactions
        .where((Transaction tx) => tx.exchangePairId != activityId)
        .toList(growable: false);

    await updateState(
      _state.copyWith(transactions: nextTransactions, savings: nextSavings),
    );
  }

  Future<void> deleteCurrencyExchangeActivity(String activityId) async {
    if (kDebugMode) {
      print(
        '[ExchangeDebug][deleteCurrencyExchangeActivity] activityId=$activityId',
      );
    }
    await _deleteCurrencyExchangeActivity(activityId);
  }

  static double _parseSavingsExchangeAmount(String description) {
    final Match? match = RegExp(
      r'Savings exchange:\s*([0-9.]+)\s',
    ).firstMatch(description);
    return double.tryParse(match?.group(1) ?? '') ?? 0.0;
  }

  Future<void> updateCurrencyExchange(
    CurrencyExchangeEditRequest request,
  ) async {
    if (kDebugMode) {
      print(
        '[ExchangeDebug][updateCurrencyExchange] activityId=${request.oldActivityId} '
        'date=${request.date} source=${request.sourceCurrency} ${request.sourceAmount} '
        'target=${request.targetCurrency} ${request.targetAmount} '
        'targets=${request.oldTargetSavingIds} '
        'sourceDeductions=${request.oldSourceSavingDeductions}',
      );
    }
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

  Future<void> reorderCategories({
    required String type,
    required int oldIndex,
    required int newIndex,
  }) async {
    final bool income = type == 'income';
    final List<String> source = List<String>.from(
      income ? _state.categories.income : _state.categories.expense,
    );
    if (oldIndex < 0 || oldIndex >= source.length) return;
    int targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= source.length) return;
    final String element = source.removeAt(oldIndex);
    source.insert(targetIndex, element);
    final AppCategories nextCategories = AppCategories(
      income: income ? source : _state.categories.income,
      expense: income ? _state.categories.expense : source,
    );
    await updateState(_state.copyWith(categories: nextCategories));
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

    if (isCurrentlyHidden && _state.biometricHideWealthEnabled) {
      final authenticated = await BiometricService.authenticate(
        reason: 'Confirm identity to reveal wealth values',
      );
      if (!authenticated) return;
    }

    aiSettings['privacyMode'] = !isCurrentlyHidden;
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  Future<void> updateAiSettings(Map<String, dynamic> aiSettings) async {
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  Future<void> updateBiometricLockEnabled(bool value) async {
    await updateState(_state.copyWith(biometricLockEnabled: value));
  }

  Future<void> updateBiometricHideWealthEnabled(bool value) async {
    await updateState(_state.copyWith(biometricHideWealthEnabled: value));
  }

  Future<void> updateBiometricExportEnabled(bool value) async {
    await updateState(_state.copyWith(biometricExportEnabled: value));
  }

  Future<void> updateBiometricRestoreEnabled(bool value) async {
    await updateState(_state.copyWith(biometricRestoreEnabled: value));
  }

  Future<void> updateBiometricAutoLockDelay(String value) async {
    await updateState(_state.copyWith(biometricAutoLockDelay: value));
  }

  Future<void> addPendingTransaction(PendingTransaction transaction) async {
    final List<PendingTransaction> next = List<PendingTransaction>.from(
      _state.pendingTransactions,
    )..add(transaction);

    // Enforce soft limit of 500 items, keeping the newest 500 items by createdAt
    if (next.length > 500) {
      next.sort(
        (PendingTransaction a, PendingTransaction b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      final List<PendingTransaction> trimmed = next.take(500).toList();
      await updateState(_state.copyWith(pendingTransactions: trimmed));
    } else {
      await updateState(_state.copyWith(pendingTransactions: next));
    }
  }

  Future<void> removePendingTransaction(String id) async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((PendingTransaction t) => t.id != id)
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> rejectPendingTransaction(
    String id, {
    String reason = 'Manually Ignored',
  }) async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((
      PendingTransaction t,
    ) {
      if (t.id == id) {
        return t.copyWith(
          status: CaptureStatus.ignored,
          reviewedAt: DateTime.now().toUtc().toIso8601String(),
          ignoreReason: reason,
        );
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> undoPendingTransaction(String pendingId) async {
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    final String? linkedId = pendingTx.linkedTransactionId;
    AppStateModel nextState = _state;

    if (linkedId != null && linkedId.isNotEmpty) {
      final List<Transaction> nextTx = nextState.transactions
          .where((t) => t.id != linkedId)
          .toList();
      final List<Saving> nextSav = nextState.savings
          .where((s) => s.id != linkedId)
          .toList();
      final List<InvestmentAsset> nextInv = nextState.investments
          .where((i) => i.id != linkedId)
          .toList();
      nextState = nextState.copyWith(
        transactions: nextTx,
        savings: nextSav,
        investments: nextInv,
      );
    }

    final List<PendingTransaction> updatedPending = nextState
        .pendingTransactions
        .map((PendingTransaction t) {
          if (t.id == pendingId) {
            return t.copyWith(
              status: CaptureStatus.pendingReview,
              clearReviewedAt: true,
              clearLinkedTransactionId: true,
              clearApprovalSource: true,
            );
          }
          return t;
        })
        .toList();

    CaptureAnalytics analytics = nextState.captureAnalytics;
    if (pendingTx.approvalSource == ApprovalSource.auto &&
        analytics.autoApprovedMessages > 0) {
      analytics = analytics.copyWith(
        autoApprovedMessages: analytics.autoApprovedMessages - 1,
      );
    }
    nextState = nextState.copyWith(
      pendingTransactions: updatedPending,
      captureAnalytics: analytics,
    );
    await updateState(nextState);
  }

  Future<void> editApprovedPendingTransaction(
    String pendingId, {
    required String type,
    required double amount,
    required String currency,
    required String category,
    required String description,
    required String date,
  }) async {
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    final String? linkedId = pendingTx.linkedTransactionId;
    if (linkedId == null || linkedId.isEmpty) {
      throw StateError('This capture is not linked to any ledger record.');
    }

    AppStateModel nextState = _state;
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    if (nextState.transactions.any((t) => t.id == linkedId)) {
      final List<Transaction> nextTx = nextState.transactions.map((t) {
        if (t.id == linkedId) {
          return Transaction(
            id: t.id,
            type: type,
            date: date,
            amount: amount,
            currency: currency.trim().toUpperCase(),
            category: category,
            description: description,
            createdAt: t.createdAt,
            rolledOver: t.rolledOver,
            rolledAmount: t.rolledAmount,
            sourceIncomeId: t.sourceIncomeId,
            exchangePairId: t.exchangePairId,
            exchangeSourceIncomeId: t.exchangeSourceIncomeId,
            remainingAmount: t.remainingAmount,
            activityType: type == 'transfer' ? 'transfer' : t.activityType,
            costBasis: t.costBasis,
            saleValue: t.saleValue,
            realizedGain: t.realizedGain,
            realizedGainLossCurrency: t.realizedGainLossCurrency,
          );
        }
        return t;
      }).toList();
      nextState = nextState.copyWith(transactions: nextTx);
    } else if (nextState.savings.any((s) => s.id == linkedId)) {
      final List<Saving> nextSav = nextState.savings.map((s) {
        if (s.id == linkedId) {
          final String metalType = type == 'gold_purchase' ? 'gold' : 'silver';
          return Saving(
            id: s.id,
            assetType: metalType,
            dateAcquired: date,
            amount: amount,
            remainingAmount: amount,
            unit: s.unit,
            description: description,
            purchaseCurrency: currency.trim().toUpperCase(),
            purchaseAmount: s.purchaseAmount,
            createdAt: s.createdAt,
          );
        }
        return s;
      }).toList();
      nextState = nextState.copyWith(savings: nextSav);
    } else if (nextState.investments.any((i) => i.id == linkedId)) {
      final List<InvestmentAsset> nextInv = nextState.investments.map((i) {
        if (i.id == linkedId) {
          return InvestmentAsset(
            id: i.id,
            investmentType: i.investmentType,
            assetSubtype: i.assetSubtype,
            ownershipType: i.ownershipType,
            valuationMode: i.valuationMode,
            currency: currency.trim().toUpperCase(),
            originalPrice: amount,
            totalInterest: i.totalInterest,
            totalPayable: amount,
            paidAmount: amount,
            remainingAmount: i.remainingAmount,
            installmentPlan: i.installmentPlan,
            valuationDate: date,
            marketValue: amount,
            marketValueDate: date,
            valuationSource: i.valuationSource,
            loanBalance: i.loanBalance,
            loanAsOfDate: i.loanAsOfDate,
            paidAmountToDate: amount,
            ownershipSharePct: i.ownershipSharePct,
            country: i.country,
            location: i.location,
            inflationRateAnnual: i.inflationRateAnnual,
            estimatedCurrentValue: amount,
            description: description,
            noZakat: i.noZakat,
            createdAt: i.createdAt,
          );
        }
        return i;
      }).toList();
      nextState = nextState.copyWith(investments: nextInv);
    }

    final String? originalCategory = pendingTx.suggestedCategory;
    if (originalCategory != null && originalCategory != category) {
      final CorrectionFeedback fb = CorrectionFeedback(
        id: const Uuid().v4(),
        fieldName: 'category',
        originalValue: originalCategory,
        correctedValue: category,
        createdAt: timestampStr,
      );
      List<CorrectionFeedback> nextFeedback = <CorrectionFeedback>[
        ...nextState.correctionFeedback,
        fb,
      ];
      if (nextFeedback.length > 500) {
        nextFeedback = nextFeedback.sublist(nextFeedback.length - 500);
      }
      CaptureAnalytics nextAnalytics = nextState.captureAnalytics.copyWith(
        correctedMessages: nextState.captureAnalytics.correctedMessages + 1,
      );
      nextState = nextState.copyWith(
        correctionFeedback: nextFeedback,
        captureAnalytics: nextAnalytics,
      );

      if (pendingTx.merchantName != null &&
          pendingTx.merchantName!.trim().isNotEmpty) {
        final String merchant = SmartCaptureParser.normalizeMerchantName(
          pendingTx.merchantName!,
        );
        final String key = merchant.toLowerCase();
        final List<MerchantConfirmation> confirmations =
            List<MerchantConfirmation>.from(nextState.merchantConfirmations);
        final int oldIndex = confirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == key &&
              c.categoryId == originalCategory,
        );
        if (oldIndex >= 0) {
          confirmations[oldIndex] = confirmations[oldIndex].copyWith(
            corrections: confirmations[oldIndex].corrections + 1,
          );
        }
        final int newIndex = confirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == key && c.categoryId == category,
        );
        if (newIndex >= 0) {
          confirmations[newIndex] = confirmations[newIndex].copyWith(
            confirmations: confirmations[newIndex].confirmations + 1,
          );
        } else {
          confirmations.add(
            MerchantConfirmation(
              merchantName: merchant,
              categoryId: category,
              confirmations: 1,
              corrections: 0,
            ),
          );
        }
        final Map<String, MerchantRule> rules = Map<String, MerchantRule>.from(
          nextState.merchantRules,
        );
        final MerchantRule? existing = rules[key];
        if (existing != null) {
          rules[key] = existing.copyWith(
            categoryId: category,
            defaultType: type,
            usageCount: existing.usageCount + 1,
            lastUsed: timestampStr,
          );
        }
        nextState = nextState.copyWith(
          merchantConfirmations: confirmations,
          merchantRules: rules,
        );
      }
    }

    final List<PendingTransaction> nextPending = nextState.pendingTransactions
        .map((t) {
          if (t.id == pendingId) {
            return t.copyWith(
              suggestedType: type,
              suggestedAmount: amount,
              suggestedCurrency: currency.trim().toUpperCase(),
              suggestedDescription: description,
              suggestedCategory: category,
              reviewedAt: timestampStr,
            );
          }
          return t;
        })
        .toList();

    nextState = nextState.copyWith(pendingTransactions: nextPending);
    await updateState(nextState);
  }

  Future<void> approvePendingTransaction(
    String pendingId, {
    required String type,
    required double amount,
    required String currency,
    required String category,
    required String description,
    required String date,
  }) async {
    // Locate the pending transaction
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    // Guard: Assert linkedTransactionId == null and status is pending to prevent duplicate approvals
    if (pendingTx.linkedTransactionId != null ||
        pendingTx.status == CaptureStatus.autoApproved ||
        pendingTx.status == CaptureStatus.manuallyApproved) {
      throw StateError('Pending transaction is already approved.');
    }

    final String generatedRecordId = const Uuid().v4();
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    AppStateModel nextState = _state;

    if (type == 'expense' || type == 'income' || type == 'transfer') {
      final Transaction newTx = Transaction(
        id: generatedRecordId,
        type: type,
        date: date,
        amount: amount,
        currency: currency.trim().toUpperCase(),
        category: category,
        description: description,
        createdAt: timestampStr,
        rolledOver: false,
        activityType: type == 'transfer' ? 'transfer' : null,
      );
      nextState = nextState.copyWith(
        transactions: <Transaction>[...nextState.transactions, newTx],
      );
    } else if (type == 'gold_purchase' || type == 'silver_purchase') {
      final String metalType = type == 'gold_purchase' ? 'gold' : 'silver';
      final Saving newSaving = Saving(
        id: generatedRecordId,
        assetType: metalType,
        dateAcquired: date,
        amount: amount,
        remainingAmount: amount,
        unit: 'grams',
        description: description,
        purchaseCurrency: currency.trim().toUpperCase(),
        purchaseAmount: 0.0,
        createdAt: timestampStr,
      );
      nextState = nextState.copyWith(
        savings: <Saving>[...nextState.savings, newSaving],
      );
    } else if (type == 'investment') {
      final InvestmentAsset newInvestment = InvestmentAsset(
        id: generatedRecordId,
        investmentType: 'Stocks/Funds',
        assetSubtype: 'Equities',
        ownershipType: 'Sole',
        valuationMode: 'Market Value',
        currency: currency.trim().toUpperCase(),
        originalPrice: amount,
        totalInterest: 0.0,
        totalPayable: amount,
        paidAmount: amount,
        remainingAmount: 0.0,
        installmentPlan: const <Map<String, dynamic>>[],
        valuationDate: date,
        marketValue: amount,
        marketValueDate: date,
        valuationSource: 'manual',
        loanBalance: 0.0,
        loanAsOfDate: date,
        paidAmountToDate: amount,
        ownershipSharePct: 100.0,
        country: '',
        location: '',
        inflationRateAnnual: 0.0,
        estimatedCurrentValue: amount,
        description: description,
        noZakat: false,
        createdAt: timestampStr,
      );
      nextState = nextState.copyWith(
        investments: <InvestmentAsset>[...nextState.investments, newInvestment],
      );
    } else {
      throw ArgumentError('Unsupported financial entry type: $type');
    }

    // Category confirmation learning logic
    if (pendingTx.merchantName != null &&
        pendingTx.merchantName!.trim().isNotEmpty) {
      final String normMerchant = SmartCaptureParser.normalizeMerchantName(
        pendingTx.merchantName!,
      ).trim();
      final String merchantKey = normMerchant.toLowerCase();

      List<MerchantConfirmation> nextConfirmations =
          List<MerchantConfirmation>.from(nextState.merchantConfirmations);
      Map<String, MerchantRule> nextRules = Map<String, MerchantRule>.from(
        nextState.merchantRules,
      );
      CaptureAnalytics nextAnalytics = nextState.captureAnalytics;

      final String? sugCat = pendingTx.suggestedCategory;

      int idx = nextConfirmations.indexWhere(
        (c) =>
            c.merchantName.toLowerCase() == merchantKey &&
            c.categoryId == category,
      );
      if (idx != -1) {
        nextConfirmations[idx] = nextConfirmations[idx].copyWith(
          confirmations: nextConfirmations[idx].confirmations + 1,
        );
      } else {
        nextConfirmations.add(
          MerchantConfirmation(
            merchantName: normMerchant,
            categoryId: category,
            confirmations: 1,
            corrections: 0,
          ),
        );
        idx = nextConfirmations.length - 1;
      }

      if (sugCat != null && sugCat != category) {
        int sugIdx = nextConfirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == merchantKey &&
              c.categoryId == sugCat,
        );
        if (sugIdx != -1) {
          nextConfirmations[sugIdx] = nextConfirmations[sugIdx].copyWith(
            corrections: nextConfirmations[sugIdx].corrections + 1,
          );
        } else {
          nextConfirmations.add(
            MerchantConfirmation(
              merchantName: normMerchant,
              categoryId: sugCat,
              confirmations: 0,
              corrections: 1,
            ),
          );
        }

        final CorrectionFeedback fb = CorrectionFeedback(
          id: const Uuid().v4(),
          fieldName: 'category',
          originalValue: sugCat,
          correctedValue: category,
          createdAt: timestampStr,
        );
        List<CorrectionFeedback> nextFeedback = <CorrectionFeedback>[
          ...nextState.correctionFeedback,
          fb,
        ];
        if (nextFeedback.length > 500) {
          nextFeedback = nextFeedback.sublist(nextFeedback.length - 500);
        }
        nextAnalytics = nextAnalytics.copyWith(
          correctedMessages: nextAnalytics.correctedMessages + 1,
        );
        nextState = nextState.copyWith(correctionFeedback: nextFeedback);
      }

      final MerchantConfirmation conf = nextConfirmations[idx];
      final int total = conf.confirmations + conf.corrections;
      final double ratio = total > 0 ? conf.confirmations / total : 0.0;
      if (conf.confirmations >= 3 && ratio >= 0.80) {
        final bool alreadyExists = nextRules.containsKey(merchantKey);
        final MerchantRule? existingRule = nextRules[merchantKey];
        nextRules[merchantKey] = MerchantRule(
          merchantName: normMerchant,
          categoryId: category,
          defaultType: type,
          autoApprove: existingRule?.autoApprove ?? true,
          usageCount: alreadyExists ? existingRule!.usageCount + 1 : 1,
          confidence: ratio,
          lastUsed: timestampStr,
          source: alreadyExists && existingRule!.source == 'custom'
              ? 'custom'
              : 'learned',
          aliases: existingRule?.aliases ?? const <String>[],
          enabled: existingRule?.enabled ?? true,
          isBuiltinOverride: existingRule?.isBuiltinOverride ?? false,
        );

        if (!alreadyExists) {
          nextAnalytics = nextAnalytics.copyWith(
            learnedRules: nextAnalytics.learnedRules + 1,
          );
        }
      }

      nextState = nextState.copyWith(
        merchantConfirmations: nextConfirmations,
        merchantRules: nextRules,
        captureAnalytics: nextAnalytics,
      );
    }

    // Update the PendingTransaction status to approved, set reviewedAt, and linkedTransactionId
    final List<PendingTransaction> updatedPending = nextState
        .pendingTransactions
        .map((PendingTransaction t) {
          if (t.id == pendingId) {
            return t.copyWith(
              status: CaptureStatus.manuallyApproved,
              approvalSource: ApprovalSource.manual,
              reviewedAt: timestampStr,
              linkedTransactionId: generatedRecordId,
            );
          }
          return t;
        })
        .toList();

    nextState = nextState.copyWith(pendingTransactions: updatedPending);
    await updateState(nextState);
  }

  Future<void> clearPendingTransactions() async {
    await updateState(
      _state.copyWith(pendingTransactions: const <PendingTransaction>[]),
    );
  }

  Future<void> deleteIgnoredPendingTransactions() async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((t) => t.status != CaptureStatus.ignored)
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> deletePendingTransactionsBulk(List<String> ids) async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((t) => !ids.contains(t.id))
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> restorePendingTransactionsBulk(List<String> ids) async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((t) {
      if (ids.contains(t.id)) {
        return t.copyWith(
          status: CaptureStatus.pendingReview,
          clearReviewedAt: true,
          clearApprovalSource: true,
        );
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> markPendingTransactionsAsRead() async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((
      PendingTransaction t,
    ) {
      if (!t.isRead) {
        return t.copyWith(isRead: true);
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> setSmartCaptureEnabled(bool enabled) async {
    await updateState(_state.copyWith(smartCaptureEnabled: enabled));
  }

  Future<void> setSmartCaptureAutoApproveEnabled(bool enabled) async {
    await updateState(_state.copyWith(smartCaptureAutoApproveEnabled: enabled));
  }

  Future<void> saveCustomMerchantRule(MerchantRule rule) async {
    final String key =
        rule.builtinKey?.toLowerCase().trim() ??
        rule.merchantName.toLowerCase().trim();
    final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
    final nextAliases = Map<String, String>.from(_state.merchantAliases);
    final bool alreadyExists = nextRules.containsKey(key);
    nextRules[key] = rule;
    nextAliases.removeWhere(
      (String alias, String merchant) => merchant.toLowerCase().trim() == key,
    );
    for (final String alias in rule.aliases) {
      final String aliasKey = alias.toLowerCase().trim();
      if (aliasKey.isNotEmpty) nextAliases[aliasKey] = rule.merchantName;
    }

    CaptureAnalytics nextAnalytics = _state.captureAnalytics;
    if (!alreadyExists && rule.source == 'custom') {
      nextAnalytics = nextAnalytics.copyWith(
        learnedRules: nextAnalytics.learnedRules + 1,
      );
    }

    await updateState(
      _state.copyWith(
        merchantRules: nextRules,
        merchantAliases: nextAliases,
        captureAnalytics: nextAnalytics,
      ),
    );
  }

  Future<void> deleteMerchantRule(String merchantName) async {
    String key = merchantName.toLowerCase().trim();
    final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
    final nextAliases = Map<String, String>.from(_state.merchantAliases);
    if (!nextRules.containsKey(key)) {
      for (final MapEntry<String, MerchantRule> entry in nextRules.entries) {
        if (entry.value.merchantName.toLowerCase().trim() == key) {
          key = entry.key;
          break;
        }
      }
    }
    final MerchantRule? removedRule = nextRules.remove(key);
    nextAliases.removeWhere(
      (String alias, String merchant) =>
          merchant.toLowerCase().trim() == key ||
          merchant.toLowerCase().trim() ==
              removedRule?.merchantName.toLowerCase().trim(),
    );
    await updateState(
      _state.copyWith(merchantRules: nextRules, merchantAliases: nextAliases),
    );
  }

  Future<void> resetBuiltinMerchantRule(String merchantName) async {
    MerchantRule? rule;
    for (final MerchantRule candidate in _state.merchantRules.values) {
      if (candidate.merchantName == merchantName) {
        rule = candidate;
        break;
      }
    }
    await deleteMerchantRule(rule?.builtinKey ?? merchantName);
  }

  Future<void> setMerchantRuleEnabled(MerchantRule rule, bool enabled) async {
    final String key = rule.merchantName.toLowerCase().trim();
    final bool isBuiltin =
        rule.isBuiltinOverride ||
        SmartCaptureParser.builtinMerchantCategoryMap.containsKey(key);
    await saveCustomMerchantRule(
      rule.copyWith(
        enabled: enabled,
        source: isBuiltin ? 'custom' : rule.source,
        isBuiltinOverride: isBuiltin,
        builtinKey: isBuiltin ? (rule.builtinKey ?? key) : rule.builtinKey,
      ),
    );
  }

  Future<void> createPendingTransaction({
    required String source,
    String? sourceIdentifier,
    required String rawMessage,
    required String suggestedType,
    required double confidence,
    double? suggestedAmount,
    String? suggestedCurrency,
    String? suggestedDescription,
    String? merchantName,
    String? suggestedCategory,
    String? parserVersion,
    String? detectedBank,
    bool requiresReview = true,
  }) async {
    final PendingTransaction transaction = PendingTransaction(
      id: const Uuid().v4(),
      source: source,
      sourceIdentifier: sourceIdentifier,
      rawMessage: rawMessage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      suggestedType: suggestedType,
      suggestedAmount: suggestedAmount,
      suggestedCurrency: suggestedCurrency,
      suggestedDescription: suggestedDescription,
      merchantName: merchantName,
      suggestedCategory: suggestedCategory,
      confidence: confidence,
      status: CaptureStatus.pendingReview,
      parserVersion: parserVersion,
      detectedBank: detectedBank,
      requiresReview: requiresReview,
      isRead: false,
    );
    await addPendingTransaction(transaction);
  }

  Future<void> createPendingTransactionFromMessage(
    String rawMessage,
    String source,
  ) async {
    await createPendingTransactionFromMessageWithResult(rawMessage, source);
  }

  Future<bool> createPendingTransactionFromMessageWithResult(
    String rawMessage,
    String source, {
    String? sourceIdentifier,
  }) async {
    if (!_state.smartCaptureEnabled) return false;

    final String cleanMessage = rawMessage.trim();
    if (cleanMessage.isEmpty || cleanMessage.length > 10000) {
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: invalid');
      }
      return false;
    }

    if (source == PendingTransactionSource.shortcut) {
      debugPrint('[Shortcut] Parser started');
    }

    final parsed = SmartCaptureParser.parse(
      rawMessage,
      merchantRules: _state.merchantRules,
      merchantAliases: _state.merchantAliases,
    );

    String? detectedBank;
    final String lowerMsg = cleanMessage.toLowerCase();
    if (lowerMsg.contains('hsbc')) {
      detectedBank = 'HSBC';
    } else if (lowerMsg.contains('cib')) {
      detectedBank = 'CIB';
    } else if (lowerMsg.contains('alrajhi') || lowerMsg.contains('الراجحي')) {
      detectedBank = 'Al Rajhi Bank';
    } else if (lowerMsg.contains('ahli') || lowerMsg.contains('الأهلي')) {
      detectedBank = 'Al Ahli Bank';
    }

    if (source == PendingTransactionSource.shortcut) {
      debugPrint(
        '[Shortcut] Parser result: merchant=${parsed.merchantName ?? 'null'}, '
        'amount=${_formatShortcutAmount(parsed.amount)}, '
        'currency=${parsed.currency ?? 'null'}, '
        'confidence=${parsed.confidence.toStringAsFixed(2)}',
      );
    }

    final String normMerchant = parsed.merchantName != null
        ? SmartCaptureParser.normalizeMerchantName(parsed.merchantName!).trim()
        : '';
    final String merchantKey = normMerchant.toLowerCase();

    CaptureAnalytics nextAnalytics = _state.captureAnalytics.copyWith(
      parsedMessages: _state.captureAnalytics.parsedMessages + 1,
      capturedFromAppleShortcuts: source == PendingTransactionSource.shortcut
          ? _state.captureAnalytics.capturedFromAppleShortcuts + 1
          : _state.captureAnalytics.capturedFromAppleShortcuts,
    );

    if (!parsed.isValid) {
      nextAnalytics = nextAnalytics.copyWith(
        ignoredMessages: nextAnalytics.ignoredMessages + 1,
        capturedFromAppleShortcutsIgnored:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsIgnored + 1
            : nextAnalytics.capturedFromAppleShortcutsIgnored,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: invalid');
      }
      await updateState(
        _state.copyWith(
          pendingTransactions: <PendingTransaction>[
            ..._state.pendingTransactions,
            PendingTransaction(
              id: const Uuid().v4(),
              source: source,
              sourceIdentifier:
                  sourceIdentifier ??
                  (source == PendingTransactionSource.shortcut
                      ? 'Apple Automation'
                      : null),
              rawMessage: cleanMessage,
              createdAt: DateTime.now().toUtc().toIso8601String(),
              suggestedType: parsed.type,
              suggestedAmount: parsed.amount,
              suggestedCurrency: parsed.currency,
              suggestedDescription: parsed.description,
              merchantName: parsed.merchantName,
              suggestedCategory: parsed.suggestedCategory,
              confidence: parsed.confidence,
              status: CaptureStatus.ignored,
              ignoreReason: parsed.ignoreReason ?? 'Invalid Transaction',
              requiresReview: false,
              isRead: true,
            ),
          ],
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('invalid');
      }
      return true;
    }

    final now = DateTime.now().toUtc();
    bool isDuplicate = false;

    for (final pt in _state.pendingTransactions) {
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
          final ptTime = DateTime.parse(pt.createdAt).toUtc();
          if (now.difference(ptTime).abs().inMinutes <= 5) {
            isDuplicate = true;
            break;
          }
        } catch (_) {}
      }
    }

    if (!isDuplicate) {
      for (final t in _state.transactions) {
        final String tM = _normalizedTransactionMerchantKey(t);
        if (t.type == parsed.type &&
            t.currency == parsed.currency &&
            t.amount == parsed.amount &&
            tM == merchantKey) {
          try {
            final tTime = DateTime.parse(t.createdAt).toUtc();
            if (now.difference(tTime).abs().inMinutes <= 5) {
              isDuplicate = true;
              break;
            }
          } catch (_) {}
        }
      }
    }

    if (isDuplicate) {
      nextAnalytics = nextAnalytics.copyWith(
        duplicateMessages: nextAnalytics.duplicateMessages + 1,
        ignoredMessages: nextAnalytics.ignoredMessages + 1,
        capturedFromAppleShortcutsIgnored:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsIgnored + 1
            : nextAnalytics.capturedFromAppleShortcutsIgnored,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: duplicate');
      }
      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        suggestedType: parsed.type,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: parsed.suggestedCategory,
        confidence: 0.0,
        status: CaptureStatus.ignored,
        ignoreReason: 'Duplicate',
        detectedBank: detectedBank,
        requiresReview: false,
        isRead: true,
      );
      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ..._state.pendingTransactions,
        transaction,
      ];
      await updateState(
        _state.copyWith(
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('duplicate');
      }
      return true;
    }

    final String generatedId = const Uuid().v4();
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    bool autoApproved = false;
    String finalCategory = parsed.suggestedCategory ?? 'Other';
    String finalType = parsed.type;
    AppStateModel nextState = _state;
    String? ruleName = parsed.merchantRuleUsed;
    String? ruleSource = parsed.merchantRuleSource;

    final bool hasRule = parsed.merchantRuleSource != null;
    final MerchantRule? persistedRule = _state.merchantRules[merchantKey];
    if (persistedRule != null && persistedRule.enabled) {
      finalCategory = persistedRule.categoryId;
      finalType = persistedRule.defaultType;
    }

    if (_state.smartCaptureAutoApproveEnabled &&
        parsed.confidence >= 0.95 &&
        parsed.merchantName != null &&
        parsed.amount != null &&
        parsed.amount! > 0 &&
        finalType != 'transfer' &&
        hasRule &&
        (persistedRule?.enabled ?? true) &&
        (persistedRule?.autoApprove ?? true)) {
      autoApproved = true;
      if (persistedRule != null) {
        final finalRule = persistedRule;
        ruleName = finalRule.merchantName;

        final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
        nextRules[merchantKey] = finalRule.copyWith(
          usageCount: finalRule.usageCount + 1,
          lastUsed: timestampStr,
        );
        nextState = nextState.copyWith(merchantRules: nextRules);
      }
    }

    if (autoApproved) {
      nextAnalytics = nextAnalytics.copyWith(
        autoApprovedMessages: nextAnalytics.autoApprovedMessages + 1,
        capturedFromAppleShortcutsAutoApproved:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsAutoApproved + 1
            : nextAnalytics.capturedFromAppleShortcutsAutoApproved,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: auto_approved');
      }

      final Transaction newTx = Transaction(
        id: generatedId,
        type: finalType,
        date: timestampStr.substring(0, 10),
        amount: parsed.amount!,
        currency: parsed.currency?.trim().toUpperCase() ?? 'EGP',
        category: finalCategory,
        description: parsed.description,
        createdAt: timestampStr,
        rolledOver: false,
      );

      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: timestampStr,
        reviewedAt: timestampStr,
        suggestedType: finalType,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: finalCategory,
        confidence: parsed.confidence,
        status: CaptureStatus.autoApproved,
        approvalSource: ApprovalSource.auto,
        merchantRuleUsed: ruleName,
        merchantRuleSource: ruleSource,
        detectedBank: detectedBank,
        requiresReview: false,
        isRead: true,
        linkedTransactionId: generatedId,
      );

      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ...nextState.pendingTransactions,
        transaction,
      ];

      await updateState(
        nextState.copyWith(
          transactions: <Transaction>[...nextState.transactions, newTx],
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('auto_approved');
      }
    } else {
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: pending_review');
      }
      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: timestampStr,
        suggestedType: finalType,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: finalCategory,
        confidence: parsed.confidence,
        status: CaptureStatus.pendingReview,
        merchantRuleUsed: ruleName,
        merchantRuleSource: ruleSource,
        detectedBank: detectedBank,
        requiresReview: true,
        isRead: false,
      );
      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ...nextState.pendingTransactions,
        transaction,
      ];
      await updateState(
        nextState.copyWith(
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('pending_review');
      }
    }

    return true;
  }

  void _logShortcutStateSnapshot(String outcome) {
    debugPrint('[Shortcut] Flutter outcome: $outcome');
    debugPrint(
      '[Shortcut] AppState pending count after: ${_state.pendingTransactions.length}',
    );
    debugPrint(
      '[Shortcut] AppState transactions count after: ${_state.transactions.length}',
    );
    debugPrint(
      '[Shortcut] AppState captureAnalytics after: ${_state.captureAnalytics.toJson()}',
    );
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

  static String _formatShortcutAmount(double? amount) {
    if (amount == null) return 'null';
    final double rounded = amount.roundToDouble();
    return amount == rounded
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
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
    final String normalizedDate = date.trim().isEmpty
        ? DateTime.now().toUtc().toIso8601String().split('T').first
        : date.trim();
    if (kDebugMode) {
      print(
        '[ExchangeDebug][executeCurrencyExchange] date=$normalizedDate source=$sourceCurrency $sourceAmount target=$targetCurrency $targetAmount',
      );
    }
    final ReconciliationResult out = reconciliationService
        .executeCurrencyExchange(
          input: _state,
          date: normalizedDate,
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
    List<PendingTransaction>? pendingTransactions,
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
    String? userId,
    String? userEmail,
    String? userDisplayName,
    String? userPhotoUrl,
    String? userProvider,
    Map<String, dynamic>? aiSettings,
    bool? cloudHydrated,
    bool? hasUnsyncedAuthChanges,
    String? loadedUserId,
    bool? biometricLockEnabled,
    bool? biometricHideWealthEnabled,
    bool? biometricExportEnabled,
    bool? biometricRestoreEnabled,
    String? biometricAutoLockDelay,
    String? restorePromptDismissedUserId,
    Map<String, MerchantRule>? merchantRules,
    Map<String, String>? merchantAliases,
    CaptureAnalytics? captureAnalytics,
    List<CorrectionFeedback>? correctionFeedback,
    List<MerchantConfirmation>? merchantConfirmations,
    bool? smartCaptureEnabled,
    bool? smartCaptureAutoApproveEnabled,
  }) {
    return AppStateModel(
      transactions: transactions ?? this.transactions,
      savings: savings ?? this.savings,
      recurringTransactions:
          recurringTransactions ?? this.recurringTransactions,
      investments: investments ?? this.investments,
      financialPlans: financialPlans ?? this.financialPlans,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
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
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userProvider: userProvider ?? this.userProvider,
      aiSettings: aiSettings ?? this.aiSettings,
      cloudHydrated: cloudHydrated ?? this.cloudHydrated,
      hasUnsyncedAuthChanges:
          hasUnsyncedAuthChanges ?? this.hasUnsyncedAuthChanges,
      loadedUserId: loadedUserId ?? this.loadedUserId,
      restorePromptDismissedUserId:
          restorePromptDismissedUserId ?? this.restorePromptDismissedUserId,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      biometricHideWealthEnabled:
          biometricHideWealthEnabled ?? this.biometricHideWealthEnabled,
      biometricExportEnabled:
          biometricExportEnabled ?? this.biometricExportEnabled,
      biometricRestoreEnabled:
          biometricRestoreEnabled ?? this.biometricRestoreEnabled,
      biometricAutoLockDelay:
          biometricAutoLockDelay ?? this.biometricAutoLockDelay,
      merchantRules: merchantRules ?? this.merchantRules,
      merchantAliases: merchantAliases ?? this.merchantAliases,
      captureAnalytics: captureAnalytics ?? this.captureAnalytics,
      correctionFeedback: correctionFeedback ?? this.correctionFeedback,
      merchantConfirmations:
          merchantConfirmations ?? this.merchantConfirmations,
      smartCaptureEnabled: smartCaptureEnabled ?? this.smartCaptureEnabled,
      smartCaptureAutoApproveEnabled:
          smartCaptureAutoApproveEnabled ?? this.smartCaptureAutoApproveEnabled,
    );
  }
}
