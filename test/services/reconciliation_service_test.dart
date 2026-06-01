import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/reconciliation_service.dart';

void main() {
  final ReconciliationService service = ReconciliationService();

  AppStateModel makeState({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> savings,
    List<String>? processedExpenseIds,
  }) {
    final AppStateModel base = AppStateDefaults.create();
    return AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': transactions,
      'savings': savings,
      'processedExpenseIds': processedExpenseIds ?? <String>[],
    });
  }

  test('expense with enough wallet does not reduce savings', () {
    final AppStateModel state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'i1', 'type': 'income', 'date': '2024-01-01', 'amount': 100, 'currency': 'EGP'},
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-02', 'amount': 20, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 50, 'remainingAmount': 50, 'dateAcquired': '2024-01-01'},
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.first.remainingAmount, 50);
  });

  test('expense with insufficient wallet reduces oldest cash saving first', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'i1', 'type': 'income', 'date': '2024-01-02', 'amount': 10, 'currency': 'EGP'},
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 30, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 25, 'remainingAmount': 25, 'dateAcquired': '2024-01-01'},
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.first.remainingAmount, 5);
  });

  test('multiple savings lots reduce FIFO', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 25, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'old', 'assetType': 'cash', 'unit': 'EGP', 'amount': 10, 'remainingAmount': 10, 'dateAcquired': '2024-01-01'},
        <String, dynamic>{'id': 'new', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-02'},
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.firstWhere((s) => s.id == 'old').remainingAmount, 0);
    expect(out.savings.firstWhere((s) => s.id == 'new').remainingAmount, 5);
  });

  test('processedExpenseIds prevents double deduction', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 10, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );

    final once = service.reconcileExpensesWithSavings(state).state;
    final twice = service.reconcileExpensesWithSavings(once).state;
    expect(once.savings.first.remainingAmount, 10);
    expect(twice.savings.first.remainingAmount, 10);
    expect(twice.processedExpenseIds, contains('e1'));
  });

  test('deleting expense restores remainingAmount after reconciliation', () {
    final initial = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 10, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );

    final deducted = service.reconcileExpensesWithSavings(initial).state;
    final restored = service.reconcileExpensesWithSavings(
      makeState(
        transactions: const <Map<String, dynamic>>[],
        savings: deducted.savings.map((s) => s.toJson()).toList(growable: false),
      ),
    ).state;

    expect(restored.savings.first.remainingAmount, 20);
  });

  test('updating expense recalculates correctly', () {
    final state1 = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 5, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );
    final once = service.reconcileExpensesWithSavings(state1).state;

    final state2 = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 15, 'currency': 'EGP'},
      ],
      savings: once.savings.map((s) => s.toJson()).toList(growable: false),
    );
    final twice = service.reconcileExpensesWithSavings(state2).state;

    expect(twice.savings.first.remainingAmount, 5);
  });

  test('different currencies are isolated', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 10, 'currency': 'USD'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
        <String, dynamic>{'id': 's2', 'assetType': 'cash', 'unit': 'USD', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.firstWhere((s) => s.unit == 'EGP').remainingAmount, 20);
    expect(out.savings.firstWhere((s) => s.unit == 'USD').remainingAmount, 10);
  });

  test('imported backup missing remainingAmount normalized then reconciled', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 10, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.first.remainingAmount, 10);
  });

  test('zakat wealth changes after reconciliation', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'e1', 'type': 'expense', 'date': '2024-01-03', 'amount': 10, 'currency': 'EGP'},
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'assetType': 'cash', 'unit': 'EGP', 'amount': 20, 'remainingAmount': 20, 'dateAcquired': '2024-01-01'},
      ],
    );

    final before = state.savings.first.remainingAmount;
    final after = service.reconcileExpensesWithSavings(state).state.savings.first.remainingAmount;
    expect(after, lessThan(before));
  });
}
