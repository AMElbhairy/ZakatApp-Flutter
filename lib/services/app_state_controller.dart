// ignore_for_file: avoid_print, prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/storage_keys.dart';

import '../models/app_state.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/market_snapshot.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';
import '../models/pending_transaction.dart';
import '../models/currency_exchange_edit_request.dart';
import '../models/merchant_rule.dart';
import '../models/merchant_confirmation.dart';
import '../models/capture_analytics.dart';
import '../models/correction_feedback.dart';
import '../models/user_profile.dart';
import '../data/local/local_store_providers.dart'
    hide useSqliteLocalStoreProvider;
import '../data/local/local_store_providers.dart' as store_providers;
import '../data/local/app_database.dart'
    hide
        Transaction,
        Saving,
        PendingTransaction,
        Investment,
        FinancialPlan,
        RecurringTransaction,
        MerchantRule,
        MerchantConfirmation,
        CorrectionFeedback;
import '../data/repositories/local_app_settings_repository.dart';
import '../data/repositories/local_correction_feedback_repository.dart';
import '../data/repositories/local_investments_repository.dart';
import '../data/repositories/local_financial_plans_repository.dart';
import '../data/repositories/local_merchant_rules_repository.dart';
import '../data/repositories/local_merchant_confirmations_repository.dart';
import '../data/repositories/local_recurring_transactions_repository.dart';
import '../data/local/daos/sync_metadata_dao.dart';
import '../data/local/daos/sync_queue_dao.dart';
import '../data/local/migration/json_to_sqlite_migrator.dart';
import '../data/repositories/local_financial_operations_repository.dart';
import '../data/repositories/local_savings_repository.dart';
import '../data/repositories/local_pending_transactions_repository.dart';
import '../repositories/app_state_repository.dart';
import '../data/sync/sync_queue_processor.dart';
import '../data/repositories/local_transactions_repository.dart';
import 'market_data_api_service.dart';
import 'reconciliation_service.dart';
import '../core/services/zakat_engine.dart';
import 'biometric_service.dart';
import 'firestore_sync_manager.dart';
import 'secure_storage_service.dart';
import 'smart_capture_parser.dart';
import '../data/sync/local_sync_pipeline.dart';
import '../data/sync/sync_reports.dart';
import 'app_diagnostics.dart';
import 'sync_diagnostics_service.dart';
import 'smart_capture_alert_service.dart';

class AppStateController extends ChangeNotifier {
  AppStateController({
    required this.repository,
    MarketDataApiService? marketDataApiService,
    ReconciliationService? reconciliationService,
    this.firestoreSyncManager,
    this.enableBackgroundSync = true,
    this.enableMarketAutoRefresh = true,
    AppDatabase? database,
    bool ownsDatabase = false,
    TransactionsLocalStore? localTransactionsRepository,
    SavingsLocalStore? localSavingsRepository,
    FinancialOperationsLocalStore? localFinancialOperationsRepository,
    UseSqliteLocalStoreProvider? useSqliteLocalStoreProvider,
    LocalSyncPipeline? localSyncPipeline,
    Duration pushDebounceDuration = const Duration(seconds: 15),
    SmartCaptureAlertService? smartCaptureAlertService,
    SecureStorageService? secureStorageService,
  }) : _state = AppStateDefaults.create(),
       secureStorageService =
           secureStorageService ?? const SecureStorageService(),
       marketDataApiService =
           marketDataApiService ?? MarketDataApiServiceImpl(),
       reconciliationService = reconciliationService ?? ReconciliationService(),
       _database = database,
       _localTransactionsRepository = localTransactionsRepository,
       _localSavingsRepository = localSavingsRepository,
       _localFinancialOperationsRepository = localFinancialOperationsRepository,
       _useSqliteLocalStoreProvider = useSqliteLocalStoreProvider,
       _localSyncPipeline = localSyncPipeline,
       _pushDebounceDuration = pushDebounceDuration,
       _smartCaptureAlertService =
           smartCaptureAlertService ?? const NoopSmartCaptureAlertService(),
       _sqliteEnabled = database != null,
       _ownsDatabase = ownsDatabase || database == null;

  final AppStateRepository repository;
  final MarketDataApiService marketDataApiService;
  final ReconciliationService reconciliationService;
  final FirestoreSyncManager? firestoreSyncManager;
  final bool enableBackgroundSync;
  final bool enableMarketAutoRefresh;
  final SecureStorageService secureStorageService;
  final bool _sqliteEnabled;
  final bool _ownsDatabase;

  AppDatabase? _database;
  AppDatabase? get database => _database;

  TransactionsLocalStore? _localTransactionsRepository;
  SavingsLocalStore? _localSavingsRepository;
  FinancialOperationsLocalStore? _localFinancialOperationsRepository;
  LocalPendingTransactionsRepository? _localPendingTransactionsRepository;
  LocalAppSettingsRepository? _localAppSettingsRepository;
  LocalFinancialPlansRepository? _localFinancialPlansRepository;
  LocalInvestmentsRepository? _localInvestmentsRepository;
  LocalMerchantRulesRepository? _localMerchantRulesRepository;
  LocalMerchantConfirmationsRepository? _localMerchantConfirmationsRepository;
  LocalCorrectionFeedbackRepository? _localCorrectionFeedbackRepository;
  LocalRecurringTransactionsRepository? _localRecurringTransactionsRepository;
  UseSqliteLocalStoreProvider? _useSqliteLocalStoreProvider;
  LocalSyncPipeline? _localSyncPipeline;
  final SmartCaptureAlertService _smartCaptureAlertService;

  TransactionsLocalStore? get localTransactionsRepository =>
      _localTransactionsRepository;
  SavingsLocalStore? get localSavingsRepository => _localSavingsRepository;
  FinancialOperationsLocalStore? get localFinancialOperationsRepository =>
      _localFinancialOperationsRepository;
  LocalPendingTransactionsRepository? get localPendingTransactionsRepository =>
      _localPendingTransactionsRepository;
  LocalAppSettingsRepository? get localAppSettingsRepository =>
      _localAppSettingsRepository;
  LocalFinancialPlansRepository? get localFinancialPlansRepository =>
      _localFinancialPlansRepository;
  LocalInvestmentsRepository? get localInvestmentsRepository =>
      _localInvestmentsRepository;
  LocalMerchantRulesRepository? get localMerchantRulesRepository =>
      _localMerchantRulesRepository;
  LocalMerchantConfirmationsRepository?
  get localMerchantConfirmationsRepository =>
      _localMerchantConfirmationsRepository;
  LocalCorrectionFeedbackRepository? get localCorrectionFeedbackRepository =>
      _localCorrectionFeedbackRepository;
  LocalRecurringTransactionsRepository?
  get localRecurringTransactionsRepository =>
      _localRecurringTransactionsRepository;
  UseSqliteLocalStoreProvider? get useSqliteLocalStoreProvider =>
      _useSqliteLocalStoreProvider;
  LocalSyncPipeline? get localSyncPipeline => _localSyncPipeline;
  SmartCaptureAlertService get smartCaptureAlertService =>
      _smartCaptureAlertService;
  List<String> get debugWriteFailures =>
      List<String>.unmodifiable(_debugWriteFailures);
  Map<String, String> get collectionSources =>
      Map<String, String>.unmodifiable(_collectionSources);

  Future<void> _initDatabase(String? userId) async {
    if (!_sqliteEnabled) {
      return;
    }

    if (_database != null && _state.loadedUserId == userId) {
      if (_localTransactionsRepository == null ||
          _localSavingsRepository == null ||
          _localFinancialOperationsRepository == null ||
          _localPendingTransactionsRepository == null ||
          _localAppSettingsRepository == null ||
          _localFinancialPlansRepository == null ||
          _localInvestmentsRepository == null ||
          _localMerchantRulesRepository == null ||
          _localMerchantConfirmationsRepository == null ||
          _localCorrectionFeedbackRepository == null ||
          _localRecurringTransactionsRepository == null ||
          _useSqliteLocalStoreProvider == null) {
        await _wireDatabaseDependencies(_database!);
      }
      return;
    }

    if (_database != null && !_ownsDatabase) {
      if (_localTransactionsRepository == null ||
          _localSavingsRepository == null ||
          _localFinancialOperationsRepository == null ||
          _localPendingTransactionsRepository == null ||
          _localAppSettingsRepository == null ||
          _localFinancialPlansRepository == null ||
          _localInvestmentsRepository == null ||
          _localMerchantRulesRepository == null ||
          _localMerchantConfirmationsRepository == null ||
          _localCorrectionFeedbackRepository == null ||
          _localRecurringTransactionsRepository == null ||
          _useSqliteLocalStoreProvider == null) {
        await _wireDatabaseDependencies(_database!);
      }
      return;
    }

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final db = AppDatabase(userId: userId);
    _database = db;
    await _wireDatabaseDependencies(db);
  }

  Future<void> _wireDatabaseDependencies(AppDatabase db) async {
    final migrationStateDao = store_providers.migrationStateProvider(db);
    final transactionsRepo = store_providers
        .localTransactionsRepositoryProvider(db);
    final savingsRepo = store_providers.localSavingsRepositoryProvider(db);
    final financialOpsRepo = store_providers
        .localFinancialOperationsRepositoryProvider(db);
    final pendingTransactionsRepo = store_providers
        .localPendingTransactionsRepositoryProvider(db);
    final appSettingsRepo = store_providers.localAppSettingsRepositoryProvider(
      db,
    );
    final financialPlansRepo = store_providers
        .localFinancialPlansRepositoryProvider(db);
    final investmentsRepo = store_providers.localInvestmentsRepositoryProvider(
      db,
    );
    final merchantRulesRepo = store_providers
        .localMerchantRulesRepositoryProvider(db);
    final merchantConfirmationsRepo = store_providers
        .localMerchantConfirmationsRepositoryProvider(db);
    final correctionFeedbackRepo = store_providers
        .localCorrectionFeedbackRepositoryProvider(db);
    final recurringTransactionsRepo = store_providers
        .localRecurringTransactionsRepositoryProvider(db);

    LocalSyncPipeline? localPipeline;
    if (firestoreSyncManager != null) {
      localPipeline = LocalSyncPipeline(
        firestoreSyncManager: firestoreSyncManager!,
        syncQueueDao: SyncQueueDao(db),
        syncMetadataDao: SyncMetadataDao(db),
        transactionsRepository: transactionsRepo,
        savingsRepository: savingsRepo,
        financialPlansRepository: financialPlansRepo,
        investmentsRepository: investmentsRepo,
        merchantRulesRepository: merchantRulesRepo,
        merchantConfirmationsRepository: merchantConfirmationsRepo,
        correctionFeedbackRepository: correctionFeedbackRepo,
        recurringTransactionsRepository: recurringTransactionsRepo,
        pendingTransactionsRepository: pendingTransactionsRepo,
      );
    }

    final sqliteGate =
        _useSqliteLocalStoreProvider ??
        store_providers.useSqliteLocalStoreProvider(
          JsonToSqliteMigrator(
            database: db,
            migrationStateDao: migrationStateDao,
            legacyRepository: repository,
          ),
        );

    _localTransactionsRepository = transactionsRepo;
    _localSavingsRepository = savingsRepo;
    _localFinancialOperationsRepository = financialOpsRepo;
    _localFinancialPlansRepository = financialPlansRepo;
    _localPendingTransactionsRepository = pendingTransactionsRepo;
    _localAppSettingsRepository = appSettingsRepo;
    _localInvestmentsRepository = investmentsRepo;
    _localMerchantRulesRepository = merchantRulesRepo;
    _localMerchantConfirmationsRepository = merchantConfirmationsRepo;
    _localCorrectionFeedbackRepository = correctionFeedbackRepo;
    _localRecurringTransactionsRepository = recurringTransactionsRepo;
    _localSyncPipeline = localPipeline;
    _useSqliteLocalStoreProvider = sqliteGate;
  }

  void _markCollectionSource(String collection, String source) {
    _collectionSources[collection] = source;
  }

  void _recordDebugWriteFailure(String message) {
    if (!kDebugMode) return;
    _debugWriteFailures.add(message);
    debugPrint(message);
  }

