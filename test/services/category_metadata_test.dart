import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/utils/category_visuals.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

AppStateController _buildController() {
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  return AppStateController(
    repository: repository,
    enableBackgroundSync: false,
    enableMarketAutoRefresh: false,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('category metadata round-trips through AppCategories JSON', () {
    const AppCategories categories = AppCategories(
      income: <String>['Salary'],
      expense: <String>['Food & Dining'],
      incomeMetadata: <String, CategoryVisual>{
        'Salary': CategoryVisual(iconKey: 'salary', colorValue: 0xFF047857),
      },
      expenseMetadata: <String, CategoryVisual>{
        'Food & Dining': CategoryVisual(
          iconKey: 'food',
          colorValue: 0xFFC8A75B,
        ),
      },
    );

    final AppCategories decoded = AppCategories.fromJson(categories.toJson());

    expect(decoded.income, <String>['Salary']);
    expect(decoded.expense, <String>['Food & Dining']);
    expect(decoded.metadataFor(type: 'income', name: 'Salary')?.iconKey, 'salary');
    expect(
      decoded.metadataFor(type: 'expense', name: 'Food & Dining')?.colorValue,
      0xFFC8A75B,
    );
  });

  test('legacy categories without metadata still load cleanly', () {
    final AppCategories categories = AppCategories.fromJson(<String, dynamic>{
      'income': <String>['Salary'],
      'expense': <String>['Food & Dining'],
    });

    expect(categories.income, <String>['Salary']);
    expect(categories.expense, <String>['Food & Dining']);
    expect(categories.incomeMetadata, isEmpty);
    expect(categories.expenseMetadata, isEmpty);
  });

  test('category resolve falls back when metadata is missing', () {
    const AppCategories categories = AppCategories(
      income: <String>['Salary'],
      expense: <String>['Coffee'],
    );

    final CategoryVisual custom = CategoryVisuals.resolveCategoryVisual(
      categories: categories,
      type: 'income',
      categoryName: 'Salary',
    );
    final CategoryVisual fallback = CategoryVisuals.resolveCategoryVisual(
      categories: categories,
      type: 'expense',
      categoryName: 'Unknown custom',
    );

    expect(custom.iconKey, isNotNull);
    expect(custom.colorValue, isNotNull);
    expect(fallback.iconKey, isNotNull);
    expect(fallback.colorValue, isNotNull);
  });

  test('renameCategory preserves transaction fields and metadata', () async {
    final AppStateController controller = _buildController();
    await controller.load();

    await controller.updateState(
      controller.state.copyWith(
        categories: const AppCategories(
          income: <String>['Salary'],
          expense: <String>['Food'],
          expenseMetadata: <String, CategoryVisual>{
            'Food': CategoryVisual(iconKey: 'food', colorValue: 0xFFC8A75B),
          },
        ),
        transactions: <Transaction>[
          const Transaction(
            id: 'tx-1',
            type: 'expense',
            date: '2026-06-25',
            amount: 125.5,
            currency: 'EGP',
            category: 'Food',
            description: 'Lunch',
            createdAt: '2026-06-25T10:00:00.000Z',
            rolledOver: false,
            rolledAmount: 12.3,
            sourceIncomeId: 'src-1',
            exchangePairId: 'pair-1',
            exchangeSourceIncomeId: 'src-x',
            remainingAmount: 99.9,
            activityType: 'manual',
            costBasis: 88.8,
            saleValue: 77.7,
            realizedGain: 11.1,
            realizedGainLossCurrency: 'EGP',
            metalQuantity: 2.5,
          ),
        ],
      ),
    );

    await controller.renameCategory(
      type: 'expense',
      from: 'Food',
      to: 'Dining',
    );

    final Transaction renamed = controller.state.transactions.first;
    expect(renamed.category, 'Dining');
    expect(renamed.amount, 125.5);
    expect(renamed.rolledAmount, 12.3);
    expect(renamed.sourceIncomeId, 'src-1');
    expect(renamed.exchangePairId, 'pair-1');
    expect(renamed.exchangeSourceIncomeId, 'src-x');
    expect(renamed.remainingAmount, 99.9);
    expect(renamed.activityType, 'manual');
    expect(renamed.costBasis, 88.8);
    expect(renamed.saleValue, 77.7);
    expect(renamed.realizedGain, 11.1);
    expect(renamed.realizedGainLossCurrency, 'EGP');
    expect(renamed.metalQuantity, 2.5);
    expect(
      controller.state.categories.metadataFor(type: 'expense', name: 'Dining')
          ?.iconKey,
      'food',
    );
  });

  test('telecom built-ins map to Internet & Phone', () {
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['stc'],
      'Internet & Phone',
    );
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['mobily'],
      'Internet & Phone',
    );
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['zain'],
      'Internet & Phone',
    );
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['vodafone'],
      'Internet & Phone',
    );
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['etisalat'],
      'Internet & Phone',
    );
    expect(
      SmartCaptureParser.builtinMerchantCategoryMap['orange'],
      'Internet & Phone',
    );
  });
}
