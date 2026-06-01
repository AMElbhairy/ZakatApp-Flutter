import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  Future<AppStateController> makeController() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final controller = AppStateController(repository: repository);
    await controller.load();
    return controller;
  }

  test('controller toggleZakatPaid persists expense transaction', () async {
    final controller = await makeController();
    await controller.toggleZakatPaid(
      monthKey: '2026-06',
      zakatAmountMainCurrency: 123,
      paymentDate: '2026-06-01',
    );
    expect(controller.state.zakatPaidMonths, contains('2026-06'));
    expect(controller.state.transactions.any((t) => t.category == 'Zakat'), isTrue);
  });

  test('controller executeCurrencyExchange creates linked records', () async {
    final controller = await makeController();
    await controller.addTransaction(
      const Transaction(
        id: 'income-1',
        type: 'income',
        date: '2026-06-01',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: '',
        createdAt: '2026-06-01T00:00:00.000Z',
        rolledOver: false,
      ),
    );
    await controller.executeCurrencyExchange(
      date: '2026-06-01',
      sourceType: 'income',
      sourceCurrency: 'USD',
      targetCurrency: 'EGP',
      sourceAmount: 50,
      targetAmount: 2500,
    );
    final exchanged = controller.state.transactions.where((t) => t.exchangePairId != null).toList();
    expect(exchanged.length, 2);
  });
}
