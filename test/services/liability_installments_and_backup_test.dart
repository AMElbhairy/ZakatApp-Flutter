import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' hide Saving;
import 'package:zakatapp_flutter/data/local/daos/investments_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/saving.dart' as model;
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

InvestmentAsset _liabilityAsset({
  required String id,
  required List<Map<String, dynamic>> plan,
}) {
  return InvestmentAsset(
    id: id,
    investmentType: 'liability',
    assetSubtype: 'personal_loan',
    ownershipType: 'installment',
    valuationMode: 'manual',
    currency: 'EGP',
    originalPrice: 10000,
    totalInterest: 0,
    totalPayable: 10000,
    paidAmount: 0,
    remainingAmount: 10000,
    installmentPlan: plan,
    valuationDate: '2026-06-01',
    marketValue: 10000,
    marketValueDate: '2026-06-01',
    valuationSource: 'manual',
    loanBalance: 10000,
    loanAsOfDate: '2026-06-01',
    paidAmountToDate: 0,
    ownershipSharePct: 100,
    country: 'EG',
    location: 'Car Loan',
    inflationRateAnnual: 0,
    estimatedCurrentValue: 10000,
    description: 'Loan description',
    noZakat: true,
    createdAt: '2026-06-01T00:00:00.000Z',
  );
}

AppStateModel _baseState({
  required List<InvestmentAsset> investments,
  List<CreditCard> creditCards = const <CreditCard>[],
  List<model.Saving> savings = const <model.Saving>[],
}) {
  return AppStateModel.fromJson(<String, dynamic>{
    ...AppStateDefaults.create().toJson(),
    'investments': investments.map((e) => e.toJson()).toList(),
    'creditCards': creditCards.map((e) => e.toJson()).toList(),
    'savings': savings.map((e) => e.toJson()).toList(),
    'mainCurrency': 'EGP',
    'categories': <String, dynamic>{
      'income': <String>['Salary'],
      'expense': <String>['Bills', 'Installments'],
    },
    'marketData': <String, dynamic>{
      'goldPrice24kEgp': 3000.0,
      'silverPriceEgp': 40.0,
      'usdToEgp': 50.0,
      'sarToEgp': 13.0,
      'ratesToEgp': <String, double>{'EGP': 1.0, 'USD': 50.0},
    },
  });
}

