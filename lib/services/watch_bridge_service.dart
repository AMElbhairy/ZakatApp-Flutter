import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/app_state.dart';
import '../models/credit_card.dart';
import '../models/pending_transaction.dart';
import '../models/transaction.dart';
import 'app_state_controller.dart';
import '../core/services/zakat_engine.dart';

/// Explicit Command Result Contract returned to Apple Watch.
class WatchCommandResult {
  const WatchCommandResult({
    required this.v,
    required this.operationId,
    required this.status,
    required this.code,
    this.message,
    this.entityId,
    this.payload,
  });

  final int v;
  final String operationId;
  final String status; // 'success' | 'rejected' | 'failed'
  final String
  code; // e.g. 'OK', 'DUPLICATE', 'NOT_FOUND', 'INSUFFICIENT_FUNDS'
  final String? message;
  final String? entityId;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': v,
    'operationId': operationId,
    'status': status,
    'code': code,
    if (message != null) 'message': message,
    if (entityId != null) 'entityId': entityId,
    if (payload != null) 'payload': payload,
  };

  factory WatchCommandResult.success({
    required String operationId,
    String code = 'OK',
    String? message,
    String? entityId,
    Map<String, dynamic>? payload,
  }) {
    return WatchCommandResult(
      v: 1,
      operationId: operationId,
      status: 'success',
      code: code,
      message: message,
      entityId: entityId,
      payload: payload,
    );
  }

  factory WatchCommandResult.failed({
    required String operationId,
    required String code,
    required String message,
    Map<String, dynamic>? payload,
  }) {
    return WatchCommandResult(
      v: 1,
      operationId: operationId,
      status: 'failed',
      code: code,
      message: message,
      payload: payload,
    );
  }

  factory WatchCommandResult.rejected({
    required String operationId,
    required String code,
    required String message,
    Map<String, dynamic>? payload,
  }) {
    return WatchCommandResult(
      v: 1,
      operationId: operationId,
      status: 'rejected',
      code: code,
      message: message,
      payload: payload,
    );
  }
}

/// Service that coordinates communication between the Flutter app and the
/// native Apple Watch companion app via MethodChannel.
class WatchBridgeService {
  WatchBridgeService._();

  static const MethodChannel _channel = MethodChannel('com.zakahwealth.watch');
  static const int schemaVersion = 1;

  static AppStateController? _controller;
  static bool _initialized = false;
  static bool _readyNotified = false;

  /// Cache of recently processed operation IDs mapped to their results
  /// to protect against duplicate taps, retries, and race conditions.
  static final Map<String, WatchCommandResult> _processedOperations =
      <String, WatchCommandResult>{};
  static const int _maxCachedOperations = 200;

  static void initialize(AppStateController controller) {
    _controller = controller;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    _debugLog(
      'MethodChannel handler registered; AppStateController is available',
    );
    unawaited(_notifyNativeReady());

    // Perform initial state sync if state is ready
    unawaited(syncFromState(controller.state));
  }

  @visibleForTesting
  static void resetForTesting() {
    _controller = null;
    _initialized = false;
    _readyNotified = false;
    _processedOperations.clear();
  }

  @visibleForTesting
  static void setControllerForTesting(AppStateController controller) {
    _controller = controller;
    _initialized = true;
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    _debugLog('Native method received: ${call.method}');
    switch (call.method) {
      case 'executeWatchCommand':
        final Map<String, dynamic> rawCommand = Map<String, dynamic>.from(
          call.arguments as Map,
        );
        final WatchCommandResult result = await executeCommand(rawCommand);
        _debugLog(
          'Command completed operationId=${result.operationId} status=${result.status}',
        );
        return result.toJson();
      default:
        throw PlatformException(
          code: 'UNSUPPORTED_METHOD',
          message: 'Method ${call.method} is not supported',
        );
    }
  }

