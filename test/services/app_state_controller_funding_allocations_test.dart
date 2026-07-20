import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

Future<AppStateController> _makeController() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const localStorage = LocalStorageService();
  final controller = AppStateController(
    repository: AppStateRepository(localStorage: localStorage),
  );
  await controller.load();
  return controller;
}

void main() {
  test('funded gold purchase cannot exceed available cash balance', () async {
    final AppStateController controller = await _makeController();
    await controller.updateState(
      controller.state.copyWith(
        transactions: <Transaction>[
          const Transaction(
            id: 'income-1',
            type: 'income',
            date: '2026-06-21',
            amount: 100,
            currency: 'EGP',
            category: 'Salary',
            description: 'income',
            createdAt: '2026-06-21T08:00:00.000Z',
            rolledOver: false,
          ),
        ],
      ),
    );

    final Saving saving = Saving(
      id: 'gold-1',
      assetType: 'gold',
      dateAcquired: '2026-06-21',
      amount: 1,
      remainingAmount: 1,
      unit: '24',
      description: 'gold purchase',
      purchaseCurrency: 'EGP',
      purchaseAmount: 150,
      createdAt: '2026-06-21T09:00:00.000Z',
      fundingAllocations: <Map<String, dynamic>>[
        <String, dynamic>{
          'sourceType': 'income',
          'sourceId': 'income-1',
          'sourceDate': '2026-06-21',
          'currency': 'EGP',
          'amount': 150,
        },
      ],
    );

    await expectLater(
      controller.addSavingWithFundingAllocations(saving),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('Insufficient available cash'),
        ),
      ),
    );

    expect(controller.state.savings, isEmpty);
    expect(controller.state.transactions, hasLength(1));
  });
}
