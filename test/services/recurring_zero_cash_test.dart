import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/collection_hydration_evidence.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('User with zero cash and recurring auto-add loads without crash or logout', () async {
    final recurringTx = RecurringTransaction(
      id: 'rec_rent_1',
      name: 'Monthly Rent',
      amount: 500,
      currency: 'USD',
      category: 'Housing',
      description: 'Monthly apartment rent',
      frequency: 'monthly',
      dayOfMonth: 1,
      type: 'expense',
      enabled: true,
      autoAdd: true,
      skipMonth: '',
      createdAt: '2026-01-01T00:00:00.000Z',
      lastProcessed: null,
    );

    final initialData = <String, dynamic>{
      'userId': 'user_123',
      'userEmail': 'test@example.com',
      'transactions': <dynamic>[],
      'savings': <dynamic>[], // NO CASH AT ALL
      'investments': <dynamic>[],
      'financialPlans': <dynamic>[],
      'pendingTransactions': <dynamic>[],
      'recurringTransactions': <dynamic>[recurringTx.toJson()],
      'lastRollover': '',
      'categories': <String, dynamic>{'income': <dynamic>[], 'expense': <dynamic>[]},
      'mainCurrency': 'USD',
      'defaultEntryCurrency': 'USD',
    };

    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': jsonEncode(initialData),
    });

    final repository = AppStateRepository(localStorage: const LocalStorageService());
    final controller = AppStateController(repository: repository);

    // Load app state (simulates opening the app)
    await controller.load();

    // Verify hydration succeeded without falling into error/logout
    expect(controller.hydrationPhase, AppHydrationPhase.ready);
    expect(controller.hasHydrationFailure, isFalse);
    expect(controller.state.userId, 'user_123');

    // Verify that the due recurring transaction was auto-added without throwing
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.amount, 500.0);
    expect(controller.state.transactions.first.currency, 'USD');
    expect(controller.state.transactions.first.type, 'expense');
  });
}