  /// Authoritative command router with idempotency validation.
  static Future<WatchCommandResult> executeCommand(
    Map<String, dynamic> command,
  ) async {
    _debugLog(
      'Authoritative operation started operationId=${command['operationId']} action=${command['action']}',
    );
    final String? operationId = command['operationId']?.toString().trim();
    if (operationId == null || operationId.isEmpty) {
      return WatchCommandResult.failed(
        operationId: const Uuid().v4(),
        code: 'MISSING_OPERATION_ID',
        message: 'operationId is required for idempotency.',
      );
    }

    // Check idempotency cache
    if (_processedOperations.containsKey(operationId)) {
      debugPrint('[WatchBridge] Duplicate operation $operationId ignored');
      return _processedOperations[operationId]!;
    }

    final String action = (command['action'] ?? '').toString().trim();
    WatchCommandResult result;

    try {
      switch (action) {
        case 'ping':
          result = _handlePing(operationId, command);
          break;

        case 'approvePending':
          result = await _handleApprovePending(operationId, command);
          break;

        case 'rejectPending':
          result = await _handleRejectPending(operationId, command);
          break;

        case 'createTransaction':
          result = await _handleCreateTransaction(operationId, command);
          break;

        case 'quoteCurrencyExchange':
          result = _handleQuoteCurrencyExchange(operationId, command);
          break;

        case 'executeCurrencyExchange':
          result = await _handleCurrencyExchange(operationId, command);
          break;

        case 'creditCardPayment':
          result = await _handleCreditCardPayment(operationId, command);
          break;

        default:
          result = WatchCommandResult.failed(
            operationId: operationId,
            code: 'UNKNOWN_ACTION',
            message: 'Unknown watch action: $action',
          );
      }
    } catch (e) {
      debugPrint('[WatchBridge] Command execution failed: $e');
      final String errStr = e.toString();
      if (errStr.contains('already approved') ||
          errStr.contains('not found') ||
          errStr.contains('no longer pending')) {
        result = WatchCommandResult.rejected(
          operationId: operationId,
          code: 'ITEM_ALREADY_PROCESSED',
          message: 'Already processed',
        );
      } else {
        result = WatchCommandResult.failed(
          operationId: operationId,
          code: 'EXECUTION_ERROR',
          message: errStr.replaceFirst(RegExp(r'^[A-Za-z]+Error:\s*'), ''),
        );
      }
    }

    _cacheOperationResult(operationId, result);
    return result;
  }

  static void _cacheOperationResult(String id, WatchCommandResult result) {
    if (_processedOperations.length >= _maxCachedOperations) {
      _processedOperations.remove(_processedOperations.keys.first);
    }
    _processedOperations[id] = result;
  }

  // --- Handlers ---

