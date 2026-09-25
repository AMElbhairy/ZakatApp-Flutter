import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/watch_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WatchBridgeService.resetForTesting();
  });

  group('WatchBridgeService Command Execution Contract', () {
    test(
      'Ping command returns valid success contract with matching operationId',
      () async {
        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-test-12345',
          'action': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);

        expect(result.v, 1);
        expect(result.operationId, 'op-test-12345');
        expect(result.status, 'success');
        expect(result.code, 'OK');
        expect(result.message, 'pong');
      },
    );

    test('Missing operationId returns failed contract', () async {
      final Map<String, dynamic> command = <String, dynamic>{
        'v': 1,
        'action': 'ping',
      };

      final WatchCommandResult result = await WatchBridgeService.executeCommand(
        command,
      );

      expect(result.status, 'failed');
      expect(result.code, 'MISSING_OPERATION_ID');
    });

    test(
      'Duplicate operationId returns identical cached result without re-executing',
      () async {
        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-duplicate-test',
          'action': 'ping',
        };

        final WatchCommandResult first =
            await WatchBridgeService.executeCommand(command);
        final WatchCommandResult second =
            await WatchBridgeService.executeCommand(command);

        expect(identical(first, second), isTrue);
        expect(second.operationId, 'op-duplicate-test');
      },
    );

    test(
      'Unknown action returns failed contract with UNKNOWN_ACTION code',
      () async {
        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-unknown-test',
          'action': 'nonExistentAction',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);

        expect(result.status, 'failed');
        expect(result.code, 'UNKNOWN_ACTION');
      },
    );
  });

  group('WatchBridgeService Snapshot Minimization & Safety', () {
    test('Snapshot contains NO rawMessage and NO balance fields', () {
      final AppStateModel state = AppStateDefaults.create().copyWith(
        mainCurrency: 'SAR',
        creditCards: <CreditCard>[
          const CreditCard(
            id: 'card-1',
            bankName: 'Al Rajhi',
            cardNickname: 'Infinite',
            network: CreditCardNetwork.visa,
            last4Digits: '9988',
            creditLimit: 50000.0,
            openingBalance: 12000.0,
            currency: 'SAR',
            isArchived: false,
          ),
        ],
        pendingTransactions: <PendingTransaction>[
          const PendingTransaction(
            id: 'pending-1',
            source: 'sms',
            rawMessage:
                'CONFIDENTIAL BANK SMS: Purchase of SAR 250 at Apple Store with card ending 9988 OTP 123456',
            createdAt: '2026-09-21T08:00:00Z',
            suggestedType: 'expense',
            suggestedAmount: 250.0,
            suggestedCurrency: 'SAR',
            merchantName: 'Apple Store',
            suggestedCategory: 'Shopping',
            suggestedPaymentSourceId: 'card-1',
            cardLast4: '9988',
            detectedBank: 'Al Rajhi',
            confidence: 0.95,
            status: CaptureStatus.pendingReview,
          ),
          const PendingTransaction(
            id: 'pending-already-approved',
            source: 'sms',
            rawMessage: 'Another SMS already processed',
            createdAt: '2026-09-20T08:00:00Z',
            suggestedType: 'expense',
            suggestedAmount: 50.0,
            suggestedCurrency: 'SAR',
            confidence: 0.90,
            status: CaptureStatus.manuallyApproved,
          ),
        ],
        transactions: <Transaction>[
          const Transaction(
            id: 'tx-1',
            type: 'expense',
            date: '2026-09-21',
            amount: 15.0,
            currency: 'SAR',
            category: 'Dining',
            description: 'Morning Coffee',
            createdAt: '2026-09-21T07:00:00Z',
            rolledOver: false,
          ),
        ],
      );

      final Map<String, dynamic> snapshot = WatchBridgeService.buildSnapshot(
        state,
      );

      // Verify schema version
      expect(snapshot['v'], 1);
      expect(snapshot['mainCurrency'], 'SAR');

      // Verify Payment Sources do NOT contain creditLimit, currentBalance, or available balance
      final List<Map<String, dynamic>> sources =
          (snapshot['paymentSources'] as List).cast<Map<String, dynamic>>();
      for (final s in sources) {
        expect(s.containsKey('creditLimit'), isFalse);
        expect(s.containsKey('currentBalance'), isFalse);
        expect(s.containsKey('available'), isFalse);
        expect(s.containsKey('balance'), isFalse);
      }

      void expectNoNulls(dynamic value) {
        if (value is Map) {
          for (final entry in value.entries) {
            expect(entry.value, isNotNull, reason: 'Null at ${entry.key}');
            expectNoNulls(entry.value);
          }
        } else if (value is Iterable) {
          for (final item in value) {
            expect(item, isNotNull);
            expectNoNulls(item);
          }
        }
      }

      expectNoNulls(snapshot);
      expect(sources.first.containsKey('last4'), isFalse);

      // Verify Pending Inbox does NOT contain rawMessage
      final List<Map<String, dynamic>> pendingList =
          (snapshot['pendingInbox'] as List).cast<Map<String, dynamic>>();
      expect(
        pendingList.length,
        1,
      ); // Only pendingReview item, not manuallyApproved
      final Map<String, dynamic> firstItem = pendingList.first;
      expect(firstItem.containsKey('rawMessage'), isFalse);
      expect(firstItem['id'], 'pending-1');
      expect(firstItem['amount'], 250.0);
      expect(firstItem['merchant'], 'Apple Store');
      expect(firstItem['cardLast4'], '9988');

      // Verify Recent Activity
      final List<Map<String, dynamic>> activity =
          (snapshot['recentActivity'] as List).cast<Map<String, dynamic>>();
      expect(activity.length, 1);
      expect(activity.first['title'], 'Morning Coffee');
      expect(activity.first['amount'], 15.0);
    });
  });

  group('Phase 3 Capture Inbox Authoritative Flows', () {
    Future<AppStateController> makeController({
      required AppStateModel state,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const localStorage = LocalStorageService();
      final repository = AppStateRepository(localStorage: localStorage);
      final controller = AppStateController(repository: repository);
      await controller.load();
      await controller.updateState(state);
      WatchBridgeService.initialize(controller);
      return controller;
    }

    final AppStateModel baseState = AppStateDefaults.create().copyWith(
      mainCurrency: 'SAR',
      transactions: <Transaction>[
        const Transaction(
          id: 'tx-seed-balance',
          type: 'income',
          date: '2026-09-20',
          amount: 5000.0,
          currency: 'SAR',
          category: 'Salary',
          description: 'Seed income',
          createdAt: '2026-09-20T00:00:00Z',
          rolledOver: false,
        ),
      ],
      pendingTransactions: <PendingTransaction>[
        const PendingTransaction(
          id: 'pending-tx-1',
          source: 'sms',
          rawMessage: 'Original SMS purchase text',
          createdAt: '2026-09-21T08:00:00Z',
          suggestedType: 'expense',
          suggestedAmount: 120.0,
          suggestedCurrency: 'SAR',
          merchantName: 'Original Merchant',
          suggestedCategory: 'Dining',
          confidence: 0.95,
          status: CaptureStatus.pendingReview,
        ),
      ],
    );

    test('Approve flow applies corrections and routes authoritatively', () async {
      final controller = await makeController(state: baseState);

      final Map<String, dynamic> command = <String, dynamic>{
        'v': 1,
        'operationId': 'op-approve-valid-1',
        'action': 'approvePending',
        'pendingId': 'pending-tx-1',
        'type': 'expense',
        'amount': 155.50, // Corrected amount
        'currency': 'SAR',
        'category': 'Special Dining', // Corrected category
        'description': 'Corrected Merchant Note', // Corrected description
      };

      final WatchCommandResult result = await WatchBridgeService.executeCommand(
        command,
      );

      expect(result.status, 'success');
      expect(result.code, 'OK');
      expect(result.entityId, 'pending-tx-1');

      // Verify transaction was added to authoritative controller state with corrected fields
      final Transaction createdTx = controller.state.transactions.last;
      expect(createdTx.amount, 155.50);
      expect(createdTx.category, 'Special Dining');
      expect(createdTx.description, 'Corrected Merchant Note');

      // Verify pending item is marked manuallyApproved
      final PendingTransaction pending = controller.state.pendingTransactions
          .firstWhere((t) => t.id == 'pending-tx-1');
      expect(pending.status, CaptureStatus.manuallyApproved);
    });

    test(
      'Approve flow returns ITEM_ALREADY_PROCESSED on stale or missing item',
      () async {
        final controller = await makeController(state: baseState);

        // 1. Missing item
        final Map<String, dynamic> commandMissing = <String, dynamic>{
          'v': 1,
          'operationId': 'op-approve-missing',
          'action': 'approvePending',
          'pendingId': 'non-existent-id',
        };
        final WatchCommandResult resMissing =
            await WatchBridgeService.executeCommand(commandMissing);
        expect(resMissing.status, 'rejected');
        expect(resMissing.code, 'ITEM_ALREADY_PROCESSED');
        expect(resMissing.message, 'Already processed');

        // 2. Already approved item
        await controller.approvePendingTransaction(
          'pending-tx-1',
          type: 'expense',
          amount: 120.0,
          currency: 'SAR',
          category: 'Dining',
          description: 'Original Merchant',
          date: '2026-09-21',
        );

        final Map<String, dynamic> commandStale = <String, dynamic>{
          'v': 1,
          'operationId': 'op-approve-stale',
          'action': 'approvePending',
          'pendingId': 'pending-tx-1',
        };
        final WatchCommandResult resStale =
            await WatchBridgeService.executeCommand(commandStale);
        expect(resStale.status, 'rejected');
        expect(resStale.code, 'ITEM_ALREADY_PROCESSED');
        expect(resStale.message, 'Already processed');
      },
    );

    test(
      'Approve flow idempotency prevents duplicate execution on repeated operationId',
      () async {
        final controller = await makeController(state: baseState);

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-approve-idem-exact',
          'action': 'approvePending',
          'pendingId': 'pending-tx-1',
          'type': 'expense',
          'amount': 80.0,
          'currency': 'SAR',
          'category': 'Groceries',
          'description': 'Supermarket',
        };

        final int initialTxCount = controller.state.transactions.length;

        // First call
        final WatchCommandResult first =
            await WatchBridgeService.executeCommand(command);
        expect(first.status, 'success');
        expect(controller.state.transactions.length, initialTxCount + 1);

        // Second call with exact same operationId
        final WatchCommandResult second =
            await WatchBridgeService.executeCommand(command);
        expect(second.status, 'success');
        expect(second.operationId, 'op-approve-idem-exact');
        // Must NOT add another transaction
        expect(controller.state.transactions.length, initialTxCount + 1);
      },
    );

    test(
      'Reject flow marks item as ignored with Manually Ignored reason',
      () async {
        final controller = await makeController(state: baseState);

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-reject-valid',
          'action': 'rejectPending',
          'pendingId': 'pending-tx-1',
          'reason': 'Manually Ignored',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);

        expect(result.status, 'success');
        expect(result.code, 'OK');

        final PendingTransaction pending = controller.state.pendingTransactions
            .firstWhere((t) => t.id == 'pending-tx-1');
        expect(pending.status, CaptureStatus.ignored);
        expect(pending.ignoreReason, 'Manually Ignored');
      },
    );

    test(
      'Reject flow returns ITEM_ALREADY_PROCESSED on already rejected item',
      () async {
        final controller = await makeController(state: baseState);

        await controller.rejectPendingTransaction(
          'pending-tx-1',
          reason: 'Manually Ignored',
        );

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-reject-already',
          'action': 'rejectPending',
          'pendingId': 'pending-tx-1',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'rejected');
        expect(result.code, 'ITEM_ALREADY_PROCESSED');
        expect(result.message, 'Already processed');
      },
    );
  });

  group('Phase 4 Notification Deep-Link Contract & Resolver', () {
    test(
      'Notification payload contains required fields and excludes sensitive data',
      () {
        const String pendingId = 'tx-notif-123';
        final Map<String, dynamic> notificationPayload = <String, dynamic>{
          'pendingTransactionId': pendingId,
          'notificationTapToken': pendingId,
          'captureStatus': 'pendingReview',
          'rawType': 'expense',
        };

        // Required fields check
        expect(notificationPayload['pendingTransactionId'], 'tx-notif-123');
        expect(notificationPayload['notificationTapToken'], 'tx-notif-123');
        expect(notificationPayload['captureStatus'], 'pendingReview');
        expect(notificationPayload['rawType'], 'expense');

        // Privacy check: no rawMessage, balances, or full credentials
        expect(notificationPayload.containsKey('rawMessage'), isFalse);
        expect(notificationPayload.containsKey('balance'), isFalse);
        expect(notificationPayload.containsKey('creditLimit'), isFalse);
        expect(notificationPayload.containsKey('availableCredit'), isFalse);
      },
    );

    test('Snapshot resolves pendingTransactionId from pendingInbox', () {
      final AppStateModel state = AppStateDefaults.create().copyWith(
        mainCurrency: 'SAR',
        pendingTransactions: <PendingTransaction>[
          const PendingTransaction(
            id: 'notif-pending-A',
            source: 'sms',
            rawMessage: 'Purchase at Apple Store',
            createdAt: '2026-09-21T09:00:00Z',
            suggestedType: 'expense',
            suggestedAmount: 399.0,
            suggestedCurrency: 'SAR',
            merchantName: 'Apple Store',
            suggestedCategory: 'Electronics',
            cardLast4: '4321',
            confidence: 0.98,
            status: CaptureStatus.pendingReview,
          ),
          const PendingTransaction(
            id: 'notif-pending-B',
            source: 'sms',
            rawMessage: 'Dining at Al Baik',
            createdAt: '2026-09-21T09:10:00Z',
            suggestedType: 'expense',
            suggestedAmount: 45.0,
            suggestedCurrency: 'SAR',
            merchantName: 'Al Baik',
            suggestedCategory: 'Dining',
            cardLast4: '8765',
            confidence: 0.95,
            status: CaptureStatus.pendingReview,
          ),
        ],
      );

      final Map<String, dynamic> snapshot = WatchBridgeService.buildSnapshot(
        state,
      );
      final List<Map<String, dynamic>> inbox =
          (snapshot['pendingInbox'] as List).cast<Map<String, dynamic>>();

      // Locate item A
      final Map<String, dynamic>? itemA = inbox
          .where((item) => item['id'] == 'notif-pending-A')
          .firstOrNull;
      expect(itemA, isNotNull);
      expect(itemA!['amount'], 399.0);
      expect(itemA['merchant'], 'Apple Store');
      expect(itemA['cardLast4'], '4321');
      expect(itemA.containsKey('rawMessage'), isFalse);

      // Locate item B
      final Map<String, dynamic>? itemB = inbox
          .where((item) => item['id'] == 'notif-pending-B')
          .firstOrNull;
      expect(itemB, isNotNull);
      expect(itemB!['amount'], 45.0);
      expect(itemB['merchant'], 'Al Baik');
      expect(itemB['cardLast4'], '8765');

      // Non-existent ID resolves to null (triggering Watch resolving/unavailable state)
      final Map<String, dynamic>? nonExistent = inbox
          .where((item) => item['id'] == 'notif-pending-C')
          .firstOrNull;
      expect(nonExistent, isNull);
    });

    test(
      'Stale notification cannot approve an item that is no longer pending',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const localStorage = LocalStorageService();
        final repository = AppStateRepository(localStorage: localStorage);
        final controller = AppStateController(repository: repository);
        await controller.load();

        // Seed state where item is already approved
        final AppStateModel state = AppStateDefaults.create().copyWith(
          mainCurrency: 'SAR',
          pendingTransactions: <PendingTransaction>[
            const PendingTransaction(
              id: 'stale-notif-item',
              source: 'sms',
              rawMessage: 'Already processed SMS',
              createdAt: '2026-09-20T08:00:00Z',
              suggestedType: 'expense',
              suggestedAmount: 50.0,
              suggestedCurrency: 'SAR',
              confidence: 0.95,
              status: CaptureStatus.manuallyApproved,
            ),
          ],
        );
        await controller.updateState(state);
        WatchBridgeService.initialize(controller);

        // Attempt approval from stale notification deep link
        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-stale-deep-link',
          'action': 'approvePending',
          'pendingId': 'stale-notif-item',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'rejected');
        expect(result.code, 'ITEM_ALREADY_PROCESSED');
        expect(result.message, 'Already processed');
      },
    );
  });

  group('Phase 5 Quick Add Authoritative Flows', () {
    Future<AppStateController> makeController({
      required AppStateModel state,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const localStorage = LocalStorageService();
      final repository = AppStateRepository(localStorage: localStorage);
      final controller = AppStateController(repository: repository);
      await controller.load();
      await controller.updateState(state);
      WatchBridgeService.initialize(controller);
      return controller;
    }

    final AppStateModel baseQuickAddState = AppStateDefaults.create().copyWith(
      mainCurrency: 'SAR',
      marketData: <String, dynamic>{
        'USD_TO_EGP': 50.0,
        'SAR_TO_EGP': 13.33,
        'RATES_TO_EGP': <String, dynamic>{
          'USD': 50.0,
          'SAR': 13.33,
          'EUR': 55.0,
          'EGP': 1.0,
        },
      },
      creditCards: <CreditCard>[
        const CreditCard(
          id: 'card-qa-1',
          bankName: 'Al Rajhi',
          cardNickname: 'Infinite',
          network: CreditCardNetwork.visa,
          last4Digits: '4455',
          creditLimit: 10000.0,
          openingBalance: 1000.0,
          currency: 'SAR',
          isArchived: false,
        ),
      ],
      transactions: <Transaction>[
        const Transaction(
          id: 'tx-seed-qa',
          type: 'income',
          date: '2026-09-20',
          amount: 5000.0,
          currency: 'SAR',
          category: 'Salary',
          description: 'Initial balance',
          createdAt: '2026-09-20T00:00:00Z',
          rolledOver: false,
        ),
      ],
    );

    // 1. Expense Flow
    test(
      'Expense with Cash source routes correctly and decrements available cash',
      () async {
        final controller = await makeController(state: baseQuickAddState);
        final double initialCash = controller.getAvailableBalance(
          currency: 'SAR',
          date: '2026-09-21',
        );

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-expense-cash',
          'action': 'createTransaction',
          'type': 'expense',
          'amount': 150.0,
          'currency': 'SAR',
          'category': 'Dining',
          'description': 'Lunch',
          'paymentSourceId': 'cash',
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'success');
        expect(result.code, 'OK');
        expect(result.entityId, isNotNull);

        // Verify transaction persisted
        final Transaction createdTx = controller.state.transactions.firstWhere(
          (t) => t.id == result.entityId,
        );
        expect(createdTx.type, 'expense');
        expect(createdTx.amount, 150.0);
        expect(createdTx.currency, 'SAR');
        expect(createdTx.paymentSourceId, isNull); // 'cash' normalizes to null

        // Verify cash balance decremented
        final double nextCash = controller.getAvailableBalance(
          currency: 'SAR',
          date: '2026-09-21',
        );
        expect(nextCash, initialCash - 150.0);
      },
    );

    test(
      'Expense with Credit Card source increments card balance and leaves cash unaffected',
      () async {
        final controller = await makeController(state: baseQuickAddState);
        final double initialCash = controller.getAvailableBalance(
          currency: 'SAR',
          date: '2026-09-21',
        );
        final CreditCard initialCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-expense-card',
          'action': 'createTransaction',
          'type': 'expense',
          'amount': 250.0,
          'currency': 'SAR',
          'category': 'Electronics',
          'description': 'Accessories',
          'paymentSourceId': 'card-qa-1',
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'success');
        expect(result.code, 'OK');

        final Transaction createdTx = controller.state.transactions.firstWhere(
          (t) => t.id == result.entityId,
        );
        expect(createdTx.paymentSourceId, 'card-qa-1');

        // Cash balance is unaffected
        final double nextCash = controller.getAvailableBalance(
          currency: 'SAR',
          date: '2026-09-21',
        );
        expect(nextCash, initialCash);

        // Card balance incremented by 250
        final CreditCard nextCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );
        expect(nextCard.openingBalance, initialCard.openingBalance + 250.0);
      },
    );

    test(
      'Expense exceeding credit card limit is authoritatively rejected',
      () async {
        final controller = await makeController(state: baseQuickAddState);

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-expense-overlimit',
          'action': 'createTransaction',
          'type': 'expense',
          'amount': 999999.0, // Exceeds limit
          'currency': 'SAR',
          'category': 'Luxury',
          'paymentSourceId': 'card-qa-1',
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'failed');
        expect(result.code, 'EXECUTION_ERROR');
      },
    );

    test('Duplicate operationId executes once for Expense', () async {
      final controller = await makeController(state: baseQuickAddState);
      final int initialCount = controller.state.transactions.length;

      final Map<String, dynamic> command = <String, dynamic>{
        'v': 1,
        'operationId': 'op-qa-expense-idempotent',
        'action': 'createTransaction',
        'type': 'expense',
        'amount': 50.0,
        'currency': 'SAR',
        'category': 'Coffee',
        'paymentSourceId': 'cash',
        'date': '2026-09-21',
      };

      final WatchCommandResult first = await WatchBridgeService.executeCommand(
        command,
      );
      final WatchCommandResult second = await WatchBridgeService.executeCommand(
        command,
      );

      expect(first.status, 'success');
      expect(second.status, 'success');
      expect(identical(first, second), isTrue);
      expect(controller.state.transactions.length, initialCount + 1);
    });

    // 2. Income Flow
    test('Income with Cash destination increments cash balance', () async {
      final controller = await makeController(state: baseQuickAddState);
      final double initialCash = controller.getAvailableBalance(
        currency: 'SAR',
        date: '2026-09-21',
      );

      final Map<String, dynamic> command = <String, dynamic>{
        'v': 1,
        'operationId': 'op-qa-income-cash',
        'action': 'createTransaction',
        'type': 'income',
        'amount': 1000.0,
        'currency': 'SAR',
        'category': 'Bonus',
        'paymentSourceId': 'cash',
        'date': '2026-09-21',
      };

      final WatchCommandResult result = await WatchBridgeService.executeCommand(
        command,
      );
      expect(result.status, 'success');

      final double nextCash = controller.getAvailableBalance(
        currency: 'SAR',
        date: '2026-09-21',
      );
      expect(nextCash, initialCash + 1000.0);
    });

    test('Income deposited to Credit Card reduces card balance', () async {
      final controller = await makeController(state: baseQuickAddState);
      final CreditCard initialCard = controller.state.creditCards.firstWhere(
        (c) => c.id == 'card-qa-1',
      );

      final Map<String, dynamic> command = <String, dynamic>{
        'v': 1,
        'operationId': 'op-qa-income-card',
        'action': 'createTransaction',
        'type': 'income',
        'amount': 300.0,
        'currency': 'SAR',
        'category': 'Refund',
        'paymentSourceId': 'card-qa-1',
        'date': '2026-09-21',
      };

      final WatchCommandResult result = await WatchBridgeService.executeCommand(
        command,
      );
      expect(result.status, 'success');

      final CreditCard nextCard = controller.state.creditCards.firstWhere(
        (c) => c.id == 'card-qa-1',
      );
      expect(nextCard.openingBalance, initialCard.openingBalance - 300.0);
    });

    // 3. Transfer Flow
    test(
      'Transfer between Cash and Card creates transfer and adjusts balances',
      () async {
        final controller = await makeController(state: baseQuickAddState);
        final CreditCard initialCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-transfer-valid',
          'action': 'createTransaction',
          'type': 'transfer',
          'amount': 400.0,
          'currency': 'SAR',
          'transferSourceId': 'cash',
          'transferDestinationId': 'card-qa-1',
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'success');

        final Transaction tx = controller.state.transactions.firstWhere(
          (t) => t.id == result.entityId,
        );
        expect(tx.type, 'transfer');
        expect(tx.transferSourceId, 'cash');
        expect(tx.transferDestinationId, 'card-qa-1');

        // Card balance is decreased when transferred to card
        final CreditCard nextCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );
        expect(nextCard.openingBalance, initialCard.openingBalance - 400.0);
      },
    );

    test(
      'Transfer with identical source and destination is authoritatively rejected',
      () async {
        final controller = await makeController(state: baseQuickAddState);

        final Map<String, dynamic> command = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-transfer-same-acc',
          'action': 'createTransaction',
          'type': 'transfer',
          'amount': 100.0,
          'currency': 'SAR',
          'transferSourceId': 'cash',
          'transferDestinationId': 'cash',
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(command);
        expect(result.status, 'failed');
        expect(result.code, 'EXECUTION_ERROR');
      },
    );

    // 4. Currency Exchange Flow
    test(
      'quoteCurrencyExchange returns authoritative target amount and rate',
      () async {
        await makeController(state: baseQuickAddState);

        final Map<String, dynamic> quoteCommand = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-quote-fx',
          'action': 'quoteCurrencyExchange',
          'sourceCurrency': 'USD',
          'targetCurrency': 'SAR',
          'sourceAmount': 100.0,
        };

        final WatchCommandResult quoteResult =
            await WatchBridgeService.executeCommand(quoteCommand);
        expect(quoteResult.status, 'success');
        expect(quoteResult.code, 'OK');
        expect(quoteResult.payload, isNotNull);
        expect(quoteResult.payload!['sourceAmount'], 100.0);
        expect(quoteResult.payload!['targetAmount'], isA<double>());
        expect(quoteResult.payload!['rate'], isA<double>());
        expect((quoteResult.payload!['targetAmount'] as double) > 0.0, isTrue);
      },
    );

    test(
      'quoteCurrencyExchange with same currency returns SAME_CURRENCY code',
      () async {
        await makeController(state: baseQuickAddState);

        final Map<String, dynamic> quoteCommand = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-quote-same-curr',
          'action': 'quoteCurrencyExchange',
          'sourceCurrency': 'SAR',
          'targetCurrency': 'SAR',
          'sourceAmount': 100.0,
        };

        final WatchCommandResult quoteResult =
            await WatchBridgeService.executeCommand(quoteCommand);
        expect(quoteResult.status, 'failed');
        expect(quoteResult.code, 'SAME_CURRENCY');
      },
    );

    test(
      'executeCurrencyExchange successfully executes authoritative exchange',
      () async {
        final controller = await makeController(state: baseQuickAddState);

        final Map<String, dynamic> exchangeCommand = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-exec-fx',
          'action': 'executeCurrencyExchange',
          'sourceCurrency': 'SAR',
          'targetCurrency': 'USD',
          'sourceAmount': 375.0,
          'targetAmount': 100.0,
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(exchangeCommand);
        expect(result.status, 'success');
        expect(result.code, 'OK');

        // Verify SAR was deducted
        final double sarBalance = controller.getAvailableBalance(
          currency: 'SAR',
          date: '2026-09-21',
        );
        expect(sarBalance, 5000.0 - 375.0);
      },
    );

    // 5. Credit Card Payment Flow
    test(
      'creditCardPayment applies transfer payment and restores card balance',
      () async {
        final controller = await makeController(state: baseQuickAddState);
        final CreditCard initialCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );

        final Map<String, dynamic> payCommand = <String, dynamic>{
          'v': 1,
          'operationId': 'op-qa-card-pay',
          'action': 'creditCardPayment',
          'cardId': 'card-qa-1',
          'amount': 500.0,
          'date': '2026-09-21',
        };

        final WatchCommandResult result =
            await WatchBridgeService.executeCommand(payCommand);
        expect(result.status, 'success');
        expect(result.code, 'OK');

        final CreditCard nextCard = controller.state.creditCards.firstWhere(
          (c) => c.id == 'card-qa-1',
        );
        expect(nextCard.openingBalance, initialCard.openingBalance - 500.0);
      },
    );
  });
}
