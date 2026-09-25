import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    hide
        Transaction,
        Saving,
        Investment,
        RecurringTransaction,
        FinancialPlan,
        MerchantRule;
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _Gate implements UseSqliteLocalStoreProvider {
  _Gate(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory documentsDirectory = Directory.systemTemp.createTempSync(
    'zakatapp-domain-tests-',
  );
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  late AppStateRepository repository;
  late AppStateController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return documentsDirectory.path;
          }
          return null;
        });
    const LocalStorageService localStorage = LocalStorageService();
    repository = AppStateRepository(localStorage: localStorage);
    controller = AppStateController(repository: repository);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await documentsDirectory.delete(recursive: true);
  });

  test('loading empty state returns default AppState', () async {
    await controller.load();

    expect(controller.state.transactions, isEmpty);
    expect(controller.state.savings, isEmpty);
    expect(controller.state.mainCurrency, 'EGP');
    expect(controller.state.financialMonthCycle, 'calendar');
    expect(controller.state.financialMonthStartDay, 1);
    expect(controller.state.zakatMethod, 'hawl');
    expect(controller.state.zakatNisabBasis, 'gold85');
    expect(controller.state.categories.income, isNotEmpty);
  });

  test('save/load roundtrip', () async {
    await controller.load();

    final Transaction tx = Transaction(
      id: 't1',
      type: 'income',
      date: '2024-01-01',
      amount: 1000,
      currency: 'EGP',
      category: 'Salary',
      description: 'Salary',
      createdAt: '2024-01-01T00:00:00.000Z',
      rolledOver: false,
    );

    await controller.addTransaction(tx);

    final AppStateController reloaded = AppStateController(
      repository: repository,
    );
    await reloaded.load();

    expect(reloaded.state.transactions.length, 1);
    expect(reloaded.state.transactions.first.id, 't1');
  });

  test('financial month cycle setting persists', () async {
    await controller.load();

    await controller.updateFinancialMonthCycle('custom');
    await controller.updateFinancialMonthStartDay(25);

    final loaded = await repository.loadAppState();
    expect(loaded.financialMonthCycle, 'custom');
    expect(loaded.financialMonthStartDay, 25);
  });

  test('add transaction persists', () async {
    await controller.load();

    await controller.addTransaction(
      const Transaction(
        id: 'tx1',
        type: 'income',
        date: '2024-01-02',
        amount: 120,
        currency: 'EGP',
        category: 'Salary',
        description: 'Salary',
        createdAt: '2024-01-02T12:00:00.000Z',
        rolledOver: false,
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.transactions.length, 1);
    expect(loaded.transactions.first.category, 'Salary');
  });

  test('add saving persists', () async {
    await controller.load();

    await controller.addSaving(
      const Saving(
        id: 's1',
        assetType: 'cash',
        dateAcquired: '2024-01-03',
        amount: 500,
        remainingAmount: 500,
        unit: 'EGP',
        description: 'Reserve',
        linkedCashEntryId: null,
        purchaseCurrency: '',
        purchaseAmount: 0,
        createdAt: '2024-01-03T00:00:00.000Z',
        sourceIncomeId: null,
        exchangeSourceSavingId: null,
        exchangeSourceIncomeId: null,
        internalTransfer: null,
        internalTransferType: null,
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.savings.length, 1);
    expect(loaded.savings.first.assetType, 'cash');
  });

  test(
    'full local state survives restart with localization pinned to English',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const LocalStorageService storage = LocalStorageService();
      final AppStateRepository localRepository = AppStateRepository(
        localStorage: storage,
      );
      final String userId = 'locale-roundtrip-user';
      final AppDatabase activeDb = AppDatabase(userId: userId);
      final AppStateController activeController = AppStateController(
        repository: localRepository,
        database: activeDb,
        ownsDatabase: true,
        useSqliteLocalStoreProvider: _Gate(true),
      );

      await activeController.loadAuthenticated(userId);

      await activeController.addTransaction(
        const Transaction(
          id: 'tx-1',
          type: 'income',
          date: '2026-06-20',
          amount: 1000,
          currency: 'EGP',
          category: 'Salary',
          description: 'Salary',
          createdAt: '2026-06-20T08:00:00.000Z',
          rolledOver: false,
        ),
      );
      await activeController.addSaving(
        const Saving(
          id: 'sv-1',
          assetType: 'cash',
          dateAcquired: '2026-06-20',
          amount: 250,
          remainingAmount: 250,
          unit: 'EGP',
          description: 'Wallet cash',
          linkedCashEntryId: null,
          purchaseCurrency: 'EGP',
          purchaseAmount: 250,
          createdAt: '2026-06-20T08:10:00.000Z',
          sourceIncomeId: null,
          exchangeSourceSavingId: null,
          exchangeSourceIncomeId: null,
          internalTransfer: null,
          internalTransferType: null,
        ),
      );
      await activeController.addInvestment(
        const InvestmentAsset(
          id: 'inv-1',
          investmentType: 'real_estate',
          assetSubtype: 'apartment',
          ownershipType: 'fully_owned',
          valuationMode: 'market_value',
          currency: 'EGP',
          originalPrice: 100000,
          totalInterest: 0,
          totalPayable: 100000,
          paidAmount: 100000,
          remainingAmount: 0,
          installmentPlan: <Map<String, dynamic>>[],
          valuationDate: '2026-06-20',
          marketValue: 120000,
          marketValueDate: '2026-06-20',
          valuationSource: 'manual',
          loanBalance: 0,
          loanAsOfDate: '2026-06-20',
          paidAmountToDate: 100000,
          ownershipSharePct: 100,
          country: 'EG',
          location: 'Cairo',
          inflationRateAnnual: 0,
          estimatedCurrentValue: 120000,
          description: 'Flat',
          noZakat: true,
          createdAt: '2026-06-20T08:20:00.000Z',
        ),
      );
      await activeController.addRecurringTransaction(
        const RecurringTransaction(
          id: 'rec-1',
          name: 'Internet',
          type: 'expense',
          amount: 200,
          currency: 'EGP',
          category: 'Utilities',
          description: 'Monthly internet',
          dayOfMonth: 15,
          frequency: 'monthly',
          lastProcessed: '2026-05-15',
          enabled: true,
          skipMonth: '',
          createdAt: '2026-06-20T08:30:00.000Z',
        ),
      );
      await activeController.addFinancialPlan(
        const FinancialPlan(
          id: 'plan-1',
          name: 'House plan',
          startDate: '2026-06-01',
          projectionCurrency: 'EGP',
          startingBalance: 50000,
          startingBalanceDate: '2026-06-01',
          startingBalanceMode: 'manual',
          snapshotWealthCurrency: 'EGP',
          startingAssetBreakdown: <String, double>{'cash': 50000},
          monthlyIncome: 10000,
          monthlyExpenses: 5000,
          includeInstallments: true,
          includeZakat: true,
          durationYears: 3,
          createdAt: '2026-06-20T08:40:00.000Z',
          isActive: true,
          startingAssets: 50000,
          startingLiabilities: 0,
          startingNetWorth: 50000,
          startingNisabSnapshot: 0,
          startingGoldPriceSnapshot: 0,
          startingFxSnapshot: <String, double>{},
        ),
      );
      await activeController.createPendingTransaction(
        source: PendingTransactionSource.manual,
        rawMessage: 'Manual receipt',
        suggestedType: 'expense',
        confidence: 0.9,
        suggestedAmount: 42,
        suggestedCurrency: 'EGP',
        suggestedDescription: 'Lunch',
        merchantName: 'Cafe Nile',
        suggestedCategory: 'Groceries',
      );
      final String pendingId =
          activeController.state.pendingTransactions.single.id;
      await activeController.approvePendingTransaction(
        pendingId,
        type: 'expense',
        amount: 42,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'Lunch',
        date: '2026-06-20',
      );
      await activeController.saveCustomMerchantRule(
        const MerchantRule(
          merchantName: 'Carrefour',
          categoryId: 'Groceries',
          defaultType: 'expense',
          autoApprove: true,
          usageCount: 1,
          confidence: 0.95,
          source: 'custom',
          aliases: <String>['carrefour market'],
          enabled: true,
          isBuiltinOverride: false,
        ),
      );
      await activeController.updateLanguagePreference('en');

      await activeController.database!.close();

      final AppDatabase reopenedDb = AppDatabase(userId: userId);
      final AppStateController reopenedController = AppStateController(
        repository: localRepository,
        database: reopenedDb,
        ownsDatabase: true,
        useSqliteLocalStoreProvider: _Gate(true),
      );
      await reopenedController.loadAuthenticated(userId);

      expect(reopenedController.state.languagePreference, 'en');
      expect(reopenedController.state.transactions, hasLength(3));
      expect(reopenedController.state.savings, hasLength(1));
      expect(reopenedController.state.investments, hasLength(1));
      expect(reopenedController.state.recurringTransactions, hasLength(1));
      expect(reopenedController.state.financialPlans, hasLength(1));
      expect(reopenedController.state.pendingTransactions, hasLength(1));
      expect(reopenedController.state.merchantConfirmations, hasLength(2));
      expect(reopenedController.state.correctionFeedback, hasLength(1));
      expect(
        reopenedController.state.merchantRules.containsKey('carrefour'),
        isTrue,
      );
      expect(reopenedController.state.financialPlans.first.name, 'House plan');
      expect(reopenedController.state.savings.first.assetType, 'cash');

      await reopenedController.database!.close();
      await AppDatabase.deleteDatabaseFiles(userId: userId);
    },
  );

  test('add investment persists', () async {
    await controller.load();

    await controller.addInvestment(
      const InvestmentAsset(
        id: 'i1',
        investmentType: 'real_estate',
        assetSubtype: 'apartment',
        ownershipType: 'fully_owned',
        valuationMode: 'net_fair',
        currency: 'EGP',
        originalPrice: 100000,
        totalInterest: 0,
        totalPayable: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        installmentPlan: <Map<String, dynamic>>[],
        valuationDate: '2024-01-01',
        marketValue: 120000,
        marketValueDate: '2024-01-01',
        valuationSource: 'manual',
        loanBalance: 0,
        loanAsOfDate: '2024-01-01',
        paidAmountToDate: 100000,
        ownershipSharePct: 100,
        country: 'EG',
        location: 'Cairo',
        inflationRateAnnual: 10,
        estimatedCurrentValue: 120000,
        description: 'Investment',
        noZakat: true,
        createdAt: '2024-01-01T00:00:00.000Z',
      ),
    );

    final loaded = await repository.loadAppState();
    expect(loaded.investments.length, 1);
    expect(loaded.investments.first.id, 'i1');
  });

  test('clearLocalData works', () async {
    await controller.load();

    await controller.addTransaction(
      const Transaction(
        id: 'tx_to_clear',
        type: 'income',
        date: '2024-01-04',
        amount: 100,
        currency: 'EGP',
        category: 'Salary',
        description: 'Temp',
        createdAt: '2024-01-04T00:00:00.000Z',
        rolledOver: false,
      ),
    );

    await controller.clearLocalData();
    final loaded = await repository.loadAppState();

    expect(loaded.transactions, isEmpty);
    expect(loaded.mainCurrency, 'EGP');
  });

  test('update market data persists', () async {
    await controller.load();

    await controller.updateMarketSnapshot(
      const MarketSnapshot(
        gold24kPricePerGramEgp: 5300,
        silverPricePerGramEgp: 63,
        usdToEgp: 51,
        sarToEgp: 13.5,
        aedToEgp: 13.9,
        kwdToEgp: 165,
        qarToEgp: 14,
        eurToEgp: 55,
        gbpToEgp: 65,
        bhdToEgp: 135,
        omrToEgp: 132,
        jodToEgp: 72,
        tryToEgp: 1.5,
        myrToEgp: 11.5,
        pkrToEgp: 0.18,
        idrToEgp: 0.0032,
        lastUpdated: '2026-05-31T10:00:00Z',
      ),
    );

    final AppStateController reloaded = AppStateController(
      repository: repository,
    );
    await reloaded.load();
    final snapshot = reloaded.currentMarketSnapshot;

    expect(snapshot.gold24kPricePerGramEgp, 5300);
    expect(snapshot.silverPricePerGramEgp, 63);
    expect(snapshot.usdToEgp, 51);
    expect(snapshot.lastUpdated, '2026-05-31T10:00:00Z');
  });

  test('corrupted local app state JSON falls back to default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': '{invalid json',
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository badRepository = AppStateRepository(
      localStorage: localStorage,
    );
    final AppStateController badController = AppStateController(
      repository: badRepository,
    );

    await badController.load();

    expect(badController.state.transactions, isEmpty);
    expect(badController.state.mainCurrency, 'EGP');
  });

  test('incompatible shapes preserve valid fields where possible', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': '''
{
  "transactions": "bad",
  "savings": "bad",
  "recurringTransactions": 1,
  "investments": {},
  "financialPlans": "bad",
  "mainCurrency": "USD",
  "defaultEntryCurrency": "SAR",
  "zakatMethod": "annual",
  "marketData": "bad"
}
''',
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository mixedRepository = AppStateRepository(
      localStorage: localStorage,
    );
    final AppStateController mixedController = AppStateController(
      repository: mixedRepository,
    );

    await mixedController.load();

    expect(mixedController.state.transactions, isEmpty);
    expect(mixedController.state.savings, isEmpty);
    expect(mixedController.state.mainCurrency, 'USD');
    expect(mixedController.state.defaultEntryCurrency, 'SAR');
    expect(mixedController.state.zakatMethod, 'annual');
    expect(mixedController.currentMarketSnapshot.gold24kPricePerGramEgp, 0);
  });

  test(
    'authenticated load does not fall back to anonymous local data',
    skip: true,
    () async {
      const LocalStorageService localStorage = LocalStorageService();
      await localStorage.saveString(StorageKeys.appStateAnonymousKey, '''
{
  "transactions": [
    {
      "id": "anon_tx",
      "type": "income",
      "date": "2026-06-18",
      "amount": 100,
      "currency": "EGP",
      "category": "Salary",
      "description": "Anonymous",
      "createdAt": "2026-06-18T00:00:00.000Z",
      "rolledOver": false
    }
  ]
}
''');

      final AppStateRepository scopedRepository = AppStateRepository(
        localStorage: localStorage,
      );

      final authenticated = await scopedRepository.loadAppState(
        userId: 'different_user',
      );
      final anonymous = await scopedRepository.loadAppState();

      expect(authenticated.transactions, isEmpty);
      expect(anonymous.transactions.length, 1);
      expect(anonymous.transactions.first.id, 'anon_tx');
    },
  );

  test('clearLocalDataForSignOut preserves scoped and anonymous state', () async {
    final String scopedKey = StorageKeys.appStateKeyForUser('u_1')!;
    SharedPreferences.setMockInitialValues(<String, Object>{
      scopedKey: '{"transactions":[]}',
      StorageKeys.appStateAnonymousKey: '{"transactions":[]}',
    });

    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository scopedRepository = AppStateRepository(
      localStorage: localStorage,
    );
    final AppStateController scopedController = AppStateController(
      repository: scopedRepository,
    );

    await scopedController.loadAuthenticated('u_1');
    await scopedController.clearLocalDataForSignOut(userId: 'u_1');

    final String? scopedAfter = await localStorage.loadString(scopedKey);
    final String? anonymousAfter = await localStorage.loadString(
      StorageKeys.appStateAnonymousKey,
    );
    expect(scopedAfter, isNotNull);
    expect(anonymousAfter, isNotNull);
    expect(scopedController.state.transactions, isEmpty);
  });

  test('deleteLocalDataForUser preserves other accounts local state', () async {
    final String user1Key = StorageKeys.appStateKeyForUser('u_1')!;
    final String user2Key = StorageKeys.appStateKeyForUser('u_2')!;
    final String? profileKey = StorageKeys.userProfileKeyForUser('u_1');
    SharedPreferences.setMockInitialValues(<String, Object>{
      user1Key: '{"transactions":[{"id":"a1"}]}',
      user2Key: '{"transactions":[{"id":"b1"}]}',
      StorageKeys.appStateAnonymousKey: '{"transactions":[{"id":"anon"}]}',
      if (profileKey != null) profileKey: '{"id":"u_1"}',
      StorageKeys.aiKeysAnonymousKey: '["legacy-anon-key"]',
    });

    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository scopedRepository = AppStateRepository(
      localStorage: localStorage,
    );
    final AppStateController scopedController = AppStateController(
      repository: scopedRepository,
    );

    await scopedController.deleteLocalDataForUser(userId: 'u_1');

    final String? user1After = await localStorage.loadString(user1Key);
    final String? user2After = await localStorage.loadString(user2Key);
    final String? anonymousAfter = await localStorage.loadString(
      StorageKeys.appStateAnonymousKey,
    );
    final String? profileAfter = await localStorage.loadString(
      StorageKeys.userProfileKey,
    );
    final String? scopedProfileAfter = profileKey == null
        ? null
        : await localStorage.loadString(profileKey);
    final String? legacyAiAfter = await localStorage.loadString(
      StorageKeys.aiKeysAnonymousKey,
    );

    expect(user1After, isNull);
    expect(user2After, isNotNull);
    expect(anonymousAfter, isNull);
    expect(profileAfter, isNull);
    expect(scopedProfileAfter, isNull);
    expect(legacyAiAfter, isNull);
  });
}
