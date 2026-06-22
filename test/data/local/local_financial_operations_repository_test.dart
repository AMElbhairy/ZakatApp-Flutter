import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/savings_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/transactions_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_financial_operations_repository.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
import 'package:zakatapp_flutter/models/transaction.dart' as model;

void main() {
  late AppDatabase database;
  late TransactionsDao transactionsDao;
  late SavingsDao savingsDao;
  late SyncQueueDao syncQueueDao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    transactionsDao = TransactionsDao(database);
    savingsDao = SavingsDao(database);
    syncQueueDao = SyncQueueDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedExchangeActivity() async {
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'source-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-18',
        amount: 70,
        remainingAmount: 70,
        unit: 'USD',
        description: 'Source cash',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-18T08:00:00.000Z',
      ),
      updatedAt: '2026-06-18T08:00:00.000Z',
    );
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'target-saving',
        assetType: 'cash',
        dateAcquired: '2026-06-18',
        amount: 2500,
        remainingAmount: 2500,
        unit: 'EGP',
        description: 'Savings exchange: 30 USD → 2500 EGP',
        purchaseCurrency: 'EGP',
        purchaseAmount: 2500,
        createdAt: '2026-06-19T08:00:00.000Z',
        internalTransfer: true,
        internalTransferType: 'savings_currency_exchange',
        exchangeSourceSavingId: 'source-saving',
        transferActivityId: 'exch_1',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    await transactionsDao.upsertTransactionRow(
      const model.Transaction(
        id: 'exchange-income',
        type: 'income',
        date: '2026-06-19',
        amount: 2500,
        currency: 'EGP',
        category: 'Currency Exchange',
        description: 'Currency exchange in: 30 USD → 2500 EGP',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        exchangePairId: 'exch_1',
        activityType: 'transfer',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    await transactionsDao.upsertTransactionRow(
      const model.Transaction(
        id: 'exchange-expense',
        type: 'expense',
        date: '2026-06-19',
        amount: 10,
        currency: 'USD',
        category: 'Currency Exchange',
        description: 'Currency exchange out: 10 USD → EGP',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        exchangePairId: 'exch_1',
        activityType: 'transfer',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
  }

  Future<void> seedMetalSaleActivity({
    bool includeLinkedCashSaving = true,
  }) async {
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'gold-saving',
        assetType: 'gold',
        dateAcquired: '2026-06-10',
        amount: 100,
        remainingAmount: 97.5,
        unit: 'g',
        description: 'Gold holding',
        purchaseCurrency: 'USD',
        purchaseAmount: 7000,
        createdAt: '2026-06-10T08:00:00.000Z',
      ),
      updatedAt: '2026-06-18T08:00:00.000Z',
    );
    await transactionsDao.upsertTransactionRow(
      const model.Transaction(
        id: 'gold-sale-tx',
        type: 'transfer',
        date: '2026-06-19',
        amount: 250,
        currency: 'USD',
        category: 'Gold Sale',
        description: '2.50g Gold -> USD 250.00',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        activityType: 'transfer',
        exchangePairId: 'gold-saving',
        costBasis: 180,
        saleValue: 250,
        realizedGain: 70,
        realizedGainLossCurrency: 'USD',
        metalQuantity: 2.5,
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    if (includeLinkedCashSaving) {
      await savingsDao.upsertSavingRow(
        const model.Saving(
          id: 'cash-proceeds',
          assetType: 'cash',
          dateAcquired: '2026-06-19',
          amount: 250,
          remainingAmount: 250,
          unit: 'USD',
          description: 'Gold Sale proceeds',
          purchaseCurrency: 'USD',
          purchaseAmount: 250,
          createdAt: '2026-06-19T08:00:00.000Z',
          internalTransfer: true,
          internalTransferType: 'precious_metals_sale',
          transferActivityId: 'gold-sale-tx',
        ),
        updatedAt: '2026-06-19T08:00:00.000Z',
      );
    }
  }

  Future<void> seedInternalTransferActivity() async {
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'cash-source',
        assetType: 'cash',
        dateAcquired: '2026-06-10',
        amount: 80,
        remainingAmount: 80,
        unit: 'USD',
        description: 'Wallet cash',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-10T08:00:00.000Z',
      ),
      updatedAt: '2026-06-18T08:00:00.000Z',
    );
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'target-transfer',
        assetType: 'cash',
        dateAcquired: '2026-06-19',
        amount: 20,
        remainingAmount: 20,
        unit: 'USD',
        description: 'Internal transfer target',
        linkedCashEntryId: 'cash-source',
        purchaseCurrency: 'USD',
        purchaseAmount: 20,
        createdAt: '2026-06-19T08:00:00.000Z',
        internalTransfer: true,
        internalTransferType: 'cash_wallet_transfer',
        transferActivityId: 'transfer_1',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
    await transactionsDao.upsertTransactionRow(
      const model.Transaction(
        id: 'transfer_1',
        type: 'transfer',
        date: '2026-06-19',
        amount: 20,
        currency: 'USD',
        category: 'Cash Transfer',
        description: 'Internal transfer to wallet',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
        activityType: 'transfer',
      ),
      updatedAt: '2026-06-19T08:00:00.000Z',
    );
  }

  Future<void> seedCurrencyExchangeSourceSaving() async {
    await savingsDao.upsertSavingRow(
      const model.Saving(
        id: 'exchange-source',
        assetType: 'cash',
        dateAcquired: '2026-06-10',
        amount: 100,
        remainingAmount: 100,
        unit: 'USD',
        description: 'USD source cash',
        purchaseCurrency: 'USD',
        purchaseAmount: 100,
        createdAt: '2026-06-10T08:00:00.000Z',
      ),
      updatedAt: '2026-06-18T08:00:00.000Z',
    );
  }

  test('success updates all rows and returns active state', () async {
    await seedExchangeActivity();
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
    );

    final result = await repository.deleteCurrencyExchange('exch_1');
    final sourceRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('source-saving'))).getSingle();
    final targetRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('target-saving'))).getSingle();
    final txRows = await (database.select(
      database.transactions,
    )..where((tbl) => tbl.exchangePairId.equals('exch_1'))).get();

    expect(sourceRow.amountText, '100');
    expect(sourceRow.remainingAmountText, '100');
    expect(targetRow.deletedAt, isNotNull);
    expect(txRows.every((Transaction row) => row.deletedAt != null), isTrue);
    expect(result.transactions, isEmpty);
    expect(result.savings.map((model.Saving s) => s.id), <String>[
      'source-saving',
    ]);
  });

  test('queue contains exactly affected dedupe keys', () async {
    await seedExchangeActivity();
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
    );

    await repository.deleteCurrencyExchange('exch_1');
    final queue = await syncQueueDao.loadReadyBatch(limit: 10);
    final keys = queue.map((row) => row.dedupeKey).toSet();

    expect(keys, <String>{
      'transactions:exchange-income',
      'transactions:exchange-expense',
      'savings:target-saving',
      'savings:source-saving',
    });
    final sourceUpsert = queue.firstWhere(
      (row) => row.dedupeKey == 'savings:source-saving',
    );
    expect(sourceUpsert.operation, 'upsert');
    expect(jsonDecode(sourceUpsert.payloadJson!)['id'], 'source-saving');
  });

  test('failure rolls back all rows', () async {
    await seedExchangeActivity();
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
      enqueueSync:
          ({
            required String collectionName,
            required String recordId,
            required String operation,
            String? payloadJson,
            required String createdAt,
            required String availableAt,
            required String dedupeKey,
            int priority = 0,
            String? deviceId,
          }) async {
            throw StateError('queue failed');
          },
    );

    await expectLater(
      repository.deleteCurrencyExchange('exch_1'),
      throwsA(isA<StateError>()),
    );

    final sourceRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('source-saving'))).getSingle();
    final targetRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('target-saving'))).getSingle();
    final txRows = await (database.select(
      database.transactions,
    )..where((tbl) => tbl.exchangePairId.equals('exch_1'))).get();
    final queue = await syncQueueDao.loadReadyBatch(limit: 10);

    expect(sourceRow.amountText, '70');
    expect(sourceRow.remainingAmountText, '70');
    expect(targetRow.deletedAt, isNull);
    expect(txRows.every((Transaction row) => row.deletedAt == null), isTrue);
    expect(queue, isEmpty);
  });

  test(
    'deleteMetalSale restores metal remaining amount and tombstones linked rows',
    () async {
      await seedMetalSaleActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      final result = await repository.deleteMetalSale('gold-sale-tx');
      final metalRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('gold-saving'))).getSingle();
      final cashRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-proceeds'))).getSingle();
      final saleTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('gold-sale-tx'))).getSingle();

      expect(metalRow.remainingAmountText, '100');
      expect(saleTx.deletedAt, isNotNull);
      expect(cashRow.deletedAt, isNotNull);
      expect(result.transactions, isEmpty);
      expect(result.savings.map((model.Saving s) => s.id), <String>[
        'gold-saving',
      ]);
    },
  );

  test('deleteMetalSale queue has exact expected dedupe keys', () async {
    await seedMetalSaleActivity();
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
    );

    await repository.deleteMetalSale('gold-sale-tx');
    final queue = await syncQueueDao.loadReadyBatch(limit: 10);
    final keys = queue.map((row) => row.dedupeKey).toSet();

    expect(keys, <String>{
      'transactions:gold-sale-tx',
      'savings:gold-saving',
      'savings:cash-proceeds',
    });
    final metalUpsert = queue.firstWhere(
      (row) => row.dedupeKey == 'savings:gold-saving',
    );
    expect(metalUpsert.operation, 'upsert');
    expect(jsonDecode(metalUpsert.payloadJson!)['id'], 'gold-saving');
  });

  test('deleteMetalSale works without linked cash saving', () async {
    await seedMetalSaleActivity(includeLinkedCashSaving: false);
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
    );

    final result = await repository.deleteMetalSale('gold-sale-tx');
    final queue = await syncQueueDao.loadReadyBatch(limit: 10);

    expect(result.transactions, isEmpty);
    expect(result.savings.map((model.Saving s) => s.id), <String>[
      'gold-saving',
    ]);
    expect(queue.map((row) => row.dedupeKey).toSet(), <String>{
      'transactions:gold-sale-tx',
      'savings:gold-saving',
    });
  });

  test('deleteMetalSale failure rolls back rows and queue writes', () async {
    await seedMetalSaleActivity();
    final repository = LocalFinancialOperationsRepository(
      database: database,
      transactionsDao: transactionsDao,
      savingsDao: savingsDao,
      syncQueueDao: syncQueueDao,
      enqueueSync:
          ({
            required String collectionName,
            required String recordId,
            required String operation,
            String? payloadJson,
            required String createdAt,
            required String availableAt,
            required String dedupeKey,
            int priority = 0,
            String? deviceId,
          }) async {
            throw StateError('queue failed');
          },
    );

    await expectLater(
      repository.deleteMetalSale('gold-sale-tx'),
      throwsA(isA<StateError>()),
    );

    final metalRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('gold-saving'))).getSingle();
    final cashRow = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals('cash-proceeds'))).getSingle();
    final saleTx = await (database.select(
      database.transactions,
    )..where((tbl) => tbl.id.equals('gold-sale-tx'))).getSingle();
    final queue = await syncQueueDao.loadReadyBatch(limit: 10);

    expect(metalRow.remainingAmountText, '97.5');
    expect(saleTx.deletedAt, isNull);
    expect(cashRow.deletedAt, isNull);
    expect(queue, isEmpty);
  });

  test(
    'deleteInternalTransfer tombstones generated rows and restores source saving',
    () async {
      await seedInternalTransferActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      final result = await repository.deleteInternalTransfer('transfer_1');
      final sourceRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-source'))).getSingle();
      final targetRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('target-transfer'))).getSingle();
      final transferTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('transfer_1'))).getSingle();

      expect(sourceRow.amountText, '100');
      expect(sourceRow.remainingAmountText, '100');
      expect(targetRow.deletedAt, isNotNull);
      expect(transferTx.deletedAt, isNotNull);
      expect(result.transactions, isEmpty);
      expect(result.savings.map((model.Saving s) => s.id), <String>[
        'cash-source',
      ]);
    },
  );

  test(
    'deleteInternalTransfer queue contains exact affected dedupe keys',
    () async {
      await seedInternalTransferActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      await repository.deleteInternalTransfer('transfer_1');
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      final keys = queue.map((row) => row.dedupeKey).toSet();

      expect(keys, <String>{
        'savings:cash-source',
        'savings:target-transfer',
        'transactions:transfer_1',
      });
    },
  );

  test(
    'deleteInternalTransfer queue failure rolls back all row changes',
    () async {
      await seedInternalTransferActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
        enqueueSync:
            ({
              required String collectionName,
              required String recordId,
              required String operation,
              String? payloadJson,
              required String createdAt,
              required String availableAt,
              required String dedupeKey,
              int priority = 0,
              String? deviceId,
            }) async {
              throw StateError('queue failed');
            },
      );

      await expectLater(
        repository.deleteInternalTransfer('transfer_1'),
        throwsA(isA<StateError>()),
      );

      final sourceRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-source'))).getSingle();
      final targetRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('target-transfer'))).getSingle();
      final transferTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('transfer_1'))).getSingle();
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);

      expect(sourceRow.amountText, '80');
      expect(sourceRow.remainingAmountText, '80');
      expect(targetRow.deletedAt, isNull);
      expect(transferTx.deletedAt, isNull);
      expect(queue, isEmpty);
    },
  );

  test(
    'recordCurrencyExchange creates generated rows and reduces source balances',
    () async {
      await seedCurrencyExchangeSourceSaving();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      final result = await repository.recordCurrencyExchange(
        const CurrencyExchangeOperation(
          activityId: 'exch_new',
          sourceSavingId: 'exchange-source',
          sourceCurrency: 'USD',
          targetCurrency: 'EUR',
          sourceAmountText: '25',
          targetAmountText: '23',
          exchangeRateText: '0.92',
          date: '2026-06-19',
          description: 'USD to EUR exchange',
          generatedTransactionRows: <model.Transaction>[
            model.Transaction(
              id: 'exchange-out',
              type: 'expense',
              date: '2026-06-19',
              amount: 25,
              currency: 'USD',
              category: 'Currency Exchange',
              description: 'Currency exchange out: 25 USD -> 23 EUR',
              createdAt: '2026-06-19T08:00:00.000Z',
              rolledOver: false,
              exchangePairId: 'exch_new',
              activityType: 'transfer',
            ),
          ],
          generatedTargetSavingRows: <model.Saving>[
            model.Saving(
              id: 'exchange-target',
              assetType: 'cash',
              dateAcquired: '2026-06-19',
              amount: 23,
              remainingAmount: 23,
              unit: 'EUR',
              description: 'Savings exchange: 25 USD -> 23 EUR',
              purchaseCurrency: 'EUR',
              purchaseAmount: 23,
              createdAt: '2026-06-19T08:00:00.000Z',
              internalTransfer: true,
              internalTransferType: 'savings_currency_exchange',
              exchangeSourceSavingId: 'exchange-source',
              transferActivityId: 'exch_new',
            ),
          ],
        ),
      );

      final sourceRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-source'))).getSingle();
      final targetRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target'))).getSingle();
      final txRow = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('exchange-out'))).getSingle();

      expect(sourceRow.amountText, '75');
      expect(sourceRow.remainingAmountText, '75');
      expect(targetRow.deletedAt, isNull);
      expect(txRow.deletedAt, isNull);
      expect(
        result.transactions.map((model.Transaction row) => row.id),
        <String>['exchange-out'],
      );
      expect(result.savings.map((model.Saving row) => row.id), <String>[
        'exchange-target',
        'exchange-source',
      ]);
    },
  );

  test(
    'recordCurrencyExchange queue contains exact affected dedupe keys',
    () async {
      await seedCurrencyExchangeSourceSaving();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      await repository.recordCurrencyExchange(
        const CurrencyExchangeOperation(
          activityId: 'exch_new',
          sourceSavingId: 'exchange-source',
          sourceCurrency: 'USD',
          targetCurrency: 'EUR',
          sourceAmountText: '25',
          targetAmountText: '23',
          exchangeRateText: '0.92',
          date: '2026-06-19',
          description: 'USD to EUR exchange',
          generatedTransactionRows: <model.Transaction>[
            model.Transaction(
              id: 'exchange-out',
              type: 'expense',
              date: '2026-06-19',
              amount: 25,
              currency: 'USD',
              category: 'Currency Exchange',
              description: 'Currency exchange out: 25 USD -> 23 EUR',
              createdAt: '2026-06-19T08:00:00.000Z',
              rolledOver: false,
              exchangePairId: 'exch_new',
              activityType: 'transfer',
            ),
          ],
          generatedTargetSavingRows: <model.Saving>[
            model.Saving(
              id: 'exchange-target',
              assetType: 'cash',
              dateAcquired: '2026-06-19',
              amount: 23,
              remainingAmount: 23,
              unit: 'EUR',
              description: 'Savings exchange: 25 USD -> 23 EUR',
              purchaseCurrency: 'EUR',
              purchaseAmount: 23,
              createdAt: '2026-06-19T08:00:00.000Z',
              internalTransfer: true,
              internalTransferType: 'savings_currency_exchange',
              exchangeSourceSavingId: 'exchange-source',
              transferActivityId: 'exch_new',
            ),
          ],
        ),
      );

      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      expect(queue.map((row) => row.dedupeKey).toSet(), <String>{
        'savings:exchange-source',
        'transactions:exchange-out',
        'savings:exchange-target',
      });
    },
  );

  test(
    'recordCurrencyExchange insufficient source amount throws and rolls back',
    () async {
      await seedCurrencyExchangeSourceSaving();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      await expectLater(
        repository.recordCurrencyExchange(
          const CurrencyExchangeOperation(
            activityId: 'exch_new',
            sourceSavingId: 'exchange-source',
            sourceCurrency: 'USD',
            targetCurrency: 'EUR',
            sourceAmountText: '250',
            targetAmountText: '230',
            exchangeRateText: '0.92',
            date: '2026-06-19',
            description: 'USD to EUR exchange',
            generatedTransactionRows: <model.Transaction>[
              model.Transaction(
                id: 'exchange-out',
                type: 'expense',
                date: '2026-06-19',
                amount: 250,
                currency: 'USD',
                category: 'Currency Exchange',
                description: 'Currency exchange out: 250 USD -> 230 EUR',
                createdAt: '2026-06-19T08:00:00.000Z',
                rolledOver: false,
                exchangePairId: 'exch_new',
                activityType: 'transfer',
              ),
            ],
            generatedTargetSavingRows: <model.Saving>[
              model.Saving(
                id: 'exchange-target',
                assetType: 'cash',
                dateAcquired: '2026-06-19',
                amount: 230,
                remainingAmount: 230,
                unit: 'EUR',
                description: 'Savings exchange: 250 USD -> 230 EUR',
                purchaseCurrency: 'EUR',
                purchaseAmount: 230,
                createdAt: '2026-06-19T08:00:00.000Z',
                internalTransfer: true,
                internalTransferType: 'savings_currency_exchange',
                exchangeSourceSavingId: 'exchange-source',
                transferActivityId: 'exch_new',
              ),
            ],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final sourceRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-source'))).getSingle();
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      final txRows = await (database.select(database.transactions)).get();
      final targetRows = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target'))).get();

      expect(sourceRow.remainingAmountText, '100');
      expect(txRows, isEmpty);
      expect(targetRows, isEmpty);
      expect(queue, isEmpty);
    },
  );

  test(
    'recordCurrencyExchange queue failure rolls back all writes with no partial rows',
    () async {
      await seedCurrencyExchangeSourceSaving();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
        enqueueSync:
            ({
              required String collectionName,
              required String recordId,
              required String operation,
              String? payloadJson,
              required String createdAt,
              required String availableAt,
              required String dedupeKey,
              int priority = 0,
              String? deviceId,
            }) async {
              throw StateError('queue failed');
            },
      );

      await expectLater(
        repository.recordCurrencyExchange(
          const CurrencyExchangeOperation(
            activityId: 'exch_new',
            sourceSavingId: 'exchange-source',
            sourceCurrency: 'USD',
            targetCurrency: 'EUR',
            sourceAmountText: '25',
            targetAmountText: '23',
            exchangeRateText: '0.92',
            date: '2026-06-19',
            description: 'USD to EUR exchange',
            generatedTransactionRows: <model.Transaction>[
              model.Transaction(
                id: 'exchange-out',
                type: 'expense',
                date: '2026-06-19',
                amount: 25,
                currency: 'USD',
                category: 'Currency Exchange',
                description: 'Currency exchange out: 25 USD -> 23 EUR',
                createdAt: '2026-06-19T08:00:00.000Z',
                rolledOver: false,
                exchangePairId: 'exch_new',
                activityType: 'transfer',
              ),
            ],
            generatedTargetSavingRows: <model.Saving>[
              model.Saving(
                id: 'exchange-target',
                assetType: 'cash',
                dateAcquired: '2026-06-19',
                amount: 23,
                remainingAmount: 23,
                unit: 'EUR',
                description: 'Savings exchange: 25 USD -> 23 EUR',
                purchaseCurrency: 'EUR',
                purchaseAmount: 23,
                createdAt: '2026-06-19T08:00:00.000Z',
                internalTransfer: true,
                internalTransferType: 'savings_currency_exchange',
                exchangeSourceSavingId: 'exchange-source',
                transferActivityId: 'exch_new',
              ),
            ],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final sourceRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-source'))).getSingle();
      final txRows = await (database.select(database.transactions)).get();
      final targetRows = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target'))).get();
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);

      expect(sourceRow.remainingAmountText, '100');
      expect(txRows, isEmpty);
      expect(targetRows, isEmpty);
      expect(queue, isEmpty);
    },
  );

  test(
    'updateCurrencyExchange successfully deletes old and records new exchange',
    () async {
      await seedExchangeActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      final newOperation = const CurrencyExchangeOperation(
        activityId: 'exch_new',
        sourceSavingId: 'source-saving',
        sourceCurrency: 'USD',
        targetCurrency: 'EUR',
        sourceAmountText: '40',
        targetAmountText: '36',
        exchangeRateText: '0.9',
        date: '2026-06-19',
        description: 'Updated USD to EUR exchange',
        generatedTransactionRows: <model.Transaction>[
          model.Transaction(
            id: 'exchange-out-new',
            type: 'expense',
            date: '2026-06-19',
            amount: 40,
            currency: 'USD',
            category: 'Currency Exchange',
            description: 'Currency exchange out: 40 USD -> 36 EUR',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            exchangePairId: 'exch_new',
            activityType: 'transfer',
          ),
        ],
        generatedTargetSavingRows: <model.Saving>[
          model.Saving(
            id: 'exchange-target-new',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 36,
            remainingAmount: 36,
            unit: 'EUR',
            description: 'Savings exchange: 40 USD -> 36 EUR',
            purchaseCurrency: 'EUR',
            purchaseAmount: 36,
            createdAt: '2026-06-19T08:00:00.000Z',
            internalTransfer: true,
            internalTransferType: 'savings_currency_exchange',
            exchangeSourceSavingId: 'source-saving',
            transferActivityId: 'exch_new',
          ),
        ],
      );

      final result = await repository.updateCurrencyExchange(
        'exch_1',
        newOperation,
      );

      // Assert: Old exchange rows are deleted (have deletedAt set)
      final oldTargetSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('target-saving'))).getSingle();
      final oldTransactions = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.exchangePairId.equals('exch_1'))).get();

      expect(oldTargetSaving.deletedAt, isNotNull);
      expect(oldTransactions.every((tx) => tx.deletedAt != null), isTrue);

      // Assert: Old source saving is restored and then deducted by new amount (70 + 30 - 40 = 60)
      final sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('source-saving'))).getSingle();
      expect(sourceSaving.amountText, '60');
      expect(sourceSaving.remainingAmountText, '60');

      // Assert: New exchange rows are created
      final newTargetSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target-new'))).getSingle();
      final newTransaction = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('exchange-out-new'))).getSingle();

      expect(newTargetSaving.deletedAt, isNull);
      expect(newTransaction.deletedAt, isNull);

      // Assert: sync_queue contains final deduped affected keys
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      final keys = queue.map((row) => row.dedupeKey).toSet();

      expect(keys, <String>{
        'transactions:exchange-income',
        'transactions:exchange-expense',
        'savings:target-saving',
        'savings:source-saving',
        'transactions:exchange-out-new',
        'savings:exchange-target-new',
      });

      // Verify result active state
      expect(
        result.transactions.map((tx) => tx.id),
        contains('exchange-out-new'),
      );
      expect(
        result.transactions.map((tx) => tx.id),
        isNot(contains('exchange-income')),
      );
      expect(
        result.transactions.map((tx) => tx.id),
        isNot(contains('exchange-expense')),
      );
      expect(result.savings.map((s) => s.id), contains('exchange-target-new'));
      expect(result.savings.map((s) => s.id), isNot(contains('target-saving')));
    },
  );

  test(
    'updateCurrencyExchange rolls back everything on queue failure',
    () async {
      await seedExchangeActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
        enqueueSync:
            ({
              required String collectionName,
              required String recordId,
              required String operation,
              String? payloadJson,
              required String createdAt,
              required String availableAt,
              required String dedupeKey,
              int priority = 0,
              String? deviceId,
            }) async {
              // Fail on recording the new target saving
              if (recordId == 'exchange-target-new') {
                throw StateError('queue failed on new record');
              }
              return 1;
            },
      );

      final newOperation = const CurrencyExchangeOperation(
        activityId: 'exch_new',
        sourceSavingId: 'source-saving',
        sourceCurrency: 'USD',
        targetCurrency: 'EUR',
        sourceAmountText: '40',
        targetAmountText: '36',
        exchangeRateText: '0.9',
        date: '2026-06-19',
        description: 'Updated USD to EUR exchange',
        generatedTransactionRows: <model.Transaction>[
          model.Transaction(
            id: 'exchange-out-new',
            type: 'expense',
            date: '2026-06-19',
            amount: 40,
            currency: 'USD',
            category: 'Currency Exchange',
            description: 'Currency exchange out: 40 USD -> 36 EUR',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            exchangePairId: 'exch_new',
            activityType: 'transfer',
          ),
        ],
        generatedTargetSavingRows: <model.Saving>[
          model.Saving(
            id: 'exchange-target-new',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 36,
            remainingAmount: 36,
            unit: 'EUR',
            description: 'Savings exchange: 40 USD -> 36 EUR',
            purchaseCurrency: 'EUR',
            purchaseAmount: 36,
            createdAt: '2026-06-19T08:00:00.000Z',
            internalTransfer: true,
            internalTransferType: 'savings_currency_exchange',
            exchangeSourceSavingId: 'source-saving',
            transferActivityId: 'exch_new',
          ),
        ],
      );

      await expectLater(
        repository.updateCurrencyExchange('exch_1', newOperation),
        throwsA(isA<StateError>()),
      );

      // Verify database state: nothing was deleted, source-saving remains 70
      final sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('source-saving'))).getSingle();
      final oldTargetSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('target-saving'))).getSingle();
      final oldTransactions = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.exchangePairId.equals('exch_1'))).get();

      expect(sourceSaving.amountText, '70');
      expect(sourceSaving.remainingAmountText, '70');
      expect(oldTargetSaving.deletedAt, isNull);
      expect(oldTransactions.every((tx) => tx.deletedAt == null), isTrue);

      // Verify no new rows exist
      final newTargetSavings = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target-new'))).get();
      final newTransactions = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('exchange-out-new'))).get();
      expect(newTargetSavings, isEmpty);
      expect(newTransactions, isEmpty);

      // Queue should be empty because of transaction rollback
      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      expect(queue, isEmpty);
    },
  );

  test(
    'updateCurrencyExchange rolls back everything if new source amount is insufficient',
    () async {
      await seedExchangeActivity();
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      final newOperation = const CurrencyExchangeOperation(
        activityId: 'exch_new',
        sourceSavingId: 'source-saving',
        sourceCurrency: 'USD',
        targetCurrency: 'EUR',
        sourceAmountText: '110', // Exceeds the restored 100 balance
        targetAmountText: '99',
        exchangeRateText: '0.9',
        date: '2026-06-19',
        description: 'Updated USD to EUR exchange',
        generatedTransactionRows: <model.Transaction>[
          model.Transaction(
            id: 'exchange-out-new',
            type: 'expense',
            date: '2026-06-19',
            amount: 110,
            currency: 'USD',
            category: 'Currency Exchange',
            description: 'Currency exchange out: 110 USD -> 99 EUR',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            exchangePairId: 'exch_new',
            activityType: 'transfer',
          ),
        ],
        generatedTargetSavingRows: <model.Saving>[
          model.Saving(
            id: 'exchange-target-new',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 99,
            remainingAmount: 99,
            unit: 'EUR',
            description: 'Savings exchange: 110 USD -> 99 EUR',
            purchaseCurrency: 'EUR',
            purchaseAmount: 99,
            createdAt: '2026-06-19T08:00:00.000Z',
            internalTransfer: true,
            internalTransferType: 'savings_currency_exchange',
            exchangeSourceSavingId: 'source-saving',
            transferActivityId: 'exch_new',
          ),
        ],
      );

      await expectLater(
        repository.updateCurrencyExchange('exch_1', newOperation),
        throwsA(isA<StateError>()),
      );

      // Verify database state: nothing was deleted, source-saving remains 70
      final sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('source-saving'))).getSingle();
      final oldTargetSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('target-saving'))).getSingle();
      final oldTransactions = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.exchangePairId.equals('exch_1'))).get();

      expect(sourceSaving.amountText, '70');
      expect(sourceSaving.remainingAmountText, '70');
      expect(oldTargetSaving.deletedAt, isNull);
      expect(oldTransactions.every((tx) => tx.deletedAt == null), isTrue);

      // Verify no new rows exist
      final newTargetSavings = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('exchange-target-new'))).get();
      final newTransactions = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('exchange-out-new'))).get();
      expect(newTargetSavings, isEmpty);
      expect(newTransactions, isEmpty);
    },
  );

  test(
    'recordMetalSale creates generated rows and reduces metal remaining amount',
    () async {
      await seedMetalSaleActivity(includeLinkedCashSaving: false);
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      // Initial state: gold-saving (remaining: 97.5g)
      await repository.recordMetalSale(
        const MetalSaleOperation(
          transactionRow: model.Transaction(
            id: 'gold-sale-2',
            type: 'transfer',
            date: '2026-06-19',
            amount: 500,
            currency: 'USD',
            category: 'Gold Sale',
            description: '5.00g Gold -> USD 500.00',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            activityType: 'transfer',
            exchangePairId: 'gold-saving',
            metalQuantity: 5.0,
          ),
          generatedTargetSavingRow: model.Saving(
            id: 'cash-proceeds-2',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 500,
            remainingAmount: 500,
            unit: 'USD',
            description: 'Gold Sale proceeds',
            purchaseCurrency: 'USD',
            purchaseAmount: 500,
            createdAt: '2026-06-19T08:00:00.000Z',
            internalTransfer: true,
            internalTransferType: 'precious_metals_sale',
            transferActivityId: 'gold-sale-2',
          ),
        ),
      );

      final metalRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('gold-saving'))).getSingle();
      final saleTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('gold-sale-2'))).getSingle();
      final cashRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-proceeds-2'))).getSingle();

      expect(metalRow.remainingAmountText, '92.5'); // 97.5 - 5.0 = 92.5
      expect(saleTx.deletedAt, isNull);
      expect(cashRow.deletedAt, isNull);

      final queue = await syncQueueDao.loadReadyBatch(limit: 10);
      expect(
        queue.map((row) => row.dedupeKey).toSet(),
        containsAll([
          'savings:gold-saving',
          'transactions:gold-sale-2',
          'savings:cash-proceeds-2',
        ]),
      );
    },
  );

  test(
    'recordMetalSale insufficient remaining weight throws and rolls back',
    () async {
      await seedMetalSaleActivity(includeLinkedCashSaving: false);
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      await expectLater(
        repository.recordMetalSale(
          const MetalSaleOperation(
            transactionRow: model.Transaction(
              id: 'gold-sale-2',
              type: 'transfer',
              date: '2026-06-19',
              amount: 10000,
              currency: 'USD',
              category: 'Gold Sale',
              description: '100.00g Gold -> USD 10000.00', // exceeds 97.5g
              createdAt: '2026-06-19T08:00:00.000Z',
              rolledOver: false,
              activityType: 'transfer',
              exchangePairId: 'gold-saving',
              metalQuantity: 100.0,
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final metalRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('gold-saving'))).getSingle();
      final saleTxs = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('gold-sale-2'))).get();

      expect(metalRow.remainingAmountText, '97.5');
      expect(saleTxs, isEmpty);
    },
  );

  test(
    'updateMetalSale successfully restores old and applies new metal sale',
    () async {
      await seedMetalSaleActivity(); // Has gold-saving (remaining: 97.5g), sale: gold-sale-tx (2.5g), cash: cash-proceeds
      final repository = LocalFinancialOperationsRepository(
        database: database,
        transactionsDao: transactionsDao,
        savingsDao: savingsDao,
        syncQueueDao: syncQueueDao,
      );

      // Replaces 2.5g sale with a 5.0g sale
      await repository.updateMetalSale(
        'gold-sale-tx',
        const MetalSaleOperation(
          transactionRow: model.Transaction(
            id: 'gold-sale-new',
            type: 'transfer',
            date: '2026-06-19',
            amount: 500,
            currency: 'USD',
            category: 'Gold Sale',
            description: '5.00g Gold -> USD 500.00',
            createdAt: '2026-06-19T08:00:00.000Z',
            rolledOver: false,
            activityType: 'transfer',
            exchangePairId: 'gold-saving',
            metalQuantity: 5.0,
          ),
          generatedTargetSavingRow: model.Saving(
            id: 'cash-proceeds-new',
            assetType: 'cash',
            dateAcquired: '2026-06-19',
            amount: 500,
            remainingAmount: 500,
            unit: 'USD',
            description: 'Gold Sale proceeds',
            purchaseCurrency: 'USD',
            purchaseAmount: 500,
            createdAt: '2026-06-19T08:00:00.000Z',
            internalTransfer: true,
            internalTransferType: 'precious_metals_sale',
            transferActivityId: 'gold-sale-new',
          ),
        ),
      );

      // Old rows should be tombstones
      final oldTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('gold-sale-tx'))).getSingle();
      final oldCash = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-proceeds'))).getSingle();
      expect(oldTx.deletedAt, isNotNull);
      expect(oldCash.deletedAt, isNotNull);

      // Gold remaining: 97.5 + 2.5 (restored) - 5.0 (new deducted) = 95.0
      final metalRow = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('gold-saving'))).getSingle();
      expect(metalRow.remainingAmountText, '95');

      // New rows are active
      final newTx = await (database.select(
        database.transactions,
      )..where((tbl) => tbl.id.equals('gold-sale-new'))).getSingle();
      final newCash = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals('cash-proceeds-new'))).getSingle();
      expect(newTx.deletedAt, isNull);
      expect(newCash.deletedAt, isNull);
    },
  );
}
