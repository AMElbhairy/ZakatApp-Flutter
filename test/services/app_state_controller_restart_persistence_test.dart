import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _Gate implements UseSqliteLocalStoreProvider {
  _Gate(this.value);

  final bool value;

  @override
  Future<bool> prepareForRead({String? userId}) async => value;
}

InvestmentAsset _investment(String id, {required String subtype}) {
  return InvestmentAsset(
    id: id,
    investmentType: 'asset',
    assetSubtype: subtype,
    ownershipType: 'full',
    valuationMode: 'manual',
    currency: 'USD',
    originalPrice: 1000,
    totalInterest: 0,
    totalPayable: 1000,
    paidAmount: 1000,
    remainingAmount: 0,
    installmentPlan: const <Map<String, dynamic>>[],
    valuationDate: '2026-06-19',
    marketValue: 1000,
    marketValueDate: '2026-06-19',
    valuationSource: 'manual',
    loanBalance: 0,
    loanAsOfDate: '',
    paidAmountToDate: 1000,
    ownershipSharePct: 100,
    country: 'EG',
    location: 'Cairo',
    inflationRateAnnual: 0,
    estimatedCurrentValue: 1000,
    description: subtype,
    noZakat: false,
    createdAt: '2026-06-19T08:00:00.000Z',
  );
}

Future<AppStateController> _controller({
  required AppDatabase? database,
  required bool useSqlite,
}) async {
  final AppStateController controller = AppStateController(
    repository: AppStateRepository(localStorage: const LocalStorageService()),
    database: database,
    useSqliteLocalStoreProvider: _Gate(useSqlite),
  );
  await controller.load();
  return controller;
}

void main() {
  late AppStateRepository repository;
  final Directory documentsDirectory = Directory.systemTemp.createTempSync(
    'zakatapp-restart-tests-',
  );
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
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
    repository = AppStateRepository(localStorage: const LocalStorageService());
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await documentsDirectory.delete(recursive: true);
  });

  test('gate false keeps full JSON fallback across restart', () async {
    final controller1 = await _controller(database: null, useSqlite: false);

    await controller1.addInvestment(
      _investment('json-only', subtype: 'property'),
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('zakatAppData');
    expect(raw, isNotNull);
    expect(raw!, contains('"investments":[{"id":"json-only"'));

    final controller2 = await _controller(database: null, useSqlite: false);
    expect(controller2.state.investments, hasLength(1));
    expect(controller2.state.investments.single.id, 'json-only');
  });

  test(
    'gate true persists property and company shares investments to SQLite',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());

      final controller1 = await _controller(
        database: database,
        useSqlite: true,
      );

      await controller1.addInvestment(
        _investment('property-1', subtype: 'property'),
      );
      await controller1.addInvestment(
        _investment('shares-1', subtype: 'company_shares'),
      );

      final rows = await database.select(database.investments).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.id),
        containsAll(<String>['property-1', 'shares-1']),
      );

      final controller2 = await _controller(
        database: database,
        useSqlite: true,
      );

      expect(
        controller2.state.investments.map((item) => item.id),
        containsAll(<String>['property-1', 'shares-1']),
      );
      await database.close();
    },
  );

  test(
    'gate true persists transaction writes to SQLite across restart',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());

      final controller1 = await _controller(
        database: database,
        useSqlite: true,
      );

      await controller1.addTransaction(
        const model.Transaction(
          id: 'tx-persist',
          type: 'income',
          date: '2026-06-19',
          amount: 250,
          currency: 'USD',
          category: 'Salary',
          description: 'persist',
          createdAt: '2026-06-19T08:00:00.000Z',
          rolledOver: false,
        ),
      );

      final rows = await database.select(database.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'tx-persist');

      final controller2 = await _controller(
        database: database,
        useSqlite: true,
      );

      expect(controller2.state.transactions, hasLength(1));
      expect(controller2.state.transactions.single.id, 'tx-persist');
      await database.close();
    },
  );

  test('authenticated users use isolated SQLite databases', () async {
    final AppDatabase database = AppDatabase(userId: 'switch-a');
    final AppStateController controller = AppStateController(
      repository: repository,
      database: database,
      ownsDatabase: true,
      useSqliteLocalStoreProvider: _Gate(true),
    );

    await controller.loadAuthenticated('switch-a');
    await controller.addTransaction(
      const model.Transaction(
        id: 'tx-a',
        type: 'income',
        date: '2026-06-19',
        amount: 100,
        currency: 'USD',
        category: 'Salary',
        description: 'user a',
        createdAt: '2026-06-19T08:00:00.000Z',
        rolledOver: false,
      ),
    );

    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'tx-a');

    await controller.loadAuthenticated('switch-b');
    expect(controller.database?.userId, 'switch-b');
    expect(controller.state.transactions, isEmpty);

    await controller.loadAuthenticated('switch-a');
    expect(controller.database?.userId, 'switch-a');
    expect(controller.state.transactions, hasLength(1));
    expect(controller.state.transactions.single.id, 'tx-a');

    await controller.database?.close();
    await AppDatabase.deleteDatabaseFiles(userId: 'switch-a');
    await AppDatabase.deleteDatabaseFiles(userId: 'switch-b');
  });
}