  static WatchCommandResult _handlePing(
    String operationId,
    Map<String, dynamic> command,
  ) {
    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'pong',
    );
  }

  static Future<WatchCommandResult> _handleApprovePending(
    String operationId,
    Map<String, dynamic> command,
  ) async {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String? pendingId = command['pendingId']?.toString().trim();
    if (pendingId == null || pendingId.isEmpty) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_ARGUMENTS',
        message: 'pendingId is required.',
      );
    }

    // Verify item still exists and is pending
    final PendingTransaction? pending = controller.state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pending == null) {
      return WatchCommandResult.rejected(
        operationId: operationId,
        code: 'ITEM_ALREADY_PROCESSED',
        message: 'Already processed',
      );
    }

    if (pending.status != CaptureStatus.pendingReview ||
        pending.linkedTransactionId != null) {
      return WatchCommandResult.rejected(
        operationId: operationId,
        code: 'ITEM_ALREADY_PROCESSED',
        message: 'Already processed',
      );
    }

    final String type = (command['type'] ?? pending.suggestedType)
        .toString()
        .trim();
    final double amount =
        (command['amount'] as num?)?.toDouble() ??
        pending.suggestedAmount ??
        0.0;
    final String currency =
        (command['currency'] ?? pending.suggestedCurrency ?? 'SAR')
            .toString()
            .trim();
    final String category =
        (command['category'] ?? pending.suggestedCategory ?? 'Uncategorized')
            .toString()
            .trim();
    final String description =
        (command['description'] ??
                pending.suggestedDescription ??
                pending.merchantName ??
                '')
            .toString()
            .trim();
    final String date = (command['date'] ?? _todayIso()).toString().trim();
    final String? paymentSourceId = command['paymentSourceId']
        ?.toString()
        .trim();

    await controller.approvePendingTransaction(
      pendingId,
      type: type,
      amount: amount,
      currency: currency,
      category: category,
      description: description,
      date: date,
      paymentSourceId: (paymentSourceId != null && paymentSourceId != 'cash')
          ? paymentSourceId
          : null,
    );

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Transaction approved successfully',
      entityId: pendingId,
    );
  }

  static Future<WatchCommandResult> _handleRejectPending(
    String operationId,
    Map<String, dynamic> command,
  ) async {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String? pendingId = command['pendingId']?.toString().trim();
    if (pendingId == null || pendingId.isEmpty) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_ARGUMENTS',
        message: 'pendingId is required.',
      );
    }

    final PendingTransaction? pending = controller.state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pending == null) {
      return WatchCommandResult.rejected(
        operationId: operationId,
        code: 'ITEM_ALREADY_PROCESSED',
        message: 'Already processed',
      );
    }

    if (pending.status != CaptureStatus.pendingReview) {
      return WatchCommandResult.rejected(
        operationId: operationId,
        code: 'ITEM_ALREADY_PROCESSED',
        message: 'Already processed',
      );
    }

    final String reason = (command['reason'] ?? 'Manually Ignored')
        .toString()
        .trim();
    await controller.rejectPendingTransaction(pendingId, reason: reason);

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Transaction rejected',
      entityId: pendingId,
    );
  }

  static Future<WatchCommandResult> _handleCreateTransaction(
    String operationId,
    Map<String, dynamic> command,
  ) async {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String type = (command['type'] ?? 'expense').toString().trim();
    final double amount = (command['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0.0) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_AMOUNT',
        message: 'Amount must be greater than zero.',
      );
    }

    final String currency = (command['currency'] ?? 'SAR')
        .toString()
        .trim()
        .toUpperCase();
    final String category = (command['category'] ?? 'Uncategorized')
        .toString()
        .trim();
    final String description = (command['description'] ?? '').toString().trim();
    final String date = (command['date'] ?? _todayIso()).toString().trim();
    final String? paymentSourceId = command['paymentSourceId']
        ?.toString()
        .trim();
    final String? transferSourceId = command['transferSourceId']
        ?.toString()
        .trim();
    final String? transferDestinationId = command['transferDestinationId']
        ?.toString()
        .trim();

    final String txId = const Uuid().v4();
    final String nowIso = DateTime.now().toUtc().toIso8601String();

    final Transaction newTx = Transaction(
      id: txId,
      type: type,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      description: description,
      createdAt: nowIso,
      rolledOver: false,
      paymentSourceId: (paymentSourceId != null && paymentSourceId != 'cash')
          ? paymentSourceId
          : null,
      displaySourceId: (paymentSourceId != null && paymentSourceId != 'cash')
          ? paymentSourceId
          : null,
      transferSourceId: transferSourceId,
      transferDestinationId: transferDestinationId,
      activityType: type == 'transfer' ? 'transfer' : null,
    );

    await controller.addTransaction(newTx);

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Transaction created successfully',
      entityId: txId,
    );
  }

  static WatchCommandResult _handleQuoteCurrencyExchange(
    String operationId,
    Map<String, dynamic> command,
  ) {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String sourceCurrency = (command['sourceCurrency'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String targetCurrency = (command['targetCurrency'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final double sourceAmount =
        (command['sourceAmount'] as num?)?.toDouble() ?? 0.0;

    if (sourceCurrency.isEmpty || targetCurrency.isEmpty) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_CURRENCY',
        message: 'Source and target currencies are required.',
      );
    }

    if (sourceCurrency == targetCurrency) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'SAME_CURRENCY',
        message: 'Source and target currencies must be different.',
      );
    }

    if (sourceAmount <= 0.0) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_AMOUNT',
        message: 'Source amount must be greater than zero.',
      );
    }

    final MarketData market = MarketData.fromJson(controller.state.marketData);
    final double targetAmount = ZakatEngineService.convertFromEgp(
      ZakatEngineService.convertToEgp(sourceAmount, sourceCurrency, market),
      targetCurrency,
      market,
    );
    final double rate = sourceAmount > 0 ? (targetAmount / sourceAmount) : 0.0;

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Quote retrieved',
      payload: <String, dynamic>{
        'sourceCurrency': sourceCurrency,
        'targetCurrency': targetCurrency,
        'sourceAmount': sourceAmount,
        'targetAmount': double.parse(targetAmount.toStringAsFixed(4)),
        'rate': double.parse(rate.toStringAsFixed(6)),
      },
    );
  }

  static Future<WatchCommandResult> _handleCurrencyExchange(
    String operationId,
    Map<String, dynamic> command,
  ) async {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String sourceCurrency = (command['sourceCurrency'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String targetCurrency = (command['targetCurrency'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final double sourceAmount =
        (command['sourceAmount'] as num?)?.toDouble() ?? 0.0;
    final double targetAmount =
        (command['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final String date = (command['date'] ?? _todayIso()).toString().trim();

    if (sourceCurrency.isEmpty || targetCurrency.isEmpty) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_CURRENCY',
        message: 'Source and target currencies are required.',
      );
    }

    if (sourceAmount <= 0.0 || targetAmount <= 0.0) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_AMOUNT',
        message: 'Source and target amounts must be greater than zero.',
      );
    }

    await controller.executeCurrencyExchange(
      date: date,
      sourceCurrency: sourceCurrency,
      targetCurrency: targetCurrency,
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
    );

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Currency exchange executed successfully',
    );
  }

  static Future<WatchCommandResult> _handleCreditCardPayment(
    String operationId,
    Map<String, dynamic> command,
  ) async {
    final controller = _controller;
    if (controller == null) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'CONTROLLER_UNAVAILABLE',
        message: 'Application state controller is not available.',
      );
    }

    final String? cardId = command['cardId']?.toString().trim();
    final double amount = (command['amount'] as num?)?.toDouble() ?? 0.0;
    final String date = (command['date'] ?? _todayIso()).toString().trim();

    if (cardId == null || cardId.isEmpty) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_CARD',
        message: 'Credit card ID is required.',
      );
    }

    if (amount <= 0.0) {
      return WatchCommandResult.failed(
        operationId: operationId,
        code: 'INVALID_AMOUNT',
        message: 'Payment amount must be greater than zero.',
      );
    }

    final CreditCard card = controller.state.creditCards.firstWhere(
      (c) => c.id == cardId,
      orElse: () =>
          throw StateError('Selected credit card is no longer available.'),
    );

    final String txId = const Uuid().v4();
    final String nowIso = DateTime.now().toUtc().toIso8601String();

    final Transaction tx = Transaction(
      id: txId,
      type: 'transfer',
      date: date,
      amount: amount,
      currency: card.currency,
      category: 'Credit Card Payment',
      description: 'Payment for ${card.bankName} •••• ${card.last4Digits}',
      createdAt: nowIso,
      rolledOver: false,
      transferSourceId: 'cash',
      transferDestinationId: card.id,
      activityType: 'transfer',
    );

    await controller.addAccountTransfer(tx);

    return WatchCommandResult.success(
      operationId: operationId,
      code: 'OK',
      message: 'Credit card payment completed',
      entityId: txId,
    );
  }

  // --- Snapshot Serialization (Strictly Minimal Presentation Cache) ---

  /// Builds a minimal presentation cache snapshot without rawMessage and without
  /// financial balances, then pushes it to the native Watch bridge.
  static Future<void> syncFromState(AppStateModel state) async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      final Map<String, dynamic> snapshot = buildSnapshot(state);
      await _channel.invokeMethod<bool>('syncWatchData', snapshot);
    } catch (e) {
      debugPrint('[WatchBridge] syncFromState failed: $e');
    }
  }

  static Future<void> _notifyNativeReady() async {
    if (_readyNotified || kIsWeb || !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('watchBridgeReady');
      _readyNotified = true;
      _debugLog('Native readiness acknowledged');
    } catch (error) {
      _debugLog('Native readiness notification failed: $error');
    }
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(
        '[WatchBridge][${DateTime.now().toUtc().toIso8601String()}] $message',
      );
    }
  }

  /// Builds the serialized DTO map matching schema v1.
  static Map<String, dynamic> buildSnapshot(AppStateModel state) {
    final String mainCurrency = state.mainCurrency.trim().isNotEmpty
        ? state.mainCurrency.trim().toUpperCase()
        : 'SAR';

    // Currencies
    final Set<String> currencies = <String>{
      mainCurrency,
      ...ZakatEngineService.supportedCurrencies,
    };

    // Payment Sources (No balances!)
    final List<Map<String, dynamic>> paymentSources = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'cash',
        'name': 'Cash Wallet',
        'type': 'cash',
        'currency': mainCurrency,
        'last4': null,
      },
      ...state.creditCards
          .where((c) => !c.isArchived)
          .map(
            (card) => <String, dynamic>{
              'id': card.id,
              'name': '${card.bankName} •••• ${card.last4Digits}',
              'type': 'card',
              'currency': card.currency,
              'last4': card.last4Digits,
            },
          ),
    ];

    // Categories
    final List<String> expenseCategories = state.categories.expense.toList(
      growable: false,
    );
    final List<String> incomeCategories = state.categories.income.toList(
      growable: false,
    );

    // Pending Inbox (Filtered to pendingReview, NO rawMessage!)
    final List<Map<String, dynamic>> pendingInbox = state.pendingTransactions
        .where((t) => t.status == CaptureStatus.pendingReview)
        .take(30)
        .map(
          (t) => <String, dynamic>{
            'id': t.id,
            'type': t.suggestedType,
            'amount': t.suggestedAmount ?? 0.0,
            'currency': t.suggestedCurrency ?? mainCurrency,
            'merchant': t.merchantName ?? t.suggestedDescription ?? '',
            'category': t.suggestedCategory ?? 'Uncategorized',
            'paymentSourceId': t.suggestedPaymentSourceId,
            'cardLast4': t.cardLast4,
            'accountLast4': t.accountLast4,
            'detectedBank': t.detectedBank,
            'date': t.createdAt,
          },
        )
        .toList(growable: false);

    // Recent Activity (Top 15 sorted by date descending)
    final List<Transaction> sortedTx = List<Transaction>.from(
      state.transactions,
    )..sort((a, b) => b.date.compareTo(a.date));

    final List<Map<String, dynamic>> recentActivity = sortedTx
        .take(15)
        .map(
          (tx) => <String, dynamic>{
            'id': tx.id,
            'type': tx.type,
            'amount': tx.amount,
            'currency': tx.currency,
            'title': tx.description.isNotEmpty ? tx.description : tx.category,
            'category': tx.category,
            'date': tx.date,
          },
        )
        .toList(growable: false);

    // Flutter's method-channel codec represents Dart null values as NSNull on
    // iOS. NSUserDefaults and WCSession application contexts only accept
    // property-list values, so remove nullable fields before crossing the
    // native boundary (optional Watch DTO fields remain absent and decode as
    // nil on watchOS).
    return _removeNullValues(<String, dynamic>{
      'v': schemaVersion,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'mainCurrency': mainCurrency,
      'currencies': currencies.toList(growable: false),
      'paymentSources': paymentSources,
      'expenseCategories': expenseCategories,
      'incomeCategories': incomeCategories,
      'pendingInbox': pendingInbox,
      'recentActivity': recentActivity,
    });
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> value) {
    final Map<String, dynamic> result = <String, dynamic>{};
    value.forEach((String key, dynamic item) {
      if (item == null) return;
      result[key] = _sanitizePropertyListValue(item);
    });
    return result;
  }

  static dynamic _sanitizePropertyListValue(dynamic value) {
    if (value is Map) {
      return _removeNullValues(
        value.map<String, dynamic>(
          (dynamic key, dynamic item) =>
              MapEntry<String, dynamic>(key.toString(), item),
        ),
      );
    }
    if (value is Iterable) {
      return value.map<dynamic>(_sanitizePropertyListValue).toList();
    }
    return value;
  }

  static String _todayIso() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
