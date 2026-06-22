import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../models/saving.dart' as model;
import '../../models/transaction.dart' as model;
import '../../services/sync_diagnostics_service.dart';
import '../local/app_database.dart';
import '../local/daos/savings_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/daos/transactions_dao.dart';
import '../local/mappers/savings_mapper.dart';

class CurrencyExchangeOperation {
  const CurrencyExchangeOperation({
    required this.activityId,
    this.sourceSavingId,
    this.sourceIncomeId,
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.sourceAmountText,
    required this.targetAmountText,
    required this.exchangeRateText,
    this.feeAmountText,
    required this.date,
    required this.description,
    required this.generatedTransactionRows,
    required this.generatedTargetSavingRows,
  });

  final String activityId;
  final String? sourceSavingId;
  final String? sourceIncomeId;
  final String sourceCurrency;
  final String targetCurrency;
  final String sourceAmountText;
  final String targetAmountText;
  final String exchangeRateText;
  final String? feeAmountText;
  final String date;
  final String description;
  final List<model.Transaction> generatedTransactionRows;
  final List<model.Saving> generatedTargetSavingRows;
}

class MetalSaleOperation {
  const MetalSaleOperation({
    required this.transactionRow,
    this.generatedTargetSavingRow,
  });

  final model.Transaction transactionRow;
  final model.Saving? generatedTargetSavingRow;
}

class FinancialOperationResult {
  const FinancialOperationResult({
    required this.transactions,
    required this.savings,
    required this.affectedTransactionIds,
    required this.affectedSavingIds,
  });

  final List<model.Transaction> transactions;
  final List<model.Saving> savings;
  final List<String> affectedTransactionIds;
  final List<String> affectedSavingIds;
}

abstract class FinancialOperationsLocalStore {
  Future<FinancialOperationResult> deleteCurrencyExchange(String activityId);
  Future<FinancialOperationResult> deleteMetalSale(String transactionId);
  Future<FinancialOperationResult> deleteInternalTransfer(String activityId);
  Future<FinancialOperationResult> recordCurrencyExchange(
    CurrencyExchangeOperation input,
  );
  Future<FinancialOperationResult> updateCurrencyExchange(
    String oldActivityId,
    CurrencyExchangeOperation newOperation,
  );
  Future<FinancialOperationResult> recordMetalSale(MetalSaleOperation input);
  Future<FinancialOperationResult> updateMetalSale(
    String oldTransactionId,
    MetalSaleOperation newOperation,
  );
}

typedef SyncQueueEnqueue =
    Future<int> Function({
      required String collectionName,
      required String recordId,
      required String operation,
      String? payloadJson,
      required String createdAt,
      required String availableAt,
      required String dedupeKey,
      int priority,
      String? deviceId,
    });

