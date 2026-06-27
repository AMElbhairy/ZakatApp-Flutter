import 'dart:async';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/correction_feedback.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/merchant_confirmation.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';

import '../support/google_drive_operation_sync_harness.dart';
import '../support/mock_cloud_storage_provider.dart';

class _BlockingManifestMockCloudStorageProvider
    extends MockCloudStorageProvider {
  _BlockingManifestMockCloudStorageProvider({super.connected = true});

  Completer<void>? blockFirstManifestWrite;
  int manifestWriteCount = 0;

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    manifestWriteCount++;
    if (manifestWriteCount == 1 && blockFirstManifestWrite != null) {
      await blockFirstManifestWrite!.future;
    }
    return super.writeManifest(
      manifestData,
      expectedRevision: expectedRevision,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GoogleDriveOperationSyncHarness> buildHarness({
    Duration debounceDuration = const Duration(days: 1),
    MockCloudStorageProvider? provider,
  }) {
    return buildGoogleDriveOperationSyncHarness(
      debounceDuration: debounceDuration,
      provider: provider,
    );
  }

  Transaction transactionModel({
    required String id,
    String description = 'Test transaction',
    double amount = 100,
    String type = 'income',
  }) {
    return Transaction(
      id: id,
      type: type,
      date: '2026-06-23',
      amount: amount,
      currency: 'USD',
      category: type == 'income' ? 'Salary' : 'Food',
      description: description,
      createdAt: '2026-06-23T08:00:00Z',
      rolledOver: false,
    );
  }

  Saving savingModel({required String id, double amount = 250}) {
    return Saving(
      id: id,
      assetType: 'cash',
      dateAcquired: '2026-06-23',
      amount: amount,
      remainingAmount: amount,
      unit: 'USD',
      description: 'Test saving',
      purchaseCurrency: 'USD',
      purchaseAmount: amount,
      createdAt: '2026-06-23T08:00:00Z',
    );
  }

  InvestmentAsset investmentModel({required String id}) {
    return InvestmentAsset(
      id: id,
      investmentType: 'property',
      assetSubtype: 'rental',
      ownershipType: 'full',
      valuationMode: 'manual',
      currency: 'USD',
      originalPrice: 1000,
      totalInterest: 0,
      totalPayable: 1000,
      paidAmount: 200,
      remainingAmount: 800,
      installmentPlan: const <Map<String, dynamic>>[],
      valuationDate: '2026-06-23',
      marketValue: 1200,
      marketValueDate: '2026-06-23',
      valuationSource: 'manual',
      loanBalance: 0,
      loanAsOfDate: '2026-06-23',
      paidAmountToDate: 200,
      ownershipSharePct: 100,
      country: 'US',
      location: 'Remote',
      inflationRateAnnual: 0,
      estimatedCurrentValue: 1200,
      description: 'Test investment',
      noZakat: false,
      createdAt: '2026-06-23T08:00:00Z',
    );
  }

  RecurringTransaction recurringModel({required String id}) {
    return RecurringTransaction(
      id: id,
      name: 'Monthly rent',
      type: 'expense',
      amount: 500,
      currency: 'USD',
      category: 'Housing',
      description: 'Recurring test',
      dayOfMonth: 1,
      frequency: 'monthly',
      enabled: true,
      skipMonth: '',
      createdAt: '2026-06-23T08:00:00Z',
    );
  }

  FinancialPlan financialPlanModel({required String id}) {
    return FinancialPlan(
      id: id,
      name: 'Plan A',
      startDate: '2026-06-23',
      projectionCurrency: 'USD',
      startingBalance: 1000,
      startingBalanceDate: '2026-06-23',
      startingBalanceMode: 'manual',
      snapshotWealthCurrency: 'USD',
      startingAssetBreakdown: const <String, double>{},
      monthlyIncome: 5000,
      monthlyExpenses: 2500,
      includeInstallments: false,
      includeZakat: true,
      durationYears: 1,
      createdAt: '2026-06-23T08:00:00Z',
    );
  }

  MerchantRule merchantRuleModel({required String merchantName}) {
    return MerchantRule(
      merchantName: merchantName,
      categoryId: 'food',
      defaultType: 'expense',
      autoApprove: false,
      usageCount: 1,
      confidence: 0.8,
      source: 'custom',
      aliases: const <String>['alias'],
    );
  }

  MerchantConfirmation merchantConfirmationModel({
    required String merchantName,
  }) {
    return MerchantConfirmation(
      merchantName: merchantName,
      categoryId: 'food',
      confirmations: 1,
      corrections: 0,
    );
  }

  CorrectionFeedback correctionFeedbackModel({required String id}) {
    return CorrectionFeedback(
      id: id,
      fieldName: 'merchant',
      originalValue: 'Old Shop',
      correctedValue: 'New Shop',
      createdAt: '2026-06-23T08:00:00Z',
    );
  }

  group('Google Drive operation sync integration', () {
    test('Device A creates transaction and Device B receives it', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      expect(
        harness.deviceA.cloudBackupController.isOperationSyncEnabled,
        isTrue,
      );

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-1'),
      );
      final bool syncA = await harness.deviceA.cloudBackupController
          .syncOperationsNow();
      expect(
        syncA,
        isTrue,
        reason: harness.deviceA.cloudBackupController.lastOperationSyncError,
      );
      final bool syncB = await harness.deviceB.cloudBackupController
          .syncOperationsNow();
      expect(
        syncB,
        isTrue,
        reason: harness.deviceB.cloudBackupController.lastOperationSyncError,
      );

      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
    });

    test('Device A updates transaction and Device B updates it', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-1', amount: 100),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      await harness.deviceA.appStateController.updateTransaction(
        transactionModel(id: 'tx-1', amount: 150),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
      final rows = await harness.deviceB.currentDatabase
          .customSelect(
            "SELECT amount_text FROM transactions WHERE id = 'tx-1'",
          )
          .get();
      expect(double.parse(rows.single.read<String>('amount_text')), 150);
    });

    test('Device A deletes transaction and Device B deletes it', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-1'),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      await harness.deviceA.appStateController.deleteTransaction('tx-1');
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
      final count = await harness.deviceB.currentDatabase
          .customSelect(
            'SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NULL',
          )
          .get();
      expect(count.single.read<int>('c'), 0);
    });

    test('Device A creates saving and Device B receives it', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addSaving(
        savingModel(id: 'sv-1'),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
      final rows = await harness.deviceB.currentDatabase
          .customSelect('SELECT id FROM savings WHERE deleted_at IS NULL')
          .get();
      expect(rows.single.read<String>('id'), 'sv-1');
    });

    test('Pulling the same log twice does not create duplicates', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-1'),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();
      await harness.deviceB.cloudBackupController.syncOperationsNow();

      final rows = await harness.deviceB.currentDatabase
          .customSelect(
            'SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NULL',
          )
          .get();
      expect(rows.single.read<int>('c'), 1);
      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
    });

    test(
      'Device A offline creates multiple records then reconnects and Device B matches',
      () async {
        final harness = await buildHarness();
        addTearDown(harness.dispose);

        harness.provider.connected = false;

        await harness.deviceA.appStateController.addTransaction(
          transactionModel(id: 'tx-offline-1'),
        );
        await harness.deviceA.appStateController.addSaving(
          savingModel(id: 'sv-offline-1'),
        );
        await harness.deviceA.appStateController.addInvestment(
          investmentModel(id: 'inv-offline-1'),
        );
        await harness.deviceA.appStateController.addRecurringTransaction(
          recurringModel(id: 'rec-offline-1'),
        );
        await harness.deviceA.appStateController.addFinancialPlan(
          financialPlanModel(id: 'plan-offline-1'),
        );
        await harness.deviceA.appStateController.saveCustomMerchantRule(
          merchantRuleModel(merchantName: 'Offline Mart'),
        );
        await harness
            .deviceA
            .appStateController
            .localMerchantConfirmationsRepository!
            .saveMerchantConfirmation(
              merchantConfirmationModel(merchantName: 'Offline Mart'),
            );
        await harness
            .deviceA
            .appStateController
            .localCorrectionFeedbackRepository!
            .saveCorrectionFeedback(
              correctionFeedbackModel(id: 'fb-offline-1'),
            );
        await harness.deviceA.appStateController.refreshFromLocalRepositories(
          reason: 'offline_seed',
        );

        harness.provider.connected = true;
        expect(
          await harness.deviceA.cloudBackupController.syncOperationsNow(),
          isTrue,
        );
        expect(
          await harness.deviceB.cloudBackupController.syncOperationsNow(),
          isTrue,
        );

        expectDatabasesEqual(
          harness.deviceA.currentDatabase,
          harness.deviceB.currentDatabase,
        );
      },
    );

    test('Backup still works while operation sync is enabled', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-backup-1'),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();

      final backedUp = await harness.deviceA.cloudBackupController.backupNow();
      expect(backedUp, isTrue);

      final manifest = await harness.provider.readManifest();
      expect(manifest, isNotNull);
      final snapshotManifest = CloudSyncManifest.fromJson(manifest!.content);
      expect(snapshotManifest.snapshots, isNotEmpty);
    });

    test('Restore suppresses automatic operation sync', () async {
      final harness = await buildHarness(
        debounceDuration: const Duration(milliseconds: 40),
      );
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-restore-1'),
      );
      await harness.deviceA.cloudBackupController.syncOperationsNow();
      expect(await harness.deviceA.cloudBackupController.backupNow(), isTrue);

      final logsBeforeRestore = await harness.provider.listFiles('logs/');
      expect(logsBeforeRestore, hasLength(1));

      expect(
        await harness.deviceB.cloudBackupController.restoreLatestBackup(),
        isTrue,
      );

      final logsBeforeLocalChange = await harness.provider.listFiles('logs/');
      await harness.deviceB.appStateController.addTransaction(
        transactionModel(id: 'tx-restored-local-1'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final logsAfterLocalChange = await harness.provider.listFiles('logs/');
      expect(logsAfterLocalChange.length, logsBeforeLocalChange.length);

      expect(
        await harness.deviceB.cloudBackupController.syncOperationsNow(),
        isFalse,
      );
      final logsAfterManualSync = await harness.provider.listFiles('logs/');
      expect(logsAfterManualSync.length, logsBeforeLocalChange.length);
    });

    test('Manifest conflict preserves both devices logs', () async {
      final provider = _BlockingManifestMockCloudStorageProvider(
        connected: true,
      );
      final harness = await buildHarness(provider: provider);
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-conflict-a'),
      );
      await harness.deviceB.appStateController.addSaving(
        savingModel(id: 'sv-conflict-b'),
      );

      final Completer<void> block = Completer<void>();
      provider.blockFirstManifestWrite = block;

      final Future<bool> syncB = harness.deviceB.cloudBackupController
          .syncOperationsNow();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final Future<bool> syncA = harness.deviceA.cloudBackupController
          .syncOperationsNow();
      block.complete();
      expect(await syncA, isTrue);
      expect(await syncB, isTrue);

      expect(
        await harness.deviceA.cloudBackupController.syncOperationsNow(),
        isTrue,
      );
      expect(
        await harness.deviceB.cloudBackupController.syncOperationsNow(),
        isTrue,
      );

      final logFiles = await provider.listFiles('logs/');
      expect(
        logFiles.where((file) => file.path.contains('device-a')).length,
        greaterThan(0),
      );
      expect(
        logFiles.where((file) => file.path.contains('device-b')).length,
        greaterThan(0),
      );

      expectDatabasesEqual(
        harness.deviceA.currentDatabase,
        harness.deviceB.currentDatabase,
      );
    });

    test('Unreadable remote operation logs are skipped instead of failing sync', () async {
      final harness = await buildHarness();
      addTearDown(harness.dispose);

      await harness.deviceA.appStateController.addTransaction(
        transactionModel(id: 'tx-bad-log'),
      );
      expect(
        await harness.deviceA.cloudBackupController.syncOperationsNow(),
        isTrue,
      );

      await harness.provider.writeFile(
        'logs/log_device-a_1.json.enc',
        Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]),
      );

      final bool syncOk = await harness.deviceB.cloudBackupController
          .syncOperationsNow();
      expect(syncOk, isTrue);
      expect(
        harness.deviceB.cloudBackupController.lastOperationSyncError,
        isEmpty,
      );
      expect(
        harness.deviceB.cloudBackupController.operationSyncStatusMessage,
        contains('Cloud Sync'),
      );
    });
  });
}
