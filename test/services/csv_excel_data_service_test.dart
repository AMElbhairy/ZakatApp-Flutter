import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/csv_excel_data_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStateModel testState;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    testState = AppStateModel.fromJson(<String, dynamic>{
      'userId': 'user_123',
      'userEmail': 'user@example.com',
      'mainCurrency': 'EGP',
      'defaultEntryCurrency': 'USD',
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'tx_1',
          'type': 'expense',
          'date': '2026-03-15',
          'amount': 250.75,
          'currency': 'USD',
          'category': 'Food & Groceries',
          'description': 'Grocery shopping "Special, Items"',
          'createdAt': '2026-03-15T12:00:00Z',
          'rolledOver': false,
        },
        <String, dynamic>{
          'id': 'tx_2',
          'type': 'income',
          'date': '2026-03-01',
          'amount': 5000.0,
          'currency': 'USD',
          'category': 'Salary',
          'description': 'Monthly Salary - راتب شهري',
          'createdAt': '2026-03-01T09:00:00Z',
          'rolledOver': true,
          'rolledAmount': 1500.0,
        },
      ],
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'sav_1',
          'assetType': 'cash',
          'dateAcquired': '2026-01-01',
          'amount': 10000.0,
          'remainingAmount': 8500.0,
          'unit': 'USD',
          'description': 'Emergency Fund',
          'purchaseCurrency': 'USD',
          'purchaseAmount': 10000.0,
          'createdAt': '2026-01-01T00:00:00Z',
        },
      ],
      'investments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inv_1',
          'investmentType': 'property',
          'assetSubtype': 'Apartment',
          'ownershipType': 'Sole',
          'valuationMode': 'manual',
          'currency': 'EGP',
          'originalPrice': 1500000.0,
          'totalInterest': 0.0,
          'totalPayable': 1500000.0,
          'paidAmount': 500000.0,
          'remainingAmount': 1000000.0,
          'installmentPlan': <Map<String, dynamic>>[
            <String, dynamic>{'date': '2026-04-01', 'amount': 50000.0, 'paid': false},
            <String, dynamic>{'date': '2026-05-01', 'amount': 50000.0, 'paid': false},
          ],
          'valuationDate': '2026-01-01',
          'marketValue': 1600000.0,
          'marketValueDate': '2026-01-01',
          'valuationSource': 'Manual',
          'loanBalance': 0.0,
          'loanAsOfDate': '2026-01-01',
          'paidAmountToDate': 500000.0,
          'ownershipSharePct': 100.0,
          'country': 'Egypt',
          'location': 'Cairo',
          'inflationRateAnnual': 0.0,
          'estimatedCurrentValue': 1600000.0,
          'description': 'New Cairo Apartment',
          'noZakat': true,
          'createdAt': '2026-01-01T00:00:00Z',
        },
      ],
      'recurringTransactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'rec_1',
          'name': 'Internet Subscription',
          'type': 'expense',
          'amount': 60.0,
          'currency': 'USD',
          'category': 'Utilities',
          'description': 'Monthly Fiber Internet',
          'dayOfMonth': 5,
          'frequency': 'monthly',
          'enabled': true,
          'skipMonth': '',
          'createdAt': '2026-01-01T00:00:00Z',
        },
      ],
    });
  });

  group('CsvExcelDataService Export Tests', () {
    test('exportMasterCsv produces UTF-8 BOM and encodes all 4 entity types', () {
      final String csv = CsvExcelDataService.exportMasterCsv(testState);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('TRANSACTION'), isTrue);
      expect(csv.contains('SAVING'), isTrue);
      expect(csv.contains('INVESTMENT'), isTrue);
      expect(csv.contains('RECURRING'), isTrue);
      expect(csv.contains('Grocery shopping ""Special, Items""'), isTrue);
      expect(csv.contains('راتب شهري'), isTrue);
    });

    test('exportTransactionsCsv encodes transactions with proper escaping', () {
      final String csv = CsvExcelDataService.exportTransactionsCsv(testState.transactions);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('tx_1'), isTrue);
      expect(csv.contains('Food & Groceries'), isTrue);
      expect(csv.contains('250.75'), isTrue);
    });

    test('exportSavingsCsv encodes savings entries', () {
      final String csv = CsvExcelDataService.exportSavingsCsv(testState.savings);
      expect(csv.contains('sav_1'), isTrue);
      expect(csv.contains('Emergency Fund'), isTrue);
      expect(csv.contains('10000.0'), isTrue);
    });

    test('exportInvestmentsCsv encodes investments and installment plans', () {
      final String csv = CsvExcelDataService.exportInvestmentsCsv(testState.investments);
      expect(csv.contains('inv_1'), isTrue);
      expect(csv.contains('New Cairo Apartment'), isTrue);
      expect(csv.contains('1500000.0'), isTrue);
    });

    test('exportRecurringCsv encodes recurring items', () {
      final String csv = CsvExcelDataService.exportRecurringCsv(testState.recurringTransactions);
      expect(csv.contains('rec_1'), isTrue);
      expect(csv.contains('Internet Subscription'), isTrue);
      expect(csv.contains('60.0'), isTrue);
    });

    test('exportCsvZip creates a valid zip containing all CSV files', () {
      final List<int> zipBytes = CsvExcelDataService.exportCsvZip(testState);
      expect(zipBytes, isNotEmpty);

      final Archive archive = ZipDecoder().decodeBytes(zipBytes);
      final List<String> fileNames = archive.map((ArchiveFile f) => f.name).toList();
      expect(fileNames, contains('transactions.csv'));
      expect(fileNames, contains('savings.csv'));
      expect(fileNames, contains('investments.csv'));
      expect(fileNames, contains('recurring.csv'));
      expect(fileNames, contains('all_entries_master.csv'));
    });
  });

  group('CsvExcelDataService Import & Parsing Tests', () {
    test('parseCsvText parses Master CSV correctly', () {
      final String masterCsv = CsvExcelDataService.exportMasterCsv(testState);
      final CsvImportResult result = CsvExcelDataService.parseCsvText(masterCsv);

      expect(result.transactions.length, 2);
      expect(result.savings.length, 1);
      expect(result.investments.length, 1);
      expect(result.recurringTransactions.length, 1);
      expect(result.transactions.first.description, 'Grocery shopping "Special, Items"');
      expect(result.transactions.last.description, 'Monthly Salary - راتب شهري');
      expect(result.investments.first.installmentPlan.length, 2);
    });

    test('parseCsvText parses dedicated Transactions CSV', () {
      final String txCsv = CsvExcelDataService.exportTransactionsCsv(testState.transactions);
      final CsvImportResult result = CsvExcelDataService.parseCsvText(txCsv, defaultFileName: 'transactions.csv');

      expect(result.transactions.length, 2);
      expect(result.savings, isEmpty);
      expect(result.transactions.first.amount, 250.75);
    });

    test('parseCsvText parses dedicated Savings CSV', () {
      final String savCsv = CsvExcelDataService.exportSavingsCsv(testState.savings);
      final CsvImportResult result = CsvExcelDataService.parseCsvText(savCsv, defaultFileName: 'savings.csv');

      expect(result.savings.length, 1);
      expect(result.savings.first.id, 'sav_1');
      expect(result.savings.first.amount, 10000.0);
    });

    test('parseCsvText parses dedicated Investments CSV with installment plan', () {
      final String invCsv = CsvExcelDataService.exportInvestmentsCsv(testState.investments);
      final CsvImportResult result = CsvExcelDataService.parseCsvText(invCsv, defaultFileName: 'investments.csv');

      expect(result.investments.length, 1);
      expect(result.investments.first.id, 'inv_1');
      expect(result.investments.first.installmentPlan.length, 2);
      expect(result.investments.first.installmentPlan.first['amount'], 50000.0);
    });

    test('parseFileContent parses a ZIP archive of CSVs', () {
      final List<int> zipBytes = CsvExcelDataService.exportCsvZip(testState);
      final CsvImportResult result = CsvExcelDataService.parseFileContent(
        bytes: zipBytes,
        fileName: 'backup_data.zip',
      );

      // The zip contains individual CSVs + master CSV
      expect(result.transactions.isNotEmpty, isTrue);
      expect(result.savings.isNotEmpty, isTrue);
      expect(result.investments.isNotEmpty, isTrue);
      expect(result.recurringTransactions.isNotEmpty, isTrue);
    });
  });

  group('CsvExcelDataService Database Apply Tests', () {
    test('applyImport with merge mode keeps user credentials and merges data entries', () async {
      final LocalStorageService localStorage = LocalStorageService();
      final AppStateRepository repository = AppStateRepository(
        localStorage: localStorage,
      );
      final AppStateController controller = AppStateController(
        repository: repository,
      );

      await controller.updateState(
        AppStateModel.fromJson(<String, dynamic>{
          'userId': 'active_user_999',
          'userEmail': 'active@user.com',
          'mainCurrency': 'EGP',
          'transactions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'existing_tx',
              'type': 'expense',
              'date': '2026-02-01',
              'amount': 50.0,
              'currency': 'EGP',
              'category': 'General',
              'description': 'Existing item',
              'createdAt': '2026-02-01T00:00:00Z',
              'rolledOver': false,
            },
          ],
        }),
      );

      final CsvImportResult incomingData = CsvImportResult(
        transactions: <Transaction>[
          const Transaction(
            id: 'imported_tx',
            type: 'income',
            date: '2026-03-01',
            amount: 1200.0,
            currency: 'USD',
            category: 'Bonus',
            description: 'Imported bonus',
            createdAt: '2026-03-01T00:00:00Z',
            rolledOver: false,
          ),
        ],
      );

      await CsvExcelDataService.applyImport(
        controller: controller,
        data: incomingData,
        replace: false,
      );

      expect(controller.state.userId, 'active_user_999');
      expect(controller.state.userEmail, 'active@user.com');
      expect(controller.state.transactions.length, 2);
      expect(controller.state.transactions.map((t) => t.id), containsAll(<String>['existing_tx', 'imported_tx']));
    });

    test('applyImport with replace mode replaces entities while preserving user settings', () async {
      final LocalStorageService localStorage = LocalStorageService();
      final AppStateRepository repository = AppStateRepository(
        localStorage: localStorage,
      );
      final AppStateController controller = AppStateController(
        repository: repository,
      );

      await controller.updateState(
        AppStateModel.fromJson(<String, dynamic>{
          'userId': 'active_user_999',
          'userEmail': 'active@user.com',
          'mainCurrency': 'SAR',
          'transactions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'old_tx',
              'type': 'expense',
              'date': '2026-01-01',
              'amount': 10.0,
              'currency': 'SAR',
              'category': 'General',
              'description': 'Old item to replace',
              'createdAt': '2026-01-01T00:00:00Z',
              'rolledOver': false,
            },
          ],
        }),
      );

      final CsvImportResult incomingData = CsvImportResult(
        transactions: <Transaction>[
          const Transaction(
            id: 'new_tx',
            type: 'income',
            date: '2026-03-10',
            amount: 300.0,
            currency: 'SAR',
            category: 'Salary',
            description: 'New salary',
            createdAt: '2026-03-10T00:00:00Z',
            rolledOver: false,
          ),
        ],
      );

      await CsvExcelDataService.applyImport(
        controller: controller,
        data: incomingData,
        replace: true,
      );

      expect(controller.state.userId, 'active_user_999');
      expect(controller.state.mainCurrency, 'SAR');
      expect(controller.state.transactions.length, 1);
      expect(controller.state.transactions.first.id, 'new_tx');
    });
  });
}