  Future<void> _verifySqliteWrite({
    required String label,
    required String id,
    required Future<bool> Function() existsCheck,
  }) async {
    if (!kDebugMode) return;
    try {
      final bool exists = await existsCheck();
      if (!exists) {
        _recordDebugWriteFailure('$label verification failed for id=$id');
      }
    } catch (error, stackTrace) {
      _recordDebugWriteFailure(
        '$label verification errored for id=$id: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  AppStateModel _state;
  Timer? _marketRefreshTimer;
  bool _marketAutoRefreshStarted = false;
  Future<MarketRefreshResult>? _marketRefreshInFlight;
  StreamSubscription<Map<String, dynamic>>? _userSettingsSubscription;
  String? _liveSyncUserId;
  bool _isApplyingRemoteSync = false;
  bool _useSqliteLocalStore = false;
  bool _skipNextSqliteTransactionMirror = false;
  bool _skipNextSqliteSavingsMirror = false;
  Timer? _deferredPushTimer;
  String _lastSyncTriggerReason = '';
  int _lastSyncQueueCountBeforeTrigger = 0;
  bool _lastSyncPullSkippedDueToThrottle = false;
  final List<String> _debugWriteFailures = <String>[];
  final Map<String, String> _collectionSources = <String, String>{};
  static const Duration marketRefreshInterval = Duration(minutes: 5);
  static const Duration _autoPullInterval = Duration(hours: 6);
  final Duration _pushDebounceDuration;

  AppStateModel get state => _state;
  MarketSnapshot get currentMarketSnapshot =>
      MarketSnapshot.fromAppStateJson(_state.marketData);

  Future<void> loadAuthenticated(String userId) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.loadAuthenticated requires a non-empty authenticated userId.',
    );
    await load(userId: userId);
  }

  Future<void> load({String? userId}) async {
    await _initDatabase(userId);
    _collectionSources.clear();
    try {
      _state = await repository.loadAppState(userId: userId);
      if (userId != null && userId.trim().isNotEmpty) {
        _state = _state.copyWith(userId: userId, loadedUserId: userId);
      }
      _state = await _hydrateAiSettingsFromSecureStorage(
        _state,
        userId: userId ?? _state.userId,
      );
      if (_state.biometricHideWealthEnabled) {
        final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
          _state.aiSettings ?? <String, dynamic>{},
        );
        aiSettings['privacyMode'] = true;
        _state = _state.copyWith(aiSettings: aiSettings);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: unexpected error while loading local app state. '
        'Using default state. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _state = AppStateDefaults.create();
    }
    await _hydrateAppSettingsFromPreferredLocalStore(userId: userId);
    await _hydrateTransactionsFromPreferredLocalStore(userId: userId);
    await _hydrateSavingsFromPreferredLocalStore(userId: userId);
    await _hydratePendingTransactionsFromPreferredLocalStore(userId: userId);
    await _hydrateFinancialPlansFromPreferredLocalStore(userId: userId);
    await _hydrateInvestmentsFromPreferredLocalStore(userId: userId);
    await _hydrateMerchantRulesFromPreferredLocalStore(userId: userId);
    await _hydrateMerchantConfirmationsFromPreferredLocalStore(userId: userId);
    await _hydrateCorrectionFeedbackFromPreferredLocalStore(userId: userId);
    await _hydrateRecurringTransactionsFromPreferredLocalStore(userId: userId);
    final ReconciliationResult reconciled = reconciliationService
        .reconcileExpensesWithSavings(_state);
    _state = reconciled.state;
    if (reconciled.modified) {
      await save();
    }
    notifyListeners();
    unawaited(_syncPendingReviewBadge());
    unawaited(triggerSyncPipeline(reason: 'app_start'));
  }

  Future<void> attachCurrentUser({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
    required String provider,
  }) async {
    _state = _state.copyWith(
      userId: userId,
      userEmail: email,
      userDisplayName: displayName,
      userPhotoUrl: photoUrl,
      userProvider: provider,
      loadedUserId: userId,
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
    unawaited(_syncPendingReviewBadge());
    unawaited(triggerSyncPipeline(reason: 'sign_in'));
  }

  Future<void> resetForCurrentUser(UserProfile user) async {
    _state = AppStateDefaults.create().copyWith(
      userId: user.id,
      userEmail: user.email,
      userDisplayName: user.displayName,
      userPhotoUrl: user.photoUrl,
      userProvider: user.provider,
      loadedUserId: user.id,
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
    unawaited(_syncPendingReviewBadge());
  }

  Future<void> resetForSignedOutUser() async {
    await stopLiveFirestoreSync();
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _state = AppStateDefaults.create();
    await _initDatabase(null);
    notifyListeners();
    unawaited(_syncPendingReviewBadge());
  }

  Future<void> markRestorePromptDismissedForCurrentUser({
    required String userId,
  }) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.markRestorePromptDismissedForCurrentUser requires userId.',
    );
    _state = _state.copyWith(restorePromptDismissedUserId: userId);
    await save();
    notifyListeners();
  }

  Future<void> clearRestorePromptDismissedForCurrentUser({
    required String userId,
  }) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.clearRestorePromptDismissedForCurrentUser requires userId.',
    );
    if (_state.restorePromptDismissedUserId == userId) {
      _state = _state.copyWith(restorePromptDismissedUserId: null);
      await save();
      notifyListeners();
    }
  }

  Future<void> startMarketAutoRefresh({bool refreshImmediately = true}) async {
    if (!enableMarketAutoRefresh) {
      return;
    }
    // Always refresh immediately when the app re-enters the active session.
    // The periodic timer should still be started only once.
    if (refreshImmediately) {
      await refreshMarketData(force: true);
    }
    if (_marketAutoRefreshStarted) return;
    _marketAutoRefreshStarted = true;
    _marketRefreshTimer?.cancel();
    _marketRefreshTimer = Timer.periodic(
      marketRefreshInterval,
      (_) => refreshMarketData(force: true),
    );
  }

  @override
  void dispose() {
    _deferredPushTimer?.cancel();
    unawaited(stopLiveFirestoreSync());
    _marketRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> startLiveFirestoreSync({required String userId}) async {
    if (!enableBackgroundSync) {
      return;
    }
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    if (syncManager == null) return;
    if (_liveSyncUserId == userId && _userSettingsSubscription != null) {
      return;
    }

    await stopLiveFirestoreSync();
    _liveSyncUserId = userId;

    if (_useSqliteLocalStore) {
      if (kDebugMode) {
        debugPrint(
          '[SYNC] user settings listener skipped in SQLite mode for uid=$userId',
        );
      }
    } else {
      await _hydrateTransactionsIncrementally(userId, syncManager);
      await _hydrateSavingsIncrementally(userId, syncManager);
      await _hydrateInvestmentsIncrementally(userId, syncManager);
      await _hydrateCaptureInboxIncrementally(userId, syncManager);
      await _hydrateRecurringTransactionsIncrementally(userId, syncManager);
      await _hydrateFinancialPlansIncrementally(userId, syncManager);
      await _hydrateCorrectionFeedbackIncrementally(userId, syncManager);
      await _hydrateMerchantConfirmationsIncrementally(userId, syncManager);
      await _hydrateMerchantRulesIncrementally(userId, syncManager);
      await _hydrateUserSettings(userId, syncManager);
      _userSettingsSubscription = syncManager
          .watchUserSettings(uid: userId)
          .listen(
            (Map<String, dynamic> settings) {
              unawaited(_applyUserSettingsSnapshot(userId, settings));
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Live user settings sync error: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
          );
      if (kDebugMode) {
        debugPrint('[SYNC] user settings listener attached for uid=$userId');
      }
    }
  }

  Future<void> stopLiveFirestoreSync() async {
    await _userSettingsSubscription?.cancel();
    _userSettingsSubscription = null;
    _liveSyncUserId = null;
  }

  Future<void> _hydrateUserSettings(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final Map<String, dynamic> settings = await syncManager.loadUserSettings(
        uid: userId,
      );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      await _applyUserSettingsSnapshot(userId, settings);
    } catch (error, stackTrace) {
      debugPrint('Firestore user settings hydration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshUserSettingsFromFirestore({
    required String userId,
    required FirestoreSyncManager? syncManager,
    required String reason,
  }) async {
    if (syncManager == null) return;
    try {
      final Map<String, dynamic> settings = await syncManager.loadUserSettings(
        uid: userId,
      );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      await _applyUserSettingsSnapshot(userId, settings);
      if (kDebugMode) {
        debugPrint(
          '[SYNC] user settings refreshed via $reason for uid=$userId',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Firestore user settings refresh error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateTransactionsIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<Transaction> changed = await syncManager
          .loadTransactionsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.transactionsCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedTransactionIdsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedTransactionsCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<Transaction> mergedTransactions = _mergeTransactionsDelta(
        _state.transactions,
        changed.items,
        deleted.ids,
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        transactionsCursor: changed.cursor,
        deletedTransactionsCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool transactionsChanged = !_listJsonEqual(
        _state.transactions,
        mergedTransactions,
        (Transaction item) => item.toJson(),
      );
      final bool syncCursorChanged =
          _state.syncHealth.transactionsCursor != changed.cursor ||
          _state.syncHealth.deletedTransactionsCursor != deleted.cursor;
      if (!transactionsChanged && !syncCursorChanged) return;

      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          transactions: mergedTransactions,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint('Firestore incremental transaction hydration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateSavingsIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<Saving> changed = await syncManager
          .loadSavingsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.savingsCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedSavingsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedSavingsCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<Saving> mergedSavings = _mergeById<Saving>(
        _state.savings,
        changed.items,
        deleted.ids,
        (Saving item) => item.id,
        (Saving item) => DateTime.tryParse(item.createdAt),
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        savingsCursor: changed.cursor,
        deletedSavingsCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.savings,
        mergedSavings,
        (Saving item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.savingsCursor != changed.cursor ||
          _state.syncHealth.deletedSavingsCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          savings: mergedSavings,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint('Firestore incremental savings hydration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateInvestmentsIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<InvestmentAsset> changed =
          await syncManager.loadInvestmentsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.investmentsCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedInvestmentsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedInvestmentsCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<InvestmentAsset> mergedInvestments =
          _mergeById<InvestmentAsset>(
            _state.investments,
            changed.items,
            deleted.ids,
            (InvestmentAsset item) => item.id,
            (InvestmentAsset item) => DateTime.tryParse(item.createdAt),
          );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        investmentsCursor: changed.cursor,
        deletedInvestmentsCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.investments,
        mergedInvestments,
        (InvestmentAsset item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.investmentsCursor != changed.cursor ||
          _state.syncHealth.deletedInvestmentsCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          investments: mergedInvestments,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint('Firestore incremental investments hydration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateCaptureInboxIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<PendingTransaction> changed =
          await syncManager.loadCaptureInboxSince(
            uid: userId,
            sinceCursor: _state.syncHealth.captureInboxCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedCaptureInboxSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedCaptureInboxCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<PendingTransaction> mergedPending =
          _mergeById<PendingTransaction>(
            _state.pendingTransactions,
            changed.items,
            deleted.ids,
            (PendingTransaction item) => item.id,
            (PendingTransaction item) => DateTime.tryParse(item.createdAt),
          );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        captureInboxCursor: changed.cursor,
        deletedCaptureInboxCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_pendingTransactionsEqual(
        _state.pendingTransactions,
        mergedPending,
      );
      final bool cursorChanged =
          _state.syncHealth.captureInboxCursor != changed.cursor ||
          _state.syncHealth.deletedCaptureInboxCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          pendingTransactions: mergedPending,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint('Firestore incremental capture inbox hydration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateRecurringTransactionsIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<RecurringTransaction> changed =
          await syncManager.loadRecurringTransactionsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.recurringTransactionsCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedRecurringTransactionsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedRecurringTransactionsCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<RecurringTransaction> merged =
          _mergeById<RecurringTransaction>(
            _state.recurringTransactions,
            changed.items,
            deleted.ids,
            (RecurringTransaction item) => item.id,
            (RecurringTransaction item) => DateTime.tryParse(item.createdAt),
          );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        recurringTransactionsCursor: changed.cursor,
        deletedRecurringTransactionsCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.recurringTransactions,
        merged,
        (RecurringTransaction item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.recurringTransactionsCursor != changed.cursor ||
          _state.syncHealth.deletedRecurringTransactionsCursor !=
              deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          recurringTransactions: merged,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Firestore incremental recurring transactions hydration error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateFinancialPlansIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<FinancialPlan> changed = await syncManager
          .loadFinancialPlansSince(
            uid: userId,
            sinceCursor: _state.syncHealth.financialPlansCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedFinancialPlansSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedFinancialPlansCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<FinancialPlan> merged = _mergeById<FinancialPlan>(
        _state.financialPlans,
        changed.items,
        deleted.ids,
        (FinancialPlan item) => item.id,
        (FinancialPlan item) => DateTime.tryParse(item.createdAt),
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        financialPlansCursor: changed.cursor,
        deletedFinancialPlansCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.financialPlans,
        merged,
        (FinancialPlan item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.financialPlansCursor != changed.cursor ||
          _state.syncHealth.deletedFinancialPlansCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          financialPlans: merged,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Firestore incremental financial plans hydration error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateCorrectionFeedbackIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<CorrectionFeedback> changed =
          await syncManager.loadCorrectionFeedbackSince(
            uid: userId,
            sinceCursor: _state.syncHealth.correctionFeedbackCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedCorrectionFeedbackSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedCorrectionFeedbackCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<CorrectionFeedback> merged = _mergeById<CorrectionFeedback>(
        _state.correctionFeedback,
        changed.items,
        deleted.ids,
        (CorrectionFeedback item) => item.id,
        (CorrectionFeedback item) => DateTime.tryParse(item.createdAt),
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        correctionFeedbackCursor: changed.cursor,
        deletedCorrectionFeedbackCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.correctionFeedback,
        merged,
        (CorrectionFeedback item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.correctionFeedbackCursor != changed.cursor ||
          _state.syncHealth.deletedCorrectionFeedbackCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          correctionFeedback: merged,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Firestore incremental correction feedback hydration error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateMerchantConfirmationsIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<MerchantConfirmation> changed =
          await syncManager.loadMerchantConfirmationsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.merchantConfirmationsCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedMerchantConfirmationsSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedMerchantConfirmationsCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<MerchantConfirmation>
      merged = _mergeById<MerchantConfirmation>(
        _state.merchantConfirmations,
        changed.items,
        deleted.ids,
        (MerchantConfirmation item) =>
            '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}',
        (_) => null,
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        merchantConfirmationsCursor: changed.cursor,
        deletedMerchantConfirmationsCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final bool changedState = !_listJsonEqual(
        _state.merchantConfirmations,
        merged,
        (MerchantConfirmation item) => item.toJson(),
      );
      final bool cursorChanged =
          _state.syncHealth.merchantConfirmationsCursor != changed.cursor ||
          _state.syncHealth.deletedMerchantConfirmationsCursor !=
              deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          merchantConfirmations: merged,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Firestore incremental merchant confirmations hydration error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateMerchantRulesIncrementally(
    String userId,
    FirestoreSyncManager syncManager,
  ) async {
    try {
      final FirestoreCollectionDelta<MerchantRule> changed = await syncManager
          .loadMerchantRulesSince(
            uid: userId,
            sinceCursor: _state.syncHealth.merchantRulesCursor,
          );
      final FirestoreDeletedIdsDelta deleted = await syncManager
          .loadDeletedMerchantRulesSince(
            uid: userId,
            sinceCursor: _state.syncHealth.deletedMerchantRulesCursor,
          );
      if (_liveSyncUserId != userId || _state.userId != userId) return;
      final List<MerchantRule> currentRules = _state.merchantRules.values
          .toList(growable: false);
      final List<MerchantRule> mergedRules = _mergeById<MerchantRule>(
        currentRules,
        changed.items,
        deleted.ids,
        (MerchantRule item) => item.merchantName.toLowerCase().trim(),
        (_) => null,
      );
      final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
        merchantRulesCursor: changed.cursor,
        deletedMerchantRulesCursor: deleted.cursor,
        lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      final Map<String, MerchantRule> nextRules = <String, MerchantRule>{
        for (final MerchantRule rule in mergedRules)
          rule.merchantName.toLowerCase().trim(): rule,
      };
      final Map<String, String> nextAliases = <String, String>{};
      for (final MerchantRule rule in mergedRules) {
        for (final String alias in rule.aliases) {
          final String key = alias.toLowerCase().trim();
          if (key.isNotEmpty) nextAliases[key] = rule.merchantName;
        }
      }
      final bool changedState =
          !_merchantRuleMapsEqual(_state.merchantRules, nextRules) ||
          !_stringMapsEqual(_state.merchantAliases, nextAliases);
      final bool cursorChanged =
          _state.syncHealth.merchantRulesCursor != changed.cursor ||
          _state.syncHealth.deletedMerchantRulesCursor != deleted.cursor;
      if (!changedState && !cursorChanged) return;
      _isApplyingRemoteSync = true;
      try {
        _state = _state.copyWith(
          merchantRules: nextRules,
          merchantAliases: nextAliases,
          syncHealth: nextSyncHealth,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await save();
        notifyListeners();
      } finally {
        _isApplyingRemoteSync = false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Firestore incremental merchant rules hydration error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _applyUserSettingsSnapshot(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    if (_liveSyncUserId != userId || _state.userId != userId) return;
    final AppStateModel mergedState = _mergeUserSettingsSnapshot(
      _state,
      settings,
    );
    if (_userSettingsEqual(_state, mergedState)) return;
    _isApplyingRemoteSync = true;
    try {
      _state = mergedState.copyWith(
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await save();
      notifyListeners();
    } finally {
      _isApplyingRemoteSync = false;
    }
  }

  bool _pendingTransactionsEqual(
    List<PendingTransaction> left,
    List<PendingTransaction> right,
  ) {
    return _listJsonEqual(
      left,
      right,
      (PendingTransaction item) => item.toJson(),
    );
  }

  bool _merchantRuleMapsEqual(
    Map<String, MerchantRule> left,
    Map<String, MerchantRule> right,
  ) {
    return _canonicalJson(<String, dynamic>{
          for (final String key in left.keys.toList(growable: false)..sort())
            key: left[key]?.toJson(),
        }) ==
        _canonicalJson(<String, dynamic>{
          for (final String key in right.keys.toList(growable: false)..sort())
            key: right[key]?.toJson(),
        });
  }

  bool _stringMapsEqual(Map<String, String> left, Map<String, String> right) {
    return _canonicalJson(left) == _canonicalJson(right);
  }

  bool _listJsonEqual<T>(
    List<T> left,
    List<T> right,
    Map<String, dynamic> Function(T item) encoder,
  ) {
    if (left.length != right.length) return false;
    return _canonicalJson(left.map(encoder).toList(growable: false)) ==
        _canonicalJson(right.map(encoder).toList(growable: false));
  }

  List<Transaction> _mergeTransactionsDelta(
    List<Transaction> current,
    List<Transaction> changed,
    List<String> deletedIds,
  ) {
    return _mergeById<Transaction>(
      current,
      changed,
      deletedIds,
      (Transaction item) => item.id,
      (Transaction item) => DateTime.tryParse(item.createdAt),
    );
  }

  List<T> _mergeById<T>(
    List<T> current,
    List<T> changed,
    List<String> deletedIds,
    String Function(T item) idSelector,
    DateTime? Function(T item) timestampSelector,
  ) {
    final Map<String, T> merged = <String, T>{
      for (final T item in current) idSelector(item): item,
    };
    for (final String id in deletedIds) {
      merged.remove(id.trim());
    }
    for (final T item in changed) {
      final String id = idSelector(item).trim();
      if (id.isNotEmpty) {
        merged[id] = item;
      }
    }
    final List<T> values = merged.values.toList(growable: false);
    values.sort((T a, T b) {
      final DateTime? left = timestampSelector(a);
      final DateTime? right = timestampSelector(b);
      if (left == null && right == null) {
        return idSelector(a).compareTo(idSelector(b));
      }
      if (left == null) return 1;
      if (right == null) return -1;
      final int cmp = right.compareTo(left);
      if (cmp != 0) return cmp;
      return idSelector(a).compareTo(idSelector(b));
    });
    return values;
  }

  String _canonicalJson(dynamic value) {
    return jsonEncode(_normalizeJsonValue(value));
  }

  dynamic _normalizeJsonValue(dynamic value) {
    if (value is Map) {
      final List<String> keys =
          value.keys
              .map((dynamic key) => key.toString())
              .toList(growable: false)
            ..sort();
      return <String, dynamic>{
        for (final String key in keys) key: _normalizeJsonValue(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String raw = (value ?? '').toString().toLowerCase();
    return raw == 'true' || raw == '1';
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic entry) => entry.toString())
          .toList(growable: false);
    }
    return <String>[];
  }

  AppStateModel _mergeUserSettingsSnapshot(
    AppStateModel current,
    Map<String, dynamic> settings,
  ) {
    final Map<String, dynamic> categoriesJson = _asMap(settings['categories']);
    final Map<String, dynamic> appPreferences = _asMap(
      settings['appPreferences'],
    );
    final Map<String, dynamic> zakatConfiguration = _asMap(
      settings['zakatConfiguration'],
    );
    final Map<String, dynamic> securityPrivacy = _asMap(
      settings['securityPrivacy'],
    );
    final Map<String, dynamic> smartCapture = _asMap(settings['smartCapture']);
    final Map<String, dynamic>? mergedAiSettings = _mergeSyncedAiSettings(
      current.aiSettings,
      appPreferences['aiSettings'],
    );
    final AppCategories nextCategories = settings['categories'] is Map
        ? AppCategories.fromJson(<String, dynamic>{
            ...current.categories.toJson(),
            ...categoriesJson,
          })
        : current.categories;
    return current.copyWith(
      categories: nextCategories,
      mainCurrency: appPreferences.containsKey('mainCurrency')
          ? appPreferences['mainCurrency'].toString()
          : current.mainCurrency,
      defaultEntryCurrency: appPreferences.containsKey('defaultEntryCurrency')
          ? appPreferences['defaultEntryCurrency'].toString()
          : current.defaultEntryCurrency,
      languagePreference: appPreferences.containsKey('languagePreference')
          ? appPreferences['languagePreference'].toString()
          : current.languagePreference,
      themeMode: appPreferences.containsKey('themeMode')
          ? appPreferences['themeMode'].toString()
          : current.themeMode,
      zakatScheduleFilter: appPreferences.containsKey('zakatScheduleFilter')
          ? appPreferences['zakatScheduleFilter'].toString()
          : current.zakatScheduleFilter,
      aiSettings: mergedAiSettings,
      lastRollover: zakatConfiguration.containsKey('lastRollover')
          ? zakatConfiguration['lastRollover'].toString()
          : current.lastRollover,
      zakatMethod: zakatConfiguration.containsKey('zakatMethod')
          ? zakatConfiguration['zakatMethod'].toString()
          : current.zakatMethod,
      zakatAnnualDate: zakatConfiguration.containsKey('zakatAnnualDate')
          ? zakatConfiguration['zakatAnnualDate'].toString()
          : current.zakatAnnualDate,
      zakatNisabBasis: zakatConfiguration.containsKey('zakatNisabBasis')
          ? (zakatConfiguration['zakatNisabBasis'].toString() == 'silver595'
                ? 'silver595'
                : 'gold85')
          : current.zakatNisabBasis,
      zakatPaidMonths: zakatConfiguration['zakatPaidMonths'] is List
          ? _asStringList(zakatConfiguration['zakatPaidMonths'])
          : current.zakatPaidMonths,
      processedExpenseIds: zakatConfiguration['processedExpenseIds'] is List
          ? _asStringList(zakatConfiguration['processedExpenseIds'])
          : current.processedExpenseIds,
      zakatExpenseIds: zakatConfiguration['zakatExpenseIds'] is Map
          ? Map<String, dynamic>.from(
              zakatConfiguration['zakatExpenseIds'] as Map,
            )
          : current.zakatExpenseIds,
      biometricLockEnabled: securityPrivacy.containsKey('biometricLockEnabled')
          ? _asBool(securityPrivacy['biometricLockEnabled'])
          : current.biometricLockEnabled,
      biometricHideWealthEnabled:
          securityPrivacy.containsKey('biometricHideWealthEnabled')
          ? _asBool(securityPrivacy['biometricHideWealthEnabled'])
          : current.biometricHideWealthEnabled,
      biometricExportEnabled:
          securityPrivacy.containsKey('biometricExportEnabled')
          ? _asBool(securityPrivacy['biometricExportEnabled'])
          : current.biometricExportEnabled,
      biometricRestoreEnabled:
          securityPrivacy.containsKey('biometricRestoreEnabled')
          ? _asBool(securityPrivacy['biometricRestoreEnabled'])
          : current.biometricRestoreEnabled,
      biometricAutoLockDelay:
          securityPrivacy.containsKey('biometricAutoLockDelay')
          ? securityPrivacy['biometricAutoLockDelay'].toString()
          : current.biometricAutoLockDelay,
      smartCaptureEnabled: smartCapture.containsKey('enabled')
          ? _asBool(smartCapture['enabled'])
          : current.smartCaptureEnabled,
      smartCaptureAutoApproveEnabled:
          smartCapture.containsKey('autoApproveEnabled')
          ? _asBool(smartCapture['autoApproveEnabled'])
          : current.smartCaptureAutoApproveEnabled,
      merchantAliases: settings['merchantAliases'] is Map
          ? (settings['merchantAliases'] as Map).map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, String>(key.toString(), value.toString()),
            )
          : current.merchantAliases,
      captureAnalytics: settings['captureAnalytics'] is Map
          ? CaptureAnalytics.fromJson(
              Map<String, dynamic>.from(settings['captureAnalytics'] as Map),
            )
          : current.captureAnalytics,
    );
  }

  Map<String, dynamic> _buildUserSettingsPayload(AppStateModel state) {
    return <String, dynamic>{
      'categories': state.categories.toJson(),
      'appPreferences': <String, dynamic>{
        'mainCurrency': state.mainCurrency,
        'defaultEntryCurrency': state.defaultEntryCurrency,
        'languagePreference': state.languagePreference,
        'themeMode': state.themeMode,
        'zakatScheduleFilter': state.zakatScheduleFilter,
        if (state.aiSettings != null)
          'aiSettings': _sanitizeAiSettingsForSync(state.aiSettings!),
      },
      'zakatConfiguration': <String, dynamic>{
        'lastRollover': state.lastRollover,
        'zakatMethod': state.zakatMethod,
        'zakatAnnualDate': state.zakatAnnualDate,
        'zakatNisabBasis': state.zakatNisabBasis,
        'zakatPaidMonths': state.zakatPaidMonths,
        'processedExpenseIds': state.processedExpenseIds,
        'zakatExpenseIds': state.zakatExpenseIds,
      },
      'securityPrivacy': <String, dynamic>{
        'biometricLockEnabled': state.biometricLockEnabled,
        'biometricHideWealthEnabled': state.biometricHideWealthEnabled,
        'biometricExportEnabled': state.biometricExportEnabled,
        'biometricRestoreEnabled': state.biometricRestoreEnabled,
        'biometricAutoLockDelay': state.biometricAutoLockDelay,
      },
      'smartCapture': <String, dynamic>{
        'enabled': state.smartCaptureEnabled,
        'autoApproveEnabled': state.smartCaptureAutoApproveEnabled,
      },
      'merchantAliases': state.merchantAliases,
      'captureAnalytics': state.captureAnalytics.toJson(),
    };
  }

  Map<String, String> _merchantAliasesFromRules(
    Map<String, MerchantRule> rules,
  ) {
    final Map<String, String> aliases = <String, String>{};
    for (final MerchantRule rule in rules.values) {
      for (final String alias in rule.aliases) {
        final String aliasKey = alias.toLowerCase().trim();
        if (aliasKey.isNotEmpty) {
          aliases[aliasKey] = rule.merchantName;
        }
      }
    }
    return aliases;
  }

  AppStateModel _mergeAllAppSettingsFromLocalStore(
    AppStateModel current,
    Map<String, dynamic> settings,
  ) {
    return current.copyWith(
      zakatPaidMonths: settings['zakat_paid_months'] is List
          ? _asStringList(settings['zakat_paid_months'])
          : current.zakatPaidMonths,
      zakatExpenseIds: settings['zakat_expense_ids'] is Map
          ? Map<String, dynamic>.from(settings['zakat_expense_ids'] as Map)
          : current.zakatExpenseIds,
      processedExpenseIds: settings['processed_expense_ids'] is List
          ? _asStringList(settings['processed_expense_ids'])
          : current.processedExpenseIds,
      zakatMethod: settings.containsKey('zakat_method')
          ? settings['zakat_method'].toString()
          : current.zakatMethod,
      zakatAnnualDate: settings.containsKey('zakat_annual_date')
          ? settings['zakat_annual_date'].toString()
          : current.zakatAnnualDate,
      zakatNisabBasis: settings.containsKey('zakat_nisab_basis')
          ? (settings['zakat_nisab_basis'].toString() == 'silver595'
                ? 'silver595'
                : 'gold85')
          : current.zakatNisabBasis,
      zakatScheduleFilter: settings.containsKey('zakat_schedule_filter')
          ? settings['zakat_schedule_filter'].toString()
          : current.zakatScheduleFilter,
      mainCurrency: settings.containsKey('main_currency')
          ? settings['main_currency'].toString()
          : current.mainCurrency,
      defaultEntryCurrency: settings.containsKey('default_entry_currency')
          ? settings['default_entry_currency'].toString()
          : current.defaultEntryCurrency,
      languagePreference: settings.containsKey('language_preference')
          ? settings['language_preference'].toString()
          : current.languagePreference,
      themeMode: settings.containsKey('theme_mode')
          ? settings['theme_mode'].toString()
          : current.themeMode,
      biometricLockEnabled: settings.containsKey('biometric_lock_enabled')
          ? _asBool(settings['biometric_lock_enabled'])
          : current.biometricLockEnabled,
      biometricHideWealthEnabled:
          settings.containsKey('biometric_hide_wealth_enabled')
          ? _asBool(settings['biometric_hide_wealth_enabled'])
          : current.biometricHideWealthEnabled,
      biometricExportEnabled: settings.containsKey('biometric_export_enabled')
          ? _asBool(settings['biometric_export_enabled'])
          : current.biometricExportEnabled,
      biometricRestoreEnabled: settings.containsKey('biometric_restore_enabled')
          ? _asBool(settings['biometric_restore_enabled'])
          : current.biometricRestoreEnabled,
      biometricAutoLockDelay: settings.containsKey('biometric_auto_lock_delay')
          ? settings['biometric_auto_lock_delay'].toString()
          : current.biometricAutoLockDelay,
      smartCaptureEnabled: settings.containsKey('smart_capture_enabled')
          ? _asBool(settings['smart_capture_enabled'])
          : current.smartCaptureEnabled,
      smartCaptureAutoApproveEnabled:
          settings.containsKey('smart_capture_auto_approve_enabled')
          ? _asBool(settings['smart_capture_auto_approve_enabled'])
          : current.smartCaptureAutoApproveEnabled,
      categories: settings['categories'] is Map
          ? AppCategories.fromJson(
              Map<String, dynamic>.from(settings['categories'] as Map),
            )
          : current.categories,
      lastRollover: settings.containsKey('last_rollover')
          ? settings['last_rollover'].toString()
          : current.lastRollover,
      merchantAliases: settings['merchant_aliases'] is Map
          ? (settings['merchant_aliases'] as Map).map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, String>(key.toString(), value.toString()),
            )
          : current.merchantAliases,
      captureAnalytics: settings['capture_analytics'] is Map
          ? CaptureAnalytics.fromJson(
              Map<String, dynamic>.from(settings['capture_analytics'] as Map),
            )
          : current.captureAnalytics,
      marketData: settings['market_data'] is Map
          ? Map<String, dynamic>.from(settings['market_data'] as Map)
          : current.marketData,
      marketHistory: settings['market_history'] is List
          ? (settings['market_history'] as List)
                .map((dynamic e) => _asMap(e))
                .toList(growable: false)
          : current.marketHistory,
      syncHealth: settings['sync_health'] is Map
          ? SyncHealth.fromJson(
              Map<String, dynamic>.from(settings['sync_health'] as Map),
            )
          : current.syncHealth,
      aiSettings: settings['ai_settings'] is Map
          ? _mergeSyncedAiSettings(current.aiSettings, settings['ai_settings'])
          : current.aiSettings,
      restorePromptDismissedUserId:
          settings.containsKey('restore_prompt_dismissed_user_id')
          ? settings['restore_prompt_dismissed_user_id']?.toString()
          : current.restorePromptDismissedUserId,
    );
  }

  Map<String, dynamic> _allAppSettingsPayload(AppStateModel state) {
    return <String, dynamic>{
      'zakat_paid_months': state.zakatPaidMonths,
      'zakat_expense_ids': state.zakatExpenseIds,
      'processed_expense_ids': state.processedExpenseIds,
      'zakat_method': state.zakatMethod,
      'zakat_annual_date': state.zakatAnnualDate,
      'zakat_nisab_basis': state.zakatNisabBasis,
      'zakat_schedule_filter': state.zakatScheduleFilter,
      'main_currency': state.mainCurrency,
      'default_entry_currency': state.defaultEntryCurrency,
      'language_preference': state.languagePreference,
      'theme_mode': state.themeMode,
      'biometric_lock_enabled': state.biometricLockEnabled,
      'biometric_hide_wealth_enabled': state.biometricHideWealthEnabled,
      'biometric_export_enabled': state.biometricExportEnabled,
      'biometric_restore_enabled': state.biometricRestoreEnabled,
      'biometric_auto_lock_delay': state.biometricAutoLockDelay,
      'smart_capture_enabled': state.smartCaptureEnabled,
      'smart_capture_auto_approve_enabled':
          state.smartCaptureAutoApproveEnabled,
      'categories': state.categories.toJson(),
      'last_rollover': state.lastRollover,
      'merchant_aliases': state.merchantAliases,
      'capture_analytics': state.captureAnalytics.toJson(),
      'market_data': state.marketData,
      'market_history': state.marketHistory,
      'sync_health': state.syncHealth.toJson(),
      if (state.aiSettings != null)
        'ai_settings': _sanitizeAiSettingsForSync(state.aiSettings!),
      if (state.restorePromptDismissedUserId != null)
        'restore_prompt_dismissed_user_id': state.restorePromptDismissedUserId,
    };
  }

  bool _userSettingsEqual(AppStateModel left, AppStateModel right) {
    return _canonicalJson(_buildUserSettingsPayload(left)) ==
        _canonicalJson(_buildUserSettingsPayload(right));
  }

  Map<String, dynamic> _sanitizeAiSettingsForSync(
    Map<String, dynamic> aiSettings,
  ) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(aiSettings);
    copy.remove('keys');
    return copy;
  }

  Map<String, dynamic>? _mergeSyncedAiSettings(
    Map<String, dynamic>? currentAiSettings,
    dynamic incomingAiSettings,
  ) {
    if (incomingAiSettings is! Map) return currentAiSettings;
    final Map<String, dynamic> merged = Map<String, dynamic>.from(
      currentAiSettings ?? <String, dynamic>{},
    );
    for (final MapEntry<dynamic, dynamic> entry in incomingAiSettings.entries) {
      if (entry.key.toString() != 'keys') {
        merged[entry.key.toString()] = entry.value;
      }
    }
    return merged;
  }

  Future<void> save() async {
    await _saveStateForCompatibility();
  }

  Future<void> _saveStateForCompatibility() async {
    await repository.saveAppState(
      _stateForPersistence(_state),
      userId: _state.userId,
    );
    if (_useSqliteLocalStore && localAppSettingsRepository != null) {
      try {
        await localAppSettingsRepository!.importSettings(
          _allAppSettingsPayload(_state),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror app settings to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore &&
        localTransactionsRepository != null &&
        !_skipNextSqliteTransactionMirror) {
      try {
        await localTransactionsRepository!.replaceAllForLocalMirror(
          _state.transactions,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror transactions to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore &&
        localSavingsRepository != null &&
        !_skipNextSqliteSavingsMirror) {
      try {
        await localSavingsRepository!.replaceAllForLocalMirror(_state.savings);
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror savings to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localPendingTransactionsRepository != null) {
      try {
        await localPendingTransactionsRepository!.replaceAllForLocalMirror(
          _state.pendingTransactions,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror pending transactions to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localFinancialPlansRepository != null) {
      try {
        await localFinancialPlansRepository!.replaceAllForLocalMirror(
          _state.financialPlans,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror financial plans to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localInvestmentsRepository != null) {
      try {
        await localInvestmentsRepository!.replaceAllForLocalMirror(
          _state.investments,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror investments to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localMerchantRulesRepository != null) {
      try {
        await localMerchantRulesRepository!.replaceAllForLocalMirror(
          _state.merchantRules.values,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror merchant rules to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localMerchantConfirmationsRepository != null) {
      try {
        await localMerchantConfirmationsRepository!.replaceAllForLocalMirror(
          _state.merchantConfirmations,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror merchant confirmations to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localCorrectionFeedbackRepository != null) {
      try {
        await localCorrectionFeedbackRepository!.replaceAllForLocalMirror(
          _state.correctionFeedback,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror correction feedback to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (_useSqliteLocalStore && localRecurringTransactionsRepository != null) {
      try {
        await localRecurringTransactionsRepository!.replaceAllForLocalMirror(
          _state.recurringTransactions,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.save: failed to mirror recurring transactions to SQLite. '
          'Falling back to JSON-only persistence for this save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    _skipNextSqliteTransactionMirror = false;
    _skipNextSqliteSavingsMirror = false;
  }

  Future<void> _hydratePendingTransactionsFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalPendingTransactionsRepository? localStore =
        localPendingTransactionsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<PendingTransaction> sqlitePending = await localStore
          .getActivePendingTransactions();
      if (sqlitePending.isNotEmpty) {
        _markCollectionSource('pending_transactions', 'SQLite');
        _state = _state.copyWith(pendingTransactions: sqlitePending);
        return;
      }

      if (_state.pendingTransactions.isNotEmpty) {
        _markCollectionSource('pending_transactions', 'JSON fallback');
        await localStore.importPendingTransactions(_state.pendingTransactions);
        return;
      }
      _markCollectionSource('pending_transactions', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite pending transactions. '
        'Falling back to JSON pending transactions. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateTransactionsFromPreferredLocalStore({
    String? userId,
  }) async {
    final TransactionsLocalStore? localStore = localTransactionsRepository;
    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }
    if (localStore == null) {
      return;
    }

    try {
      final List<Transaction> sqliteTransactions = await localStore
          .getActiveTransactions();
      if (sqliteTransactions.isNotEmpty) {
        _markCollectionSource('transactions', 'SQLite');
        _state = _state.copyWith(transactions: sqliteTransactions);
        return;
      }

      if (_state.transactions.isNotEmpty) {
        _markCollectionSource('transactions', 'JSON fallback');
        if (localStore is LocalTransactionsRepository) {
          await localStore.importTransactions(_state.transactions);
        }
        return;
      }

      _markCollectionSource('transactions', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite transactions. '
        'Falling back to JSON transactions. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateSavingsFromPreferredLocalStore({String? userId}) async {
    final SavingsLocalStore? localStore = localSavingsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<Saving> sqliteSavings = await localStore.getActiveSavings();
      if (sqliteSavings.isNotEmpty) {
        _markCollectionSource('savings', 'SQLite');
        _state = _state.copyWith(savings: sqliteSavings);
        return;
      }

      if (_state.savings.isNotEmpty) {
        _markCollectionSource('savings', 'JSON fallback');
        if (localStore is LocalSavingsRepository) {
          await localStore.importSavings(_state.savings);
        }
        return;
      }

      _markCollectionSource('savings', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite savings. '
        'Falling back to JSON savings. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateFinancialPlansFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalFinancialPlansRepository? localStore =
        localFinancialPlansRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<FinancialPlan> sqlitePlans = await localStore
          .getActiveFinancialPlans();
      if (sqlitePlans.isNotEmpty) {
        _markCollectionSource('financial_plans', 'SQLite');
        _state = _state.copyWith(financialPlans: sqlitePlans);
        return;
      }

      if (_state.financialPlans.isNotEmpty) {
        _markCollectionSource('financial_plans', 'JSON fallback');
        await localStore.importFinancialPlans(_state.financialPlans);
        return;
      }
      _markCollectionSource('financial_plans', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite financial plans. '
        'Falling back to JSON financial plans. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateInvestmentsFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalInvestmentsRepository? localStore = localInvestmentsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<InvestmentAsset> sqliteInvestments = await localStore
          .getActiveInvestments();
      if (sqliteInvestments.isNotEmpty) {
        _markCollectionSource('investments', 'SQLite');
        _state = _state.copyWith(investments: sqliteInvestments);
        return;
      }

      if (_state.investments.isNotEmpty) {
        _markCollectionSource('investments', 'JSON fallback');
        await localStore.importInvestments(_state.investments);
        return;
      }
      _markCollectionSource('investments', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite investments. '
        'Falling back to JSON investments. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateMerchantRulesFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalMerchantRulesRepository? localStore =
        localMerchantRulesRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final Map<String, MerchantRule> sqliteRules = await localStore
          .getActiveMerchantRules();
      if (sqliteRules.isNotEmpty) {
        _markCollectionSource('merchant_rules', 'SQLite');
        _state = _state.copyWith(
          merchantRules: sqliteRules,
          merchantAliases: _merchantAliasesFromRules(sqliteRules),
        );
        return;
      }

      if (_state.merchantRules.isNotEmpty) {
        _markCollectionSource('merchant_rules', 'JSON fallback');
        await localStore.importMerchantRules(_state.merchantRules.values);
        return;
      }
      _markCollectionSource('merchant_rules', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite merchant rules. '
        'Falling back to JSON merchant rules. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateMerchantConfirmationsFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalMerchantConfirmationsRepository? localStore =
        localMerchantConfirmationsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<MerchantConfirmation> sqliteItems = await localStore
          .getActiveMerchantConfirmations();
      if (sqliteItems.isNotEmpty) {
        _markCollectionSource('merchant_confirmations', 'SQLite');
        _state = _state.copyWith(merchantConfirmations: sqliteItems);
        return;
      }

      if (_state.merchantConfirmations.isNotEmpty) {
        _markCollectionSource('merchant_confirmations', 'JSON fallback');
        await localStore.importMerchantConfirmations(
          _state.merchantConfirmations,
        );
        return;
      }
      _markCollectionSource('merchant_confirmations', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite merchant confirmations. '
        'Falling back to JSON merchant confirmations. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateCorrectionFeedbackFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalCorrectionFeedbackRepository? localStore =
        localCorrectionFeedbackRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<CorrectionFeedback> sqliteItems = await localStore
          .getActiveCorrectionFeedback();
      if (sqliteItems.isNotEmpty) {
        _markCollectionSource('correction_feedback', 'SQLite');
        _state = _state.copyWith(correctionFeedback: sqliteItems);
        return;
      }

      if (_state.correctionFeedback.isNotEmpty) {
        _markCollectionSource('correction_feedback', 'JSON fallback');
        await localStore.importCorrectionFeedback(_state.correctionFeedback);
        return;
      }
      _markCollectionSource('correction_feedback', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite correction feedback. '
        'Falling back to JSON correction feedback. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateRecurringTransactionsFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalRecurringTransactionsRepository? localStore =
        localRecurringTransactionsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final List<RecurringTransaction> sqliteRecurring = await localStore
          .getActiveRecurringTransactions();
      if (sqliteRecurring.isNotEmpty) {
        _markCollectionSource('recurring_transactions', 'SQLite');
        _state = _state.copyWith(recurringTransactions: sqliteRecurring);
        return;
      }

      if (_state.recurringTransactions.isNotEmpty) {
        _markCollectionSource('recurring_transactions', 'JSON fallback');
        await localStore.importRecurringTransactions(
          _state.recurringTransactions,
        );
        return;
      }
      _markCollectionSource('recurring_transactions', 'empty default');
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite recurring transactions. '
        'Falling back to JSON recurring transactions. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateAppSettingsFromPreferredLocalStore({
    String? userId,
  }) async {
    final LocalAppSettingsRepository? localStore = localAppSettingsRepository;
    if (localStore == null) {
      return;
    }

    if (!await _prepareSqliteLocalStore(userId: userId)) {
      return;
    }

    try {
      final Map<String, dynamic> settings = await localStore.getAllSettings();
      final AppStateModel mergedState = _mergeAllAppSettingsFromLocalStore(
        _state,
        settings,
      );
      final bool missingSettings = <String>[
        'zakat_paid_months',
        'zakat_expense_ids',
        'processed_expense_ids',
        'zakat_method',
        'zakat_annual_date',
        'zakat_nisab_basis',
        'zakat_schedule_filter',
        'main_currency',
        'theme_mode',
      ].any((String key) => !settings.containsKey(key));
      _state = mergedState;
      _markCollectionSource(
        'app_settings',
        settings.isNotEmpty ? 'SQLite' : 'empty default',
      );
      if (missingSettings) {
        await localStore.importSettings(_allAppSettingsPayload(_state));
      }
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.load: failed to read SQLite app settings. '
        'Falling back to JSON settings. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _prepareSqliteLocalStore({String? userId}) async {
    if (_useSqliteLocalStore) {
      return true;
    }

    final UseSqliteLocalStoreProvider? gate = useSqliteLocalStoreProvider;
    if (gate == null) {
      _useSqliteLocalStore = false;
      return false;
    }

    final bool useSqlite = await gate.prepareForRead(userId: userId);
    _useSqliteLocalStore = useSqlite;
    return useSqlite;
  }

  Future<void> clearLocalData() async {
    await stopLiveFirestoreSync();
    await repository.clearLocalData(userId: _state.userId);
    await secureStorageService.deleteAiKeys(userId: _state.userId);
    _state = AppStateDefaults.create();
    notifyListeners();
  }

  Future<void> clearLocalDataForUser({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.clearLocalDataForUser requires userId.',
    );
    await stopLiveFirestoreSync();
    await repository.clearLocalData(userId: userId);
    await secureStorageService.deleteAiKeys(userId: userId);
    _state = AppStateDefaults.create();
    notifyListeners();
  }

  Future<void> clearLocalDataForSignOut({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.clearLocalDataForSignOut requires userId.',
    );
    await stopLiveFirestoreSync();
    await repository.clearLocalDataForSignOut(userId: userId);
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _state = AppStateDefaults.create();
    await _initDatabase(null);
    notifyListeners();
  }

  Future<void> deleteCloudDataForUser({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.deleteCloudDataForUser requires userId.',
    );
    await stopLiveFirestoreSync();
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    if (syncManager == null) {
      throw StateError(
        'Cloud sync is not configured; cannot delete remote account data.',
      );
    }
    await syncManager.deleteAllUserData(uid: userId);
  }

  Future<void> deleteLocalDataForUser({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.deleteLocalDataForUser requires userId.',
    );
    await stopLiveFirestoreSync();
    await repository.clearLocalDataForSignOut(userId: userId);
    await secureStorageService.deleteAiKeys(userId: userId);
    await repository.localStorage.remove(StorageKeys.userProfileKey);
    await repository.localStorage.remove(StorageKeys.appStateAnonymousKey);
    await repository.localStorage.remove(StorageKeys.aiKeysAnonymousKey);
    await SyncDiagnosticsService.clear();
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await AppDatabase.deleteDatabaseFiles(userId: userId);
    _useSqliteLocalStore = false;
    _localTransactionsRepository = null;
    _localSavingsRepository = null;
    _localFinancialOperationsRepository = null;
    _localPendingTransactionsRepository = null;
    _localAppSettingsRepository = null;
    _localFinancialPlansRepository = null;
    _localInvestmentsRepository = null;
    _localMerchantRulesRepository = null;
    _localMerchantConfirmationsRepository = null;
    _localCorrectionFeedbackRepository = null;
    _localRecurringTransactionsRepository = null;
    _localSyncPipeline = null;
    _useSqliteLocalStoreProvider = null;
    _state = AppStateDefaults.create();
    _collectionSources.clear();
    _debugWriteFailures.clear();
    await _initDatabase(null);
    notifyListeners();
  }

  Future<void> deleteAccountData({required String userId}) async {
    assert(
      userId.trim().isNotEmpty,
      'AppStateController.deleteAccountData requires userId.',
    );
    await stopLiveFirestoreSync();
    await deleteCloudDataForUser(userId: userId);
    await deleteLocalDataForUser(userId: userId);
  }

  Future<void> updateState(AppStateModel newState) async {
    final AppStateModel previousState = _state;
    final ReconciliationResult reconciled = reconciliationService
        .reconcileExpensesWithSavings(newState);
    _state = reconciled.state.copyWith(
      lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await save();
    notifyListeners();
    final int previousPendingReviewCount = previousState.pendingTransactions
        .where(
          (PendingTransaction item) =>
              item.status == CaptureStatus.pendingReview,
        )
        .length;
    final int nextPendingReviewCount = _state.pendingTransactions
        .where(
          (PendingTransaction item) =>
              item.status == CaptureStatus.pendingReview,
        )
        .length;
    if (previousPendingReviewCount != nextPendingReviewCount) {
      unawaited(_syncPendingReviewBadge(nextPendingReviewCount));
    }
    if (!_isApplyingRemoteSync &&
        _useSqliteLocalStore &&
        localPendingTransactionsRepository != null &&
        !_pendingTransactionsEqual(
          previousState.pendingTransactions,
          _state.pendingTransactions,
        )) {
      try {
        final Set<String> previousIds = previousState.pendingTransactions
            .map((PendingTransaction item) => item.id)
            .toSet();
        final Set<String> nextIds = _state.pendingTransactions
            .map((PendingTransaction item) => item.id)
            .toSet();
        for (final String id in previousIds.difference(nextIds)) {
          await localPendingTransactionsRepository!.deletePendingTransaction(
            id,
          );
          await _verifySqliteWrite(
            label: 'Pending transaction delete',
            id: id,
            existsCheck: () async =>
                (await localPendingTransactionsRepository!
                        .getActivePendingTransactions())
                    .every((PendingTransaction item) => item.id != id),
          );
        }
        for (final PendingTransaction pending in _state.pendingTransactions) {
          await localPendingTransactionsRepository!.savePendingTransaction(
            pending,
          );
          await _verifySqliteWrite(
            label: 'Pending transaction write',
            id: pending.id,
            existsCheck: () async =>
                (await localPendingTransactionsRepository!
                        .getActivePendingTransactions())
                    .any((PendingTransaction item) => item.id == pending.id),
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateState: failed to mirror pending transactions to SQLite queue. '
          'Continuing with JSON compatibility only. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!_isApplyingRemoteSync &&
        _useSqliteLocalStore &&
        localFinancialPlansRepository != null &&
        !_listJsonEqual(
          previousState.financialPlans,
          _state.financialPlans,
          (FinancialPlan item) => item.toJson(),
        )) {
      try {
        final Map<String, FinancialPlan> previousById = <String, FinancialPlan>{
          for (final FinancialPlan plan in previousState.financialPlans)
            plan.id: plan,
        };
        final Map<String, FinancialPlan> nextById = <String, FinancialPlan>{
          for (final FinancialPlan plan in _state.financialPlans) plan.id: plan,
        };
        final Set<String> previousIds = previousById.keys.toSet();
        final Set<String> nextIds = nextById.keys.toSet();
        for (final String id in previousIds.difference(nextIds)) {
          await localFinancialPlansRepository!.deleteFinancialPlan(id);
          await _verifySqliteWrite(
            label: 'Financial plan delete',
            id: id,
            existsCheck: () async =>
                (await localFinancialPlansRepository!.getActiveFinancialPlans())
                    .any((FinancialPlan item) => item.id == id),
          );
        }
        for (final MapEntry<String, FinancialPlan> entry in nextById.entries) {
          final FinancialPlan? previous = previousById[entry.key];
          if (previous == null ||
              jsonEncode(previous.toJson()) !=
                  jsonEncode(entry.value.toJson())) {
            await localFinancialPlansRepository!.saveFinancialPlan(entry.value);
            await _verifySqliteWrite(
              label: 'Financial plan write',
              id: entry.key,
              existsCheck: () async =>
                  (await localFinancialPlansRepository!
                          .getActiveFinancialPlans())
                      .any((FinancialPlan item) => item.id == entry.key),
            );
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateState: failed to mirror financial plans to SQLite queue. '
          'Continuing with JSON compatibility only. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!_isApplyingRemoteSync &&
        _useSqliteLocalStore &&
        localMerchantRulesRepository != null &&
        !_merchantRuleMapsEqual(
          previousState.merchantRules,
          _state.merchantRules,
        )) {
      try {
        final Map<String, MerchantRule> previousById =
            previousState.merchantRules;
        final Map<String, MerchantRule> nextById = _state.merchantRules;
        final Set<String> previousIds = previousById.keys.toSet();
        final Set<String> nextIds = nextById.keys.toSet();
        for (final String id in previousIds.difference(nextIds)) {
          await localMerchantRulesRepository!.deleteMerchantRule(id);
          await _verifySqliteWrite(
            label: 'Merchant rule delete',
            id: id,
            existsCheck: () async =>
                !(await localMerchantRulesRepository!.getActiveMerchantRules())
                    .containsKey(id),
          );
        }
        for (final MapEntry<String, MerchantRule> entry in nextById.entries) {
          final MerchantRule? previous = previousById[entry.key];
          if (previous == null ||
              jsonEncode(previous.toJson()) !=
                  jsonEncode(entry.value.toJson())) {
            await localMerchantRulesRepository!.saveMerchantRule(entry.value);
            await _verifySqliteWrite(
              label: 'Merchant rule write',
              id: entry.key,
              existsCheck: () async =>
                  (await localMerchantRulesRepository!.getActiveMerchantRules())
                      .containsKey(entry.key),
            );
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateState: failed to mirror merchant rules to SQLite queue. '
          'Continuing with JSON compatibility only. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!_isApplyingRemoteSync &&
        _useSqliteLocalStore &&
        localMerchantConfirmationsRepository != null &&
        !_listJsonEqual(
          previousState.merchantConfirmations,
          _state.merchantConfirmations,
          (MerchantConfirmation item) => item.toJson(),
        )) {
      try {
        final Map<String, MerchantConfirmation>
        previousById = <String, MerchantConfirmation>{
          for (final MerchantConfirmation item
              in previousState.merchantConfirmations)
            '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}':
                item,
        };
        final Map<String, MerchantConfirmation>
        nextById = <String, MerchantConfirmation>{
          for (final MerchantConfirmation item in _state.merchantConfirmations)
            '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}':
                item,
        };
        final Set<String> previousIds = previousById.keys.toSet();
        final Set<String> nextIds = nextById.keys.toSet();
        for (final String id in previousIds.difference(nextIds)) {
          await localMerchantConfirmationsRepository!
              .deleteMerchantConfirmation(id);
          await _verifySqliteWrite(
            label: 'Merchant confirmation delete',
            id: id,
            existsCheck: () async =>
                (await localMerchantConfirmationsRepository!
                        .getActiveMerchantConfirmations())
                    .every(
                      (MerchantConfirmation item) =>
                          '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}' !=
                          id,
                    ),
          );
        }
        for (final MapEntry<String, MerchantConfirmation> entry
            in nextById.entries) {
          final MerchantConfirmation? previous = previousById[entry.key];
          if (previous == null ||
              jsonEncode(previous.toJson()) !=
                  jsonEncode(entry.value.toJson())) {
            await localMerchantConfirmationsRepository!
                .saveMerchantConfirmation(entry.value);
            await _verifySqliteWrite(
              label: 'Merchant confirmation write',
              id: entry.key,
              existsCheck: () async =>
                  (await localMerchantConfirmationsRepository!
                          .getActiveMerchantConfirmations())
                      .any(
                        (MerchantConfirmation item) =>
                            '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}' ==
                            entry.key,
                      ),
            );
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateState: failed to mirror merchant confirmations to SQLite queue. '
          'Continuing with JSON compatibility only. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!_isApplyingRemoteSync &&
        _useSqliteLocalStore &&
        localCorrectionFeedbackRepository != null &&
        !_listJsonEqual(
          previousState.correctionFeedback,
          _state.correctionFeedback,
          (CorrectionFeedback item) => item.toJson(),
        )) {
      try {
        final Map<String, CorrectionFeedback> previousById =
            <String, CorrectionFeedback>{
              for (final CorrectionFeedback item
                  in previousState.correctionFeedback)
                item.id: item,
            };
        final Map<String, CorrectionFeedback> nextById =
            <String, CorrectionFeedback>{
              for (final CorrectionFeedback item in _state.correctionFeedback)
                item.id: item,
            };
        final Set<String> previousIds = previousById.keys.toSet();
        final Set<String> nextIds = nextById.keys.toSet();
        for (final String id in previousIds.difference(nextIds)) {
          await localCorrectionFeedbackRepository!.deleteCorrectionFeedback(id);
          await _verifySqliteWrite(
            label: 'Correction feedback delete',
            id: id,
            existsCheck: () async =>
                (await localCorrectionFeedbackRepository!
                        .getActiveCorrectionFeedback())
                    .every((CorrectionFeedback item) => item.id != id),
          );
        }
        for (final MapEntry<String, CorrectionFeedback> entry
            in nextById.entries) {
          final CorrectionFeedback? previous = previousById[entry.key];
          if (previous == null ||
              jsonEncode(previous.toJson()) !=
                  jsonEncode(entry.value.toJson())) {
            await localCorrectionFeedbackRepository!.saveCorrectionFeedback(
              entry.value,
            );
            await _verifySqliteWrite(
              label: 'Correction feedback write',
              id: entry.key,
              existsCheck: () async =>
                  (await localCorrectionFeedbackRepository!
                          .getActiveCorrectionFeedback())
                      .any((CorrectionFeedback item) => item.id == entry.key),
            );
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateState: failed to mirror correction feedback to SQLite queue. '
          'Continuing with JSON compatibility only. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!_isApplyingRemoteSync) {
      _syncSensitiveCollectionsInBackground(previousState, _state);
    }
  }

  Future<void> triggerSyncPipeline({String reason = 'manual'}) async {
    _lastSyncTriggerReason = reason;
    _lastSyncPullSkippedDueToThrottle = false;
    if (kDebugMode) {
      print(
        '[SYNC-TRIGGER] triggerSyncPipeline called: reason=$reason, userId=${_state.userId != null}, SQLite mode active=$_useSqliteLocalStore',
      );
    }

    final String? uid = _state.userId;
    if (uid == null || uid.trim().isEmpty) {
      if (kDebugMode) {
        print('[SYNC-TRIGGER] Sync skipped: userId does not exist');
      }
      return;
    }
    if (!_useSqliteLocalStore || localSyncPipeline == null) {
      if (kDebugMode) {
        print(
          '[SYNC-TRIGGER] Sync skipped: SQLite mode is inactive or sync pipeline is uninitialized',
        );
      }
      return;
    }
    if (localSyncPipeline!.syncInProgress) {
      if (kDebugMode) {
        print('[SYNC-TRIGGER] Sync skipped: sync already in progress');
      }
      return;
    }
    final int queueCountBeforeTrigger = await _queueCount();
    _lastSyncQueueCountBeforeTrigger = queueCountBeforeTrigger;
    if (kDebugMode) {
      print('[SYNC-TRIGGER] queueCountBeforeTrigger=$queueCountBeforeTrigger');
    }

    final bool isManual = reason == 'manual';
    if (reason == 'local_write') {
      if (queueCountBeforeTrigger == 0) {
        return;
      }
      _scheduleDebouncedPush(
        uid,
        queueCountBeforeTrigger: queueCountBeforeTrigger,
      );
      return;
    }

    _cancelDebouncedPush();

    final bool queueNonEmpty = queueCountBeforeTrigger > 0;
    final bool isStartupReason =
        reason == 'app_start' || reason == 'app_resume';
    final String? lastPullSuccessAt = await localSyncPipeline!
        .lastPullSuccessAt();
    final bool hasPullCursor = await localSyncPipeline!.hasPullCursor();
    final bool hasRecentPull = _isRecentPull(lastPullSuccessAt);
    if (isStartupReason &&
        queueCountBeforeTrigger == 0 &&
        hasPullCursor &&
        !hasRecentPull) {
      if (kDebugMode) {
        print(
          '[SYNC-TRIGGER] pull skipped on $reason: empty queue with existing pull cursor',
        );
      }
      _lastSyncPullSkippedDueToThrottle = true;
      return;
    }
    final bool shouldPull = isManual
        ? true
        : reason == 'sign_in'
        ? (await localSyncPipeline!.shouldPullNow()) ||
              !(await localSyncPipeline!.hasPullCursor())
        : await localSyncPipeline!.shouldPullNow();

    _lastSyncPullSkippedDueToThrottle = !isManual && !shouldPull;

    try {
      if (isManual) {
        if (kDebugMode) {
          print('[SYNC-TRIGGER] manual sync requested');
        }
        await localSyncPipeline!.pushThenPull(uid);
        await _refreshStateFromLocalRepositories(reason: 'manual');
        if (_useSqliteLocalStore) {
          await _refreshUserSettingsFromFirestore(
            userId: uid,
            syncManager: firestoreSyncManager,
            reason: 'manual',
          );
        }
        unawaited(
          _logSavingsConsistencyWarningIfNeeded(source: 'sync:$reason'),
        );
        return;
      }

      if (queueNonEmpty) {
        if (kDebugMode) {
          print('[SYNC-TRIGGER] pushing queue before pull decision');
        }
        await localSyncPipeline!.pushOnly(uid);
      }

      if (!shouldPull) {
        if (kDebugMode) {
          print('[SYNC-TRIGGER] pull skipped due to throttle');
        }
        return;
      }

      if (kDebugMode) {
        print('[SYNC-TRIGGER] running pull');
      }
      await localSyncPipeline!.pullOnly(uid);
      await _refreshStateFromLocalRepositories(reason: reason);
      unawaited(_logSavingsConsistencyWarningIfNeeded(source: 'sync:$reason'));
    } catch (error) {
      debugPrint('AppStateController: Sync pipeline failed: $error');
    }
  }

  Future<ManualSyncResult> runManualSync() async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final LocalSyncPipeline? pipeline = localSyncPipeline;
    final AppDatabase? db = _database;
    final String uid = _state.userId?.trim() ?? '';
    final String databaseFileName = db?.fileName ?? 'unavailable';
    final String? databasePath = db == null
        ? null
        : await db.resolveDatabasePath();
    final String firestorePath = uid.isEmpty ? 'users/<none>' : 'users/$uid';

    if (syncManager == null || pipeline == null || db == null) {
      return ManualSyncResult(
        success: false,
        message: 'Sync is not available.',
        reason: 'sync unavailable',
        expectedUid: uid,
        firebaseUid: null,
        databaseFileName: databaseFileName,
        databasePath: databasePath,
        firestorePushPath: firestorePath,
        firestorePullPath: firestorePath,
        authValid: false,
        pushAttempted: false,
        pullAttempted: false,
        queueCountBefore: 0,
        queueCountAfter: 0,
        rowsPushed: 0,
        rowsFailed: 0,
        pullCollectionsQueried: 0,
        pullDocsApplied: 0,
        pullDeletedDocsApplied: 0,
        cursorUpdates: 0,
        failureCode: 'sync-unavailable',
        failureMessage: 'Sync is not available.',
      );
    }
    if (pipeline.syncInProgress) {
      return ManualSyncResult(
        success: false,
        message: 'Sync already in progress.',
        reason: 'sync already in progress',
        expectedUid: uid,
        firebaseUid: null,
        databaseFileName: databaseFileName,
        databasePath: databasePath,
        firestorePushPath: firestorePath,
        firestorePullPath: firestorePath,
        authValid: false,
        pushAttempted: false,
        pullAttempted: false,
        queueCountBefore: 0,
        queueCountAfter: 0,
        rowsPushed: 0,
        rowsFailed: 0,
        pullCollectionsQueried: 0,
        pullDocsApplied: 0,
        pullDeletedDocsApplied: 0,
        cursorUpdates: 0,
        failureCode: 'sync-in-progress',
        failureMessage: 'Sync already in progress.',
      );
    }

    final FirestoreAuthValidationResult authCheck = await syncManager
        .validateSession(expectedUid: uid);
    final int queueBefore = await _queueCount();
    final bool pushAttempted = queueBefore > 0;
    final String pushPath = firestorePath;
    final String pullPath = firestorePath;
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'sync',
      message: 'Manual sync started',
      metadata: <String, dynamic>{
        'controllerUserId': uid,
        'firebaseUid': authCheck.currentUid,
        'authValid': authCheck.isValid,
        'authErrorCode': authCheck.errorCode,
        'authErrorMessage': authCheck.errorMessage,
        'databaseFileName': databaseFileName,
        'databasePath': databasePath,
        'pushPath': pushPath,
        'pullPath': pullPath,
        'queueCountBefore': queueBefore,
        'syncPipelineInitialized': true,
      },
    );

    if (!authCheck.isValid) {
      final String message = authCheck.isSignedIn
          ? (authCheck.isUidMatch
                ? (authCheck.errorMessage ?? 'Auth token refresh failed.')
                : 'Auth user mismatch.')
          : 'Not signed in.';
      return ManualSyncResult(
        success: false,
        message: message,
        reason: authCheck.errorCode ?? 'auth invalid',
        expectedUid: uid,
        firebaseUid: authCheck.currentUid,
        databaseFileName: databaseFileName,
        databasePath: databasePath,
        firestorePushPath: pushPath,
        firestorePullPath: pullPath,
        authValid: false,
        pushAttempted: false,
        pullAttempted: false,
        queueCountBefore: queueBefore,
        queueCountAfter: queueBefore,
        rowsPushed: 0,
        rowsFailed: 0,
        pullCollectionsQueried: 0,
        pullDocsApplied: 0,
        pullDeletedDocsApplied: 0,
        cursorUpdates: 0,
        failureCode: authCheck.errorCode,
        failureMessage: message,
      );
    }

    final SyncQueueProcessResult pushResult = pushAttempted
        ? await pipeline.pushOnly(uid)
        : const SyncQueueProcessResult(attempted: 0, succeeded: 0, failed: 0);
    final PullSyncResult pullResult = await pipeline.pullOnlyDetailed(uid);
    if (pullResult.success) {
      await pipeline.markPullSuccess();
    }
    final int queueAfter = await _queueCount();
    final bool success = pushResult.failed == 0 && pullResult.success;
    final bool alreadySynced =
        !pushAttempted &&
        pullResult.success &&
        pullResult.docsApplied == 0 &&
        pullResult.deletedDocsApplied == 0;
    final String message = !success
        ? (authCheck.errorMessage ?? pullResult.errorMessage ?? 'Sync failed.')
        : alreadySynced
        ? 'Already synced'
        : 'Manual sync completed';

    await SyncDiagnosticsService.record(
      level: success ? 'info' : 'error',
      subsystem: 'sync',
      message: success ? 'Manual sync completed' : 'Manual sync failed',
      metadata: <String, dynamic>{
        'controllerUserId': uid,
        'firebaseUid': authCheck.currentUid,
        'authValid': authCheck.isValid,
        'queueCountBefore': queueBefore,
        'queueCountAfter': queueAfter,
        'pushAttempted': pushAttempted,
        'pushSucceeded': pushResult.succeeded,
        'pushFailed': pushResult.failed,
        'pullAttempted': true,
        'pullCollectionsQueried': pullResult.collectionsQueried,
        'pullDocsApplied': pullResult.docsApplied,
        'pullDeletedDocsApplied': pullResult.deletedDocsApplied,
        'cursorUpdates': pullResult.cursorUpdates,
        'pushPath': pushPath,
        'pullPath': pullPath,
        'databaseFileName': databaseFileName,
        'databasePath': databasePath,
        'alreadySynced': alreadySynced,
        'failureCode': pullResult.errorCode ?? authCheck.errorCode,
        'failureMessage': pullResult.errorMessage ?? authCheck.errorMessage,
      },
    );

    return ManualSyncResult(
      success: success,
      message: message,
      reason: success
          ? 'manual sync completed'
          : (authCheck.errorCode ?? pullResult.errorCode ?? 'sync failed'),
      expectedUid: uid,
      firebaseUid: authCheck.currentUid,
      databaseFileName: databaseFileName,
      databasePath: databasePath,
      firestorePushPath: pushPath,
      firestorePullPath: pullPath,
      authValid: authCheck.isValid,
      pushAttempted: pushAttempted,
      pullAttempted: true,
      queueCountBefore: queueBefore,
      queueCountAfter: queueAfter,
      rowsPushed: pushResult.succeeded,
      rowsFailed: pushResult.failed,
      pullCollectionsQueried: pullResult.collectionsQueried,
      pullDocsApplied: pullResult.docsApplied,
      pullDeletedDocsApplied: pullResult.deletedDocsApplied,
      cursorUpdates: pullResult.cursorUpdates,
      failureCode: success
          ? null
          : (pullResult.errorCode ?? authCheck.errorCode),
      failureMessage: success
          ? null
          : (pullResult.errorMessage ?? authCheck.errorMessage),
      alreadySynced: alreadySynced,
    );
  }

  Future<int> _queueCount() async {
    final LocalSyncPipeline? pipeline = localSyncPipeline;
    if (pipeline == null) return 0;
    try {
      return await pipeline.queueCount();
    } catch (_) {
      return 0;
    }
  }

  void _scheduleDebouncedPush(
    String uid, {
    required int queueCountBeforeTrigger,
  }) {
    _cancelDebouncedPush();
    if (queueCountBeforeTrigger <= 0) return;
    if (kDebugMode) {
      print(
        '[SYNC-TRIGGER] scheduling debounced push in ${_pushDebounceDuration.inSeconds}s',
      );
    }
    _deferredPushTimer = Timer(_pushDebounceDuration, () {
      unawaited(_runDebouncedPush(uid));
    });
  }

  Future<void> _runDebouncedPush(String uid) async {
    if (_useSqliteLocalStore == false || localSyncPipeline == null) return;
    if (localSyncPipeline!.syncInProgress) {
      final int queueCount = await _queueCount();
      if (queueCount > 0) {
        _scheduleDebouncedPush(uid, queueCountBeforeTrigger: queueCount);
      }
      return;
    }
    try {
      await localSyncPipeline!.pushOnly(uid);
    } catch (error) {
      debugPrint('AppStateController: debounced push failed: $error');
    }
  }

  void _cancelDebouncedPush() {
    _deferredPushTimer?.cancel();
    _deferredPushTimer = null;
  }

  bool _isRecentPull(String? timestamp) {
    final String raw = (timestamp ?? '').trim();
    if (raw.isEmpty) return false;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    return DateTime.now().toUtc().difference(parsed.toUtc()) <
        _autoPullInterval;
  }

  Future<void> _refreshStateFromLocalRepositories({
    required String reason,
  }) async {
    if (localTransactionsRepository != null && localSavingsRepository != null) {
      final transactions = await localTransactionsRepository!
          .getActiveTransactions();
      final savings = await localSavingsRepository!.getActiveSavings();
      final financialPlans = localFinancialPlansRepository != null
          ? await localFinancialPlansRepository!.getActiveFinancialPlans()
          : _state.financialPlans;
      final recurringTransactions = localRecurringTransactionsRepository != null
          ? await localRecurringTransactionsRepository!
                .getActiveRecurringTransactions()
          : _state.recurringTransactions;
      final pending = localPendingTransactionsRepository != null
          ? await localPendingTransactionsRepository!
                .getActivePendingTransactions()
          : _state.pendingTransactions;
      final merchantRules = localMerchantRulesRepository != null
          ? await localMerchantRulesRepository!.getActiveMerchantRules()
          : _state.merchantRules;
      final merchantConfirmations = localMerchantConfirmationsRepository != null
          ? await localMerchantConfirmationsRepository!
                .getActiveMerchantConfirmations()
          : _state.merchantConfirmations;
      final correctionFeedback = localCorrectionFeedbackRepository != null
          ? await localCorrectionFeedbackRepository!
                .getActiveCorrectionFeedback()
          : _state.correctionFeedback;

      _state = _state.copyWith(
        transactions: transactions.isNotEmpty
            ? transactions
            : _state.transactions,
        savings: savings.isNotEmpty ? savings : _state.savings,
        financialPlans: financialPlans.isNotEmpty
            ? financialPlans
            : _state.financialPlans,
        recurringTransactions: recurringTransactions.isNotEmpty
            ? recurringTransactions
            : _state.recurringTransactions,
        pendingTransactions: pending.isNotEmpty
            ? pending
            : _state.pendingTransactions,
        merchantRules: merchantRules.isNotEmpty
            ? merchantRules
            : _state.merchantRules,
        merchantAliases: merchantRules.isNotEmpty
            ? _merchantAliasesFromRules(merchantRules)
            : _state.merchantAliases,
        merchantConfirmations: merchantConfirmations.isNotEmpty
            ? merchantConfirmations
            : _state.merchantConfirmations,
        correctionFeedback: correctionFeedback.isNotEmpty
            ? correctionFeedback
            : _state.correctionFeedback,
      );
      _state = _state.copyWith(
        syncHealth: _state.syncHealth.copyWith(
          lastSuccessAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      await save();
      notifyListeners();
      if (kDebugMode) {
        print(
          '[SYNC-TRIGGER] State refresh occurred successfully after $reason.',
        );
      }
    }
  }

  Future<void> _finalizeLocalWrite({
    required AppStateModel previousState,
    bool transactionChanged = false,
    bool savingChanged = false,
  }) async {
    if (transactionChanged) _skipNextSqliteTransactionMirror = true;
    if (savingChanged) _skipNextSqliteSavingsMirror = true;
    await _saveStateForCompatibility();
    notifyListeners();
    if (!_isApplyingRemoteSync) {
      _syncSensitiveCollectionsInBackground(previousState, _state);
      unawaited(triggerSyncPipeline(reason: 'local_write'));
    }
  }

  Future<void> syncRestoredStateToFirestore({
    required AppStateModel previousState,
    required AppStateModel nextState,
  }) async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String? uid = nextState.userId;
    if (syncManager == null || uid == null || uid.trim().isEmpty) return;

    await _syncStateToFirestore(
      syncManager: syncManager,
      uid: uid,
      previousState: previousState,
      nextState: nextState,
      includeTransactions: true,
      includeSavings: true,
      requireLiveSyncSession: false,
      awaitWrites: true,
    );
  }

  Future<void> syncSensitiveStateToFirestore() async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String? uid = _state.userId;
    if (syncManager == null || uid == null || uid.trim().isEmpty) return;

    await _syncStateToFirestore(
      syncManager: syncManager,
      uid: uid,
      previousState: AppStateDefaults.create(),
      nextState: _state,
      includeTransactions: false,
      includeSavings: false,
      requireLiveSyncSession: false,
      awaitWrites: true,
    );
  }

  void _syncSensitiveCollectionsInBackground(
    AppStateModel previousState,
    AppStateModel nextState,
  ) {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String? uid = nextState.userId;
    if (syncManager == null || uid == null || uid.trim().isEmpty) return;
    if (_liveSyncUserId != uid) return;

    unawaited(
      _syncStateToFirestore(
        syncManager: syncManager,
        uid: uid,
        previousState: previousState,
        nextState: nextState,
        includeTransactions: false,
        includeSavings: false,
        requireLiveSyncSession: true,
        awaitWrites: false,
      ),
    );
  }

  Future<void> _syncStateToFirestore({
    required FirestoreSyncManager syncManager,
    required String uid,
    required AppStateModel previousState,
    required AppStateModel nextState,
    required bool includeTransactions,
    required bool includeSavings,
    required bool requireLiveSyncSession,
    required bool awaitWrites,
  }) async {
    if (requireLiveSyncSession && _liveSyncUserId != uid) return;
    final bool userSettingsChanged = !_userSettingsEqual(
      previousState,
      nextState,
    );

    if (!userSettingsChanged) {
      return;
    }

    try {
      await syncManager.syncUserSettings(
        uid: uid,
        settings: _buildUserSettingsPayload(nextState),
      );
    } catch (error, stackTrace) {
      debugPrint('Background user settings sync skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> enqueueAllLocalDataForCloudSync() async {
    if (!_useSqliteLocalStore) return;

    if (localTransactionsRepository != null) {
      final List<Transaction> transactions = await localTransactionsRepository!
          .getActiveTransactions();
      if (localTransactionsRepository is LocalTransactionsRepository) {
        await (localTransactionsRepository as LocalTransactionsRepository)
            .importTransactions(transactions);
      }
    }

    if (localSavingsRepository != null) {
      final List<Saving> savings = await localSavingsRepository!
          .getActiveSavings();
      if (localSavingsRepository is LocalSavingsRepository) {
        await (localSavingsRepository as LocalSavingsRepository)
            .enqueueSavingsForResync(savings);
      }
    }

    if (localPendingTransactionsRepository != null) {
      final List<PendingTransaction> pending =
          await localPendingTransactionsRepository!
              .getActivePendingTransactions();
      await localPendingTransactionsRepository!.importPendingTransactions(
        pending,
      );
    }

    if (localFinancialPlansRepository != null) {
      final List<FinancialPlan> plans = await localFinancialPlansRepository!
          .getActiveFinancialPlans();
      await localFinancialPlansRepository!.importFinancialPlans(plans);
    }

    if (localInvestmentsRepository != null) {
      final List<InvestmentAsset> investments =
          await localInvestmentsRepository!.getActiveInvestments();
      await localInvestmentsRepository!.importInvestments(investments);
    }

    if (localMerchantRulesRepository != null) {
      final Map<String, MerchantRule> rules =
          await localMerchantRulesRepository!.getActiveMerchantRules();
      await localMerchantRulesRepository!.importMerchantRules(rules.values);
    }

    if (localMerchantConfirmationsRepository != null) {
      final List<MerchantConfirmation> confirmations =
          await localMerchantConfirmationsRepository!
              .getActiveMerchantConfirmations();
      await localMerchantConfirmationsRepository!.importMerchantConfirmations(
        confirmations,
      );
    }

    if (localCorrectionFeedbackRepository != null) {
      final List<CorrectionFeedback> feedback =
          await localCorrectionFeedbackRepository!
              .getActiveCorrectionFeedback();
      await localCorrectionFeedbackRepository!.importCorrectionFeedback(
        feedback,
      );
    }

    if (localRecurringTransactionsRepository != null) {
      final List<RecurringTransaction> recurring =
          await localRecurringTransactionsRepository!
              .getActiveRecurringTransactions();
      await localRecurringTransactionsRepository!.importRecurringTransactions(
        recurring,
      );
    }
  }

  Future<void> _syncPendingReviewBadge([int? pendingReviewCount]) async {
    final int count =
        pendingReviewCount ??
        _state.pendingTransactions
            .where(
              (PendingTransaction item) =>
                  item.status == CaptureStatus.pendingReview,
            )
            .length;
    await _smartCaptureAlertService.syncPendingReviewBadge(count);
  }

  Future<void> forceUploadAllLocalData() async {
    await enqueueAllLocalDataForCloudSync();
    await triggerSyncPipeline(reason: 'debug_force_upload_all_local_data');
  }

  Future<void> runFullReconciliation() async {
    await collectDebugDiagnostics();
  }

  Future<void> repairSavingsSyncCursors() async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String? uid = _state.userId;
    if (syncManager == null || uid == null || uid.trim().isEmpty) return;

    final DebugDiagnosticsReport diagnostics = await collectDebugDiagnostics();
    if (!diagnostics.localCountGreaterThanFirebaseCount) {
      if (kDebugMode) {
        print(
          '[DIAGNOSTICS] repairSavingsSyncCursors skipped: local savings are not greater than Firebase savings.',
        );
      }
      return;
    }

    final String beforeSavingsCursor = _state.syncHealth.savingsCursor;
    final String beforeDeletedSavingsCursor =
        _state.syncHealth.deletedSavingsCursor;
    final SyncHealth nextSyncHealth = _state.syncHealth.copyWith(
      savingsCursor: '',
      deletedSavingsCursor: '',
    );

    if (kDebugMode) {
      print(
        '[DIAGNOSTICS] Repairing savings cursors: '
        'savingsCursor="$beforeSavingsCursor" -> "", '
        'deletedSavingsCursor="$beforeDeletedSavingsCursor" -> ""',
      );
    }
    await SyncDiagnosticsService.record(
      level: 'warning',
      subsystem: 'diagnostics',
      message: 'Repair savings cursors',
      metadata: <String, dynamic>{
        'beforeSavingsCursor': beforeSavingsCursor,
        'beforeDeletedSavingsCursor': beforeDeletedSavingsCursor,
        'afterSavingsCursor': '',
        'afterDeletedSavingsCursor': '',
      },
    );

    await updateState(
      _state.copyWith(
        syncHealth: nextSyncHealth,
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<int> enqueueMissingFirebaseSavings() async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String uid = (_state.userId ?? '').trim();
    if (syncManager == null || uid.isEmpty || localSavingsRepository == null) {
      return 0;
    }

    final List<Saving> localSavings = await localSavingsRepository!
        .getActiveSavings();
    final List<Saving> firebaseSavings = await syncManager
        .loadCollection<Saving>(
          uid: uid,
          collection: FirestoreSyncManager.savingsCollection,
          decoder: (String id, Map<String, dynamic> json) {
            return Saving.fromJson(<String, dynamic>{'id': id, ...json});
          },
        );
    final Set<String> firebaseIds = firebaseSavings
        .map((Saving saving) => saving.id)
        .toSet();
    final List<Saving> missing = localSavings
        .where((Saving saving) => !firebaseIds.contains(saving.id))
        .toList(growable: false);
    if (missing.isEmpty) {
      return 0;
    }
    if (localSavingsRepository is LocalSavingsRepository) {
      await (localSavingsRepository as LocalSavingsRepository)
          .enqueueSavingsForResync(missing);
    }
    if (kDebugMode) {
      print(
        '[DIAGNOSTICS] Enqueued ${missing.length} missing Firebase savings records.',
      );
    }
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'diagnostics',
      message: 'Enqueued missing Firebase savings',
      metadata: <String, dynamic>{
        'missingIds': missing.map((Saving saving) => saving.id).toList(),
        'count': missing.length,
      },
    );
    return missing.length;
  }

  Future<void> _logSavingsConsistencyWarningIfNeeded({
    required String source,
  }) async {
    final FirestoreSyncManager? syncManager = firestoreSyncManager;
    final String uid = (_state.userId ?? '').trim();
    if (syncManager == null || uid.isEmpty || localSavingsRepository == null) {
      return;
    }

    try {
      final List<Saving> localSavings = await localSavingsRepository!
          .getActiveSavings();
      final int pendingSyncQueueCount = _database == null
          ? 0
          : await (_database!.select(
              _database!.syncQueue,
            )).get().then((rows) => rows.length);
      if (localSavings.isEmpty || pendingSyncQueueCount != 0) {
        return;
      }

      final List<Saving> firebaseSavings = await syncManager
          .loadCollection<Saving>(
            uid: uid,
            collection: FirestoreSyncManager.savingsCollection,
            decoder: (String id, Map<String, dynamic> json) {
              return Saving.fromJson(<String, dynamic>{'id': id, ...json});
            },
          );

      if (localSavings.isNotEmpty && firebaseSavings.isEmpty) {
        final String message =
            'Local savings exist but Firebase savings is empty and no queue writes are pending. '
            'source=$source localCount=${localSavings.length} firebaseCount=0 pendingQueueCount=0';
        debugPrint('[SYNC][HIGH] $message');
        await SyncDiagnosticsService.record(
          level: 'error',
          subsystem: 'sync',
          message: 'Local savings missing from Firebase',
          metadata: <String, dynamic>{
            'source': source,
            'localCount': localSavings.length,
            'firebaseCount': 0,
            'pendingQueueCount': 0,
          },
        );
      }
    } catch (error) {
      debugPrint(
        'AppStateController: savings consistency warning skipped: $error',
      );
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    if (transaction.type == 'expense') {
      final double availableBalance = getAvailableBalance(
        currency: transaction.currency,
      );
      if (availableBalance <= ReconciliationService.minAmount) {
        if (kDebugMode) {
          debugPrint(
            'AppStateController: blocked expense ${transaction.id} '
            'for ${transaction.currency} because available balance is $availableBalance',
          );
        }
        return;
      }
    }
    if (_useSqliteLocalStore && localTransactionsRepository != null) {
      await _saveTransactionViaLocalRepository(
        transaction,
        fallbackState: _state.copyWith(
          transactions: <Transaction>[..._state.transactions, transaction],
        ),
      );
      return;
    }
    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, transaction],
      ),
    );
  }

  Future<void> addTransactions(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;
    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, ...transactions],
      ),
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final List<Transaction> next = _state.transactions
        .map((Transaction tx) => tx.id == transaction.id ? transaction : tx)
        .toList(growable: false);
    if (_useSqliteLocalStore && localTransactionsRepository != null) {
      await _saveTransactionViaLocalRepository(
        transaction,
        fallbackState: _state.copyWith(transactions: next),
      );
      return;
    }
    await updateState(_state.copyWith(transactions: next));
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (kDebugMode) {
      print('[ExchangeDebug][deleteTransaction] id=$transactionId');
    }
    Transaction? target;
    for (final tx in _state.transactions) {
      if (tx.id == transactionId) {
        target = tx;
        break;
      }
    }
    if (target == null) return;
    final Transaction txTarget = target;

    if (_useSqliteLocalStore &&
        localTransactionsRepository != null &&
        _canUseRepositoryDeleteForTransaction(txTarget)) {
      await _deleteTransactionViaLocalRepository(
        txTarget,
        fallbackState: _state.copyWith(
          transactions: _state.transactions
              .where((Transaction tx) => tx.id != transactionId)
              .toList(growable: false),
        ),
      );
      return;
    }

    final String? exchangeActivityId =
        txTarget.exchangePairId != null &&
            txTarget.exchangePairId!.trim().isNotEmpty
        ? txTarget.exchangePairId!.trim()
        : null;
    if (exchangeActivityId != null &&
        txTarget.category != 'Gold Sale' &&
        txTarget.category != 'Silver Sale') {
      if (kDebugMode) {
        print(
          '[ExchangeDebug][deleteTransaction] deleting exchange activityId=$exchangeActivityId',
        );
      }
      await _deleteCurrencyExchangeActivity(exchangeActivityId);
      return;
    }

    List<Saving> nextSavings = List<Saving>.from(_state.savings);

    if (txTarget.category == 'Gold Sale' ||
        txTarget.category == 'Silver Sale') {
      if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
        await _deleteMetalSaleTransaction(txTarget.id);
        return;
      }
      final String? metalSavingId = txTarget.exchangePairId;
      if (metalSavingId != null && metalSavingId.isNotEmpty) {
        double soldWeight = txTarget.metalQuantity ?? 0.0;
        if (soldWeight == 0.0) {
          final RegExp regex = RegExp(r'([0-9.]+)\s*g');
          final Match? match = regex.firstMatch(txTarget.description);
          if (match != null) {
            soldWeight = double.tryParse(match.group(1) ?? '') ?? 0.0;
          }
        }
        if (soldWeight > 0.0) {
          nextSavings = nextSavings.map((Saving s) {
            if (s.id == metalSavingId) {
              return s.copyWith(
                remainingAmount: s.remainingAmount + soldWeight,
              );
            }
            return s;
          }).toList();
        }
      }
      nextSavings.removeWhere(
        (Saving s) =>
            s.transferActivityId == txTarget.id &&
            ZakatEngineService.normaliseAssetType(s.assetType) == 'cash',
      );
    }

    final String? pairId = txTarget.exchangePairId;
    final List<Transaction> nextTransactions = _state.transactions
        .where((Transaction tx) {
          if (txTarget.category == 'Gold Sale' ||
              txTarget.category == 'Silver Sale') {
            return tx.id != transactionId;
          }
          if (pairId != null && pairId.isNotEmpty) {
            return tx.exchangePairId != pairId;
          }
          return tx.id != transactionId;
        })
        .toList(growable: false);

    await updateState(
      _state.copyWith(savings: nextSavings, transactions: nextTransactions),
    );
  }

  Future<void> addSaving(Saving saving) async {
    if (_useSqliteLocalStore && localSavingsRepository != null) {
      await _saveSavingViaLocalRepository(
        saving,
        fallbackState: _state.copyWith(
          savings: <Saving>[..._state.savings, saving],
        ),
      );
      return;
    }
    await updateState(
      _state.copyWith(savings: <Saving>[..._state.savings, saving]),
    );
  }

  Future<void> addSavingWithFundingAllocations(Saving saving) async {
    final String purchaseCurrency = saving.purchaseCurrency.trim().isEmpty
        ? saving.unit.trim().toUpperCase()
        : saving.purchaseCurrency.trim().toUpperCase();
    final double requestedFunding = saving.fundingAllocations.fold<double>(
      0,
      (double sum, Map<String, dynamic> allocation) =>
          sum + _asDouble(allocation['amount']),
    );
    final double availableFunding = reconciliationService
        .getAvailableCashBalance(state: _state, currency: purchaseCurrency);
    if (requestedFunding - availableFunding > ReconciliationService.minAmount) {
      throw StateError('Insufficient available cash to fund this purchase.');
    }

    final List<Transaction> fundingExpenses = saving.fundingAllocations
        .where(
          (Map<String, dynamic> allocation) =>
              (allocation['sourceType'] ?? '').toString() == 'income',
        )
        .map((Map<String, dynamic> allocation) {
          final String sourceId = (allocation['sourceId'] ?? '').toString();
          final String currency = (allocation['currency'] ?? '').toString();
          final double amount = _asDouble(allocation['amount']);
          return Transaction(
            id: 'tx_${DateTime.now().microsecondsSinceEpoch}_${sourceId}_metal',
            type: 'expense',
            date: saving.dateAcquired,
            amount: amount,
            currency: currency,
            category: 'Precious Metals Purchase',
            description:
                '${saving.assetType} purchase funding from income $sourceId',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            rolledOver: false,
            sourceIncomeId: sourceId,
            exchangePairId: saving.id,
            activityType: 'transfer',
          );
        })
        .where((Transaction tx) => tx.amount > 0 && tx.sourceIncomeId != null)
        .toList(growable: false);

    await updateState(
      _state.copyWith(
        transactions: <Transaction>[..._state.transactions, ...fundingExpenses],
        savings: <Saving>[..._state.savings, saving],
      ),
    );
  }

  Future<void> updateSaving(Saving saving) async {
    final List<Saving> next = _state.savings
        .map((Saving entry) => entry.id == saving.id ? saving : entry)
        .toList(growable: false);
    if (_useSqliteLocalStore && localSavingsRepository != null) {
      await _saveSavingViaLocalRepository(
        saving,
        fallbackState: _state.copyWith(savings: next),
      );
      return;
    }
    await updateState(_state.copyWith(savings: next));
  }

  bool _canUseRepositoryDeleteForTransaction(Transaction transaction) {
    final bool hasExchangeActivity =
        transaction.exchangePairId != null &&
        transaction.exchangePairId!.trim().isNotEmpty;
    if (hasExchangeActivity) return false;
    if (transaction.category == 'Gold Sale' ||
        transaction.category == 'Silver Sale') {
      return false;
    }
    return true;
  }

  Future<void> _saveTransactionViaLocalRepository(
    Transaction transaction, {
    required AppStateModel fallbackState,
  }) async {
    final TransactionsLocalStore? localStore = localTransactionsRepository;
    if (localStore == null) {
      await updateState(fallbackState);
      return;
    }
    final AppStateModel previousState = _state;
    try {
      await localStore.saveTransaction(transaction);
      final List<Transaction> sqliteTransactions = await localStore
          .getActiveTransactions();
      await _verifySqliteWrite(
        label: 'Transaction write',
        id: transaction.id,
        existsCheck: () async => sqliteTransactions.any(
          (Transaction item) => item.id == transaction.id,
        ),
      );
      final AppStateModel reconciledInput = _state.copyWith(
        transactions: sqliteTransactions,
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      final ReconciliationResult reconciled = reconciliationService
          .reconcileExpensesWithSavings(reconciledInput);
      _state = reconciled.state.copyWith(
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _finalizeLocalWrite(
        previousState: previousState,
        transactionChanged: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController: SQLite transaction save failed. '
        'Falling back to JSON transaction write. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await updateState(fallbackState);
    }
  }

  Future<void> _deleteMetalSaleTransaction(String transactionId) async {
    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final FinancialOperationResult result =
            await localFinancialOperationsRepository!.deleteMetalSale(
              transactionId,
            );
        _state = _state.copyWith(
          transactions: result.transactions,
          savings: result.savings,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _finalizeLocalWrite(
          previousState: previousState,
          transactionChanged: true,
          savingChanged: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite metal sale delete failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
  }

  Future<void> _deleteTransactionViaLocalRepository(
    Transaction transaction, {
    required AppStateModel fallbackState,
  }) async {
    final TransactionsLocalStore? localStore = localTransactionsRepository;
    if (localStore == null) {
      await updateState(fallbackState);
      return;
    }
    final AppStateModel previousState = _state;
    try {
      await localStore.deleteTransaction(transaction.id);
      final List<Transaction> sqliteTransactions = await localStore
          .getActiveTransactions();
      await _verifySqliteWrite(
        label: 'Transaction delete',
        id: transaction.id,
        existsCheck: () async => sqliteTransactions.any(
          (Transaction item) => item.id == transaction.id,
        ),
      );
      final AppStateModel reconciledInput = _state.copyWith(
        transactions: sqliteTransactions,
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      final ReconciliationResult reconciled = reconciliationService
          .reconcileExpensesWithSavings(reconciledInput);
      _state = reconciled.state.copyWith(
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _finalizeLocalWrite(
        previousState: previousState,
        transactionChanged: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController: SQLite transaction delete failed. '
        'Falling back to JSON transaction delete. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await updateState(fallbackState);
    }
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> deleteSaving(String savingId) async {
    if (kDebugMode) {
      print('[ExchangeDebug][deleteSaving] id=$savingId');
    }
    Saving? target;
    for (final s in _state.savings) {
      if (s.id == savingId) {
        target = s;
        break;
      }
    }
    if (target == null) return;

    if (_useSqliteLocalStore &&
        localSavingsRepository != null &&
        _canUseRepositoryDeleteForSaving(target)) {
      await _deleteSavingViaLocalRepository(
        target,
        fallbackState: _state.copyWith(
          savings: _state.savings
              .where((Saving entry) => entry.id != savingId)
              .toList(growable: false),
        ),
      );
      return;
    }

    final String? exchangeActivityId =
        target.transferActivityId != null &&
            target.transferActivityId!.trim().isNotEmpty
        ? target.transferActivityId!.trim()
        : null;
    if (exchangeActivityId != null) {
      final bool isCurrencyExchangeSaving =
          target.internalTransferType == 'savings_currency_exchange';
      if (!isCurrencyExchangeSaving &&
          _useSqliteLocalStore &&
          localFinancialOperationsRepository != null) {
        await _deleteInternalTransferActivity(exchangeActivityId);
        return;
      }
      if (kDebugMode) {
        print(
          '[ExchangeDebug][deleteSaving] deleting exchange activityId=$exchangeActivityId',
        );
      }
      await _deleteCurrencyExchangeActivity(exchangeActivityId);
      return;
    }

    List<Saving> nextSavings = _state.savings
        .where((Saving entry) => entry.id != savingId)
        .toList(growable: false);

    if (target.exchangeSourceSavingId != null &&
        target.exchangeSourceSavingId!.isNotEmpty) {
      final String srcId = target.exchangeSourceSavingId!;
      final double deducted = _parseSavingsExchangeAmount(target.description);
      if (deducted > 0) {
        nextSavings = nextSavings
            .map((Saving s) {
              if (s.id == srcId) {
                return s.copyWith(
                  amount: s.amount + deducted,
                  remainingAmount: s.remainingAmount + deducted,
                );
              }
              return s;
            })
            .toList(growable: false);
      }
    }

    final List<Transaction> nextTransactions = _state.transactions
        .where(
          (Transaction tx) =>
              tx.exchangePairId != savingId ||
              tx.category != 'Precious Metals Purchase',
        )
        .toList(growable: false);
    await updateState(
      _state.copyWith(savings: nextSavings, transactions: nextTransactions),
    );
  }

  bool _canUseRepositoryDeleteForSaving(Saving saving) {
    if (saving.transferActivityId != null &&
        saving.transferActivityId!.trim().isNotEmpty) {
      return false;
    }
    if (saving.exchangeSourceSavingId != null &&
        saving.exchangeSourceSavingId!.trim().isNotEmpty) {
      return false;
    }
    if (saving.exchangeSourceIncomeId != null &&
        saving.exchangeSourceIncomeId!.trim().isNotEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _saveSavingViaLocalRepository(
    Saving saving, {
    required AppStateModel fallbackState,
  }) async {
    final SavingsLocalStore? localStore = localSavingsRepository;
    if (localStore == null) {
      await updateState(fallbackState);
      return;
    }
    final AppStateModel previousState = _state;
    try {
      await localStore.saveSaving(saving);
      final List<Saving> sqliteSavings = await localStore.getActiveSavings();
      await _verifySqliteWrite(
        label: 'Saving write',
        id: saving.id,
        existsCheck: () async =>
            sqliteSavings.any((Saving item) => item.id == saving.id),
      );
      _state = _state.copyWith(
        savings: sqliteSavings,
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _finalizeLocalWrite(
        previousState: previousState,
        savingChanged: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController: SQLite saving write failed. '
        'Falling back to JSON saving write. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await updateState(fallbackState);
    }
  }

  Future<void> _deleteSavingViaLocalRepository(
    Saving saving, {
    required AppStateModel fallbackState,
  }) async {
    final SavingsLocalStore? localStore = localSavingsRepository;
    if (localStore == null) {
      await updateState(fallbackState);
      return;
    }
    final AppStateModel previousState = _state;
    try {
      await localStore.deleteSaving(saving.id);
      final List<Saving> sqliteSavings = await localStore.getActiveSavings();
      await _verifySqliteWrite(
        label: 'Saving delete',
        id: saving.id,
        existsCheck: () async =>
            sqliteSavings.any((Saving item) => item.id == saving.id),
      );
      _state = _state.copyWith(
        savings: sqliteSavings,
        lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await _finalizeLocalWrite(
        previousState: previousState,
        savingChanged: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController: SQLite saving delete failed. '
        'Falling back to JSON saving delete. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await updateState(fallbackState);
    }
  }

  Future<void> _deleteCurrencyExchangeActivity(String activityId) async {
    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final FinancialOperationResult result =
            await localFinancialOperationsRepository!.deleteCurrencyExchange(
              activityId,
            );
        _state = _state.copyWith(
          transactions: result.transactions,
          savings: result.savings,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _finalizeLocalWrite(
          previousState: previousState,
          transactionChanged: true,
          savingChanged: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite currency exchange delete failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
    await _deleteCurrencyExchangeActivityLegacy(activityId);
  }

  Future<void> _deleteInternalTransferActivity(String activityId) async {
    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final FinancialOperationResult result =
            await localFinancialOperationsRepository!.deleteInternalTransfer(
              activityId,
            );
        _state = _state.copyWith(
          transactions: result.transactions,
          savings: result.savings,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _finalizeLocalWrite(
          previousState: previousState,
          transactionChanged: true,
          savingChanged: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite internal transfer delete failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
  }

  Future<void> _deleteCurrencyExchangeActivityLegacy(String activityId) async {
    final List<Saving> exchangeSavings = _state.savings
        .where((Saving saving) => saving.transferActivityId == activityId)
        .toList(growable: false);

    final Map<String, double> sourceRestorations = <String, double>{};
    for (final Saving saving in exchangeSavings) {
      final String? sourceId = saving.exchangeSourceSavingId;
      if (sourceId == null || sourceId.trim().isEmpty) continue;
      final double restored = _parseSavingsExchangeAmount(saving.description);
      if (restored <= 0) continue;
      sourceRestorations[sourceId] =
          (sourceRestorations[sourceId] ?? 0) + restored;
    }

    final List<Saving> nextSavings = _state.savings
        .where((Saving saving) => saving.transferActivityId != activityId)
        .map((Saving saving) {
          final double restored = sourceRestorations[saving.id] ?? 0;
          if (restored <= 0) return saving;
          return saving.copyWith(
            amount: saving.amount + restored,
            remainingAmount: saving.remainingAmount + restored,
          );
        })
        .toList(growable: false);

    final List<Transaction> nextTransactions = _state.transactions
        .where((Transaction tx) => tx.exchangePairId != activityId)
        .toList(growable: false);

    await updateState(
      _state.copyWith(transactions: nextTransactions, savings: nextSavings),
    );
  }

  Future<void> deleteCurrencyExchangeActivity(String activityId) async {
    if (kDebugMode) {
      print(
        '[ExchangeDebug][deleteCurrencyExchangeActivity] activityId=$activityId',
      );
    }
    await _deleteCurrencyExchangeActivity(activityId);
  }

  static double _parseSavingsExchangeAmount(String description) {
    final Match? match = RegExp(
      r'Savings exchange:\s*([0-9.]+)\s',
    ).firstMatch(description);
    return double.tryParse(match?.group(1) ?? '') ?? 0.0;
  }

  Future<void> updateCurrencyExchange(
    CurrencyExchangeEditRequest request,
  ) async {
    if (kDebugMode) {
      print(
        '[ExchangeDebug][updateCurrencyExchange] activityId=${request.oldActivityId} '
        'date=${request.date} source=${request.sourceCurrency} ${request.sourceAmount} '
        'target=${request.targetCurrency} ${request.targetAmount} '
        'targets=${request.oldTargetSavingIds} '
        'sourceDeductions=${request.oldSourceSavingDeductions}',
      );
    }

    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        List<Transaction> nextTransactions = _state.transactions;
        List<Saving> nextSavings = _state.savings;
        final Set<String> targetSavingIds = request.oldTargetSavingIds.toSet();
        final List<Saving> removedTargetSavings = <Saving>[];

        if (request.oldActivityId.isNotEmpty) {
          nextTransactions = nextTransactions
              .where(
                (Transaction tx) => tx.exchangePairId != request.oldActivityId,
              )
              .toList(growable: false);
          removedTargetSavings.addAll(
            _state.savings.where(
              (Saving saving) =>
                  saving.transferActivityId == request.oldActivityId &&
                  saving.internalTransferType == 'savings_currency_exchange',
            ),
          );
          targetSavingIds.addAll(
            removedTargetSavings.map((Saving saving) => saving.id),
          );
        }

        if (targetSavingIds.isNotEmpty) {
          removedTargetSavings.addAll(
            _state.savings.where(
              (Saving saving) =>
                  targetSavingIds.contains(saving.id) &&
                  !removedTargetSavings.any(
                    (Saving existing) => existing.id == saving.id,
                  ),
            ),
          );
        }

        if (targetSavingIds.isNotEmpty) {
          nextSavings = nextSavings
              .where((Saving saving) => !targetSavingIds.contains(saving.id))
              .toList(growable: false);
        }

        if (request.oldSourceSavingDeductions.isNotEmpty) {
          nextSavings = nextSavings
              .map((Saving saving) {
                final double restoredAmount =
                    request.oldSourceSavingDeductions[saving.id] ?? 0;
                if (restoredAmount <= 0) return saving;
                return saving.copyWith(
                  amount: saving.amount + restoredAmount,
                  remainingAmount: saving.remainingAmount + restoredAmount,
                );
              })
              .toList(growable: false);

          for (final MapEntry<String, double> entry
              in request.oldSourceSavingDeductions.entries) {
            final bool exists = nextSavings.any(
              (Saving saving) => saving.id == entry.key,
            );
            if (exists || entry.value <= 0) continue;

            final Saving? sourceTemplate = removedTargetSavings
                .where(
                  (Saving saving) => saving.exchangeSourceSavingId == entry.key,
                )
                .firstOrNull;
            nextSavings = <Saving>[
              ...nextSavings,
              Saving(
                id: entry.key,
                assetType: 'cash',
                dateAcquired: sourceTemplate?.dateAcquired ?? request.date,
                amount: entry.value,
                remainingAmount: entry.value,
                unit: request.sourceCurrency,
                description: 'Restored exchange source',
                purchaseCurrency: request.sourceCurrency,
                purchaseAmount: entry.value,
                createdAt:
                    sourceTemplate?.createdAt ??
                    DateTime.now().toUtc().toIso8601String(),
                sourceIncomeId: sourceTemplate?.sourceIncomeId,
              ),
            ];
          }
        }

        final AppStateModel revertedState = _state.copyWith(
          transactions: nextTransactions,
          savings: nextSavings,
        );

        final ReconciliationResult out = reconciliationService
            .executeCurrencyExchange(
              input: revertedState,
              date: request.date,
              sourceCurrency: request.sourceCurrency,
              targetCurrency: request.targetCurrency,
              sourceAmount: request.sourceAmount,
              targetAmount: request.targetAmount,
            );

        if (out.modified) {
          final Set<String> oldTxIds = revertedState.transactions
              .map((tx) => tx.id)
              .toSet();
          final Set<String> oldSavingIds = revertedState.savings
              .map((s) => s.id)
              .toSet();

          final List<Transaction> newTxRows = out.state.transactions
              .where((tx) => !oldTxIds.contains(tx.id))
              .toList();
          final List<Saving> newSavingRows = out.state.savings
              .where((s) => !oldSavingIds.contains(s.id))
              .toList();

          final String? sourceSavingId = newSavingRows
              .map((s) => s.exchangeSourceSavingId)
              .firstWhere((id) => id != null, orElse: () => null);

          final String newActivityId = newTxRows.isNotEmpty
              ? (newTxRows.first.exchangePairId ?? '')
              : (newSavingRows.isNotEmpty
                    ? (newSavingRows.first.transferActivityId ?? '')
                    : '');

          final double exchangeRate = request.sourceAmount > 0
              ? request.targetAmount / request.sourceAmount
              : 0.0;
          final String description =
              'Currency exchange: ${request.sourceAmount} ${request.sourceCurrency} → ${request.targetAmount} ${request.targetCurrency}';

          final CurrencyExchangeOperation newOperation =
              CurrencyExchangeOperation(
                activityId: newActivityId,
                sourceSavingId: sourceSavingId,
                sourceCurrency: request.sourceCurrency,
                targetCurrency: request.targetCurrency,
                sourceAmountText: request.sourceAmount.toString(),
                targetAmountText: request.targetAmount.toString(),
                exchangeRateText: exchangeRate.toString(),
                date: request.date,
                description: description,
                generatedTransactionRows: newTxRows,
                generatedTargetSavingRows: newSavingRows,
              );

          final FinancialOperationResult result =
              await localFinancialOperationsRepository!.updateCurrencyExchange(
                request.oldActivityId,
                newOperation,
              );

          _state = _state.copyWith(
            transactions: result.transactions,
            savings: result.savings,
            lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
          );
          await _finalizeLocalWrite(
            previousState: previousState,
            transactionChanged: true,
            savingChanged: true,
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite currency exchange update failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    List<Transaction> nextTransactions = _state.transactions;
    List<Saving> nextSavings = _state.savings;
    final Set<String> targetSavingIds = request.oldTargetSavingIds.toSet();
    final List<Saving> removedTargetSavings = <Saving>[];

    if (request.oldActivityId.isNotEmpty) {
      nextTransactions = nextTransactions
          .where((Transaction tx) => tx.exchangePairId != request.oldActivityId)
          .toList(growable: false);
      removedTargetSavings.addAll(
        _state.savings.where(
          (Saving saving) =>
              saving.transferActivityId == request.oldActivityId &&
              saving.internalTransferType == 'savings_currency_exchange',
        ),
      );
      targetSavingIds.addAll(
        removedTargetSavings.map((Saving saving) => saving.id),
      );
    }

    if (targetSavingIds.isNotEmpty) {
      removedTargetSavings.addAll(
        _state.savings.where(
          (Saving saving) =>
              targetSavingIds.contains(saving.id) &&
              !removedTargetSavings.any(
                (Saving existing) => existing.id == saving.id,
              ),
        ),
      );
    }

    if (targetSavingIds.isNotEmpty) {
      nextSavings = nextSavings
          .where((Saving saving) => !targetSavingIds.contains(saving.id))
          .toList(growable: false);
    }

    if (request.oldSourceSavingDeductions.isNotEmpty) {
      nextSavings = nextSavings
          .map((Saving saving) {
            final double restoredAmount =
                request.oldSourceSavingDeductions[saving.id] ?? 0;
            if (restoredAmount <= 0) return saving;
            return saving.copyWith(
              amount: saving.amount + restoredAmount,
              remainingAmount: saving.remainingAmount + restoredAmount,
            );
          })
          .toList(growable: false);

      for (final MapEntry<String, double> entry
          in request.oldSourceSavingDeductions.entries) {
        final bool exists = nextSavings.any(
          (Saving saving) => saving.id == entry.key,
        );
        if (exists || entry.value <= 0) continue;

        final Saving? sourceTemplate = removedTargetSavings
            .where(
              (Saving saving) => saving.exchangeSourceSavingId == entry.key,
            )
            .firstOrNull;
        nextSavings = <Saving>[
          ...nextSavings,
          Saving(
            id: entry.key,
            assetType: 'cash',
            dateAcquired: sourceTemplate?.dateAcquired ?? request.date,
            amount: entry.value,
            remainingAmount: entry.value,
            unit: request.sourceCurrency,
            description: 'Restored exchange source',
            purchaseCurrency: request.sourceCurrency,
            purchaseAmount: entry.value,
            createdAt:
                sourceTemplate?.createdAt ??
                DateTime.now().toUtc().toIso8601String(),
            sourceIncomeId: sourceTemplate?.sourceIncomeId,
          ),
        ];
      }
    }

    final AppStateModel revertedState = _state.copyWith(
      transactions: nextTransactions,
      savings: nextSavings,
    );

    final ReconciliationResult out = reconciliationService
        .executeCurrencyExchange(
          input: revertedState,
          date: request.date,
          sourceCurrency: request.sourceCurrency,
          targetCurrency: request.targetCurrency,
          sourceAmount: request.sourceAmount,
          targetAmount: request.targetAmount,
        );

    if (out.modified) {
      await updateState(out.state);
    }
  }

  Future<void> executeMetalSale({
    required Transaction transaction,
    Saving? generatedTargetSaving,
  }) async {
    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final MetalSaleOperation operation = MetalSaleOperation(
          transactionRow: transaction,
          generatedTargetSavingRow: generatedTargetSaving,
        );
        final FinancialOperationResult result =
            await localFinancialOperationsRepository!.recordMetalSale(
              operation,
            );

        _state = _state.copyWith(
          transactions: result.transactions,
          savings: result.savings,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _finalizeLocalWrite(
          previousState: previousState,
          transactionChanged: true,
          savingChanged: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite metal sale execute failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    final List<Transaction> nextTransactions = <Transaction>[
      ..._state.transactions,
      transaction,
    ];
    final List<Saving> nextSavings = List<Saving>.from(_state.savings);
    if (generatedTargetSaving != null) {
      nextSavings.add(generatedTargetSaving);
    }
    await updateState(
      _state.copyWith(transactions: nextTransactions, savings: nextSavings),
    );
  }

  Future<void> updateMetalSale({
    required String oldTransactionId,
    required Transaction transaction,
    Saving? generatedTargetSaving,
  }) async {
    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final MetalSaleOperation operation = MetalSaleOperation(
          transactionRow: transaction,
          generatedTargetSavingRow: generatedTargetSaving,
        );
        final FinancialOperationResult result =
            await localFinancialOperationsRepository!.updateMetalSale(
              oldTransactionId,
              operation,
            );

        _state = _state.copyWith(
          transactions: result.transactions,
          savings: result.savings,
          lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _finalizeLocalWrite(
          previousState: previousState,
          transactionChanged: true,
          savingChanged: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite metal sale update failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    final List<Transaction> nextTransactions = _state.transactions
        .map((tx) => tx.id == oldTransactionId ? transaction : tx)
        .toList();
    final List<Saving> nextSavings = _state.savings
        .where(
          (s) =>
              !(s.transferActivityId == oldTransactionId &&
                  s.assetType == 'cash'),
        )
        .toList();
    if (generatedTargetSaving != null) {
      nextSavings.add(generatedTargetSaving);
    }
    await updateState(
      _state.copyWith(transactions: nextTransactions, savings: nextSavings),
    );
  }

  Future<void> addInvestment(InvestmentAsset investment) async {
    if (_useSqliteLocalStore && localInvestmentsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localInvestmentsRepository!.saveInvestment(investment);
        final List<InvestmentAsset> sqliteInvestments =
            await localInvestmentsRepository!.getActiveInvestments();
        if (kDebugMode) {
          final bool exists = sqliteInvestments.any(
            (InvestmentAsset item) => item.id == investment.id,
          );
          if (!exists) {
            _recordDebugWriteFailure(
              'Investment write verification failed for id=${investment.id}',
            );
          }
        }
        _state = _state.copyWith(
          investments: sqliteInvestments.isNotEmpty
              ? sqliteInvestments
              : <InvestmentAsset>[..._state.investments, investment],
        );
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.addInvestment: failed to mirror investment to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    await updateState(
      _state.copyWith(
        investments: <InvestmentAsset>[..._state.investments, investment],
      ),
    );
  }

  Future<void> updateInvestment(InvestmentAsset investment) async {
    if (_useSqliteLocalStore && localInvestmentsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localInvestmentsRepository!.saveInvestment(investment);
        final List<InvestmentAsset> sqliteInvestments =
            await localInvestmentsRepository!.getActiveInvestments();
        if (kDebugMode) {
          final bool exists = sqliteInvestments.any(
            (InvestmentAsset item) => item.id == investment.id,
          );
          if (!exists) {
            _recordDebugWriteFailure(
              'Investment update verification failed for id=${investment.id}',
            );
          }
        }
        _state = _state.copyWith(
          investments: sqliteInvestments.isNotEmpty
              ? sqliteInvestments
              : _state.investments
                    .map(
                      (InvestmentAsset entry) =>
                          entry.id == investment.id ? investment : entry,
                    )
                    .toList(growable: false),
        );
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateInvestment: failed to mirror investment to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final List<InvestmentAsset> next = _state.investments
        .map(
          (InvestmentAsset entry) =>
              entry.id == investment.id ? investment : entry,
        )
        .toList(growable: false);
    await updateState(_state.copyWith(investments: next));
  }

  Future<void> deleteInvestment(String investmentId) async {
    if (_useSqliteLocalStore && localInvestmentsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localInvestmentsRepository!.deleteInvestment(investmentId);
        final List<InvestmentAsset> sqliteInvestments =
            await localInvestmentsRepository!.getActiveInvestments();
        if (kDebugMode &&
            sqliteInvestments.any(
              (InvestmentAsset item) => item.id == investmentId,
            )) {
          _recordDebugWriteFailure(
            'Investment delete verification failed for id=$investmentId',
          );
        }
        _state = _state.copyWith(investments: sqliteInvestments);
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.deleteInvestment: failed to mirror investment delete to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final List<InvestmentAsset> next = _state.investments
        .where((InvestmentAsset entry) => entry.id != investmentId)
        .toList(growable: false);
    await updateState(_state.copyWith(investments: next));
  }

  Future<void> addRecurringTransaction(RecurringTransaction recurring) async {
    if (_useSqliteLocalStore && localRecurringTransactionsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localRecurringTransactionsRepository!.saveRecurringTransaction(
          recurring,
        );
        final List<RecurringTransaction> sqliteRecurring =
            await localRecurringTransactionsRepository!
                .getActiveRecurringTransactions();
        final List<RecurringTransaction> nextRecurring =
            _upsertRecurringTransactionInList(sqliteRecurring, recurring);
        if (kDebugMode) {
          final bool exists = nextRecurring.any(
            (RecurringTransaction item) => item.id == recurring.id,
          );
          if (!exists) {
            _recordDebugWriteFailure(
              'Recurring transaction write verification failed for id=${recurring.id}',
            );
          }
        }
        _state = _state.copyWith(
          recurringTransactions: nextRecurring.isNotEmpty
              ? nextRecurring
              : <RecurringTransaction>[
                  ..._state.recurringTransactions,
                  recurring,
                ],
        );
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.addRecurringTransaction: failed to mirror recurring transaction to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    await updateState(
      _state.copyWith(
        recurringTransactions: <RecurringTransaction>[
          ..._state.recurringTransactions,
          recurring,
        ],
      ),
    );
  }

  Future<void> updateRecurringTransaction(
    RecurringTransaction recurring,
  ) async {
    if (_useSqliteLocalStore && localRecurringTransactionsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localRecurringTransactionsRepository!.saveRecurringTransaction(
          recurring,
        );
        final List<RecurringTransaction> sqliteRecurring =
            await localRecurringTransactionsRepository!
                .getActiveRecurringTransactions();
        final List<RecurringTransaction> nextRecurring =
            _upsertRecurringTransactionInList(sqliteRecurring, recurring);
        if (kDebugMode) {
          final bool exists = nextRecurring.any(
            (RecurringTransaction item) => item.id == recurring.id,
          );
          if (!exists) {
            _recordDebugWriteFailure(
              'Recurring transaction update verification failed for id=${recurring.id}',
            );
          }
        }
        _state = _state.copyWith(
          recurringTransactions: nextRecurring.isNotEmpty
              ? nextRecurring
              : _state.recurringTransactions
                    .map(
                      (RecurringTransaction entry) =>
                          entry.id == recurring.id ? recurring : entry,
                    )
                    .toList(growable: false),
        );
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.updateRecurringTransaction: failed to mirror recurring transaction to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final List<RecurringTransaction> next = _state.recurringTransactions
        .map(
          (RecurringTransaction entry) =>
              entry.id == recurring.id ? recurring : entry,
        )
        .toList(growable: false);
    await updateState(_state.copyWith(recurringTransactions: next));
  }

  List<RecurringTransaction> _upsertRecurringTransactionInList(
    List<RecurringTransaction> items,
    RecurringTransaction recurring,
  ) {
    final List<RecurringTransaction> next = items
        .where((RecurringTransaction item) => item.id != recurring.id)
        .toList(growable: true);
    next.add(recurring);
    return next;
  }

  Future<void> deleteRecurringTransaction(String recurringId) async {
    if (_useSqliteLocalStore && localRecurringTransactionsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        await localRecurringTransactionsRepository!.deleteRecurringTransaction(
          recurringId,
        );
        final List<RecurringTransaction> sqliteRecurring =
            await localRecurringTransactionsRepository!
                .getActiveRecurringTransactions();
        if (kDebugMode &&
            sqliteRecurring.any((item) => item.id == recurringId)) {
          _recordDebugWriteFailure(
            'Recurring transaction delete verification failed for id=$recurringId',
          );
        }
        _state = _state.copyWith(recurringTransactions: sqliteRecurring);
        await _finalizeLocalWrite(previousState: previousState);
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController.deleteRecurringTransaction: failed to mirror recurring transaction delete to SQLite. '
          'Continuing with JSON compatibility save. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final List<RecurringTransaction> next = _state.recurringTransactions
        .where((RecurringTransaction entry) => entry.id != recurringId)
        .toList(growable: false);
    await updateState(_state.copyWith(recurringTransactions: next));
  }

  Future<void> addCategory({required String type, required String name}) async {
    final String clean = name.trim();
    if (clean.isEmpty) return;
    final bool income = type == 'income';
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    if (source.any((String c) => c.toLowerCase() == clean.toLowerCase())) {
      return;
    }
    final AppCategories nextCategories = AppCategories(
      income: income ? <String>[...source, clean] : _state.categories.income,
      expense: income ? _state.categories.expense : <String>[...source, clean],
    );
    await updateState(_state.copyWith(categories: nextCategories));
  }

  Future<void> renameCategory({
    required String type,
    required String from,
    required String to,
  }) async {
    final String cleanFrom = from.trim();
    final String cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty || cleanFrom == cleanTo) return;
    final bool income = type == 'income';
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    if (!source.contains(cleanFrom)) return;
    if (source.any((String c) => c.toLowerCase() == cleanTo.toLowerCase())) {
      return;
    }
    final List<String> updatedCategories = source
        .map((String c) => c == cleanFrom ? cleanTo : c)
        .toList(growable: false);
    final List<Transaction> updatedTransactions = _state.transactions
        .map(
          (Transaction tx) => tx.category == cleanFrom
              ? Transaction(
                  id: tx.id,
                  type: tx.type,
                  date: tx.date,
                  amount: tx.amount,
                  currency: tx.currency,
                  category: cleanTo,
                  description: tx.description,
                  createdAt: tx.createdAt,
                  rolledOver: tx.rolledOver,
                  rolledAmount: tx.rolledAmount,
                  sourceIncomeId: tx.sourceIncomeId,
                  exchangePairId: tx.exchangePairId,
                  exchangeSourceIncomeId: tx.exchangeSourceIncomeId,
                  remainingAmount: tx.remainingAmount,
                )
              : tx,
        )
        .toList(growable: false);
    final AppCategories nextCategories = AppCategories(
      income: income ? updatedCategories : _state.categories.income,
      expense: income ? _state.categories.expense : updatedCategories,
    );
    await updateState(
      _state.copyWith(
        categories: nextCategories,
        transactions: updatedTransactions,
      ),
    );
  }

  Future<bool> deleteCategory({
    required String type,
    required String name,
  }) async {
    final String clean = name.trim();
    final bool income = type == 'income';
    final bool inUse = _state.transactions.any(
      (Transaction tx) =>
          tx.category == clean &&
          (income ? tx.type == 'income' : tx.type == 'expense'),
    );
    if (inUse) return false;
    final List<String> source = income
        ? _state.categories.income
        : _state.categories.expense;
    final List<String> updated = source
        .where((String c) => c != clean)
        .toList(growable: false);
    final AppCategories nextCategories = AppCategories(
      income: income ? updated : _state.categories.income,
      expense: income ? _state.categories.expense : updated,
    );
    await updateState(_state.copyWith(categories: nextCategories));
    return true;
  }

  Future<void> reorderCategories({
    required String type,
    required int oldIndex,
    required int newIndex,
  }) async {
    final bool income = type == 'income';
    final List<String> source = List<String>.from(
      income ? _state.categories.income : _state.categories.expense,
    );
    if (oldIndex < 0 || oldIndex >= source.length) return;
    int targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= source.length) return;
    final String element = source.removeAt(oldIndex);
    source.insert(targetIndex, element);
    final AppCategories nextCategories = AppCategories(
      income: income ? source : _state.categories.income,
      expense: income ? _state.categories.expense : source,
    );
    await updateState(_state.copyWith(categories: nextCategories));
  }

  Future<void> addFinancialPlan(FinancialPlan plan) async {
    await updateState(
      _state.copyWith(
        financialPlans: <FinancialPlan>[..._state.financialPlans, plan],
      ),
    );
  }

  Future<void> updateFinancialPlan(FinancialPlan plan) async {
    final List<FinancialPlan> next = _state.financialPlans
        .map((FinancialPlan entry) => entry.id == plan.id ? plan : entry)
        .toList(growable: false);
    await updateState(_state.copyWith(financialPlans: next));
  }

  Future<void> deleteFinancialPlan(String planId) async {
    final List<FinancialPlan> next = _state.financialPlans
        .where((FinancialPlan entry) => entry.id != planId)
        .toList(growable: false);
    await updateState(_state.copyWith(financialPlans: next));
  }

  Future<void> updateMainCurrency(String currency) async {
    await updateState(_state.copyWith(mainCurrency: currency));
  }

  Future<void> updateDefaultEntryCurrency(String currency) async {
    await updateState(_state.copyWith(defaultEntryCurrency: currency));
  }

  Future<void> updateZakatMethod(String method) async {
    await updateState(_state.copyWith(zakatMethod: method));
  }

  Future<void> updateZakatAnnualDate(String annualDate) async {
    await updateState(_state.copyWith(zakatAnnualDate: annualDate));
  }

  Future<void> updateZakatNisabBasis(String basis) async {
    final String normalized = basis == 'silver595' ? 'silver595' : 'gold85';
    await updateState(_state.copyWith(zakatNisabBasis: normalized));
  }

  Future<void> updateLanguagePreference(String languageCode) async {
    await updateState(_state.copyWith(languagePreference: languageCode));
  }

  Future<void> updateThemeMode(String mode) async {
    final String normalized = switch (mode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    await updateState(_state.copyWith(themeMode: normalized));
  }

  Future<void> togglePrivacyMode() async {
    final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
      _state.aiSettings ?? <String, dynamic>{},
    );
    final bool isCurrentlyHidden =
        aiSettings['privacyMode'] == true ||
        aiSettings['hideBalances'] == true ||
        aiSettings['balancesHidden'] == true;

    if (isCurrentlyHidden && _state.biometricHideWealthEnabled) {
      final authenticated = await BiometricService.authenticate(
        reason: 'Confirm identity to reveal wealth values',
      );
      if (!authenticated) return;
    }

    aiSettings['privacyMode'] = !isCurrentlyHidden;
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  Future<void> updateAiSettings(Map<String, dynamic> aiSettings) async {
    await _saveAiKeysToSecureStorage(aiSettings, userId: _state.userId);
    await updateState(_state.copyWith(aiSettings: aiSettings));
  }

  AppStateModel _stateForPersistence(AppStateModel state) {
    AppStateModel result = state;

    final Map<String, dynamic>? aiSettings = state.aiSettings;
    if (aiSettings != null) {
      final Map<String, dynamic> sanitized = Map<String, dynamic>.from(
        aiSettings,
      );
      sanitized.remove('keys');
      result = result.copyWith(aiSettings: sanitized);
    }

    return result;
  }

  Future<AppStateModel> _hydrateAiSettingsFromSecureStorage(
    AppStateModel state, {
    String? userId,
  }) async {
    final List<String>? secureKeys = await secureStorageService.loadAiKeys(
      userId: userId,
    );
    final Map<String, dynamic> aiSettings = Map<String, dynamic>.from(
      state.aiSettings ?? <String, dynamic>{},
    );
    final bool hasLegacyKeys = aiSettings['keys'] is List;
    final List<String> legacyKeys = _extractAiKeys(aiSettings['keys']);

    if (secureKeys != null) {
      aiSettings['keys'] = secureKeys;
      return state.copyWith(aiSettings: aiSettings);
    }

    if (hasLegacyKeys) {
      aiSettings['keys'] = legacyKeys;
      await secureStorageService.saveAiKeys(legacyKeys, userId: userId);
      await repository.saveAppState(
        state.copyWith(aiSettings: _sanitizeAiSettingsForSync(aiSettings)),
        userId: userId ?? state.userId,
      );
      return state.copyWith(aiSettings: aiSettings);
    }

    aiSettings['keys'] = const <String>['', ''];
    return state.copyWith(aiSettings: aiSettings);
  }

  Future<void> _saveAiKeysToSecureStorage(
    Map<String, dynamic> aiSettings, {
    String? userId,
  }) async {
    await secureStorageService.saveAiKeys(
      _extractAiKeys(aiSettings['keys']),
      userId: userId,
    );
  }

  List<String> _extractAiKeys(dynamic rawKeys) {
    if (rawKeys is! List) return const <String>['', ''];
    final List<String> keys = rawKeys
        .map((dynamic item) => item.toString())
        .toList(growable: false);
    if (keys.length >= 2) {
      return <String>[keys[0], keys[1]];
    }
    if (keys.length == 1) {
      return <String>[keys[0], ''];
    }
    return const <String>['', ''];
  }

  Future<void> updateBiometricLockEnabled(bool value) async {
    await updateState(_state.copyWith(biometricLockEnabled: value));
  }

  Future<void> updateBiometricHideWealthEnabled(bool value) async {
    await updateState(_state.copyWith(biometricHideWealthEnabled: value));
  }

  Future<void> updateBiometricExportEnabled(bool value) async {
    await updateState(_state.copyWith(biometricExportEnabled: value));
  }

  Future<void> updateBiometricRestoreEnabled(bool value) async {
    await updateState(_state.copyWith(biometricRestoreEnabled: value));
  }

  Future<void> updateBiometricAutoLockDelay(String value) async {
    await updateState(_state.copyWith(biometricAutoLockDelay: value));
  }

  Future<void> addPendingTransaction(PendingTransaction transaction) async {
    final List<PendingTransaction> next = List<PendingTransaction>.from(
      _state.pendingTransactions,
    )..add(transaction);

    // Enforce soft limit of 500 items, keeping the newest 500 items by createdAt
    if (next.length > 500) {
      next.sort(
        (PendingTransaction a, PendingTransaction b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      final List<PendingTransaction> trimmed = next.take(500).toList();
      await updateState(_state.copyWith(pendingTransactions: trimmed));
    } else {
      await updateState(_state.copyWith(pendingTransactions: next));
    }
  }

  Future<void> removePendingTransaction(String id) async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((PendingTransaction t) => t.id != id)
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> rejectPendingTransaction(
    String id, {
    String reason = 'Manually Ignored',
  }) async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((
      PendingTransaction t,
    ) {
      if (t.id == id) {
        return t.copyWith(
          status: CaptureStatus.ignored,
          reviewedAt: DateTime.now().toUtc().toIso8601String(),
          ignoreReason: reason,
        );
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> undoPendingTransaction(String pendingId) async {
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    final String? linkedId = pendingTx.linkedTransactionId;
    AppStateModel nextState = _state;

    if (linkedId != null && linkedId.isNotEmpty) {
      final List<Transaction> nextTx = nextState.transactions
          .where((t) => t.id != linkedId)
          .toList();
      final List<Saving> nextSav = nextState.savings
          .where((s) => s.id != linkedId)
          .toList();
      final List<InvestmentAsset> nextInv = nextState.investments
          .where((i) => i.id != linkedId)
          .toList();
      nextState = nextState.copyWith(
        transactions: nextTx,
        savings: nextSav,
        investments: nextInv,
      );
    }

    final List<PendingTransaction> updatedPending = nextState
        .pendingTransactions
        .map((PendingTransaction t) {
          if (t.id == pendingId) {
            return t.copyWith(
              status: CaptureStatus.pendingReview,
              clearReviewedAt: true,
              clearLinkedTransactionId: true,
              clearApprovalSource: true,
            );
          }
          return t;
        })
        .toList();

    CaptureAnalytics analytics = nextState.captureAnalytics;
    if (pendingTx.approvalSource == ApprovalSource.auto &&
        analytics.autoApprovedMessages > 0) {
      analytics = analytics.copyWith(
        autoApprovedMessages: analytics.autoApprovedMessages - 1,
      );
    }
    nextState = nextState.copyWith(
      pendingTransactions: updatedPending,
      captureAnalytics: analytics,
    );
    await updateState(nextState);
  }

  Future<void> editApprovedPendingTransaction(
    String pendingId, {
    required String type,
    required double amount,
    required String currency,
    required String category,
    required String description,
    required String date,
  }) async {
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    final String? linkedId = pendingTx.linkedTransactionId;
    if (linkedId == null || linkedId.isEmpty) {
      throw StateError('This capture is not linked to any ledger record.');
    }

    AppStateModel nextState = _state;
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    if (nextState.transactions.any((t) => t.id == linkedId)) {
      final List<Transaction> nextTx = nextState.transactions.map((t) {
        if (t.id == linkedId) {
          return Transaction(
            id: t.id,
            type: type,
            date: date,
            amount: amount,
            currency: currency.trim().toUpperCase(),
            category: category,
            description: description,
            createdAt: t.createdAt,
            rolledOver: t.rolledOver,
            rolledAmount: t.rolledAmount,
            sourceIncomeId: t.sourceIncomeId,
            exchangePairId: t.exchangePairId,
            exchangeSourceIncomeId: t.exchangeSourceIncomeId,
            remainingAmount: t.remainingAmount,
            activityType: type == 'transfer' ? 'transfer' : t.activityType,
            costBasis: t.costBasis,
            saleValue: t.saleValue,
            realizedGain: t.realizedGain,
            realizedGainLossCurrency: t.realizedGainLossCurrency,
          );
        }
        return t;
      }).toList();
      nextState = nextState.copyWith(transactions: nextTx);
    } else if (nextState.savings.any((s) => s.id == linkedId)) {
      final List<Saving> nextSav = nextState.savings.map((s) {
        if (s.id == linkedId) {
          final String metalType = type == 'gold_purchase' ? 'gold' : 'silver';
          return Saving(
            id: s.id,
            assetType: metalType,
            dateAcquired: date,
            amount: amount,
            remainingAmount: amount,
            unit: s.unit,
            description: description,
            purchaseCurrency: currency.trim().toUpperCase(),
            purchaseAmount: s.purchaseAmount,
            createdAt: s.createdAt,
          );
        }
        return s;
      }).toList();
      nextState = nextState.copyWith(savings: nextSav);
    } else if (nextState.investments.any((i) => i.id == linkedId)) {
      final List<InvestmentAsset> nextInv = nextState.investments.map((i) {
        if (i.id == linkedId) {
          return InvestmentAsset(
            id: i.id,
            investmentType: i.investmentType,
            assetSubtype: i.assetSubtype,
            ownershipType: i.ownershipType,
            valuationMode: i.valuationMode,
            currency: currency.trim().toUpperCase(),
            originalPrice: amount,
            totalInterest: i.totalInterest,
            totalPayable: amount,
            paidAmount: amount,
            remainingAmount: i.remainingAmount,
            installmentPlan: i.installmentPlan,
            valuationDate: date,
            marketValue: amount,
            marketValueDate: date,
            valuationSource: i.valuationSource,
            loanBalance: i.loanBalance,
            loanAsOfDate: i.loanAsOfDate,
            paidAmountToDate: amount,
            ownershipSharePct: i.ownershipSharePct,
            country: i.country,
            location: i.location,
            inflationRateAnnual: i.inflationRateAnnual,
            estimatedCurrentValue: amount,
            description: description,
            noZakat: i.noZakat,
            createdAt: i.createdAt,
            yearlyGrowthRate: i.yearlyGrowthRate,
          );
        }
        return i;
      }).toList();
      nextState = nextState.copyWith(investments: nextInv);
    }

    final String? originalCategory = pendingTx.suggestedCategory;
    if (originalCategory != null && originalCategory != category) {
      final CorrectionFeedback fb = CorrectionFeedback(
        id: const Uuid().v4(),
        fieldName: 'category',
        originalValue: originalCategory,
        correctedValue: category,
        createdAt: timestampStr,
      );
      List<CorrectionFeedback> nextFeedback = <CorrectionFeedback>[
        ...nextState.correctionFeedback,
        fb,
      ];
      if (nextFeedback.length > 500) {
        nextFeedback = nextFeedback.sublist(nextFeedback.length - 500);
      }
      CaptureAnalytics nextAnalytics = nextState.captureAnalytics.copyWith(
        correctedMessages: nextState.captureAnalytics.correctedMessages + 1,
      );
      nextState = nextState.copyWith(
        correctionFeedback: nextFeedback,
        captureAnalytics: nextAnalytics,
      );

      if (pendingTx.merchantName != null &&
          pendingTx.merchantName!.trim().isNotEmpty) {
        final String merchant = SmartCaptureParser.normalizeMerchantName(
          pendingTx.merchantName!,
        );
        final String key = merchant.toLowerCase();
        final List<MerchantConfirmation> confirmations =
            List<MerchantConfirmation>.from(nextState.merchantConfirmations);
        final int oldIndex = confirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == key &&
              c.categoryId == originalCategory,
        );
        if (oldIndex >= 0) {
          confirmations[oldIndex] = confirmations[oldIndex].copyWith(
            corrections: confirmations[oldIndex].corrections + 1,
          );
        }
        final int newIndex = confirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == key && c.categoryId == category,
        );
        if (newIndex >= 0) {
          confirmations[newIndex] = confirmations[newIndex].copyWith(
            confirmations: confirmations[newIndex].confirmations + 1,
          );
        } else {
          confirmations.add(
            MerchantConfirmation(
              merchantName: merchant,
              categoryId: category,
              confirmations: 1,
              corrections: 0,
            ),
          );
        }
        final Map<String, MerchantRule> rules = Map<String, MerchantRule>.from(
          nextState.merchantRules,
        );
        final MerchantRule? existing = rules[key];
        if (existing != null) {
          rules[key] = existing.copyWith(
            categoryId: category,
            defaultType: type,
            usageCount: existing.usageCount + 1,
            lastUsed: timestampStr,
          );
        }
        nextState = nextState.copyWith(
          merchantConfirmations: confirmations,
          merchantRules: rules,
        );
      }
    }

    final List<PendingTransaction> nextPending = nextState.pendingTransactions
        .map((t) {
          if (t.id == pendingId) {
            return t.copyWith(
              suggestedType: type,
              suggestedAmount: amount,
              suggestedCurrency: currency.trim().toUpperCase(),
              suggestedDescription: description,
              suggestedCategory: category,
            );
          }
          return t;
        })
        .toList();

    nextState = nextState.copyWith(pendingTransactions: nextPending);
    await updateState(nextState);
  }

  Future<void> approvePendingTransaction(
    String pendingId, {
    required String type,
    required double amount,
    required String currency,
    required String category,
    required String description,
    required String date,
  }) async {
    // Locate the pending transaction
    final PendingTransaction? pendingTx = _state.pendingTransactions
        .where((t) => t.id == pendingId)
        .firstOrNull;

    if (pendingTx == null) {
      throw ArgumentError('Pending transaction with ID $pendingId not found.');
    }

    // Guard: Assert linkedTransactionId == null and status is pending to prevent duplicate approvals
    if (pendingTx.linkedTransactionId != null ||
        pendingTx.status == CaptureStatus.autoApproved ||
        pendingTx.status == CaptureStatus.manuallyApproved) {
      throw StateError('Pending transaction is already approved.');
    }

    final String generatedRecordId = const Uuid().v4();
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    AppStateModel nextState = _state;

    if (type == 'expense' || type == 'income' || type == 'transfer') {
      final Transaction newTx = Transaction(
        id: generatedRecordId,
        type: type,
        date: date,
        amount: amount,
        currency: currency.trim().toUpperCase(),
        category: category,
        description: description,
        createdAt: timestampStr,
        rolledOver: false,
        activityType: type == 'transfer' ? 'transfer' : null,
      );
      nextState = nextState.copyWith(
        transactions: <Transaction>[...nextState.transactions, newTx],
      );
    } else if (type == 'gold_purchase' || type == 'silver_purchase') {
      final String metalType = type == 'gold_purchase' ? 'gold' : 'silver';
      final Saving newSaving = Saving(
        id: generatedRecordId,
        assetType: metalType,
        dateAcquired: date,
        amount: amount,
        remainingAmount: amount,
        unit: 'grams',
        description: description,
        purchaseCurrency: currency.trim().toUpperCase(),
        purchaseAmount: 0.0,
        createdAt: timestampStr,
      );
      nextState = nextState.copyWith(
        savings: <Saving>[...nextState.savings, newSaving],
      );
    } else if (type == 'investment') {
      final InvestmentAsset newInvestment = InvestmentAsset(
        id: generatedRecordId,
        investmentType: 'Stocks/Funds',
        assetSubtype: 'Equities',
        ownershipType: 'Sole',
        valuationMode: 'Market Value',
        currency: currency.trim().toUpperCase(),
        originalPrice: amount,
        totalInterest: 0.0,
        totalPayable: amount,
        paidAmount: amount,
        remainingAmount: 0.0,
        installmentPlan: const <Map<String, dynamic>>[],
        valuationDate: date,
        marketValue: amount,
        marketValueDate: date,
        valuationSource: 'manual',
        loanBalance: 0.0,
        loanAsOfDate: date,
        paidAmountToDate: amount,
        ownershipSharePct: 100.0,
        country: '',
        location: '',
        inflationRateAnnual: 0.0,
        estimatedCurrentValue: amount,
        description: description,
        noZakat: false,
        createdAt: timestampStr,
      );
      nextState = nextState.copyWith(
        investments: <InvestmentAsset>[...nextState.investments, newInvestment],
      );
    } else {
      throw ArgumentError('Unsupported financial entry type: $type');
    }

    // Category confirmation learning logic
    if (pendingTx.merchantName != null &&
        pendingTx.merchantName!.trim().isNotEmpty) {
      final String normMerchant = SmartCaptureParser.normalizeMerchantName(
        pendingTx.merchantName!,
      ).trim();
      final String merchantKey = normMerchant.toLowerCase();

      List<MerchantConfirmation> nextConfirmations =
          List<MerchantConfirmation>.from(nextState.merchantConfirmations);
      Map<String, MerchantRule> nextRules = Map<String, MerchantRule>.from(
        nextState.merchantRules,
      );
      CaptureAnalytics nextAnalytics = nextState.captureAnalytics;

      final String? sugCat = pendingTx.suggestedCategory;

      int idx = nextConfirmations.indexWhere(
        (c) =>
            c.merchantName.toLowerCase() == merchantKey &&
            c.categoryId == category,
      );
      if (idx != -1) {
        nextConfirmations[idx] = nextConfirmations[idx].copyWith(
          confirmations: nextConfirmations[idx].confirmations + 1,
        );
      } else {
        nextConfirmations.add(
          MerchantConfirmation(
            merchantName: normMerchant,
            categoryId: category,
            confirmations: 1,
            corrections: 0,
          ),
        );
        idx = nextConfirmations.length - 1;
      }

      if (sugCat != null && sugCat != category) {
        int sugIdx = nextConfirmations.indexWhere(
          (c) =>
              c.merchantName.toLowerCase() == merchantKey &&
              c.categoryId == sugCat,
        );
        if (sugIdx != -1) {
          nextConfirmations[sugIdx] = nextConfirmations[sugIdx].copyWith(
            corrections: nextConfirmations[sugIdx].corrections + 1,
          );
        } else {
          nextConfirmations.add(
            MerchantConfirmation(
              merchantName: normMerchant,
              categoryId: sugCat,
              confirmations: 0,
              corrections: 1,
            ),
          );
        }

        final CorrectionFeedback fb = CorrectionFeedback(
          id: const Uuid().v4(),
          fieldName: 'category',
          originalValue: sugCat,
          correctedValue: category,
          createdAt: timestampStr,
        );
        List<CorrectionFeedback> nextFeedback = <CorrectionFeedback>[
          ...nextState.correctionFeedback,
          fb,
        ];
        if (nextFeedback.length > 500) {
          nextFeedback = nextFeedback.sublist(nextFeedback.length - 500);
        }
        nextAnalytics = nextAnalytics.copyWith(
          correctedMessages: nextAnalytics.correctedMessages + 1,
        );
        nextState = nextState.copyWith(correctionFeedback: nextFeedback);
      }

      final MerchantConfirmation conf = nextConfirmations[idx];
      final int total = conf.confirmations + conf.corrections;
      final double ratio = total > 0 ? conf.confirmations / total : 0.0;
      if (conf.confirmations >= 3 && ratio >= 0.80) {
        final bool alreadyExists = nextRules.containsKey(merchantKey);
        final MerchantRule? existingRule = nextRules[merchantKey];
        nextRules[merchantKey] = MerchantRule(
          merchantName: normMerchant,
          categoryId: category,
          defaultType: type,
          autoApprove: existingRule?.autoApprove ?? true,
          usageCount: alreadyExists ? existingRule!.usageCount + 1 : 1,
          confidence: ratio,
          lastUsed: timestampStr,
          source: alreadyExists && existingRule!.source == 'custom'
              ? 'custom'
              : 'learned',
          aliases: existingRule?.aliases ?? const <String>[],
          enabled: existingRule?.enabled ?? true,
          isBuiltinOverride: existingRule?.isBuiltinOverride ?? false,
        );

        if (!alreadyExists) {
          nextAnalytics = nextAnalytics.copyWith(
            learnedRules: nextAnalytics.learnedRules + 1,
          );
        }
      }

      nextState = nextState.copyWith(
        merchantConfirmations: nextConfirmations,
        merchantRules: nextRules,
        captureAnalytics: nextAnalytics,
      );
    }

    // Update the PendingTransaction status to approved, set reviewedAt, and linkedTransactionId
    final List<PendingTransaction> updatedPending = nextState
        .pendingTransactions
        .map((PendingTransaction t) {
          if (t.id == pendingId) {
            return t.copyWith(
              status: CaptureStatus.manuallyApproved,
              approvalSource: ApprovalSource.manual,
              reviewedAt: timestampStr,
              linkedTransactionId: generatedRecordId,
              suggestedType: type,
              suggestedAmount: amount,
              suggestedCurrency: currency.trim().toUpperCase(),
              suggestedDescription: description,
              suggestedCategory: category,
            );
          }
          return t;
        })
        .toList();

    nextState = nextState.copyWith(pendingTransactions: updatedPending);
    await updateState(nextState);
  }

  Future<void> clearPendingTransactions() async {
    await updateState(
      _state.copyWith(pendingTransactions: const <PendingTransaction>[]),
    );
  }

  Future<void> deleteIgnoredPendingTransactions() async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((t) => t.status != CaptureStatus.ignored)
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> deletePendingTransactionsBulk(List<String> ids) async {
    final List<PendingTransaction> next = _state.pendingTransactions
        .where((t) => !ids.contains(t.id))
        .toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> restorePendingTransactionsBulk(List<String> ids) async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((t) {
      if (ids.contains(t.id)) {
        return t.copyWith(
          status: CaptureStatus.pendingReview,
          clearReviewedAt: true,
          clearApprovalSource: true,
        );
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> markPendingTransactionsAsRead() async {
    final List<PendingTransaction> next = _state.pendingTransactions.map((
      PendingTransaction t,
    ) {
      if (!t.isRead) {
        return t.copyWith(isRead: true);
      }
      return t;
    }).toList();
    await updateState(_state.copyWith(pendingTransactions: next));
  }

  Future<void> setSmartCaptureEnabled(bool enabled) async {
    await updateState(_state.copyWith(smartCaptureEnabled: enabled));
  }

  Future<void> setSmartCaptureAutoApproveEnabled(bool enabled) async {
    await updateState(_state.copyWith(smartCaptureAutoApproveEnabled: enabled));
  }

  Future<void> saveCustomMerchantRule(MerchantRule rule) async {
    final String key =
        rule.builtinKey?.toLowerCase().trim() ??
        rule.merchantName.toLowerCase().trim();
    final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
    final nextAliases = Map<String, String>.from(_state.merchantAliases);
    final bool alreadyExists = nextRules.containsKey(key);
    nextRules[key] = rule;
    nextAliases.removeWhere(
      (String alias, String merchant) => merchant.toLowerCase().trim() == key,
    );
    for (final String alias in rule.aliases) {
      final String aliasKey = alias.toLowerCase().trim();
      if (aliasKey.isNotEmpty) nextAliases[aliasKey] = rule.merchantName;
    }

    CaptureAnalytics nextAnalytics = _state.captureAnalytics;
    if (!alreadyExists && rule.source == 'custom') {
      nextAnalytics = nextAnalytics.copyWith(
        learnedRules: nextAnalytics.learnedRules + 1,
      );
    }

    await updateState(
      _state.copyWith(
        merchantRules: nextRules,
        merchantAliases: nextAliases,
        captureAnalytics: nextAnalytics,
      ),
    );
  }

  Future<void> deleteMerchantRule(String merchantName) async {
    String key = merchantName.toLowerCase().trim();
    final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
    final nextAliases = Map<String, String>.from(_state.merchantAliases);
    if (!nextRules.containsKey(key)) {
      for (final MapEntry<String, MerchantRule> entry in nextRules.entries) {
        if (entry.value.merchantName.toLowerCase().trim() == key) {
          key = entry.key;
          break;
        }
      }
    }
    final MerchantRule? removedRule = nextRules.remove(key);
    nextAliases.removeWhere(
      (String alias, String merchant) =>
          merchant.toLowerCase().trim() == key ||
          merchant.toLowerCase().trim() ==
              removedRule?.merchantName.toLowerCase().trim(),
    );
    await updateState(
      _state.copyWith(merchantRules: nextRules, merchantAliases: nextAliases),
    );
  }

  Future<void> resetBuiltinMerchantRule(String merchantName) async {
    MerchantRule? rule;
    for (final MerchantRule candidate in _state.merchantRules.values) {
      if (candidate.merchantName == merchantName) {
        rule = candidate;
        break;
      }
    }
    await deleteMerchantRule(rule?.builtinKey ?? merchantName);
  }

  Future<void> setMerchantRuleEnabled(MerchantRule rule, bool enabled) async {
    final String key = rule.merchantName.toLowerCase().trim();
    final bool isBuiltin =
        rule.isBuiltinOverride ||
        SmartCaptureParser.builtinMerchantCategoryMap.containsKey(key);
    await saveCustomMerchantRule(
      rule.copyWith(
        enabled: enabled,
        source: isBuiltin ? 'custom' : rule.source,
        isBuiltinOverride: isBuiltin,
        builtinKey: isBuiltin ? (rule.builtinKey ?? key) : rule.builtinKey,
      ),
    );
  }

  Future<void> createPendingTransaction({
    required String source,
    String? sourceIdentifier,
    required String rawMessage,
    required String suggestedType,
    required double confidence,
    double? suggestedAmount,
    String? suggestedCurrency,
    String? suggestedDescription,
    String? merchantName,
    String? suggestedCategory,
    String? parserVersion,
    String? detectedBank,
    bool requiresReview = true,
  }) async {
    final PendingTransaction transaction = PendingTransaction(
      id: const Uuid().v4(),
      source: source,
      sourceIdentifier: sourceIdentifier,
      rawMessage: rawMessage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      suggestedType: suggestedType,
      suggestedAmount: suggestedAmount,
      suggestedCurrency: suggestedCurrency,
      suggestedDescription: suggestedDescription,
      merchantName: merchantName,
      suggestedCategory: suggestedCategory,
      confidence: confidence,
      status: CaptureStatus.pendingReview,
      parserVersion: parserVersion,
      detectedBank: detectedBank,
      requiresReview: requiresReview,
      isRead: false,
    );
    await addPendingTransaction(transaction);
  }

  Future<void> createPendingTransactionFromMessage(
    String rawMessage,
    String source,
  ) async {
    await createPendingTransactionFromMessageWithResult(rawMessage, source);
  }

  Future<bool> createPendingTransactionFromMessageWithResult(
    String rawMessage,
    String source, {
    String? sourceIdentifier,
  }) async {
    if (!_state.smartCaptureEnabled) return false;

    final String cleanMessage = rawMessage.trim();
    if (cleanMessage.isEmpty || cleanMessage.length > 10000) {
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: invalid');
      }
      return false;
    }

    if (source == PendingTransactionSource.shortcut) {
      debugPrint('[Shortcut] Parser started');
    }

    final parsed = SmartCaptureParser.parse(
      rawMessage,
      merchantRules: _state.merchantRules,
      merchantAliases: _state.merchantAliases,
    );

    String? detectedBank;
    final String lowerMsg = cleanMessage.toLowerCase();
    if (lowerMsg.contains('hsbc')) {
      detectedBank = 'HSBC';
    } else if (lowerMsg.contains('cib')) {
      detectedBank = 'CIB';
    } else if (lowerMsg.contains('alrajhi') || lowerMsg.contains('الراجحي')) {
      detectedBank = 'Al Rajhi Bank';
    } else if (lowerMsg.contains('ahli') || lowerMsg.contains('الأهلي')) {
      detectedBank = 'Al Ahli Bank';
    }

    if (source == PendingTransactionSource.shortcut) {
      debugPrint(
        '[Shortcut] Parser result: merchant=${parsed.merchantName ?? 'null'}, '
        'amount=${_formatShortcutAmount(parsed.amount)}, '
        'currency=${parsed.currency ?? 'null'}, '
        'confidence=${parsed.confidence.toStringAsFixed(2)}',
      );
    }

    final String normMerchant = parsed.merchantName != null
        ? SmartCaptureParser.normalizeMerchantName(parsed.merchantName!).trim()
        : '';
    final String merchantKey = normMerchant.toLowerCase();

    CaptureAnalytics nextAnalytics = _state.captureAnalytics.copyWith(
      parsedMessages: _state.captureAnalytics.parsedMessages + 1,
      capturedFromAppleShortcuts: source == PendingTransactionSource.shortcut
          ? _state.captureAnalytics.capturedFromAppleShortcuts + 1
          : _state.captureAnalytics.capturedFromAppleShortcuts,
    );

    if (!parsed.isValid) {
      nextAnalytics = nextAnalytics.copyWith(
        ignoredMessages: nextAnalytics.ignoredMessages + 1,
        capturedFromAppleShortcutsIgnored:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsIgnored + 1
            : nextAnalytics.capturedFromAppleShortcutsIgnored,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: invalid');
      }
      await updateState(
        _state.copyWith(
          pendingTransactions: <PendingTransaction>[
            ..._state.pendingTransactions,
            PendingTransaction(
              id: const Uuid().v4(),
              source: source,
              sourceIdentifier:
                  sourceIdentifier ??
                  (source == PendingTransactionSource.shortcut
                      ? 'Apple Automation'
                      : null),
              rawMessage: cleanMessage,
              createdAt: DateTime.now().toUtc().toIso8601String(),
              suggestedType: parsed.type,
              suggestedAmount: parsed.amount,
              suggestedCurrency: parsed.currency,
              suggestedDescription: parsed.description,
              merchantName: parsed.merchantName,
              suggestedCategory: parsed.suggestedCategory,
              confidence: parsed.confidence,
              status: CaptureStatus.ignored,
              ignoreReason: parsed.ignoreReason ?? 'Invalid Transaction',
              requiresReview: false,
              isRead: true,
            ),
          ],
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('invalid');
      }
      return true;
    }

    final now = DateTime.now().toUtc();
    bool isDuplicate = false;

    for (final pt in _state.pendingTransactions) {
      if (pt.status == CaptureStatus.ignored) continue;
      final String ptM = pt.merchantName != null
          ? SmartCaptureParser.normalizeMerchantName(
              pt.merchantName!,
            ).trim().toLowerCase()
          : '';
      if (pt.suggestedType == parsed.type &&
          pt.suggestedCurrency == parsed.currency &&
          pt.suggestedAmount == parsed.amount &&
          ptM == merchantKey) {
        try {
          final ptTime = DateTime.parse(pt.createdAt).toUtc();
          if (now.difference(ptTime).abs().inMinutes <= 5) {
            isDuplicate = true;
            break;
          }
        } catch (_) {}
      }
    }

    if (!isDuplicate) {
      for (final t in _state.transactions) {
        final String tM = _normalizedTransactionMerchantKey(t);
        if (t.type == parsed.type &&
            t.currency == parsed.currency &&
            t.amount == parsed.amount &&
            tM == merchantKey) {
          try {
            final tTime = DateTime.parse(t.createdAt).toUtc();
            if (now.difference(tTime).abs().inMinutes <= 5) {
              isDuplicate = true;
              break;
            }
          } catch (_) {}
        }
      }
    }

    if (isDuplicate) {
      nextAnalytics = nextAnalytics.copyWith(
        duplicateMessages: nextAnalytics.duplicateMessages + 1,
        ignoredMessages: nextAnalytics.ignoredMessages + 1,
        capturedFromAppleShortcutsIgnored:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsIgnored + 1
            : nextAnalytics.capturedFromAppleShortcutsIgnored,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: duplicate');
      }
      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        suggestedType: parsed.type,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: parsed.suggestedCategory,
        confidence: 0.0,
        status: CaptureStatus.ignored,
        ignoreReason: 'Duplicate',
        detectedBank: detectedBank,
        requiresReview: false,
        isRead: true,
      );
      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ..._state.pendingTransactions,
        transaction,
      ];
      await updateState(
        _state.copyWith(
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('duplicate');
      }
      return true;
    }

    final String generatedId = const Uuid().v4();
    final String timestampStr = DateTime.now().toUtc().toIso8601String();

    bool autoApproved = false;
    String finalCategory = parsed.suggestedCategory ?? 'Other';
    String finalType = parsed.type;
    AppStateModel nextState = _state;
    String? ruleName = parsed.merchantRuleUsed;
    String? ruleSource = parsed.merchantRuleSource;

    final bool hasRule = parsed.merchantRuleSource != null;
    final MerchantRule? persistedRule = _state.merchantRules[merchantKey];
    if (persistedRule != null && persistedRule.enabled) {
      finalCategory = persistedRule.categoryId;
      finalType = persistedRule.defaultType;
    }

    if (_state.smartCaptureAutoApproveEnabled &&
        parsed.confidence >= 0.95 &&
        parsed.merchantName != null &&
        parsed.amount != null &&
        parsed.amount! > 0 &&
        finalType != 'transfer' &&
        hasRule &&
        (persistedRule?.enabled ?? true) &&
        (persistedRule?.autoApprove ?? true)) {
      autoApproved = true;
      if (persistedRule != null) {
        final finalRule = persistedRule;
        ruleName = finalRule.merchantName;

        final nextRules = Map<String, MerchantRule>.from(_state.merchantRules);
        nextRules[merchantKey] = finalRule.copyWith(
          usageCount: finalRule.usageCount + 1,
          lastUsed: timestampStr,
        );
        nextState = nextState.copyWith(merchantRules: nextRules);
      }
    }

    if (autoApproved) {
      nextAnalytics = nextAnalytics.copyWith(
        autoApprovedMessages: nextAnalytics.autoApprovedMessages + 1,
        capturedFromAppleShortcutsAutoApproved:
            source == PendingTransactionSource.shortcut
            ? nextAnalytics.capturedFromAppleShortcutsAutoApproved + 1
            : nextAnalytics.capturedFromAppleShortcutsAutoApproved,
      );
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: auto_approved');
      }

      final Transaction newTx = Transaction(
        id: generatedId,
        type: finalType,
        date: timestampStr.substring(0, 10),
        amount: parsed.amount!,
        currency: parsed.currency?.trim().toUpperCase() ?? 'EGP',
        category: finalCategory,
        description: parsed.description,
        createdAt: timestampStr,
        rolledOver: false,
      );

      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: timestampStr,
        reviewedAt: timestampStr,
        suggestedType: finalType,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: finalCategory,
        confidence: parsed.confidence,
        status: CaptureStatus.autoApproved,
        approvalSource: ApprovalSource.auto,
        merchantRuleUsed: ruleName,
        merchantRuleSource: ruleSource,
        detectedBank: detectedBank,
        requiresReview: false,
        isRead: true,
        linkedTransactionId: generatedId,
      );

      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ...nextState.pendingTransactions,
        transaction,
      ];

      await updateState(
        nextState.copyWith(
          transactions: <Transaction>[...nextState.transactions, newTx],
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('auto_approved');
      }
    } else {
      if (source == PendingTransactionSource.shortcut) {
        debugPrint('[Shortcut] Flutter outcome: pending_review');
      }
      final PendingTransaction transaction = PendingTransaction(
        id: const Uuid().v4(),
        source: source,
        sourceIdentifier:
            sourceIdentifier ??
            (source == PendingTransactionSource.shortcut
                ? 'Apple Automation'
                : null),
        rawMessage: cleanMessage,
        createdAt: timestampStr,
        suggestedType: finalType,
        suggestedAmount: parsed.amount,
        suggestedCurrency: parsed.currency,
        suggestedDescription: parsed.description,
        merchantName: parsed.merchantName,
        suggestedCategory: finalCategory,
        confidence: parsed.confidence,
        status: CaptureStatus.pendingReview,
        merchantRuleUsed: ruleName,
        merchantRuleSource: ruleSource,
        detectedBank: detectedBank,
        requiresReview: true,
        isRead: false,
      );
      final List<PendingTransaction> nextPending = <PendingTransaction>[
        ...nextState.pendingTransactions,
        transaction,
      ];
      await updateState(
        nextState.copyWith(
          pendingTransactions: nextPending,
          captureAnalytics: nextAnalytics,
        ),
      );
      await _smartCaptureAlertService.notifyPendingReview(
        pendingTransaction: transaction,
        pendingReviewCount: _state.pendingTransactions
            .where(
              (PendingTransaction item) =>
                  item.status == CaptureStatus.pendingReview,
            )
            .length,
      );
      if (source == PendingTransactionSource.shortcut) {
        _logShortcutStateSnapshot('pending_review');
      }
    }

    return true;
  }

  void _logShortcutStateSnapshot(String outcome) {
    debugPrint('[Shortcut] Flutter outcome: $outcome');
    debugPrint(
      '[Shortcut] AppState pending count after: ${_state.pendingTransactions.length}',
    );
    debugPrint(
      '[Shortcut] AppState transactions count after: ${_state.transactions.length}',
    );
    debugPrint(
      '[Shortcut] AppState captureAnalytics after: ${_state.captureAnalytics.toJson()}',
    );
  }

  double getAvailableBalance({required String currency, String? date}) {
    return reconciliationService.getAvailableCashBalance(
      state: _state,
      currency: currency,
      asOfDate: date,
    );
  }

  List<CashSource> getAvailableCashSources({
    required String currency,
    bool newestFirst = false,
  }) {
    return reconciliationService.getAvailableCashSources(
      state: _state,
      currency: currency,
      newestFirst: newestFirst,
    );
  }

  Map<String, double> get cashByCurrency {
    return reconciliationService.getCashByCurrency(_state);
  }

  static String _formatShortcutAmount(double? amount) {
    if (amount == null) return 'null';
    final double rounded = amount.roundToDouble();
    return amount == rounded
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  static String _normalizedTransactionMerchantKey(Transaction transaction) {
    String merchant = transaction.description.trim().toLowerCase();
    merchant = merchant.replaceAll(
      RegExp(
        r'^(purchase at|income from|internal transfer to)\s+',
        caseSensitive: false,
      ),
      '',
    );
    merchant = merchant.replaceAll(
      RegExp(
        r'\s+(purchase|order|subscription|deposit|transfer|payment)$',
        caseSensitive: false,
      ),
      '',
    );
    merchant = merchant.trim();
    if (merchant.isEmpty ||
        merchant == 'bank transfer' ||
        merchant == 'account deposit' ||
        merchant == 'expense capture' ||
        merchant == 'salary deposit' ||
        merchant == 'captured message') {
      return '';
    }
    return SmartCaptureParser.normalizeMerchantName(
      merchant,
    ).trim().toLowerCase();
  }

  Future<void> updateMarketSnapshot(MarketSnapshot snapshot) async {
    await updateState(_state.copyWith(marketData: snapshot.toAppStateJson()));
  }

  Future<void> toggleInstallmentPaid({
    required String assetId,
    required int installmentIndex,
    required String paymentCategory,
  }) async {
    final MarketData market = MarketData.fromJson(_state.marketData);
    final ReconciliationResult out = reconciliationService
        .toggleInstallmentPaid(
          input: _state,
          assetId: assetId,
          installmentIndex: installmentIndex,
          paymentCategory: paymentCategory,
          marketData: market,
        );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> markInstallmentPaid({
    required String assetId,
    required int installmentIndex,
  }) async {
    final MarketData market = MarketData.fromJson(_state.marketData);
    final ReconciliationResult out = reconciliationService.markInstallmentPaid(
      input: _state,
      assetId: assetId,
      installmentIndex: installmentIndex,
      marketData: market,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> payInstallment({
    required String assetId,
    required int installmentIndex,
    required String paymentCategory,
  }) async {
    final MarketData market = MarketData.fromJson(_state.marketData);
    final ReconciliationResult out = reconciliationService.payInstallment(
      input: _state,
      assetId: assetId,
      installmentIndex: installmentIndex,
      paymentCategory: paymentCategory,
      marketData: market,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> toggleZakatPaid({
    required String monthKey,
    required double zakatAmountMainCurrency,
    required String paymentDate,
  }) async {
    final ReconciliationResult out = reconciliationService.toggleZakatPaid(
      input: _state,
      monthKey: monthKey,
      zakatAmountMainCurrency: zakatAmountMainCurrency,
      mainCurrency: _state.mainCurrency.trim().isEmpty
          ? 'EGP'
          : _state.mainCurrency,
      paymentDate: paymentDate,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> markZakatPaid({required String monthKey}) async {
    final ReconciliationResult out = reconciliationService.markZakatPaid(
      input: _state,
      monthKey: monthKey,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> payZakat({
    required String monthKey,
    required double zakatAmountMainCurrency,
    required String paymentDate,
  }) async {
    final ReconciliationResult out = reconciliationService.payZakat(
      input: _state,
      monthKey: monthKey,
      zakatAmountMainCurrency: zakatAmountMainCurrency,
      mainCurrency: _state.mainCurrency.trim().isEmpty
          ? 'EGP'
          : _state.mainCurrency,
      paymentDate: paymentDate,
    );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<void> executeCurrencyExchange({
    required String date,
    required String sourceCurrency,
    required String targetCurrency,
    required double sourceAmount,
    required double targetAmount,
  }) async {
    final String normalizedDate = date.trim().isEmpty
        ? DateTime.now().toUtc().toIso8601String().split('T').first
        : date.trim();
    if (kDebugMode) {
      print(
        '[ExchangeDebug][executeCurrencyExchange] date=$normalizedDate source=$sourceCurrency $sourceAmount target=$targetCurrency $targetAmount',
      );
    }

    if (_useSqliteLocalStore && localFinancialOperationsRepository != null) {
      final AppStateModel previousState = _state;
      try {
        final ReconciliationResult out = reconciliationService
            .executeCurrencyExchange(
              input: _state,
              date: normalizedDate,
              sourceCurrency: sourceCurrency,
              targetCurrency: targetCurrency,
              sourceAmount: sourceAmount,
              targetAmount: targetAmount,
            );

        if (out.modified) {
          final Set<String> oldTxIds = _state.transactions
              .map((tx) => tx.id)
              .toSet();
          final Set<String> oldSavingIds = _state.savings
              .map((s) => s.id)
              .toSet();

          final List<Transaction> newTxRows = out.state.transactions
              .where((tx) => !oldTxIds.contains(tx.id))
              .toList();
          final List<Saving> newSavingRows = out.state.savings
              .where((s) => !oldSavingIds.contains(s.id))
              .toList();

          final String? sourceSavingId = newSavingRows
              .map((s) => s.exchangeSourceSavingId)
              .firstWhere((id) => id != null, orElse: () => null);

          final String newActivityId = newTxRows.isNotEmpty
              ? (newTxRows.first.exchangePairId ?? '')
              : (newSavingRows.isNotEmpty
                    ? (newSavingRows.first.transferActivityId ?? '')
                    : '');

          final double exchangeRate = sourceAmount > 0
              ? targetAmount / sourceAmount
              : 0.0;
          final String description =
              'Currency exchange: $sourceAmount $sourceCurrency → $targetAmount $targetCurrency';

          final CurrencyExchangeOperation newOperation =
              CurrencyExchangeOperation(
                activityId: newActivityId,
                sourceSavingId: sourceSavingId,
                sourceCurrency: sourceCurrency,
                targetCurrency: targetCurrency,
                sourceAmountText: sourceAmount.toString(),
                targetAmountText: targetAmount.toString(),
                exchangeRateText: exchangeRate.toString(),
                date: normalizedDate,
                description: description,
                generatedTransactionRows: newTxRows,
                generatedTargetSavingRows: newSavingRows,
              );

          final FinancialOperationResult result =
              await localFinancialOperationsRepository!.recordCurrencyExchange(
                newOperation,
              );

          _state = _state.copyWith(
            transactions: result.transactions,
            savings: result.savings,
            lastModifiedAt: DateTime.now().toUtc().toIso8601String(),
          );
          await _finalizeLocalWrite(
            previousState: previousState,
            transactionChanged: true,
            savingChanged: true,
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'AppStateController: SQLite currency exchange execute failed. '
          'State left unchanged. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    final ReconciliationResult out = reconciliationService
        .executeCurrencyExchange(
          input: _state,
          date: normalizedDate,
          sourceCurrency: sourceCurrency,
          targetCurrency: targetCurrency,
          sourceAmount: sourceAmount,
          targetAmount: targetAmount,
        );
    if (!out.modified) return;
    await updateState(out.state);
  }

  Future<MarketRefreshResult> refreshMarketData({
    bool force = false,
    bool respectCooldown = false,
  }) {
    if (_marketRefreshInFlight != null) {
      return _marketRefreshInFlight!;
    }
    final Future<MarketRefreshResult> run = _refreshMarketDataInternal(
      force: force,
      respectCooldown: respectCooldown,
    );
    _marketRefreshInFlight = run;
    run.whenComplete(() => _marketRefreshInFlight = null);
    return run;
  }

  Future<MarketRefreshResult> _refreshMarketDataInternal({
    required bool force,
    required bool respectCooldown,
  }) async {
    final MarketSnapshot before = currentMarketSnapshot;
    if (!force &&
        respectCooldown &&
        _isWithinMarketCooldown(before.lastUpdated)) {
      return const MarketRefreshResult(
        success: true,
        updatedFields: 0,
        message: 'Using last saved market data',
      );
    }
    Map<String, double>? fxRates;

    try {
      fxRates = await marketDataApiService.fetchFxRatesToEgp();
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.refreshMarketData: FX refresh failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      fxRates = null;
    }

    int updated = 0;
    MarketSnapshot after = before;

    if (fxRates != null && fxRates.isNotEmpty) {
      after = after.copyWith(
        usdToEgp: fxRates['USD'] ?? after.usdToEgp,
        sarToEgp: fxRates['SAR'] ?? after.sarToEgp,
        aedToEgp: fxRates['AED'] ?? after.aedToEgp,
        kwdToEgp: fxRates['KWD'] ?? after.kwdToEgp,
        qarToEgp: fxRates['QAR'] ?? after.qarToEgp,
        eurToEgp: fxRates['EUR'] ?? after.eurToEgp,
        gbpToEgp: fxRates['GBP'] ?? after.gbpToEgp,
        bhdToEgp: fxRates['BHD'] ?? after.bhdToEgp,
        omrToEgp: fxRates['OMR'] ?? after.omrToEgp,
        jodToEgp: fxRates['JOD'] ?? after.jodToEgp,
        tryToEgp: fxRates['TRY'] ?? after.tryToEgp,
        myrToEgp: fxRates['MYR'] ?? after.myrToEgp,
        pkrToEgp: fxRates['PKR'] ?? after.pkrToEgp,
        idrToEgp: fxRates['IDR'] ?? after.idrToEgp,
      );
      updated += fxRates.length;
    }

    final double usdToEgpForMetals = after.usdToEgp > 0
        ? after.usdToEgp
        : before.usdToEgp;
    double? goldPrice;
    double? silverPrice;
    try {
      goldPrice = await marketDataApiService.fetchGold24kPerGramEgp(
        usdToEgp: usdToEgpForMetals,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.refreshMarketData: gold refresh failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      goldPrice = null;
    }
    try {
      silverPrice = await marketDataApiService.fetchSilverPerGramEgp(
        usdToEgp: usdToEgpForMetals,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateController.refreshMarketData: silver refresh failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      silverPrice = null;
    }

    if (goldPrice != null && goldPrice > 0) {
      after = after.copyWith(gold24kPricePerGramEgp: goldPrice);
      updated += 1;
    }
    if (silverPrice != null && silverPrice > 0) {
      after = after.copyWith(silverPricePerGramEgp: silverPrice);
      updated += 1;
    }

    if (updated > 0) {
      after = after.copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
      await updateMarketSnapshot(after);
      return MarketRefreshResult(
        success: true,
        updatedFields: updated,
        message: 'Market data refreshed.',
      );
    }

    if (before.lastUpdated.trim().isNotEmpty) {
      return const MarketRefreshResult(
        success: true,
        updatedFields: 0,
        message: 'Using last saved market data',
      );
    }
    return const MarketRefreshResult(
      success: false,
      updatedFields: 0,
      message: 'No market data refreshed. Manual prices required.',
    );
  }

  static bool _isWithinMarketCooldown(String lastUpdatedRaw) {
    final String value = lastUpdatedRaw.trim();
    if (value.isEmpty) return false;
    try {
      final DateTime last = DateTime.parse(value).toUtc();
      final Duration diff = DateTime.now().toUtc().difference(last);
      return diff.inSeconds >= 0 && diff < marketRefreshInterval;
    } catch (_) {
      return false;
    }
  }

  Future<void> printLocalFirstDebugStatus() async {
    final AppDiagnosticsSnapshot diagnostics = await collectDiagnostics();
    print('=== LOCAL-FIRST DEBUG STATUS ===');
    print('Firebase UID: ${diagnostics.firebaseUid}');
    print(
      'SQLite Database File: ${diagnostics.databaseFileName} (${diagnostics.databasePath ?? 'unavailable'})',
    );
    print('SQLite gate active: ${diagnostics.sqliteGateActive}');
    print(
      'Runtime JSON collections stripped: ${diagnostics.runtimeJsonCollectionsStripped}',
    );
    print(
      'Runtime JSON fallback size: ${diagnostics.runtimeJsonFallbackSizeBytes} bytes',
    );
    print('Migration completed_at: ${diagnostics.migrationCompletedAt}');
    print('sync_queue ready count: ${diagnostics.syncQueueReadyCount}');
    print('sync_queue retry count: ${diagnostics.syncQueueRetryCount}');
    print('last_sync_success_at: ${diagnostics.lastSyncSuccessAt}');
    print('Collection sources: ${diagnostics.collectionSources}');
    print('All Sync Cursors: ${diagnostics.syncCursors}');
    print('Row counts: ${diagnostics.tableRowCounts}');
    print('Write failures: ${diagnostics.writeFailures}');
    print('================================');
  }

  Future<AppDiagnosticsSnapshot> collectDiagnostics() async {
    final AppDatabase? db = _database;
    final String jsonKey =
        StorageKeys.appStateKeyForUser(_state.userId) ??
        StorageKeys.appStateAnonymousKey;
    String? raw;
    try {
      raw = await repository.localStorage.loadString(jsonKey);
    } catch (_) {
      raw = null;
    }

    final Map<String, int> tableCounts = <String, int>{
      'transactions': 0,
      'savings': 0,
      'investments': 0,
      'pending_transactions': 0,
      'financial_plans': 0,
      'recurring_transactions': 0,
      'merchant_rules': 0,
      'merchant_confirmations': 0,
      'correction_feedback': 0,
      'app_settings': 0,
      'sync_queue': 0,
    };
    String migrationCompletedAt = '';
    int syncQueueReady = 0;
    int syncQueueRetry = 0;
    String lastSyncSuccessAt = _state.syncHealth.lastSuccessAt;
    Map<String, String> syncCursors = _fallbackSyncCursorSnapshot();

    if (db != null) {
      final SyncMetadataDao syncMetadataDao = SyncMetadataDao(db);
      tableCounts['transactions'] = await db
          .select(db.transactions)
          .get()
          .then((r) => r.length);
      tableCounts['savings'] = await db
          .select(db.savings)
          .get()
          .then((r) => r.length);
      tableCounts['investments'] = await db
          .select(db.investments)
          .get()
          .then((r) => r.length);
      tableCounts['pending_transactions'] = await db
          .select(db.pendingTransactions)
          .get()
          .then((r) => r.length);
      tableCounts['financial_plans'] = await db
          .select(db.financialPlans)
          .get()
          .then((r) => r.length);
      tableCounts['recurring_transactions'] = await db
          .select(db.recurringTransactions)
          .get()
          .then((r) => r.length);
      tableCounts['merchant_rules'] = await db
          .select(db.merchantRules)
          .get()
          .then((r) => r.length);
      tableCounts['merchant_confirmations'] = await db
          .select(db.merchantConfirmations)
          .get()
          .then((r) => r.length);
      tableCounts['correction_feedback'] = await db
          .select(db.correctionFeedbacks)
          .get()
          .then((r) => r.length);
      tableCounts['app_settings'] = await db
          .select(db.appSettings)
          .get()
          .then((r) => r.length);
      tableCounts['sync_queue'] = await db
          .select(db.syncQueue)
          .get()
          .then((r) => r.length);

      final String nowStr = DateTime.now().toUtc().toIso8601String();
      syncQueueReady =
          await (db.select(db.syncQueue)
                ..where((tbl) => tbl.availableAt.isSmallerOrEqualValue(nowStr)))
              .get()
              .then((r) => r.length);
      syncQueueRetry =
          await (db.select(db.syncQueue)
                ..where((tbl) => tbl.attemptCount.isBiggerThanValue(0)))
              .get()
              .then((r) => r.length);
      migrationCompletedAt =
          await (db.select(db.migrationState)..where(
                (tbl) => tbl.key.equals('json_to_sqlite_v1_completed_at'),
              ))
              .getSingleOrNull()
              .then((row) => row?.value ?? '');
      lastSyncSuccessAt =
          await (db.select(db.syncMetadata)
                ..where((tbl) => tbl.key.equals(lastSyncSuccessAtKey)))
              .getSingleOrNull()
              .then((row) => row?.value ?? lastSyncSuccessAt);
      syncCursors = await _readPersistedSyncCursors(syncMetadataDao);
    }
    final String lastPushSuccessAt = await _lastPushSuccessAt();
    final String lastPullSuccessAt = await _lastPullSuccessAt();
    final bool nextAutoPullAllowed = await _nextAutoPullAllowed();

    final String? databasePath = db == null
        ? null
        : await db.resolveDatabasePath();
    return AppDiagnosticsSnapshot(
      firebaseUid: _state.userId ?? '',
      databaseFileName: db?.fileName ?? 'unavailable',
      databasePath: databasePath,
      sqliteGateActive: _useSqliteLocalStore,
      migrationCompletedAt: migrationCompletedAt,
      runtimeJsonFallbackSizeBytes: raw?.length ?? 0,
      runtimeJsonCollectionsStripped: false,
      tableRowCounts: tableCounts,
      syncQueueReadyCount: syncQueueReady,
      syncQueueRetryCount: syncQueueRetry,
      lastSyncSuccessAt: lastSyncSuccessAt,
      lastPushSuccessAt: lastPushSuccessAt,
      lastPullSuccessAt: lastPullSuccessAt,
      nextAutoPullAllowed: nextAutoPullAllowed,
      lastTriggerReason: _lastSyncTriggerReason,
      pullSkippedDueToThrottle: _lastSyncPullSkippedDueToThrottle,
      queueCountBeforeTrigger: _lastSyncQueueCountBeforeTrigger,
      lastSyncError: _state.syncHealth.lastError,
      syncCursors: syncCursors,
      collectionSources: Map<String, String>.from(_collectionSources),
      writeFailures: List<String>.unmodifiable(_debugWriteFailures),
    );
  }

  Future<DebugDiagnosticsReport> collectDebugDiagnostics({
    bool includeFirebaseSavingsComparison = false,
  }) async {
    final AppDatabase? db = _database;
    final List<String> errors = <String>[];
    final Map<String, dynamic> syncState =
        await SyncDiagnosticsService.readState();

    final String currentUserId = _state.userId ?? '';
    final bool sqliteActive = _sqliteEnabled && db != null;
    final bool syncEnabled =
        firestoreSyncManager != null && currentUserId.trim().isNotEmpty;
    final Map<String, String> syncCursors = db == null
        ? _fallbackSyncCursorSnapshot()
        : await _readPersistedSyncCursors(SyncMetadataDao(db));

    final String databasePath = db == null
        ? ''
        : (await db.resolveDatabasePath() ?? '');

    final List<Saving> localSavings = _localSavingsRepository != null
        ? await _localSavingsRepository!.getActiveSavings()
        : List<Saving>.from(_state.savings);

    List<Saving> firebaseSavings = <Saving>[];
    if (includeFirebaseSavingsComparison &&
        syncEnabled &&
        firestoreSyncManager != null) {
      try {
        firebaseSavings = await firestoreSyncManager!.loadCollection<Saving>(
          uid: currentUserId,
          collection: FirestoreSyncManager.savingsCollection,
          decoder: (String id, Map<String, dynamic> json) {
            return Saving.fromJson(<String, dynamic>{'id': id, ...json});
          },
        );
      } catch (error) {
        errors.add('Firebase savings load failed: $error');
      }
    }

    final DebugDiagnosticsSavingsSummary savingsSummary =
        includeFirebaseSavingsComparison
        ? _buildSavingsSummary(localSavings, firebaseSavings)
        : _buildSavingsSummary(localSavings, <Saving>[]);
    final DebugDiagnosticsSavingsSummary preciousMetalsSummary =
        includeFirebaseSavingsComparison
        ? _buildPreciousMetalsSummary(localSavings, firebaseSavings)
        : _buildPreciousMetalsSummary(localSavings, <Saving>[]);
    final DebugDiagnosticsSavingsComparison comparison =
        includeFirebaseSavingsComparison
        ? DebugDiagnosticsSavingsComparison.compare(
            localSavings: localSavings,
            firebaseSavings: firebaseSavings,
          )
        : const DebugDiagnosticsSavingsComparison(
            missingFromFirebaseIds: <String>[],
            missingLocallyIds: <String>[],
            mismatches: <DebugDiagnosticsSavingsMismatch>[],
          );

    final String lastPushSuccessAt = await _lastPushSuccessAt();
    final String lastPullSuccessAt = await _lastPullSuccessAt();
    final bool nextAutoPullAllowed = await _nextAutoPullAllowed();

    final int pendingSyncQueueCount = db == null
        ? 0
        : await (db.select(db.syncQueue)).get().then((rows) => rows.length);
    final int syncQueueRetryCount = db == null
        ? 0
        : await (db.select(db.syncQueue)
                ..where((tbl) => tbl.attemptCount.isBiggerThanValue(0)))
              .get()
              .then((rows) => rows.length);

    final String lastSavingsPayload = (syncState['lastSavingsPayload'] ?? '')
        .toString();
    final String lastSavingsResponse = (syncState['lastSavingsResponse'] ?? '')
        .toString();
    final String lastSavingsError = (syncState['lastSavingsError'] ?? '')
        .toString();
    final String lastSavingsWritePath =
        (syncState['lastSavingsWritePath'] ?? '').toString();
    final String lastSavingsWriteDocumentId =
        (syncState['lastSavingsWriteDocumentId'] ?? '').toString();
    final String firebaseSavingsPath =
        syncEnabled && firestoreSyncManager != null
        ? firestoreSyncManager!.savingsCollectionPath(currentUserId)
        : '';
    final bool localCountGreaterThanFirebaseCount =
        includeFirebaseSavingsComparison
        ? localSavings.length > firebaseSavings.length
        : false;
    final bool autoRepairRecommended =
        includeFirebaseSavingsComparison &&
        localCountGreaterThanFirebaseCount &&
        pendingSyncQueueCount == 0;

    final MarketSnapshot marketSnapshot = currentMarketSnapshot;
    final double latestGoldPrice = marketSnapshot.gold24kPricePerGramEgp;
    final double latestSilverPrice = marketSnapshot.silverPricePerGramEgp;
    final bool goldApiKeyConfigured = const String.fromEnvironment(
      'GOLD_API_KEY',
    ).trim().isNotEmpty;
    final String marketStatus = marketSnapshot.hasRequiredData
        ? 'cached'
        : (latestGoldPrice > 0 || latestSilverPrice > 0)
        ? 'partial'
        : 'unavailable';

    final List<SyncDiagnosticsLogEntry> recentLogs =
        await SyncDiagnosticsService.readLogs(limit: 100);

    final DebugDiagnosticsReport report = DebugDiagnosticsReport(
      generatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      app: DebugDiagnosticsAppInfo(
        version: const String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        ),
        buildNumber: const String.fromEnvironment(
          'APP_BUILD_NUMBER',
          defaultValue: '1',
        ),
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
        device: kIsWeb ? 'web' : defaultTargetPlatform.name,
        operatingSystemVersion: kIsWeb
            ? 'web'
            : Platform.operatingSystemVersion,
        dartVersion: const String.fromEnvironment(
          'DART_VERSION',
          defaultValue: 'unknown',
        ),
      ),
      auth: DebugDiagnosticsAuthInfo(
        state: _buildAuthState(),
        userId: currentUserId,
        providerIds: _currentProviderIds(),
        isSignedIn: currentUserId.isNotEmpty,
      ),
      firebase: _buildFirebaseInfo(),
      storage: DebugDiagnosticsStorageInfo(
        sqliteActive: sqliteActive,
        databaseFileName: db?.fileName ?? 'unavailable',
        databasePath: databasePath.isEmpty ? null : databasePath,
        syncEnabled: syncEnabled,
        pendingSyncQueueCount: pendingSyncQueueCount,
        syncQueueRetryCount: syncQueueRetryCount,
        lastSuccessfulSyncAt: _state.syncHealth.lastSuccessAt,
        lastFailedSyncAt: _state.syncHealth.lastFailureAt,
        lastSyncError: _state.syncHealth.lastError,
      ),
      syncPolicy: DebugDiagnosticsSyncPolicy(
        lastPushSuccessAt: lastPushSuccessAt,
        lastPullSuccessAt: lastPullSuccessAt,
        nextAutoPullAllowed: nextAutoPullAllowed,
        lastTriggerReason: _lastSyncTriggerReason,
        pullSkippedDueToThrottle: _lastSyncPullSkippedDueToThrottle,
        queueCountBeforeTrigger: _lastSyncQueueCountBeforeTrigger,
      ),
      syncHealth: DebugDiagnosticsSyncHealth(
        pendingWrites: _state.syncHealth.pendingWrites,
        cursors: syncCursors,
      ),
      savingsSummary: savingsSummary,
      preciousMetalsSummary: preciousMetalsSummary,
      comparison: comparison,
      marketData: DebugDiagnosticsMarketData(
        status: marketStatus,
        goldApiKeyConfigured: goldApiKeyConfigured,
        latestCachedGoldPrice: latestGoldPrice > 0 ? latestGoldPrice : null,
        latestCachedSilverPrice: latestSilverPrice > 0
            ? latestSilverPrice
            : null,
        rawSnapshot: Map<String, dynamic>.from(_state.marketData),
      ),
      firebaseSavingsReadPath: firebaseSavingsPath,
      firebaseSavingsWritePath: firebaseSavingsPath,
      pullSyncSavingsPath: firebaseSavingsPath,
      lastSavingsWritePath: lastSavingsWritePath.isEmpty
          ? firebaseSavingsPath
          : lastSavingsWritePath,
      lastSavingsWritePayload: lastSavingsPayload,
      lastSavingsWriteSuccessDocumentId: lastSavingsWriteDocumentId,
      lastSavingsWriteError: lastSavingsError,
      recentSavingsPayloadJson: lastSavingsPayload,
      recentSavingsResponse: lastSavingsResponse,
      recentSavingsError: lastSavingsError,
      recentSyncLogs: recentLogs,
      collectionSources: Map<String, String>.from(_collectionSources),
      writeFailures: List<String>.unmodifiable(_debugWriteFailures),
      savingsCursorValue: _state.syncHealth.savingsCursor,
      deletedSavingsCursorValue: _state.syncHealth.deletedSavingsCursor,
      localCountGreaterThanFirebaseCount: localCountGreaterThanFirebaseCount,
      autoRepairRecommended: autoRepairRecommended,
      firebaseSavingsComparisonLoaded: includeFirebaseSavingsComparison,
    );

    if (errors.isNotEmpty) {
      return DebugDiagnosticsReport(
        generatedAtUtc: report.generatedAtUtc,
        app: report.app,
        auth: report.auth,
        firebase: report.firebase,
        storage: report.storage,
        syncPolicy: report.syncPolicy,
        syncHealth: report.syncHealth,
        savingsSummary: report.savingsSummary,
        preciousMetalsSummary: report.preciousMetalsSummary,
        comparison: report.comparison,
        marketData: report.marketData,
        firebaseSavingsReadPath: report.firebaseSavingsReadPath,
        firebaseSavingsWritePath: report.firebaseSavingsWritePath,
        pullSyncSavingsPath: report.pullSyncSavingsPath,
        lastSavingsWritePath: report.lastSavingsWritePath,
        lastSavingsWritePayload: report.lastSavingsWritePayload,
        lastSavingsWriteSuccessDocumentId:
            report.lastSavingsWriteSuccessDocumentId,
        lastSavingsWriteError: report.lastSavingsWriteError,
        recentSavingsPayloadJson: report.recentSavingsPayloadJson,
        recentSavingsResponse: report.recentSavingsResponse,
        recentSavingsError: report.recentSavingsError.isEmpty
            ? errors.join(' | ')
            : report.recentSavingsError,
        recentSyncLogs: report.recentSyncLogs,
        collectionSources: report.collectionSources,
        writeFailures: <String>[...report.writeFailures, ...errors],
        savingsCursorValue: report.savingsCursorValue,
        deletedSavingsCursorValue: report.deletedSavingsCursorValue,
        localCountGreaterThanFirebaseCount:
            report.localCountGreaterThanFirebaseCount,
        autoRepairRecommended: report.autoRepairRecommended,
        firebaseSavingsComparisonLoaded: report.firebaseSavingsComparisonLoaded,
      );
    }

    return report;
  }

  Future<String> _lastPushSuccessAt() async {
    final LocalSyncPipeline? pipeline = localSyncPipeline;
    if (pipeline == null) return '';
    final String? value = await pipeline.lastPushSuccessAt();
    return value ?? '';
  }

  Future<String> _lastPullSuccessAt() async {
    final LocalSyncPipeline? pipeline = localSyncPipeline;
    if (pipeline == null) return '';
    final String? value = await pipeline.lastPullSuccessAt();
    return value ?? '';
  }

  Future<bool> _nextAutoPullAllowed() async {
    final LocalSyncPipeline? pipeline = localSyncPipeline;
    if (pipeline == null) return false;
    return pipeline.shouldPullNow();
  }

  Map<String, String> _fallbackSyncCursorSnapshot() {
    return <String, String>{
      'transactions_cursor': _state.syncHealth.transactionsCursor,
      'transactions_deleted_cursor':
          _state.syncHealth.deletedTransactionsCursor,
      'savings_cursor': _state.syncHealth.savingsCursor,
      'savings_deleted_cursor': _state.syncHealth.deletedSavingsCursor,
      'investments_cursor': _state.syncHealth.investmentsCursor,
      'investments_deleted_cursor': _state.syncHealth.deletedInvestmentsCursor,
      'pending_transactions_cursor': _state.syncHealth.captureInboxCursor,
      'pending_transactions_deleted_cursor':
          _state.syncHealth.deletedCaptureInboxCursor,
      'recurring_transactions_cursor':
          _state.syncHealth.recurringTransactionsCursor,
      'recurring_transactions_deleted_cursor':
          _state.syncHealth.deletedRecurringTransactionsCursor,
      'financial_plans_cursor': _state.syncHealth.financialPlansCursor,
      'financial_plans_deleted_cursor':
          _state.syncHealth.deletedFinancialPlansCursor,
      'correction_feedback_cursor': _state.syncHealth.correctionFeedbackCursor,
      'correction_feedback_deleted_cursor':
          _state.syncHealth.deletedCorrectionFeedbackCursor,
      'merchant_confirmations_cursor':
          _state.syncHealth.merchantConfirmationsCursor,
      'merchant_confirmations_deleted_cursor':
          _state.syncHealth.deletedMerchantConfirmationsCursor,
      'merchant_rules_cursor': _state.syncHealth.merchantRulesCursor,
      'merchant_rules_deleted_cursor':
          _state.syncHealth.deletedMerchantRulesCursor,
    };
  }

  Future<Map<String, String>> _readPersistedSyncCursors(
    SyncMetadataDao syncMetadataDao,
  ) async {
    final Map<String, String> cursors = <String, String>{};
    final List<String> collections = <String>[
      'transactions',
      'savings',
      'investments',
      'pending_transactions',
      'recurring_transactions',
      'financial_plans',
      'merchant_rules',
      'merchant_confirmations',
      'correction_feedback',
    ];
    for (final String collection in collections) {
      cursors[syncCursorKeyFor(collection)] =
          await syncMetadataDao.getCursor(collection) ?? '';
      cursors[syncDeletedCursorKeyFor(collection)] =
          await syncMetadataDao.getDeletedCursor(collection) ?? '';
    }
    return cursors;
  }

  DebugDiagnosticsSavingsSummary _buildSavingsSummary(
    List<Saving> localSavings,
    List<Saving> firebaseSavings,
  ) {
    return DebugDiagnosticsSavingsSummary(
      localCount: localSavings.length,
      firebaseCount: firebaseSavings.length,
      localIds: localSavings
          .map((Saving saving) => saving.id)
          .toList(growable: false),
      firebaseIds: firebaseSavings
          .map((Saving saving) => saving.id)
          .toList(growable: false),
      localGoldCount: _countByAssetType(localSavings, 'gold'),
      firebaseGoldCount: _countByAssetType(firebaseSavings, 'gold'),
      localSilverCount: _countByAssetType(localSavings, 'silver'),
      firebaseSilverCount: _countByAssetType(firebaseSavings, 'silver'),
    );
  }

  DebugDiagnosticsSavingsSummary _buildPreciousMetalsSummary(
    List<Saving> localSavings,
    List<Saving> firebaseSavings,
  ) {
    final List<Saving> localMetals = localSavings
        .where((Saving saving) => _isPreciousMetal(saving.assetType))
        .toList(growable: false);
    final List<Saving> firebaseMetals = firebaseSavings
        .where((Saving saving) => _isPreciousMetal(saving.assetType))
        .toList(growable: false);
    return DebugDiagnosticsSavingsSummary(
      localCount: localMetals.length,
      firebaseCount: firebaseMetals.length,
      localIds: localMetals
          .map((Saving saving) => saving.id)
          .toList(growable: false),
      firebaseIds: firebaseMetals
          .map((Saving saving) => saving.id)
          .toList(growable: false),
      localGoldCount: _countByAssetType(localMetals, 'gold'),
      firebaseGoldCount: _countByAssetType(firebaseMetals, 'gold'),
      localSilverCount: _countByAssetType(localMetals, 'silver'),
      firebaseSilverCount: _countByAssetType(firebaseMetals, 'silver'),
    );
  }

  int _countByAssetType(List<Saving> savings, String assetType) {
    return savings
        .where(
          (Saving saving) =>
              saving.assetType.trim().toLowerCase() == assetType.toLowerCase(),
        )
        .length;
  }

  bool _isPreciousMetal(String assetType) {
    final String normalized = assetType.trim().toLowerCase();
    return normalized == 'gold' || normalized == 'silver';
  }

  String _buildAuthState() {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'signed-out';
      return 'signed-in';
    } catch (_) {
      return 'unavailable';
    }
  }

  List<String> _currentProviderIds() {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return <String>[];
      return user.providerData
          .map((UserInfo info) => info.providerId)
          .where((String providerId) => providerId.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return <String>[];
    }
  }

  DebugDiagnosticsFirebaseInfo _buildFirebaseInfo() {
    try {
      final FirebaseApp app = Firebase.app();
      return DebugDiagnosticsFirebaseInfo(
        projectId: app.options.projectId,
        appId: app.options.appId,
        messagingSenderId: app.options.messagingSenderId,
      );
    } catch (_) {
      return const DebugDiagnosticsFirebaseInfo(
        projectId: '',
        appId: '',
        messagingSenderId: '',
      );
    }
  }
}

extension AppStateModelCopyWith on AppStateModel {
  AppStateModel copyWith({
    List<Transaction>? transactions,
    List<Saving>? savings,
    List<RecurringTransaction>? recurringTransactions,
    List<InvestmentAsset>? investments,
    List<FinancialPlan>? financialPlans,
    List<PendingTransaction>? pendingTransactions,
    String? lastRollover,
    AppCategories? categories,
    List<String>? zakatPaidMonths,
    List<String>? processedExpenseIds,
    String? mainCurrency,
    String? defaultEntryCurrency,
    Map<String, dynamic>? zakatExpenseIds,
    String? zakatMethod,
    String? zakatAnnualDate,
    String? zakatNisabBasis,
    String? languagePreference,
    String? themeMode,
    String? zakatScheduleFilter,
    Map<String, dynamic>? marketData,
    List<Map<String, dynamic>>? marketHistory,
    SyncHealth? syncHealth,
    String? lastModifiedAt,
    String? userId,
    String? userEmail,
    String? userDisplayName,
    String? userPhotoUrl,
    String? userProvider,
    Map<String, dynamic>? aiSettings,
    bool? cloudHydrated,
    bool? hasUnsyncedAuthChanges,
    String? loadedUserId,
    bool? biometricLockEnabled,
    bool? biometricHideWealthEnabled,
    bool? biometricExportEnabled,
    bool? biometricRestoreEnabled,
    String? biometricAutoLockDelay,
    String? restorePromptDismissedUserId,
    Map<String, MerchantRule>? merchantRules,
    Map<String, String>? merchantAliases,
    CaptureAnalytics? captureAnalytics,
    List<CorrectionFeedback>? correctionFeedback,
    List<MerchantConfirmation>? merchantConfirmations,
    bool? smartCaptureEnabled,
    bool? smartCaptureAutoApproveEnabled,
  }) {
    return AppStateModel(
      transactions: transactions ?? this.transactions,
      savings: savings ?? this.savings,
      recurringTransactions:
          recurringTransactions ?? this.recurringTransactions,
      investments: investments ?? this.investments,
      financialPlans: financialPlans ?? this.financialPlans,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      lastRollover: lastRollover ?? this.lastRollover,
      categories: categories ?? this.categories,
      zakatPaidMonths: zakatPaidMonths ?? this.zakatPaidMonths,
      processedExpenseIds: processedExpenseIds ?? this.processedExpenseIds,
      mainCurrency: mainCurrency ?? this.mainCurrency,
      defaultEntryCurrency: defaultEntryCurrency ?? this.defaultEntryCurrency,
      zakatExpenseIds: zakatExpenseIds ?? this.zakatExpenseIds,
      zakatMethod: zakatMethod ?? this.zakatMethod,
      zakatAnnualDate: zakatAnnualDate ?? this.zakatAnnualDate,
      zakatNisabBasis: zakatNisabBasis ?? this.zakatNisabBasis,
      languagePreference: languagePreference ?? this.languagePreference,
      themeMode: themeMode ?? this.themeMode,
      zakatScheduleFilter: zakatScheduleFilter ?? this.zakatScheduleFilter,
      marketData: marketData ?? this.marketData,
      marketHistory: marketHistory ?? this.marketHistory,
      syncHealth: syncHealth ?? this.syncHealth,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userProvider: userProvider ?? this.userProvider,
      aiSettings: aiSettings ?? this.aiSettings,
      cloudHydrated: cloudHydrated ?? this.cloudHydrated,
      hasUnsyncedAuthChanges:
          hasUnsyncedAuthChanges ?? this.hasUnsyncedAuthChanges,
      loadedUserId: loadedUserId ?? this.loadedUserId,
      restorePromptDismissedUserId:
          restorePromptDismissedUserId ?? this.restorePromptDismissedUserId,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      biometricHideWealthEnabled:
          biometricHideWealthEnabled ?? this.biometricHideWealthEnabled,
      biometricExportEnabled:
          biometricExportEnabled ?? this.biometricExportEnabled,
      biometricRestoreEnabled:
          biometricRestoreEnabled ?? this.biometricRestoreEnabled,
      biometricAutoLockDelay:
          biometricAutoLockDelay ?? this.biometricAutoLockDelay,
      merchantRules: merchantRules ?? this.merchantRules,
      merchantAliases: merchantAliases ?? this.merchantAliases,
      captureAnalytics: captureAnalytics ?? this.captureAnalytics,
      correctionFeedback: correctionFeedback ?? this.correctionFeedback,
      merchantConfirmations:
          merchantConfirmations ?? this.merchantConfirmations,
      smartCaptureEnabled: smartCaptureEnabled ?? this.smartCaptureEnabled,
      smartCaptureAutoApproveEnabled:
          smartCaptureAutoApproveEnabled ?? this.smartCaptureAutoApproveEnabled,
    );
  }
}