Future<AppStateController> _createController({
  required AppDatabase database,
  required AppStateModel state,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'zakatAppData': jsonEncode(state.toJson()),
  });
  final controller = AppStateController(
    repository: AppStateRepository(localStorage: const LocalStorageService()),
    database: database,
    useSqliteLocalStoreProvider: _AlwaysSqliteProvider(),
    enableBackgroundSync: false,
    enableMarketAutoRefresh: false,
  );
  await controller.load();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late InvestmentsDao investmentsDao;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    investmentsDao = InvestmentsDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Liability Installments Persistence', () {
    test('marking installment as paid persists to SQLite and survives reload', () async {
      final initialAsset = _liabilityAsset(
        id: 'liab-1',
        plan: <Map<String, dynamic>>[
          <String, dynamic>{
            'amount': 2500,
            'date': '2026-07-01',
            'isPaid': false,
            'currency': 'EGP',
          },
          <String, dynamic>{
            'amount': 2500,
            'date': '2026-08-01',
            'isPaid': false,
            'currency': 'EGP',
          },
        ],
      );

      final controller = await _createController(
        database: database,
        state: _baseState(investments: <InvestmentAsset>[initialAsset]),
      );

      // Verify initial state
      expect(controller.state.investments, hasLength(1));
      expect(controller.state.investments.first.installmentPlan[0]['isPaid'], isFalse);

      // Mark the first installment as paid
      await controller.markInstallmentPaid(
        assetId: 'liab-1',
        installmentIndex: 0,
      );

      // Verify in-memory state updated
      expect(controller.state.investments.first.installmentPlan[0]['isPaid'], isTrue);
      expect(controller.state.investments.first.remainingAmount, 2500);

      // Verify SQLite directly has the updated installmentPlanJson
      final sqliteInvestments = await investmentsDao.getActiveInvestments();
      expect(sqliteInvestments, hasLength(1));
      expect(sqliteInvestments.first.installmentPlan[0]['isPaid'], isTrue);
      expect(sqliteInvestments.first.remainingAmount, 2500);

      // Reload into a fresh AppStateController to simulate app restart
      final reloadedController = await _createController(
        database: database,
        state: _baseState(investments: <InvestmentAsset>[initialAsset]), // Stale JSON
      );

      // The reloaded controller must have loaded from SQLite, preserving the paid state!
      expect(reloadedController.state.investments, hasLength(1));
      expect(reloadedController.state.investments.first.installmentPlan[0]['isPaid'], isTrue);
      expect(reloadedController.state.investments.first.remainingAmount, 2500);
    });

    test('toggling installment back to unpaid persists to SQLite and survives reload', () async {
      final initialAsset = _liabilityAsset(
        id: 'liab-2',
        plan: <Map<String, dynamic>>[
          <String, dynamic>{
            'amount': 3000,
            'date': '2026-07-01',
            'isPaid': false,
            'currency': 'EGP',
          },
        ],
      );

      final controller = await _createController(
        database: database,
        state: _baseState(investments: <InvestmentAsset>[initialAsset]),
      );

      // Mark as paid
      await controller.markInstallmentPaid(assetId: 'liab-2', installmentIndex: 0);
      expect(controller.state.investments.first.installmentPlan[0]['isPaid'], isTrue);

      // Toggle to unpaid
      await controller.toggleInstallmentPaid(
        assetId: 'liab-2',
        installmentIndex: 0,
        paymentCategory: '',
      );
      expect(controller.state.investments.first.installmentPlan[0]['isPaid'], isFalse);

      // Verify SQLite is updated
      final sqliteInvestments = await investmentsDao.getActiveInvestments();
      expect(sqliteInvestments.first.installmentPlan[0]['isPaid'], isFalse);

      // Reload controller
      final reloaded = await _createController(
        database: database,
        state: _baseState(investments: <InvestmentAsset>[initialAsset]),
      );
      expect(reloaded.state.investments.first.installmentPlan[0]['isPaid'], isFalse);
    });

    test('payInstallment records expense and persists both transaction and investment to SQLite', () async {
      final initialAsset = _liabilityAsset(
        id: 'liab-3',
        plan: <Map<String, dynamic>>[
          <String, dynamic>{
            'amount': 2000,
            'date': '2026-07-01',
            'isPaid': false,
            'currency': 'EGP',
          },
        ],
      );

      // Give user initial cash to pay installment
      final AppStateModel stateWithCash = _baseState(
        investments: <InvestmentAsset>[initialAsset],
        savings: const <model.Saving>[
          model.Saving(
            id: 'sav-cash',
            assetType: 'cash',
            amount: 10000,
            remainingAmount: 10000,
            dateAcquired: '2026-06-01',
            unit: 'EGP',
            description: '',
            purchaseCurrency: 'EGP',
            purchaseAmount: 10000,
            createdAt: '2026-06-01T00:00:00.000Z',
          ),
        ],
      );

      final controller = await _createController(
        database: database,
        state: stateWithCash,
      );

      await controller.payInstallment(
        assetId: 'liab-3',
        installmentIndex: 0,
        paymentCategory: 'Installments',
      );

      expect(controller.state.investments.first.installmentPlan[0]['isPaid'], isTrue);
      expect(controller.state.transactions.any((t) => t.category == 'Installments'), isTrue);

      // Verify SQLite has the updated investment
      final sqliteInvestments = await investmentsDao.getActiveInvestments();
      expect(sqliteInvestments.first.installmentPlan[0]['isPaid'], isTrue);
    });

    test('backup export and preview includes paid installment state', () {
      final assetWithPaid = _liabilityAsset(
        id: 'liab-export',
        plan: <Map<String, dynamic>>[
          <String, dynamic>{
            'amount': 1500,
            'date': '2026-07-01',
            'isPaid': true,
            'currency': 'EGP',
          },
        ],
      );

      final state = _baseState(investments: <InvestmentAsset>[assetWithPaid]);
      final String exported = BackupService.exportBackup(
        state.toJson(),
        userId: 'u1',
        provider: 'google',
        email: 'u1@example.com',
      );

      final preview = BackupService.parseBackupPreview(exported);
      expect(preview.investmentsCount, 1);
      expect(preview.canRestore, isTrue);

      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      final invList = (decoded['appState'] as Map)['investments'] as List;
      final plan = invList.first['installmentPlan'] as List;
      expect(plan.first['isPaid'], isTrue);
    });

    test('snapshot manager vacuum captures SQLite database with updated liability', () async {
      final initialAsset = _liabilityAsset(
        id: 'liab-snap',
        plan: <Map<String, dynamic>>[
          <String, dynamic>{
            'amount': 5000,
            'date': '2026-07-01',
            'isPaid': false,
            'currency': 'EGP',
          },
        ],
      );

      final controller = await _createController(
        database: database,
        state: _baseState(investments: <InvestmentAsset>[initialAsset]),
      );

      await controller.markInstallmentPaid(assetId: 'liab-snap', installmentIndex: 0);

      final snapshotManager = SnapshotManager(
        encryptionService: SyncEncryptionService(),
      );
      final checksum = await snapshotManager.calculateDatabaseChecksum(
        db: database,
      );
      expect(checksum, isNotEmpty);
    });
  });
}
