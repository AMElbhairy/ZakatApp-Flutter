import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/models/raw_capture_payload.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/reconciliation_service.dart';
import 'package:zakatapp_flutter/services/smart_capture_alert_service.dart';
import 'package:zakatapp_flutter/services/smart_capture_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppStateModel createTestState({
    List<CreditCard> creditCards = const <CreditCard>[],
    List<Transaction> transactions = const <Transaction>[],
    bool smartCaptureEnabled = true,
    bool smartCaptureAutoApproveEnabled = false,
  }) {
    return AppStateModel.fromJson(<String, dynamic>{
      'creditCards': creditCards.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'smartCaptureEnabled': smartCaptureEnabled,
      'smartCaptureAutoApproveEnabled': smartCaptureAutoApproveEnabled,
      'marketData': <String, dynamic>{
        'GOLD_PRICE_24K': 3000.0,
        'SILVER_PRICE': 40.0,
        'USD_TO_EGP': 50.0,
        'SAR_TO_EGP': 13.33,
        'RATES_TO_EGP': <String, dynamic>{
          'USD': 50.0,
          'SAR': 13.33,
          'EGP': 1.0,
          'EUR': 55.0,
        },
      },
    });
  }

  Future<AppStateController> makeController({AppStateModel? initialState}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    final controller = AppStateController(
      repository: repository,
      smartCaptureAlertService: const NoopSmartCaptureAlertService(),
    );
    await controller.load();
    if (initialState != null) {
      await controller.updateState(initialState);
    }
    return controller;
  }

  group('SmartCaptureParser card reference extraction for income / refunds', () {
    test('parses بطاقة *1234', () {
      final parsed = SmartCaptureParser.parse('تم إيداع 500 SAR بطاقة *1234');
      expect(parsed.cardReference, '*1234');
    });

    test('parses بطاقتك الائتمانية المنتهية بـ 1234', () {
      final parsed = SmartCaptureParser.parse(
        'تم استرداد مبلغ 100 ر.س إلى بطاقتك الائتمانية المنتهية بـ 1234',
      );
      expect(parsed.cardReference, '1234');
    });

    test('parses إلى بطاقة 1234', () {
      final parsed = SmartCaptureParser.parse('تم إضافة 250 EGP إلى بطاقة 1234');
      expect(parsed.cardReference, '1234');
    });

    test('parses تم رد المبلغ إلى بطاقتك ****1234', () {
      final parsed = SmartCaptureParser.parse(
        'تم رد المبلغ إلى بطاقتك ****1234 بقيمة 80 USD',
      );
      expect(parsed.cardReference, '****1234');
    });

    test('parses refund to card ending in 1234', () {
      final parsed = SmartCaptureParser.parse(
        'Refund of 150.00 USD to card ending in 1234',
      );
      expect(parsed.cardReference, '1234');
    });

    test('parses credited to your card ending 1234', () {
      final parsed = SmartCaptureParser.parse(
        '50.00 SAR credited to your card ending 1234',
      );
      expect(parsed.cardReference, '1234');
    });

    test('parses deposit to card ****1234', () {
      final parsed = SmartCaptureParser.parse(
        'Deposit of 300 EUR to card ****1234 successfully processed',
      );
      expect(parsed.cardReference, '****1234');
    });

    test('negative tests: does not extract unrelated 4-digit numbers as card reference', () {
      // Date only
      final dateOnly = SmartCaptureParser.parse('Deposit of 500 EGP on 2026-06-25');
      expect(dateOnly.cardReference, isNull);

      // OTP code
      final otp = SmartCaptureParser.parse('رمز التحقق 5432 لإتمام العملية');
      expect(otp.cardReference, isNull);

      // Balance only
      final balanceOnly = SmartCaptureParser.parse('تم استلام 100 USD الرصيد 4321');
      expect(balanceOnly.cardReference, isNull);

      // Transaction reference number
      final refNum = SmartCaptureParser.parse('حوالة واردة 300 SAR رقم العملية 9876');
      expect(refNum.cardReference, isNull);

      // Merchant with numbers
      final merchantNum = SmartCaptureParser.parse('Purchase at Store 1234 SAR 50');
      expect(merchantNum.cardReference, isNull);
    });
  });

  group('Destination card resolution and collision safety', () {
    const cardA = CreditCard(
      id: 'card-a',
      bankName: 'Al Rajhi',
      cardNickname: 'Primary Visa',
      network: CreditCardNetwork.visa,
      last4Digits: '1234',
      creditLimit: 10000,
      currency: 'SAR',
      openingBalance: 1000,
    );

    const cardB = CreditCard(
      id: 'card-b',
      bankName: 'SNB',
      cardNickname: 'Mastercard World',
      network: CreditCardNetwork.mastercard,
      last4Digits: '5678',
      creditLimit: 15000,
      currency: 'SAR',
      openingBalance: 800,
    );

    test('resolves unique card from income message', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA, cardB],
        ),
      );

      final payload = RawCapturePayload(
        source: CaptureSource.sms,
        rawText: 'Refund of 200 SAR to card ending in 1234',
        receivedAt: DateTime.now(),
      );

      await controller.createPendingTransactionFromPayload(payload, sendNotification: false);
      expect(controller.state.pendingTransactions, hasLength(1));
      final pending = controller.state.pendingTransactions.first;
      expect(pending.suggestedType, 'income');
      expect(pending.suggestedPaymentSourceId, 'card-a');
    });

    test('leaves card unresolved if two active cards share the same last 4 digits', () async {
      const cardA2 = CreditCard(
        id: 'card-a2',
        bankName: 'Riyad Bank',
        cardNickname: 'Secondary',
        network: CreditCardNetwork.visa,
        last4Digits: '1234', // Same last 4 as cardA!
        creditLimit: 5000,
        currency: 'SAR',
        openingBalance: 500,
      );

      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA, cardA2],
        ),
      );

      final payload = RawCapturePayload(
        source: CaptureSource.sms,
        rawText: 'Refund of 200 SAR to card ending in 1234',
        receivedAt: DateTime.now(),
      );

      await controller.createPendingTransactionFromPayload(payload, sendNotification: false);
      expect(controller.state.pendingTransactions, hasLength(1));
      final pending = controller.state.pendingTransactions.first;
      expect(pending.suggestedPaymentSourceId, isNull);
    });
  });

  group('Credit card income financial lifecycle & reversal-first edits', () {
    const cardA = CreditCard(
      id: 'card-a',
      bankName: 'Al Rajhi',
      cardNickname: 'Card A',
      network: CreditCardNetwork.visa,
      last4Digits: '1234',
      creditLimit: 10000,
      currency: 'SAR',
      openingBalance: 1000,
    );

    const cardB = CreditCard(
      id: 'card-b',
      bankName: 'SNB',
      cardNickname: 'Card B',
      network: CreditCardNetwork.mastercard,
      last4Digits: '5678',
      creditLimit: 15000,
      currency: 'SAR',
      openingBalance: 800,
    );

    test('adding income to credit card reduces outstanding balance', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      final tx = Transaction(
        id: 'tx-inc-1',
        type: 'income',
        date: '2026-09-05',
        amount: 400,
        currency: 'SAR',
        category: 'Refund',
        description: 'Merchant refund',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(tx);

      final updatedCard = controller.state.creditCards.firstWhere((c) => c.id == 'card-a');
      expect(updatedCard.openingBalance, 600.0); // 1000 - 400
    });

    test('adding income exceeding balance clamps to 0', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      final tx = Transaction(
        id: 'tx-inc-clamp',
        type: 'income',
        date: '2026-09-05',
        amount: 1500,
        currency: 'SAR',
        category: 'Refund',
        description: 'Over-refund',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(tx);

      final updatedCard = controller.state.creditCards.firstWhere((c) => c.id == 'card-a');
      expect(updatedCard.openingBalance, 0.0);
    });

    test('deleting income restores credit card balance', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      final tx = Transaction(
        id: 'tx-inc-del',
        type: 'income',
        date: '2026-09-05',
        amount: 300,
        currency: 'SAR',
        category: 'Refund',
        description: 'Refund to delete',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(tx);
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 700.0);

      await controller.deleteTransaction('tx-inc-del');
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 1000.0);
    });

    test('editing destination: Card A (+500) -> Card B (-300) restores Card A and reduces Card B', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA, cardB],
        ),
      );

      // 1. Initial transaction: SAR 500 income to Card A
      final originalTx = Transaction(
        id: 'tx-edit-test',
        type: 'income',
        date: '2026-09-05',
        amount: 500,
        currency: 'SAR',
        category: 'Refund',
        description: 'Initial refund to Card A',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(originalTx);

      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 500.0); // 1000 - 500
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-b').openingBalance, 800.0); // Unchanged

      // 2. Edit transaction: changed to SAR 300 income to Card B
      final updatedTx = Transaction(
        id: 'tx-edit-test',
        type: 'income',
        date: '2026-09-05',
        amount: 300,
        currency: 'SAR',
        category: 'Refund',
        description: 'Edited refund to Card B',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-b',
      );

      await controller.updateTransaction(updatedTx);

      // Card A should be restored (+500 -> 1000)
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 1000.0);
      // Card B should be reduced (-300 -> 500)
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-b').openingBalance, 500.0);
    });

    test('editing destination: Card A -> Cash restores Card A', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      final originalTx = Transaction(
        id: 'tx-card-to-cash',
        type: 'income',
        date: '2026-09-05',
        amount: 250,
        currency: 'SAR',
        category: 'Refund',
        description: 'Initial refund to Card A',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(originalTx);
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 750.0);

      // Edit to cash (paymentSourceId == null)
      final updatedTx = Transaction(
        id: 'tx-card-to-cash',
        type: 'income',
        date: '2026-09-05',
        amount: 250,
        currency: 'SAR',
        category: 'Refund',
        description: 'Now cash refund',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: null,
      );

      await controller.updateTransaction(updatedTx);
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 1000.0);
    });

    test('editing type: Expense on Card A -> Income on Card A correctly reverses charge and applies credit', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      // Initial: 200 expense charged on Card A -> owed increases 1000 + 200 = 1200
      final expTx = Transaction(
        id: 'tx-exp-to-inc',
        type: 'expense',
        date: '2026-09-05',
        amount: 200,
        currency: 'SAR',
        category: 'General',
        description: 'Mistaken expense',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.addTransaction(expTx);
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 1200.0);

      // Edit: change type to income of 150 -> reverses expense (-200 to 1000) and applies income (-150 to 850)
      final incTx = Transaction(
        id: 'tx-exp-to-inc',
        type: 'income',
        date: '2026-09-05',
        amount: 150,
        currency: 'SAR',
        category: 'Refund',
        description: 'Actually an income refund',
        createdAt: '2026-09-05T12:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a',
      );

      await controller.updateTransaction(incTx);
      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 850.0);
    });

    test('approving pending transaction with credit card income mutates balance', () async {
      final controller = await makeController(
        initialState: createTestState(
          creditCards: <CreditCard>[cardA],
        ),
      );

      final payload = RawCapturePayload(
        source: CaptureSource.sms,
        rawText: 'Refund of 350 SAR to card ending in 1234',
        receivedAt: DateTime.now(),
      );

      await controller.createPendingTransactionFromPayload(payload, sendNotification: false);
      final pending = controller.state.pendingTransactions.first;

      await controller.approvePendingTransaction(
        pending.id,
        type: 'income',
        amount: 350,
        currency: 'SAR',
        category: 'Refund',
        description: 'Merchant refund',
        date: '2026-09-05',
        paymentSourceId: pending.suggestedPaymentSourceId,
      );

      expect(controller.state.creditCards.firstWhere((c) => c.id == 'card-a').openingBalance, 650.0); // 1000 - 350
    });
  });

  group('ZakatEngine & ReconciliationService separation', () {
    test('credit card income is excluded from cash wallet balance and cash Hawl lots', () {
      final cashIncome = Transaction(
        id: 'tx-cash-inc',
        type: 'income',
        date: '2026-09-01',
        amount: 1000,
        currency: 'SAR',
        category: 'Salary',
        description: 'Cash salary',
        createdAt: '2026-09-01T10:00:00Z',
        rolledOver: false,
        paymentSourceId: null, // Cash
      );

      final cardIncome = Transaction(
        id: 'tx-card-inc',
        type: 'income',
        date: '2026-09-02',
        amount: 500,
        currency: 'SAR',
        category: 'Refund',
        description: 'Card refund',
        createdAt: '2026-09-02T10:00:00Z',
        rolledOver: false,
        paymentSourceId: 'card-a', // Credit card
      );

      final creditCardIds = <String>{'card-a'};

      // 1. ZakatEngine wallet balance
      final walletBalance = ZakatEngineService.calculateWalletBalanceByCurrency(
        currency: 'SAR',
        transactions: <Transaction>[cashIncome, cardIncome],
        savings: const [],
        creditCardIds: creditCardIds,
      );

      // Only cashIncome (1000) should be in wallet balance; cardIncome should be excluded
      expect(walletBalance, 1000.0);

      // 2. ZakatEngine Hawl lots
      final lots = ZakatEngineService.getNetIncomeLots(
        transactions: <Transaction>[cashIncome, cardIncome],
        marketData: const MarketData(
          goldPrice24kEgp: 0,
          silverPriceEgp: 0,
          usdToEgp: 50,
          sarToEgp: 13,
          ratesToEgp: <String, double>{'EGP': 1, 'SAR': 13},
        ),
        creditCardIds: creditCardIds,
      );

      // Only 1 lot for cashIncome
      expect(lots, hasLength(1));
      expect(lots.first['id'], 'tx-cash-inc');

      // 3. ReconciliationService lots
      final recon = ReconciliationService();
      final reconLots = recon.getNetIncomeLotsForTransactions(
        transactions: <Transaction>[cashIncome, cardIncome],
        currency: 'SAR',
        creditCardIds: creditCardIds,
      );

      expect(reconLots, hasLength(1));
      expect(reconLots.first.id, 'tx-cash-inc');
    });
  });
}