class LocalFinancialOperationsRepository
    implements FinancialOperationsLocalStore {
  factory LocalFinancialOperationsRepository({
    required AppDatabase database,
    TransactionsDao? transactionsDao,
    SavingsDao? savingsDao,
    SyncQueueDao? syncQueueDao,
    SavingsMapper? savingsMapper,
    SyncQueueEnqueue? enqueueSync,
  }) {
    return LocalFinancialOperationsRepository._(
      database,
      transactionsDao ?? TransactionsDao(database),
      savingsDao ?? SavingsDao(database),
      syncQueueDao ?? SyncQueueDao(database),
      savingsMapper ?? const SavingsMapper(),
      enqueueSync,
    );
  }

  LocalFinancialOperationsRepository._(
    this.database,
    this._transactionsDao,
    this._savingsDao,
    this._syncQueueDao,
    this._savingsMapper, [
    this._enqueueSync,
  ]);

  final AppDatabase database;
  final TransactionsDao _transactionsDao;
  final SavingsDao _savingsDao;
  final SyncQueueDao _syncQueueDao;
  final SavingsMapper _savingsMapper;
  final SyncQueueEnqueue? _enqueueSync;

  @override
  Future<FinancialOperationResult> deleteCurrencyExchange(
    String activityId,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _deleteCurrencyExchangeInTransaction(
        activityId,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: affectedTransactionIds,
      affectedSavingIds: affectedSavingIds,
    );
  }

  Future<void> _deleteCurrencyExchangeInTransaction(
    String activityId,
    List<String> affectedTransactionIds,
    List<String> affectedSavingIds,
  ) async {
    final List<Transaction> exchangeTransactions = await (database.select(
      database.transactions,
    )..where((tbl) => tbl.exchangePairId.equals(activityId))).get();
    final List<Saving> targetSavings = await (database.select(
      database.savings,
    )..where((tbl) => tbl.transferActivityId.equals(activityId))).get();

    final Map<String, String> restoredSavingRemaining = <String, String>{};
    final Map<String, String> restoredSavingAmount = <String, String>{};

    for (final Saving saving in targetSavings) {
      final String? sourceSavingId = saving.exchangeSourceSavingId;
      if (sourceSavingId == null || sourceSavingId.trim().isEmpty) continue;
      final Saving? sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingleOrNull();
      if (sourceSaving == null) continue;

      final String deductedText = _parseSavingsExchangeAmountText(
        saving.description,
      );
      final String nextRemaining = _addDecimalText(
        sourceSaving.remainingAmountText,
        deductedText,
      );
      final String nextAmount = _addDecimalText(
        sourceSaving.amountText,
        deductedText,
      );

      await (database.update(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).write(
        SavingsCompanion(
          amountText: Value<String>(nextAmount),
          remainingAmountText: Value<String>(nextRemaining),
          updatedAt: Value<String>(_timestampNow()),
        ),
      );

      restoredSavingAmount[sourceSavingId] = nextAmount;
      restoredSavingRemaining[sourceSavingId] = nextRemaining;
      if (!affectedSavingIds.contains(sourceSavingId)) {
        affectedSavingIds.add(sourceSavingId);
      }
    }

    final String deleteTimestamp = _timestampNow();
    for (final Transaction transaction in exchangeTransactions) {
      await (database.update(
        database.transactions,
      )..where((tbl) => tbl.id.equals(transaction.id))).write(
        TransactionsCompanion(
          deletedAt: Value<String>(deleteTimestamp),
          updatedAt: Value<String>(deleteTimestamp),
        ),
      );
      if (!affectedTransactionIds.contains(transaction.id)) {
        affectedTransactionIds.add(transaction.id);
      }
    }

    for (final Saving saving in targetSavings) {
      await (database.update(
        database.savings,
      )..where((tbl) => tbl.id.equals(saving.id))).write(
        SavingsCompanion(
          deletedAt: Value<String>(deleteTimestamp),
          updatedAt: Value<String>(deleteTimestamp),
        ),
      );
      if (!affectedSavingIds.contains(saving.id)) {
        affectedSavingIds.add(saving.id);
      }
    }

    for (final Transaction transaction in exchangeTransactions) {
      await _enqueue(
        collectionName: 'transactions',
        recordId: transaction.id,
        operation: 'delete',
        createdAt: deleteTimestamp,
        availableAt: deleteTimestamp,
        dedupeKey: 'transactions:${transaction.id}',
      );
    }

    for (final Saving saving in targetSavings) {
      await _enqueue(
        collectionName: 'savings',
        recordId: saving.id,
        operation: 'delete',
        createdAt: deleteTimestamp,
        availableAt: deleteTimestamp,
        dedupeKey: 'savings:${saving.id}',
      );
    }

    for (final String sourceSavingId in restoredSavingRemaining.keys) {
      final Saving? sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingleOrNull();
      if (sourceSaving == null) continue;
      final model.Saving payload = _savingsMapper.fromRow(sourceSaving);
      await _enqueue(
        collectionName: 'savings',
        recordId: sourceSavingId,
        operation: 'upsert',
        payloadJson: jsonEncode(payload.toJson()),
        createdAt: deleteTimestamp,
        availableAt: deleteTimestamp,
        dedupeKey: 'savings:$sourceSavingId',
      );
    }
  }

  @override
  Future<FinancialOperationResult> deleteMetalSale(String transactionId) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _deleteMetalSaleInTransaction(
        transactionId,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: affectedTransactionIds,
      affectedSavingIds: affectedSavingIds,
    );
  }

  Future<void> _deleteMetalSaleInTransaction(
    String transactionId,
    List<String> affectedTransactionIds,
    List<String> affectedSavingIds,
  ) async {
    final Transaction? saleTransaction = await (database.select(
      database.transactions,
    )..where((tbl) => tbl.id.equals(transactionId))).getSingleOrNull();
    if (saleTransaction == null) {
      throw StateError('Metal sale transaction not found: $transactionId');
    }

    final String? metalSavingId = saleTransaction.exchangePairId?.trim();
    if (metalSavingId == null || metalSavingId.isEmpty) {
      throw StateError(
        'Metal sale transaction $transactionId is missing exchangePairId.',
      );
    }

    final Saving? metalSaving = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).getSingleOrNull();
    if (metalSaving == null) {
      throw StateError('Metal saving not found: $metalSavingId');
    }

    final Saving? linkedCashSaving =
        await (database.select(database.savings)..where(
              (tbl) =>
                  tbl.transferActivityId.equals(transactionId) &
                  tbl.assetType.equals('cash'),
            ))
            .getSingleOrNull();

    final String restoredRemaining = _addDecimalText(
      metalSaving.remainingAmountText,
      _getMetalWeightFromRow(saleTransaction),
    );
    final String now = _timestampNow();

    await (database.update(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).write(
      SavingsCompanion(
        remainingAmountText: Value<String>(restoredRemaining),
        updatedAt: Value<String>(now),
      ),
    );
    if (!affectedSavingIds.contains(metalSavingId)) {
      affectedSavingIds.add(metalSavingId);
    }

    await (database.update(
      database.transactions,
    )..where((tbl) => tbl.id.equals(transactionId))).write(
      TransactionsCompanion(
        deletedAt: Value<String>(now),
        updatedAt: Value<String>(now),
      ),
    );
    if (!affectedTransactionIds.contains(transactionId)) {
      affectedTransactionIds.add(transactionId);
    }

    if (linkedCashSaving != null) {
      await (database.update(
        database.savings,
      )..where((tbl) => tbl.id.equals(linkedCashSaving.id))).write(
        SavingsCompanion(
          deletedAt: Value<String>(now),
          updatedAt: Value<String>(now),
        ),
      );
      if (!affectedSavingIds.contains(linkedCashSaving.id)) {
        affectedSavingIds.add(linkedCashSaving.id);
      }
    }

    await _enqueue(
      collectionName: 'transactions',
      recordId: transactionId,
      operation: 'delete',
      createdAt: now,
      availableAt: now,
      dedupeKey: 'transactions:$transactionId',
    );

    final Saving restoredMetalSaving = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).getSingle();
    await _enqueue(
      collectionName: 'savings',
      recordId: metalSavingId,
      operation: 'upsert',
      payloadJson: jsonEncode(
        _savingsMapper.fromRow(restoredMetalSaving).toFirestoreJson(),
      ),
      createdAt: now,
      availableAt: now,
      dedupeKey: 'savings:$metalSavingId',
    );

    if (linkedCashSaving != null) {
      await _enqueue(
        collectionName: 'savings',
        recordId: linkedCashSaving.id,
        operation: 'delete',
        createdAt: now,
        availableAt: now,
        dedupeKey: 'savings:${linkedCashSaving.id}',
      );
    }
  }

  @override
  Future<FinancialOperationResult> recordMetalSale(
    MetalSaleOperation input,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _recordMetalSaleInTransaction(
        input,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: affectedTransactionIds,
      affectedSavingIds: affectedSavingIds,
    );
  }

  Future<void> _recordMetalSaleInTransaction(
    MetalSaleOperation input,
    List<String> affectedTransactionIds,
    List<String> affectedSavingIds,
  ) async {
    final String now = _timestampNow();
    final String? metalSavingId = input.transactionRow.exchangePairId?.trim();
    if (metalSavingId == null || metalSavingId.isEmpty) {
      throw StateError('Metal sale transaction is missing exchangePairId.');
    }

    final Saving? metalSaving = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).getSingleOrNull();
    if (metalSaving == null) {
      throw StateError('Metal saving not found: $metalSavingId');
    }

    final String soldWeightText = input.transactionRow.metalQuantity != null
        ? _decimalText(input.transactionRow.metalQuantity!)
        : _parseMetalWeightText(input.transactionRow.description);
    if (_compareDecimalText(metalSaving.remainingAmountText, soldWeightText) <
        0) {
      throw StateError('Metal saving has insufficient remaining weight.');
    }

    final String nextRemaining = _subtractDecimalText(
      metalSaving.remainingAmountText,
      soldWeightText,
    );

    await (database.update(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).write(
      SavingsCompanion(
        remainingAmountText: Value<String>(nextRemaining),
        updatedAt: Value<String>(now),
      ),
    );
    if (!affectedSavingIds.contains(metalSavingId)) {
      affectedSavingIds.add(metalSavingId);
    }

    await _transactionsDao.upsertTransactionRow(
      input.transactionRow,
      updatedAt: now,
    );
    if (!affectedTransactionIds.contains(input.transactionRow.id)) {
      affectedTransactionIds.add(input.transactionRow.id);
    }

    if (input.generatedTargetSavingRow != null) {
      await _savingsDao.upsertSavingRow(
        input.generatedTargetSavingRow!,
        updatedAt: now,
      );
      if (!affectedSavingIds.contains(input.generatedTargetSavingRow!.id)) {
        affectedSavingIds.add(input.generatedTargetSavingRow!.id);
      }
    }

    final Saving updatedMetalSaving = await (database.select(
      database.savings,
    )..where((tbl) => tbl.id.equals(metalSavingId))).getSingle();
    await _enqueue(
      collectionName: 'savings',
      recordId: metalSavingId,
      operation: 'upsert',
      payloadJson: jsonEncode(
        _savingsMapper.fromRow(updatedMetalSaving).toFirestoreJson(),
      ),
      createdAt: now,
      availableAt: now,
      dedupeKey: 'savings:$metalSavingId',
    );

    await _enqueue(
      collectionName: 'transactions',
      recordId: input.transactionRow.id,
      operation: 'upsert',
      payloadJson: jsonEncode(input.transactionRow.toJson()),
      createdAt: now,
      availableAt: now,
      dedupeKey: 'transactions:${input.transactionRow.id}',
    );

    if (input.generatedTargetSavingRow != null) {
      await _enqueue(
        collectionName: 'savings',
        recordId: input.generatedTargetSavingRow!.id,
        operation: 'upsert',
        payloadJson: jsonEncode(
          input.generatedTargetSavingRow!.toFirestoreJson(),
        ),
        createdAt: now,
        availableAt: now,
        dedupeKey: 'savings:${input.generatedTargetSavingRow!.id}',
      );
    }
  }

  @override
  Future<FinancialOperationResult> updateMetalSale(
    String oldTransactionId,
    MetalSaleOperation newOperation,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _deleteMetalSaleInTransaction(
        oldTransactionId,
        affectedTransactionIds,
        affectedSavingIds,
      );
      await _recordMetalSaleInTransaction(
        newOperation,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    final List<String> uniqueTransactionIds = affectedTransactionIds
        .toSet()
        .toList();
    final List<String> uniqueSavingIds = affectedSavingIds.toSet().toList();

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: uniqueTransactionIds,
      affectedSavingIds: uniqueSavingIds,
    );
  }

  @override
  Future<FinancialOperationResult> deleteInternalTransfer(
    String activityId,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      final List<Saving> targetSavings = await (database.select(
        database.savings,
      )..where((tbl) => tbl.transferActivityId.equals(activityId))).get();
      final List<Transaction> linkedTransactions =
          await (database.select(database.transactions)..where(
                (tbl) =>
                    tbl.exchangePairId.equals(activityId) |
                    tbl.id.equals(activityId),
              ))
              .get();

      final Map<String, String> restoredAmounts = <String, String>{};
      final Map<String, String> restoredRemainingAmounts = <String, String>{};

      for (final Saving targetSaving in targetSavings) {
        final String? sourceSavingId = targetSaving.linkedCashEntryId?.trim();
        if (sourceSavingId == null || sourceSavingId.isEmpty) continue;
        final Saving? sourceSaving = await (database.select(
          database.savings,
        )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingleOrNull();
        if (sourceSaving == null) continue;

        final String nextAmount = _addDecimalText(
          sourceSaving.amountText,
          targetSaving.amountText,
        );
        final String nextRemaining = _addDecimalText(
          sourceSaving.remainingAmountText,
          targetSaving.remainingAmountText,
        );

        await (database.update(
          database.savings,
        )..where((tbl) => tbl.id.equals(sourceSavingId))).write(
          SavingsCompanion(
            amountText: Value<String>(nextAmount),
            remainingAmountText: Value<String>(nextRemaining),
            updatedAt: Value<String>(_timestampNow()),
          ),
        );

        restoredAmounts[sourceSavingId] = nextAmount;
        restoredRemainingAmounts[sourceSavingId] = nextRemaining;
        if (!affectedSavingIds.contains(sourceSavingId)) {
          affectedSavingIds.add(sourceSavingId);
        }
      }

      final String deleteTimestamp = _timestampNow();
      for (final Saving targetSaving in targetSavings) {
        await (database.update(
          database.savings,
        )..where((tbl) => tbl.id.equals(targetSaving.id))).write(
          SavingsCompanion(
            deletedAt: Value<String>(deleteTimestamp),
            updatedAt: Value<String>(deleteTimestamp),
          ),
        );
        if (!affectedSavingIds.contains(targetSaving.id)) {
          affectedSavingIds.add(targetSaving.id);
        }
      }

      for (final Transaction transaction in linkedTransactions) {
        await (database.update(
          database.transactions,
        )..where((tbl) => tbl.id.equals(transaction.id))).write(
          TransactionsCompanion(
            deletedAt: Value<String>(deleteTimestamp),
            updatedAt: Value<String>(deleteTimestamp),
          ),
        );
        affectedTransactionIds.add(transaction.id);
      }

      for (final Saving targetSaving in targetSavings) {
        await _enqueue(
          collectionName: 'savings',
          recordId: targetSaving.id,
          operation: 'delete',
          createdAt: deleteTimestamp,
          availableAt: deleteTimestamp,
          dedupeKey: 'savings:${targetSaving.id}',
        );
      }

      for (final Transaction transaction in linkedTransactions) {
        await _enqueue(
          collectionName: 'transactions',
          recordId: transaction.id,
          operation: 'delete',
          createdAt: deleteTimestamp,
          availableAt: deleteTimestamp,
          dedupeKey: 'transactions:${transaction.id}',
        );
      }

      for (final String sourceSavingId in restoredAmounts.keys) {
        final Saving? sourceSaving = await (database.select(
          database.savings,
        )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingleOrNull();
        if (sourceSaving == null) continue;
        await _enqueue(
          collectionName: 'savings',
          recordId: sourceSavingId,
          operation: 'upsert',
          payloadJson: jsonEncode(
            _savingsMapper.fromRow(sourceSaving).toFirestoreJson(),
          ),
          createdAt: deleteTimestamp,
          availableAt: deleteTimestamp,
          dedupeKey: 'savings:$sourceSavingId',
        );
      }
    });

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: affectedTransactionIds,
      affectedSavingIds: affectedSavingIds,
    );
  }

  @override
  Future<FinancialOperationResult> recordCurrencyExchange(
    CurrencyExchangeOperation input,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _recordCurrencyExchangeInTransaction(
        input,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: affectedTransactionIds,
      affectedSavingIds: affectedSavingIds,
    );
  }

  Future<void> _recordCurrencyExchangeInTransaction(
    CurrencyExchangeOperation input,
    List<String> affectedTransactionIds,
    List<String> affectedSavingIds,
  ) async {
    final String now = _timestampNow();
    Saving? sourceSaving;
    final String? sourceSavingId = input.sourceSavingId?.trim();
    if (sourceSavingId != null && sourceSavingId.isNotEmpty) {
      sourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingleOrNull();
      if (sourceSaving == null) {
        throw StateError(
          'Currency exchange source saving not found: $sourceSavingId',
        );
      }
      if (_compareDecimalText(
            sourceSaving.remainingAmountText,
            input.sourceAmountText,
          ) <
          0) {
        throw StateError(
          'Currency exchange source saving has insufficient remaining amount.',
        );
      }

      final String nextRemaining = _subtractDecimalText(
        sourceSaving.remainingAmountText,
        input.sourceAmountText,
      );
      final String nextAmount = _subtractDecimalText(
        sourceSaving.amountText,
        input.sourceAmountText,
      );
      await (database.update(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).write(
        SavingsCompanion(
          amountText: Value<String>(nextAmount),
          remainingAmountText: Value<String>(nextRemaining),
          updatedAt: Value<String>(now),
        ),
      );
      if (!affectedSavingIds.contains(sourceSavingId)) {
        affectedSavingIds.add(sourceSavingId);
      }
    }

    await _transactionsDao.upsertTransactionRows(
      input.generatedTransactionRows,
      updatedAt: now,
    );
    await _savingsDao.upsertSavingRows(
      input.generatedTargetSavingRows,
      updatedAt: now,
    );

    for (final row in input.generatedTransactionRows) {
      if (!affectedTransactionIds.contains(row.id)) {
        affectedTransactionIds.add(row.id);
      }
    }
    for (final row in input.generatedTargetSavingRows) {
      if (!affectedSavingIds.contains(row.id)) {
        affectedSavingIds.add(row.id);
      }
    }

    if (sourceSavingId != null && sourceSavingId.isNotEmpty) {
      final Saving updatedSourceSaving = await (database.select(
        database.savings,
      )..where((tbl) => tbl.id.equals(sourceSavingId))).getSingle();
      await _enqueue(
        collectionName: 'savings',
        recordId: sourceSavingId,
        operation: 'upsert',
        payloadJson: jsonEncode(
          _savingsMapper.fromRow(updatedSourceSaving).toFirestoreJson(),
        ),
        createdAt: now,
        availableAt: now,
        dedupeKey: 'savings:$sourceSavingId',
      );
    }

    for (final model.Transaction row in input.generatedTransactionRows) {
      await _enqueue(
        collectionName: 'transactions',
        recordId: row.id,
        operation: 'upsert',
        payloadJson: jsonEncode(row.toJson()),
        createdAt: now,
        availableAt: now,
        dedupeKey: 'transactions:${row.id}',
      );
    }

    for (final model.Saving row in input.generatedTargetSavingRows) {
      await _enqueue(
        collectionName: 'savings',
        recordId: row.id,
        operation: 'upsert',
        payloadJson: jsonEncode(row.toFirestoreJson()),
        createdAt: now,
        availableAt: now,
        dedupeKey: 'savings:${row.id}',
      );
    }
  }

  @override
  Future<FinancialOperationResult> updateCurrencyExchange(
    String oldActivityId,
    CurrencyExchangeOperation newOperation,
  ) async {
    final List<String> affectedTransactionIds = <String>[];
    final List<String> affectedSavingIds = <String>[];

    await database.transaction(() async {
      await _deleteCurrencyExchangeInTransaction(
        oldActivityId,
        affectedTransactionIds,
        affectedSavingIds,
      );
      await _recordCurrencyExchangeInTransaction(
        newOperation,
        affectedTransactionIds,
        affectedSavingIds,
      );
    });

    final List<String> uniqueTransactionIds = affectedTransactionIds
        .toSet()
        .toList();
    final List<String> uniqueSavingIds = affectedSavingIds.toSet().toList();

    return FinancialOperationResult(
      transactions: await _transactionsDao.getActiveTransactions(),
      savings: await _savingsDao.getActiveSavings(),
      affectedTransactionIds: uniqueTransactionIds,
      affectedSavingIds: uniqueSavingIds,
    );
  }

  Future<int> _enqueue({
    required String collectionName,
    required String recordId,
    required String operation,
    String? payloadJson,
    required String createdAt,
    required String availableAt,
    required String dedupeKey,
  }) {
    final SyncQueueEnqueue enqueue = _enqueueSync ?? _syncQueueDao.enqueue;
    return enqueue(
      collectionName: collectionName,
      recordId: recordId,
      operation: operation,
      payloadJson: payloadJson,
      createdAt: createdAt,
      availableAt: availableAt,
      dedupeKey: dedupeKey,
      priority: 0,
      deviceId: null,
    ).then((int queueId) async {
      _logQueueInsert(
        entityType: collectionName,
        entityId: recordId,
        assetType: _extractAssetType(payloadJson),
        queueId: queueId,
        payloadJson: payloadJson,
      );
      if (collectionName == 'savings') {
        await SyncDiagnosticsService.recordSavingsQueueInsert(
          entityId: recordId,
          assetType: _extractAssetType(payloadJson) ?? 'delete',
          queueId: queueId,
          payloadJson: payloadJson,
        );
      }
      return queueId;
    });
  }

  void _logQueueInsert({
    required String entityType,
    required String entityId,
    required String? assetType,
    required int queueId,
    required String? payloadJson,
  }) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print(
      '[SYNC_QUEUE] entityType=$entityType entityId=$entityId assetType=${assetType ?? ''} queueId=$queueId payload=${payloadJson ?? 'null'}',
    );
  }

  String? _extractAssetType(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        final String assetType = (decoded['assetType'] ?? '').toString().trim();
        return assetType.isEmpty ? null : assetType;
      }
    } catch (_) {}
    return null;
  }

  String _timestampNow() => DateTime.now().toUtc().toIso8601String();
  String _parseSavingsExchangeAmountText(String description) {
    final Match? match = RegExp(
      r'Savings exchange:\s*([0-9.]+)\s',
    ).firstMatch(description);
    return match?.group(1) ?? '0';
  }

  String _parseMetalWeightText(String description) {
    final Match? match = RegExp(r'([0-9.]+)\s*g').firstMatch(description);
    return match?.group(1) ?? '0';
  }

  String _addDecimalText(String left, String right) {
    final double sum =
        (double.tryParse(left) ?? 0) + (double.tryParse(right) ?? 0);
    final String raw = sum.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) {
      return raw;
    }
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _subtractDecimalText(String left, String right) {
    final double difference =
        (double.tryParse(left) ?? 0) - (double.tryParse(right) ?? 0);
    final String raw = difference.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) {
      return raw;
    }
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  int _compareDecimalText(String left, String right) {
    final double leftValue = double.tryParse(left) ?? 0;
    final double rightValue = double.tryParse(right) ?? 0;
    if (leftValue < rightValue) return -1;
    if (leftValue > rightValue) return 1;
    return 0;
  }

  String _getMetalWeightFromRow(Transaction tx) {
    if (tx.metalQuantityText != null && tx.metalQuantityText!.isNotEmpty) {
      return tx.metalQuantityText!;
    }
    return _parseMetalWeightText(tx.description);
  }

  String _decimalText(num value) {
    if (value is int) return value.toString();
    final String raw = value.toString();
    if (!raw.contains('.') || raw.contains('e') || raw.contains('E')) {
      return raw;
    }
    return raw.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
