import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/data/repositories/local_savings_repository.dart';
import 'package:zakatapp_flutter/data/repositories/local_transactions_repository.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _StaticGate implements UseSqliteLocalStoreProvider {
  _StaticGate(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

class _MutableTransactionsStore implements TransactionsLocalStore {
  _MutableTransactionsStore(this.transactions);

  final List<model.Transaction> transactions;

  @override
  Future<void> deleteTransaction(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    transactions.removeWhere((model.Transaction tx) => tx.id == id);
  }

  @override
  Future<List<model.Transaction>> getActiveTransactions() async =>
      List<model.Transaction>.from(transactions);

  @override
  Future<void> replaceAllForLocalMirror(
    Iterable<model.Transaction> next,
  ) async {
    transactions
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> saveTransaction(
    model.Transaction transaction, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    transactions.removeWhere((model.Transaction tx) => tx.id == transaction.id);
    transactions.add(transaction);
  }

  @override
  Stream<List<model.Transaction>> watchActiveTransactions() async* {
    yield List<model.Transaction>.from(transactions);
  }
}

class _MutableSavingsStore implements SavingsLocalStore {
  _MutableSavingsStore(this.savings);

  final List<model.Saving> savings;

  @override
  Future<void> deleteSaving(
    String id, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    savings.removeWhere((model.Saving saving) => saving.id == id);
  }

  @override
  Future<List<model.Saving>> getActiveSavings() async =>
      List<model.Saving>.from(savings);

  @override
  Future<void> replaceAllForLocalMirror(Iterable<model.Saving> next) async {
    savings
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> saveSaving(
    model.Saving saving, {
    String? now,
    int priority = 0,
    String? deviceId,
  }) async {
    savings.removeWhere((model.Saving entry) => entry.id == saving.id);
    savings.add(saving);
  }

  @override
  Stream<List<model.Saving>> watchActiveSavings() async* {
    yield List<model.Saving>.from(savings);
  }
}

Future<AppStateController> _makeController({
  required List<model.Transaction> transactions,
  required List<model.Saving> savings,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppStateController controller = AppStateController(
    repository: AppStateRepository(localStorage: const LocalStorageService()),
    localTransactionsRepository: _MutableTransactionsStore(transactions),
    localSavingsRepository: _MutableSavingsStore(savings),
    useSqliteLocalStoreProvider: _StaticGate(true),
  );
  await controller.load();
  return controller;
}

model.Transaction _income({
  required String id,
  required double amount,
  String date = '2026-06-19',
}) {
  return model.Transaction(
    id: id,
    type: 'income',
    date: date,
    amount: amount,
    currency: 'USD',
    category: 'Salary',
    description: 'Salary',
    createdAt: '${date}T08:00:00.000Z',
    rolledOver: false,
  );
}

model.Transaction _expense({
  required String id,
  required double amount,
  String date = '2026-06-19',
}) {
  return model.Transaction(
    id: id,
    type: 'expense',
    date: date,
    amount: amount,
    currency: 'USD',
    category: 'Food',
    description: 'Lunch',
    createdAt: '${date}T09:00:00.000Z',
    rolledOver: false,
  );
}

model.Saving _cashSaving({
  required String id,
  required double amount,
  required double remainingAmount,
  String date = '2026-06-18',
}) {
  return model.Saving(
    id: id,
    assetType: 'cash',
    dateAcquired: date,
    amount: amount,
    remainingAmount: remainingAmount,
    unit: 'USD',
    description: 'Wallet cash',
    purchaseCurrency: 'USD',
    purchaseAmount: amount,
    createdAt: '${date}T08:00:00.000Z',
  );
}

void main() {
  test(
    'SQLite expense deduction pulls from income then source saving',
    () async {
      final controller = await _makeController(
        transactions: <model.Transaction>[_income(id: 'income-1', amount: 100)],
        savings: <model.Saving>[
          _cashSaving(id: 'cash-source', amount: 50, remainingAmount: 50),
        ],
      );

      await controller.addTransaction(_expense(id: 'expense-1', amount: 130));

      expect(controller.state.transactions, hasLength(2));
      expect(controller.state.savings.single.remainingAmount, 20);
      expect(controller.getAvailableBalance(currency: 'USD'), 20);
    },
  );

  test('SQLite edit expense recalculates deduction correctly', () async {
    final controller = await _makeController(
      transactions: <model.Transaction>[_income(id: 'income-1', amount: 100)],
      savings: <model.Saving>[
        _cashSaving(id: 'cash-source', amount: 50, remainingAmount: 50),
      ],
    );

    await controller.addTransaction(_expense(id: 'expense-1', amount: 130));
    await controller.updateTransaction(_expense(id: 'expense-1', amount: 80));

    expect(controller.state.savings.single.remainingAmount, 50);
    expect(controller.getAvailableBalance(currency: 'USD'), 70);
  });

  test('SQLite delete expense restores source amount', () async {
    final controller = await _makeController(
      transactions: <model.Transaction>[_income(id: 'income-1', amount: 100)],
      savings: <model.Saving>[
        _cashSaving(id: 'cash-source', amount: 50, remainingAmount: 50),
      ],
    );

    await controller.addTransaction(_expense(id: 'expense-1', amount: 130));
    await controller.deleteTransaction('expense-1');

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'income-1');
    expect(controller.state.savings.single.remainingAmount, 50);
    expect(controller.getAvailableBalance(currency: 'USD'), 150);
  });

  test(
    'SQLite blocks expense entry when the selected currency has no balance',
    () async {
      final controller = await _makeController(
        transactions: const <model.Transaction>[],
        savings: const <model.Saving>[],
      );

      await controller.addTransaction(_expense(id: 'expense-1', amount: 25));

      expect(controller.state.transactions, isEmpty);
    },
  );

  test('SQLite pending approval creates one final transaction', () async {
    final controller = await _makeController(
      transactions: <model.Transaction>[_income(id: 'income-1', amount: 100)],
      savings: <model.Saving>[
        _cashSaving(id: 'cash-source', amount: 50, remainingAmount: 50),
      ],
    );

    final PendingTransaction pending = PendingTransaction(
      id: 'pending-1',
      source: 'sms',
      rawMessage: 'Lunch',
      createdAt: '2026-06-19T10:00:00.000Z',
      suggestedType: 'expense',
      suggestedAmount: 130,
      suggestedCurrency: 'USD',
      suggestedDescription: 'Lunch',
      merchantName: 'Cafe',
      suggestedCategory: 'Food',
      confidence: 0.98,
      status: CaptureStatus.pendingReview,
      requiresReview: true,
      isRead: false,
    );

    await controller.updateState(
      controller.state.copyWith(
        pendingTransactions: <PendingTransaction>[pending],
      ),
    );

    final int beforeTransactionCount = controller.state.transactions.length;

    await controller.approvePendingTransaction(
      'pending-1',
      type: 'expense',
      amount: 130,
      currency: 'USD',
      category: 'Food',
      description: 'Lunch',
      date: '2026-06-19',
    );

    final PendingTransaction updatedPending = controller
        .state
        .pendingTransactions
        .singleWhere((PendingTransaction item) => item.id == 'pending-1');
    expect(updatedPending.status, CaptureStatus.manuallyApproved);
    expect(updatedPending.linkedTransactionId, isNotNull);
    expect(controller.state.transactions.length, beforeTransactionCount + 1);
    expect(
      controller.state.transactions
          .where(
            (model.Transaction tx) =>
                tx.id == updatedPending.linkedTransactionId,
          )
          .length,
      1,
    );
    expect(controller.state.savings.single.remainingAmount, 20);
  });

  test('SQLite restart reload preserves calculated state', () async {
    final transactions = <model.Transaction>[
      _income(id: 'income-1', amount: 100),
    ];
    final savings = <model.Saving>[
      _cashSaving(id: 'cash-source', amount: 50, remainingAmount: 50),
    ];

    final controller1 = await _makeController(
      transactions: transactions,
      savings: savings,
    );

    await controller1.addTransaction(_expense(id: 'expense-1', amount: 130));

    expect(controller1.state.savings.single.remainingAmount, 20);
    expect(controller1.getAvailableBalance(currency: 'USD'), 20);

    final controller2 = await _makeController(
      transactions: transactions,
      savings: savings,
    );

    expect(controller2.state.transactions, hasLength(2));
    expect(controller2.state.savings.single.remainingAmount, 20);
    expect(controller2.getAvailableBalance(currency: 'USD'), 20);
  });
}
