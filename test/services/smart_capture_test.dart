import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/core/theme/app_colors.dart';
import 'package:zakatapp_flutter/core/theme/app_theme.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/account/notifications_screen.dart';
import 'package:zakatapp_flutter/services/apple_shortcuts_service.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  group('PendingTransaction Model', () {
    test('serialization and deserialization roundtrip', () {
      const original = PendingTransaction(
        id: 'pt-123',
        source: PendingTransactionSource.sms,
        sourceIdentifier: 'HSBC',
        rawMessage: 'Paid EGP 250 at Carrefour',
        createdAt: '2026-06-14T09:00:00Z',
        suggestedType: 'expense',
        suggestedAmount: 250.0,
        suggestedCurrency: 'EGP',
        suggestedDescription: 'Carrefour Groceries',
        merchantName: 'Carrefour',
        confidence: 0.95,
        status: CaptureStatus.pendingReview,
        parserVersion: 'v1.0',
        detectedBank: 'HSBC Bank',
        requiresReview: true,
        isRead: false,
      );

      final json = original.toJson();
      final decoded = PendingTransaction.fromJson(json);

      expect(decoded, equals(original));
      expect(decoded.id, 'pt-123');
      expect(decoded.sourceDisplayLabel, 'SMS Import');
      expect(decoded.sourceIdentifier, 'HSBC');
      expect(decoded.requiresReview, isTrue);
      expect(decoded.isRead, isFalse);
    });

    test('backward compatibility deserialization', () {
      final minimalJson = <String, dynamic>{
        'id': 'pt-456',
        'source': 'shortcut',
        'rawMessage': 'EGP 500 received',
        'createdAt': '2026-06-14T10:00:00Z',
        'suggestedType': 'income',
        'confidence': 1.0,
        'status': 'pendingReview',
      };

      final decoded = PendingTransaction.fromJson(minimalJson);

      expect(decoded.id, 'pt-456');
      expect(decoded.source, 'shortcut');
      expect(decoded.sourceDisplayLabel, 'Apple Automation');
      expect(decoded.suggestedAmount, isNull);
      expect(decoded.requiresReview, isTrue); // default fallback
      expect(decoded.isRead, isFalse); // default fallback
    });
  });

  group('AppStateController and Pending Transactions', () {
    setUp(() {
      AppleShortcutsService.resetForTests();
    });

    Future<AppStateController> makeController() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const localStorage = LocalStorageService();
      final repository = AppStateRepository(localStorage: localStorage);
      final controller = AppStateController(repository: repository);
      await controller.load();
      return controller;
    }

    test('add, remove, reject, and clear actions', () async {
      final controller = await makeController();
      expect(controller.state.pendingTransactions, isEmpty);

      // Create
      await controller.createPendingTransaction(
        source: PendingTransactionSource.manual,
        rawMessage: 'Manual SMS paste test',
        suggestedType: 'expense',
        confidence: 0.8,
        suggestedAmount: 120.0,
        suggestedCurrency: 'EGP',
      );

      expect(controller.state.pendingTransactions, hasLength(1));
      final added = controller.state.pendingTransactions.first;
      expect(added.sourceDisplayLabel, 'Manual Entry');
      expect(added.suggestedAmount, 120.0);
      expect(added.status, CaptureStatus.pendingReview);
      expect(added.isRead, isFalse);

      // Mark as read
      await controller.markPendingTransactionsAsRead();
      expect(controller.state.pendingTransactions.first.isRead, isTrue);

      // Reject
      await controller.rejectPendingTransaction(added.id);
      expect(
        controller.state.pendingTransactions.first.status,
        CaptureStatus.ignored,
      );
      expect(controller.state.pendingTransactions.first.reviewedAt, isNotNull);

      // Clear
      await controller.clearPendingTransactions();
      expect(controller.state.pendingTransactions, isEmpty);
    });

    test(
      'AppleShortcutsService routes shortcut payloads into Smart Capture',
      () async {
        final controller = await makeController();
        AppleShortcutsService.initialize(controller);

        final bool result =
            await AppleShortcutsService.handleLogBankMessagePayload(
              <String, dynamic>{'messageText': 'Purchase at Talabat SAR 45.50'},
            );

        expect(result, isTrue);
        expect(controller.state.pendingTransactions, hasLength(1));
        final pending = controller.state.pendingTransactions.first;
        expect(pending.source, PendingTransactionSource.shortcut);
        expect(pending.sourceDisplayLabel, 'Apple Automation');
        expect(pending.sourceIdentifier, 'Apple Automation');
        expect(controller.state.captureAnalytics.capturedFromAppleShortcuts, 1);
      },
    );

    test(
      'AppleShortcutsService drains queued shortcut payloads on initialize',
      () async {
        final controller = await makeController();

        const MethodChannel nativeChannel = MethodChannel(
          'com.zakahwealth.smartcapture.native',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(nativeChannel, (MethodCall call) async {
              if (call.method == 'markShortcutServiceReady') {
                return true;
              }
              if (call.method == 'getPendingShortcutMessages') {
                return <String>['Purchase at Talabat SAR 45.50'];
              }
              return null;
            });

        AppleShortcutsService.initialize(controller);

        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(controller.state.pendingTransactions, hasLength(1));
        expect(
          controller.state.pendingTransactions.single.merchantName,
          'Talabat',
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(nativeChannel, null);
      },
    );

    test(
      'simulateShortcutCapture developer helper routes Talabat mixed text',
      () async {
        final controller = await makeController();
        AppleShortcutsService.initialize(controller);

        final bool result = await AppleShortcutsService.simulateShortcutCapture(
          'شكراً لاستخدامك بطاقة بنك مصر… Talabat … EGP 378.00',
        );

        expect(result, isTrue);
        expect(controller.state.pendingTransactions, hasLength(1));
        final capture = controller.state.pendingTransactions.single;
        expect(capture.merchantName, 'Talabat');
        expect(capture.suggestedCategory, 'Food & Dining');
        expect(capture.confidence, greaterThanOrEqualTo(0.95));
      },
    );

    test(
      'simulateShortcutCapture auto approves Talabat mixed text when rule is enabled',
      () async {
        final controller = await makeController();
        await controller.setSmartCaptureAutoApproveEnabled(true);
        AppleShortcutsService.initialize(controller);

        final bool result = await AppleShortcutsService.simulateShortcutCapture(
          'شكراً لاستخدامك بطاقة بنك مصر… Talabat … EGP 378.00',
        );

        expect(result, isTrue);
        expect(controller.state.pendingTransactions, hasLength(1));
        final capture = controller.state.pendingTransactions.single;
        expect(capture.merchantName, 'Talabat');
        expect(capture.suggestedCategory, 'Food & Dining');
        expect(capture.status, CaptureStatus.autoApproved);
        expect(capture.approvalSource, ApprovalSource.auto);
        expect(controller.state.transactions, hasLength(1));
        expect(controller.state.transactions.single.category, 'Food & Dining');
      },
    );

    test('AppleShortcutsService rejects empty shortcut payloads', () async {
      final controller = await makeController();
      AppleShortcutsService.initialize(controller);

      final bool result =
          await AppleShortcutsService.handleLogBankMessagePayload(
            <String, dynamic>{'messageText': '   '},
          );

      expect(result, isFalse);
      expect(controller.state.pendingTransactions, isEmpty);
    });

    test('soft limit of 500 items sorted by createdAt (newest kept)', () async {
      final controller = await makeController();

      // Push 501 items. Let's make the 501st have an old createdAt so it gets pruned.
      final oldest = PendingTransaction(
        id: 'oldest',
        source: 'manual',
        rawMessage: 'old message',
        createdAt: '2026-06-01T00:00:00Z',
        suggestedType: 'expense',
        confidence: 1.0,
        status: CaptureStatus.pendingReview,
      );
      await controller.addPendingTransaction(oldest);

      // Push 500 newer items
      for (int i = 0; i < 500; i++) {
        final item = PendingTransaction(
          id: 'item-$i',
          source: 'manual',
          rawMessage: 'message $i',
          createdAt: '2026-06-14T${(i % 24).toString().padLeft(2, '0')}:00:00Z',
          suggestedType: 'expense',
          confidence: 1.0,
          status: CaptureStatus.pendingReview,
        );
        await controller.addPendingTransaction(item);
      }

      // Check count is capped at 500
      expect(controller.state.pendingTransactions, hasLength(500));

      // Verify that the oldest transaction was pruned
      final hasOldest = controller.state.pendingTransactions.any(
        (t) => t.id == 'oldest',
      );
      expect(hasOldest, isFalse);
    });

    test('complete isolation from calculations', () async {
      final controller = await makeController();

      // Check initial Zakat and Net Worth
      final initialWealth = ZakatEngineService.calculateTotalWealthEgp(
        transactions: controller.state.transactions,
        savings: controller.state.savings,
        investments: controller.state.investments,
        marketData: MarketData.fromJson(controller.state.marketData),
        lastRollover: controller.state.lastRollover,
      );

      // Add a pending transaction with high suggested amount (e.g. 1,000,000)
      await controller.createPendingTransaction(
        source: PendingTransactionSource.sms,
        rawMessage: 'Salary of EGP 1000000 deposited',
        suggestedType: 'income',
        confidence: 1.0,
        suggestedAmount: 1000000.0,
        suggestedCurrency: 'EGP',
      );

      // Verify calculations remain identical
      final wealthAfterPending = ZakatEngineService.calculateTotalWealthEgp(
        transactions: controller.state.transactions,
        savings: controller.state.savings,
        investments: controller.state.investments,
        marketData: MarketData.fromJson(controller.state.marketData),
        lastRollover: controller.state.lastRollover,
      );
      expect(wealthAfterPending, equals(initialWealth));

      // Verify lists of real items remain empty
      expect(controller.state.transactions, isEmpty);
      expect(controller.state.savings, isEmpty);
      expect(controller.state.investments, isEmpty);
    });

    test('backup and restore persistence', () async {
      final controller = await makeController();

      // Add pending transaction
      await controller.createPendingTransaction(
        source: PendingTransactionSource.sms,
        rawMessage: 'EGP 50 details',
        suggestedType: 'expense',
        confidence: 0.9,
      );
      final originalPt = controller.state.pendingTransactions.first;

      // Export state
      final exportedJson = BackupService.exportBackup(
        controller.state.toJson(),
        userId: 'user-1',
        provider: 'google',
        email: 'user@example.com',
      );

      // Clear local data
      await controller.clearLocalData();
      expect(controller.state.pendingTransactions, isEmpty);

      // Restore backup
      final rawState = BackupService.extractRawState(exportedJson);
      final restoredState = AppStateModel.fromJson(rawState);
      await controller.updateState(restoredState);

      // Verify restored pending transaction properties match original
      expect(controller.state.pendingTransactions, hasLength(1));
      final restoredPt = controller.state.pendingTransactions.first;
      expect(restoredPt, equals(originalPt));
    });

    test(
      'approvePendingTransaction creates correct transaction and blocks duplicate approval',
      () async {
        final controller = await makeController();

        await controller.createPendingTransaction(
          source: PendingTransactionSource.sms,
          rawMessage: 'Paid EGP 150 at Supermarket',
          suggestedType: 'expense',
          confidence: 0.9,
          suggestedAmount: 150.0,
          suggestedCurrency: 'EGP',
          suggestedDescription: 'Supermarket Expense',
        );

        final pt = controller.state.pendingTransactions.first;
        expect(pt.status, CaptureStatus.pendingReview);
        expect(pt.linkedTransactionId, isNull);

        // Approve as expense
        await controller.approvePendingTransaction(
          pt.id,
          type: 'expense',
          amount: 150.0,
          currency: 'EGP',
          category: 'Groceries',
          description: 'Approved Supermarket Expense',
          date: '2026-06-14',
        );

        // Verify Transaction was created
        expect(controller.state.transactions, hasLength(1));
        final tx = controller.state.transactions.first;
        expect(tx.amount, 150.0);
        expect(tx.type, 'expense');
        expect(tx.category, 'Groceries');

        // Verify pending transaction updated
        final updatedPt = controller.state.pendingTransactions.first;
        expect(updatedPt.status, CaptureStatus.manuallyApproved);
        expect(updatedPt.linkedTransactionId, tx.id);
        expect(updatedPt.reviewedAt, isNotNull);

        // Attempt duplicate approval
        expect(
          () => controller.approvePendingTransaction(
            pt.id,
            type: 'expense',
            amount: 150.0,
            currency: 'EGP',
            category: 'Groceries',
            description: 'Approved Supermarket Expense',
            date: '2026-06-14',
          ),
          throwsStateError,
        );
      },
    );

    test(
      'approvePendingTransaction creates savings for metal purchase',
      () async {
        final controller = await makeController();

        await controller.createPendingTransaction(
          source: PendingTransactionSource.shortcut,
          rawMessage: 'Bought 10g Gold',
          suggestedType: 'gold_purchase',
          confidence: 0.95,
          suggestedAmount: 10.0,
          suggestedCurrency: 'grams',
        );

        final pt = controller.state.pendingTransactions.first;

        await controller.approvePendingTransaction(
          pt.id,
          type: 'gold_purchase',
          amount: 10.0,
          currency: 'grams',
          category: 'Gold',
          description: 'Gold gram purchase',
          date: '2026-06-14',
        );

        expect(controller.state.savings, hasLength(1));
        final saving = controller.state.savings.first;
        expect(saving.assetType, 'gold');
        expect(saving.amount, 10.0);
        expect(saving.unit, 'GRAMS');
        expect(saving.remainingAmount, 10.0);

        final updatedPt = controller.state.pendingTransactions.first;
        expect(updatedPt.status, CaptureStatus.manuallyApproved);
        expect(updatedPt.linkedTransactionId, saving.id);
      },
    );

    test('approvePendingTransaction creates InvestmentAsset', () async {
      final controller = await makeController();

      await controller.createPendingTransaction(
        source: PendingTransactionSource.manual,
        rawMessage: 'Invested 5000 in Stock Market',
        suggestedType: 'investment',
        confidence: 0.85,
        suggestedAmount: 5000.0,
        suggestedCurrency: 'USD',
      );

      final pt = controller.state.pendingTransactions.first;

      await controller.approvePendingTransaction(
        pt.id,
        type: 'investment',
        amount: 5000.0,
        currency: 'USD',
        category: 'Stocks',
        description: 'Stock investment',
        date: '2026-06-14',
      );

      expect(controller.state.investments, hasLength(1));
      final investment = controller.state.investments.first;
      expect(investment.marketValue, 5000.0);
      expect(investment.currency, 'USD');
      expect(investment.ownershipSharePct, 100.0);

      final updatedPt = controller.state.pendingTransactions.first;
      expect(updatedPt.status, CaptureStatus.manuallyApproved);
      expect(updatedPt.linkedTransactionId, investment.id);
    });

    test('bilingual regex parser handles typical bank texts and maps correctly', () {
      final inputs = [
        // English
        {
          'text': 'Salary credited SAR 8000',
          'type': 'income',
          'amount': 8000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Salary Deposit',
        },
        {
          'text': 'POS Purchase Carrefour SAR 250',
          'type': 'expense',
          'amount': 250.0,
          'currency': 'SAR',
          'confidence': 0.85,
          'merchant': 'Carrefour',
          'desc': 'Purchase at Carrefour',
        },
        {
          'text': 'Transfer SAR 5000',
          'type': 'transfer',
          'amount': 5000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Bank Transfer',
        },

        // Arabic
        {
          'text': 'تم إيداع راتب بقيمة 8000 ريال',
          'type': 'income',
          'amount': 8000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Salary Deposit',
        },
        {
          'text': 'عملية شراء بقيمة 250 ريال من كارفور',
          'type': 'expense',
          'amount': 250.0,
          'currency': 'SAR',
          'confidence': 0.85,
          'merchant': 'كارفور',
          'desc': 'Purchase at كارفور',
        },
        {
          'text': 'تم تحويل 5000 ريال',
          'type': 'transfer',
          'amount': 5000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Bank Transfer',
        },

        // Phase 3.1 Hardening cases
        {
          'text':
              'PoS purchase\nCard:0669\nAt: Saudi Cre\nAmount:40 SAR\nBalance:1460 SAR\n12/6/26 00:20',
          'type': 'expense',
          'amount': 40.0,
          'currency': 'SAR',
          'confidence': 0.85,
          'merchant': 'Saudi Cre',
          'desc': 'Purchase at Saudi Cre',
        },
        {
          'text': 'Salary credited SAR 8000\nBalance SAR 12000',
          'type': 'income',
          'amount': 8000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Salary Deposit',
        },
        {
          'text': 'Transfer SAR 5000\nRemaining Balance SAR 10000',
          'type': 'transfer',
          'amount': 5000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Bank Transfer',
        },

        // Phase 3.2 Production Hardening cases
        {
          'text': 'بطاقة:0669\nمبلغ: SAR 373.99\nالرصيد: 500 ريال',
          'type': 'expense',
          'amount': 373.99,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'رقم الحساب:**5000\nمبلغ: EGP 221.52',
          'type': 'expense',
          'amount': 221.52,
          'currency': 'EGP',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'POS Purchase\nAmount: SAR 10.65\nالرصيد: 19,302.84 ريال',
          'type': 'expense',
          'amount': 10.65,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text':
              'تم سداد البطاقة\nمبلغ: SAR 428.78\nحد الصرف المتبقي: 20,000 SAR',
          'type': 'transfer',
          'amount': 428.78,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Bank Transfer',
        },
        {
          'text':
              'مبلغ: USD 134.92\nرسوم العملية: SAR 11.65\nإجمالي المبلغ المستحق: SAR 518.19',
          'type': 'expense',
          'amount': 518.19,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'تم إضافة مبلغ 200.00 EGP إلى حسابك',
          'type': 'transfer',
          'amount': 200.0,
          'currency': 'EGP',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Account Deposit',
        },
        {
          'text': 'Debit Internal Transfer\nTransfer SAR 5000',
          'type': 'transfer',
          'amount': 5000.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Bank Transfer',
        },
        {
          'text': 'من: ToYou\nAmount: SAR 100',
          'type': 'expense',
          'amount': 100.0,
          'currency': 'SAR',
          'confidence': 1.0,
          'merchant': 'ToYou',
          'desc': 'ToYou Order',
        },
        {
          'text': 'من: talabat.com\nAmount: EGP 150',
          'type': 'expense',
          'amount': 150.0,
          'currency': 'EGP',
          'confidence': 1.0,
          'merchant': 'Talabat',
          'desc': 'Talabat Purchase',
        },
        {
          'text': 'لدى: WHOOP\nAmount: USD 30',
          'type': 'expense',
          'amount': 30.0,
          'currency': 'USD',
          'confidence': 1.0,
          'merchant': 'WHOOP',
          'desc': 'WHOOP Subscription',
        },
        {
          'text':
              'Credit Transfer Local\nAmount: SR 1194.30\nFrom: شركة الساحلية للمقاولات',
          'type': 'income',
          'amount': 1194.30,
          'currency': 'SAR',
          'confidence': 0.85,
          'merchant': 'شركة الساحلية للمقاولات',
          'desc': 'Income from شركة الساحلية للمقاولات',
        },
        {
          'text':
              'EGP 221.52\nFee SAR 0.37\nExchange Rate 0.07\nTotal Due SAR 16.44',
          'type': 'expense',
          'amount': 16.44,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'Purchase: 1160 SAR\nFee: 23.20 SAR\nTotal Due: 1183.20 SAR',
          'type': 'expense',
          'amount': 1183.20,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'Amount: SR 50',
          'type': 'expense',
          'amount': 50.0,
          'currency': 'SAR',
          'confidence': 0.60,
          'merchant': null,
          'desc': 'Expense Capture',
        },
        {
          'text': 'شراء دولي\napple pay\ntalabat',
          'type': 'expense',
          'amount': null,
          'currency': null,
          'confidence': 0.95,
          'merchant': 'Talabat',
          'desc': 'Talabat Purchase',
        },
      ];

      for (final input in inputs) {
        final parsed = SmartCaptureParser.parse(input['text'] as String);
        expect(
          parsed.type,
          equals(input['type']),
          reason: 'Failed type for ${input['text']}',
        );
        expect(
          parsed.amount,
          equals(input['amount']),
          reason: 'Failed amount for ${input['text']}',
        );
        expect(
          parsed.currency,
          equals(input['currency']),
          reason: 'Failed currency for ${input['text']}',
        );
        expect(
          parsed.confidence,
          equals(input['confidence']),
          reason: 'Failed confidence for ${input['text']}',
        );
        expect(
          parsed.merchantName,
          equals(input['merchant']),
          reason: 'Failed merchant for ${input['text']}',
        );
        expect(
          parsed.description,
          equals(input['desc']),
          reason: 'Failed description for ${input['text']}',
        );
        expect(
          parsed.isValid,
          isTrue,
          reason: 'Expected valid transaction for ${input['text']}',
        );
      }
    });

    test(
      'merchant labels beat location metadata and known aliases resolve',
      () {
        final talabat = SmartCaptureParser.parse(
          'Bank Misr purchase EGP 150 using card 1234 at TALABAT.COM',
        );
        expect(talabat.merchantName, 'Talabat');
        expect(talabat.suggestedCategory, 'Food & Dining');
        expect(talabat.confidence, greaterThanOrEqualTo(0.95));

        final tamimi = SmartCaptureParser.parse(
          'شراء\nAmount: SAR 100\nمن: S505 TAMIMI MARKET\nفي: SA',
        );
        expect(tamimi.merchantName, 'Tamimi Market');
        expect(tamimi.suggestedCategory, 'Groceries');
        expect(tamimi.confidence, greaterThanOrEqualTo(0.95));

        final locationOnly = SmartCaptureParser.parse(
          'Purchase amount: SAR 100\nفي: SA',
        );
        expect(locationOnly.merchantName, isNull);
        expect(locationOnly.confidence, 0.60);

        final mixedRtl = SmartCaptureParser.parse(
          'شكراً لاستخدامك بطاقة بنك مصر… Talabat … EGP 378.00',
        );
        expect(mixedRtl.merchantName, 'Talabat');
        expect(mixedRtl.suggestedCategory, 'Food & Dining');
        expect(mixedRtl.confidence, greaterThanOrEqualTo(0.95));
      },
    );

    test(
      'priority merchant patterns extract labeled Arabic and English merchants',
      () {
        final talabatMaa = SmartCaptureParser.parse(
          'تم خصم 265.82EGP من بطاقة الخصم المباشر رقم 6461\n'
          'By Mobile payment\n'
          'عند Talabat Maa\n'
          'يوم 08/06 الساعة 16:14\n'
          'المتاح 10041.27',
        );
        expect(talabatMaa.merchantName, 'Talabat');
        expect(talabatMaa.suggestedCategory, 'Food & Dining');
        expect(talabatMaa.confidence, greaterThanOrEqualTo(0.95));

        final talabat = SmartCaptureParser.parse(
          'تم خصم 265.82EGP من بطاقة الخصم المباشر رقم 6461\n'
          'عند Talabat\n'
          'يوم 08/06 الساعة 16:14',
        );
        expect(talabat.merchantName, 'Talabat');
        expect(talabat.suggestedCategory, 'Food & Dining');
        expect(talabat.confidence, greaterThanOrEqualTo(0.95));

        final fawry = SmartCaptureParser.parse(
          'عند FAWRY*TARSHOUBY PHAR\nAmount: EGP 150',
        );
        expect(fawry.merchantName, 'FAWRY*TARSHOUBY PHAR');

        final jood = SmartCaptureParser.parse('At: JOOD\nAmount: SAR 30');
        expect(jood.merchantName, 'JOOD');

        final tamimi = SmartCaptureParser.parse(
          'PoS\nAt: S505 TAMIMI MARKET\nAmount: SAR 100',
        );
        expect(tamimi.merchantName, 'Tamimi Market');
        expect(tamimi.suggestedCategory, 'Groceries');
        expect(tamimi.confidence, greaterThanOrEqualTo(0.95));
      },
    );

    test(
      'bank account deposit to account is classified as transfer with no merchant',
      () {
        final parsed = SmartCaptureParser.parse(
          'تم إضافة مبلغ 1294.25 EGP من xxx7127 إلى حساب رقم xxx7443 في 07-JUN-2026',
        );

        expect(parsed.type, 'transfer');
        expect(parsed.amount, 1294.25);
        expect(parsed.currency, 'EGP');
        expect(parsed.merchantName, isNull);
        expect(parsed.description, 'Account Deposit');
      },
    );

    test(
      'built-in override takes precedence and reset restores default',
      () async {
        final controller = await makeController();
        await controller.saveCustomMerchantRule(
          const MerchantRule(
            merchantName: 'Talabat',
            categoryId: 'Family Expenses',
            defaultType: 'expense',
            autoApprove: false,
            usageCount: 0,
            confidence: 1,
            source: 'custom',
            aliases: <String>['talabat.com', 'talabat app', 'طلبات'],
            isBuiltinOverride: true,
            builtinKey: 'talabat',
          ),
        );

        await controller.createPendingTransactionFromMessage(
          'Purchase amount: EGP 100 at talabat.com',
          'sms',
        );
        expect(
          controller.state.pendingTransactions.single.suggestedCategory,
          'Family Expenses',
        );

        await controller.clearPendingTransactions();
        await controller.resetBuiltinMerchantRule('Talabat');
        await controller.createPendingTransactionFromMessage(
          'Purchase amount: EGP 100 at talabat.com',
          'sms',
        );
        expect(
          controller.state.pendingTransactions.single.suggestedCategory,
          'Food & Dining',
        );
      },
    );

    test('disabled built-in override does not apply or auto approve', () async {
      final controller = await makeController();
      await controller.setSmartCaptureAutoApproveEnabled(true);
      await controller.saveCustomMerchantRule(
        const MerchantRule(
          merchantName: 'Talabat',
          categoryId: 'Family Expenses',
          defaultType: 'expense',
          autoApprove: true,
          usageCount: 0,
          confidence: 1,
          source: 'custom',
          enabled: false,
          isBuiltinOverride: true,
          builtinKey: 'talabat',
        ),
      );

      await controller.createPendingTransactionFromMessage(
        'Purchase amount: EGP 100 at Talabat',
        'sms',
      );
      final capture = controller.state.pendingTransactions.single;
      expect(capture.suggestedCategory, 'Other');
      expect(capture.status, CaptureStatus.pendingReview);
      expect(capture.confidence, 0.85);
    });

    test(
      'declined and failed transactions are marked as invalid and not stored',
      () {
        final declinedMessages = [
          'Transaction Declined: Insufficient funds\nAmount: SAR 44.99',
          'تم رفض عملية الشراء بقيمة 100 ريال',
          'Declined Purchase at Amazon EGP 500',
          'Transaction failed: card blocked',
        ];

        for (final msg in declinedMessages) {
          final parsed = SmartCaptureParser.parse(msg);
          expect(
            parsed.isValid,
            isFalse,
            reason: 'Expected invalid transaction for: $msg',
          );
        }
      },
    );

    test('OTP and verification code messages are excluded from smart capture', () {
      final parsed = SmartCaptureParser.parse(
        'عميلنا العزيز، برجاء عدم الافصاح عن الكود OTP: 65657 الصالح لمره واحدة '
        'لإتمام معاملة الدفع بمبلغ EGP 105.70 من E-FINANCE بطاقة رقم xxxx-xxxx-xxxx-8799 '
        'و عدم مشاركته مع أي طرف بأي وسيلة كانت.',
      );

      expect(parsed.isValid, isFalse);
      expect(parsed.ignoreReason, 'Verification Code Message');
      expect(parsed.description, 'Verification Code Message');
      expect(parsed.amount, isNull);
      expect(parsed.currency, isNull);
      expect(parsed.merchantName, isNull);
    });

    test('bank purchase alerts with balance and URL still parse correctly', () {
      final parsed = SmartCaptureParser.parse(
        'شكرًا لاستخدامك بطاقة بنك مصر ****8799، تم الآن خصم EGP 105.70'
        'عند  E-Finance يوم 15/06 ، الرصيد المتاح EGP 367.84 '
        'لمزيد من المعلومات عن الحساب، تفضل بزيارة الرابط التالي https://bnkmsr.com/online',
      );

      expect(parsed.isValid, isTrue);
      expect(parsed.type, 'expense');
      expect(parsed.amount, 105.70);
      expect(parsed.currency, 'EGP');
      expect(parsed.merchantName, 'E-Finance');
      expect(parsed.description, 'Purchase at E-Finance');
    });

    test(
      'createPendingTransactionFromMessage parses and inserts transaction correctly',
      () async {
        final controller = await makeController();

        await controller.createPendingTransactionFromMessage(
          'Salary credited SAR 8000',
          'manual',
        );

        expect(controller.state.pendingTransactions, hasLength(1));
        final pt = controller.state.pendingTransactions.first;
        expect(pt.suggestedType, 'income');
        expect(pt.suggestedAmount, 8000.0);
        expect(pt.suggestedCurrency, 'SAR');
        expect(pt.source, 'manual');
        expect(pt.confidence, 0.60);

        // Verify no changes to real balances/transactions
        expect(controller.state.transactions, isEmpty);
      },
    );

    test('Strict duplicate transaction detection within 5 minutes', () async {
      final controller = await makeController();

      // Send first message
      await controller.createPendingTransactionFromMessage(
        'Purchase at Amazon EGP 150',
        'sms',
      );
      expect(controller.state.pendingTransactions, hasLength(1));
      expect(
        controller.state.pendingTransactions.first.status,
        equals(CaptureStatus.pendingReview),
      );

      // Send duplicate message within 5 minutes
      await controller.createPendingTransactionFromMessage(
        'Purchase at Amazon EGP 150',
        'sms',
      );
      expect(controller.state.pendingTransactions, hasLength(2));
      expect(
        controller.state.pendingTransactions[1].status,
        equals(CaptureStatus.ignored),
      );
      expect(controller.state.captureAnalytics.duplicateMessages, equals(1));
    });

    test(
      'duplicate approved shortcut message is ignored after auto approval',
      () async {
        final controller = await makeController();
        await controller.setSmartCaptureAutoApproveEnabled(true);

        await controller.createPendingTransactionFromMessage(
          'Purchase at Talabat EGP 90',
          PendingTransactionSource.shortcut,
        );

        expect(controller.state.transactions, hasLength(1));
        expect(
          controller.state.pendingTransactions.first.status,
          equals(CaptureStatus.autoApproved),
        );

        await controller.createPendingTransactionFromMessage(
          'Purchase at Talabat EGP 90',
          PendingTransactionSource.shortcut,
        );

        expect(controller.state.transactions, hasLength(1));
        expect(controller.state.pendingTransactions, hasLength(2));
        expect(
          controller.state.pendingTransactions.last.status,
          equals(CaptureStatus.ignored),
        );
        expect(controller.state.captureAnalytics.duplicateMessages, equals(1));
      },
    );

    test('Confirmation learning promo milestone on 3 confirmations', () async {
      final controller = await makeController();

      // Enable smart capture auto approve
      await controller.setSmartCaptureAutoApproveEnabled(true);

      // Perform 3 manual approvals with category Food & Dining for merchant Talabat
      for (int i = 0; i < 3; i++) {
        await controller.createPendingTransaction(
          source: 'sms',
          rawMessage: 'Purchase at Talabat EGP 50',
          suggestedType: 'expense',
          confidence: 0.95,
          suggestedAmount: 50.0,
          suggestedCurrency: 'EGP',
          merchantName: 'Talabat',
          suggestedCategory: 'Food & Dining',
        );

        final pendingId = controller.state.pendingTransactions.last.id;
        await controller.approvePendingTransaction(
          pendingId,
          type: 'expense',
          amount: 50.0,
          currency: 'EGP',
          category: 'Food & Dining',
          description: 'Talabat Purchase',
          date: '2026-06-14',
        );
      }

      // Check that a learned MerchantRule now exists
      expect(controller.state.merchantRules.containsKey('talabat'), isTrue);
      final rule = controller.state.merchantRules['talabat']!;
      expect(rule.categoryId, equals('Food & Dining'));
      expect(rule.source, equals('learned'));
      expect(controller.state.captureAnalytics.learnedRules, equals(1));
    });

    test('Auto-approval requirement: rule presence', () async {
      final controller = await makeController();
      await controller.setSmartCaptureAutoApproveEnabled(true);

      // Scenario A: unknown merchant, high confidence (95%). Should go to review.
      await controller.createPendingTransactionFromMessage(
        'Purchase at XYZTRADING9384 EGP 100',
        'sms',
      );
      expect(controller.state.pendingTransactions, hasLength(1));
      expect(
        controller.state.pendingTransactions.first.status,
        equals(CaptureStatus.pendingReview),
      );
      expect(controller.state.transactions, isEmpty);

      // Scenario B: builtin merchant (Amazon), high confidence (95%). Should auto-approve.
      await controller.createPendingTransactionFromMessage(
        'Purchase amount: EGP 100 at Amazon',
        'sms',
      );
      expect(controller.state.pendingTransactions, hasLength(2));
      expect(
        controller.state.pendingTransactions[1].status,
        equals(CaptureStatus.autoApproved),
      );
      expect(controller.state.transactions, hasLength(1));
      expect(controller.state.transactions.first.category, equals('Shopping'));
    });

    test(
      'Talabat built-in rule resolves before creation and auto approves',
      () async {
        final controller = await makeController();
        await controller.setSmartCaptureAutoApproveEnabled(true);

        await controller.createPendingTransactionFromMessage(
          'Purchase at talabat.com amount EGP 150',
          'sms',
        );

        final capture = controller.state.pendingTransactions.single;
        expect(capture.merchantName, 'Talabat');
        expect(capture.suggestedCategory, 'Food & Dining');
        expect(capture.merchantRuleSource, 'builtin');
        expect(capture.confidence, 1.0);
        expect(capture.status, CaptureStatus.autoApproved);
        expect(capture.approvalSource, ApprovalSource.auto);
        expect(controller.state.transactions.single.category, 'Food & Dining');
      },
    );

    test('rule is applied to pending capture before review', () async {
      final controller = await makeController();

      await controller.createPendingTransactionFromMessage(
        'Purchase at Talabat EGP 75',
        'sms',
      );

      final capture = controller.state.pendingTransactions.single;
      expect(capture.status, CaptureStatus.pendingReview);
      expect(capture.merchantName, 'Talabat');
      expect(capture.suggestedCategory, 'Food & Dining');
      expect(capture.merchantRuleUsed, 'Talabat');
      expect(capture.merchantRuleSource, 'builtin');
      expect(capture.confidence, greaterThanOrEqualTo(0.95));
    });

    test('manual approval is not counted as auto approval', () async {
      final controller = await makeController();
      await controller.createPendingTransaction(
        source: 'sms',
        rawMessage: 'Purchase at Store EGP 50',
        suggestedType: 'expense',
        confidence: 0.85,
        suggestedAmount: 50,
        suggestedCurrency: 'EGP',
        merchantName: 'Store',
      );

      await controller.approvePendingTransaction(
        controller.state.pendingTransactions.single.id,
        type: 'expense',
        amount: 50,
        currency: 'EGP',
        category: 'Other',
        description: 'Store purchase',
        date: '2026-06-14',
      );

      final capture = controller.state.pendingTransactions.single;
      expect(capture.approvalSource, ApprovalSource.manual);
      expect(controller.state.captureAnalytics.autoApprovedMessages, 0);
    });

    test(
      'undo approval deletes ledger record and restores pending capture',
      () async {
        final controller = await makeController();
        await controller.setSmartCaptureAutoApproveEnabled(true);
        await controller.createPendingTransactionFromMessage(
          'Purchase at Amazon EGP 100',
          'sms',
        );
        final capture = controller.state.pendingTransactions.single;
        expect(controller.state.transactions, hasLength(1));

        await controller.undoPendingTransaction(capture.id);

        final restored = controller.state.pendingTransactions.single;
        expect(controller.state.transactions, isEmpty);
        expect(restored.status, CaptureStatus.pendingReview);
        expect(restored.linkedTransactionId, isNull);
        expect(restored.approvalSource, isNull);
        expect(restored.reviewedAt, isNull);
      },
    );

    test('editing approved category updates merchant learning rule', () async {
      final controller = await makeController();
      await controller.saveCustomMerchantRule(
        const MerchantRule(
          merchantName: 'Corner Shop',
          categoryId: 'Shopping',
          defaultType: 'expense',
          autoApprove: true,
          usageCount: 0,
          confidence: 1,
          source: 'custom',
        ),
      );
      await controller.createPendingTransaction(
        source: 'sms',
        rawMessage: 'Purchase at Corner Shop EGP 50',
        suggestedType: 'expense',
        confidence: 1,
        suggestedAmount: 50,
        suggestedCurrency: 'EGP',
        merchantName: 'Corner Shop',
        suggestedCategory: 'Shopping',
      );
      final id = controller.state.pendingTransactions.single.id;
      await controller.approvePendingTransaction(
        id,
        type: 'expense',
        amount: 50,
        currency: 'EGP',
        category: 'Shopping',
        description: 'Corner Shop',
        date: '2026-06-14',
      );

      final String approvedAt =
          controller.state.pendingTransactions.single.reviewedAt!;

      await controller.editApprovedPendingTransaction(
        id,
        type: 'expense',
        amount: 50,
        currency: 'EGP',
        category: 'Food & Dining',
        description: 'Corner Shop',
        date: '2026-06-14',
      );

      expect(
        controller.state.merchantRules['corner shop']!.categoryId,
        'Food & Dining',
      );
      expect(
        controller.state.pendingTransactions.single.reviewedAt,
        approvedAt,
      );
      expect(
        controller.state.merchantConfirmations.any(
          (c) =>
              c.merchantName == 'Corner Shop' &&
              c.categoryId == 'Food & Dining' &&
              c.confirmations == 1,
        ),
        isTrue,
      );
    });

    test('ignored bulk delete and analytics use persisted captures', () async {
      final controller = await makeController();
      await controller.createPendingTransactionFromMessage(
        'Transaction declined: insufficient funds',
        'sms',
      );
      await controller.createPendingTransactionFromMessage(
        'Purchase at Talabat EGP 90',
        'sms',
      );
      final ignored = controller.state.pendingTransactions
          .where((t) => t.status == CaptureStatus.ignored)
          .single;
      expect(ignored.ignoreReason, 'Declined Transaction');
      expect(controller.state.captureAnalytics.parsedMessages, 2);
      expect(controller.state.captureAnalytics.ignoredMessages, 1);

      await controller.deletePendingTransactionsBulk(<String>[ignored.id]);

      expect(
        controller.state.pendingTransactions.where(
          (t) => t.status == CaptureStatus.ignored,
        ),
        isEmpty,
      );
      expect(
        controller.state.pendingTransactions.where(
          (t) => t.status == CaptureStatus.pendingReview,
        ),
        hasLength(1),
      );
    });

    testWidgets('pending cards display merchant as the primary title', (
      WidgetTester tester,
    ) async {
      final controller = await makeController();
      await controller.createPendingTransactionFromMessage(
        'Purchase at Talabat EGP 90',
        'sms',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateController>.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Talabat'), findsOneWidget);
      expect(find.text('Expense Capture'), findsNothing);
    });

    testWidgets('Smart Capture cards keep emerald contrast in both themes', (
      WidgetTester tester,
    ) async {
      for (final brightness in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        final controller = await makeController();
        await controller.createPendingTransaction(
          source: 'sms',
          rawMessage: 'Purchase at Talabat EGP 90',
          suggestedType: 'expense',
          confidence: 1,
          suggestedAmount: 90,
          suggestedCurrency: 'EGP',
          merchantName: 'Talabat',
          suggestedCategory: 'Food & Dining',
        );
        await controller.approvePendingTransaction(
          controller.state.pendingTransactions.single.id,
          type: 'expense',
          amount: 90,
          currency: 'EGP',
          category: 'Food & Dining',
          description: 'Talabat Purchase',
          date: '2026-06-14',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateController>.value(
            value: controller,
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: const NotificationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approved (1)'));
        await tester.pumpAndSettle();

        final Card card = tester.widget<Card>(
          find.ancestor(of: find.text('Talabat'), matching: find.byType(Card)),
        );
        final expected = brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        expect(card.color, expected.hero);

        final Text amount = tester.widget<Text>(find.text('EGP 90.00'));
        expect(amount.style?.color, expected.gold);
      }
    });

    test('Correction feedback capped at 500 records', () async {
      final controller = await makeController();

      // Perform 510 manual corrections
      for (int i = 0; i < 510; i++) {
        await controller.createPendingTransaction(
          source: 'sms',
          rawMessage: 'Purchase at Merchant EGP 50',
          suggestedType: 'expense',
          confidence: 0.95,
          suggestedAmount: 50.0,
          suggestedCurrency: 'EGP',
          merchantName: 'Merchant',
          suggestedCategory: 'OriginalCategory',
        );

        final pendingId = controller.state.pendingTransactions
            .firstWhere((t) => t.status == CaptureStatus.pendingReview)
            .id;
        await controller.approvePendingTransaction(
          pendingId,
          type: 'expense',
          amount: 50.0,
          currency: 'EGP',
          category: 'CorrectedCategory',
          description: 'Purchase',
          date: '2026-06-14',
        );
      }

      // Check feedback list length is capped at 500
      expect(controller.state.correctionFeedback.length, equals(500));
      expect(controller.state.captureAnalytics.correctedMessages, equals(510));
    });
  });
}
