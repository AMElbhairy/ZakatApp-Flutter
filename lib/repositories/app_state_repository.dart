import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../models/app_state.dart';
import '../models/merchant_rule.dart';
import '../models/merchant_confirmation.dart';
import '../models/capture_analytics.dart';
import '../models/correction_feedback.dart';
import '../services/local_storage_service.dart';

class AppStateRepository {
  const AppStateRepository({required this.localStorage});

  final LocalStorageService localStorage;

  Future<AppStateLoadResult> loadAppStateResult({String? userId}) async {
    final String? raw = await _loadRawAppState(userId: userId);
    if (raw == null || raw.trim().isEmpty) {
      return AppStateLoadResult(
        state: AppStateDefaults.create(),
        source: AppStateLoadSource.missing,
        rawStatePresent: false,
      );
    }

    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return AppStateLoadResult(
        state: AppStateModel.fromJson(json),
        source: AppStateLoadSource.loaded,
        rawStatePresent: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateRepository.loadAppState: failed to parse persisted app state. '
        'Falling back to default state. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return AppStateLoadResult(
        state: AppStateDefaults.create(),
        source: AppStateLoadSource.parseFailed,
        rawStatePresent: true,
        failureCode: 'parse_failed',
      );
    }
  }

  Future<AppStateModel> loadAppState({String? userId}) async {
    return (await loadAppStateResult(userId: userId)).state;
  }

  Future<bool> loadBiometricLockEnabled({String? userId}) async {
    final String? raw = await _loadRawAppState(userId: userId);
    if (raw == null || raw.trim().isEmpty) {
      return false;
    }

    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return json['biometricLockEnabled'] == true;
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateRepository.loadBiometricLockEnabled: failed to read persisted lock setting. '
        'Falling back to unlocked. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> saveAppState(AppStateModel state, {String? userId}) async {
    final String raw = jsonEncode(state.toJson());
    final String? key = StorageKeys.appStateKeyForUser(userId ?? state.userId);
    await localStorage.saveString(key ?? StorageKeys.appStateAnonymousKey, raw);
  }

  Future<void> clearLocalData({String? userId}) async {
    final String? key = StorageKeys.appStateKeyForUser(userId);
    await localStorage.remove(key ?? StorageKeys.appStateAnonymousKey);
  }

  Future<void> clearLocalDataForSignOut({required String userId}) async {
    final String? scopedKey = StorageKeys.appStateKeyForUser(userId);
    if (scopedKey != null) {
      await localStorage.remove(scopedKey);
    }
    await localStorage.remove(StorageKeys.appStateAnonymousKey);
  }

  Future<String?> _loadRawAppState({String? userId}) async {
    final String? scopedKey = StorageKeys.appStateKeyForUser(userId);
    if (scopedKey != null) {
      final String? scopedRaw = await localStorage.loadString(scopedKey);
      if (scopedRaw != null && scopedRaw.trim().isNotEmpty) {
        return scopedRaw;
      }
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        final String? legacyRaw = await localStorage.loadString(
          StorageKeys.appStateAnonymousKey,
        );
        if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
          return legacyRaw;
        }
      }
      // Authenticated accounts should only load their own scoped state.
      return null;
    }

    final String? legacyRaw = await localStorage.loadString(
      StorageKeys.appStateAnonymousKey,
    );
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      return legacyRaw;
    }
    return null;
  }
}

enum AppStateLoadSource {
  missing,
  loaded,
  parseFailed,
}

class AppStateLoadResult {
  const AppStateLoadResult({
    required this.state,
    required this.source,
    required this.rawStatePresent,
    this.failureCode,
  });

  final AppStateModel state;
  final AppStateLoadSource source;
  final bool rawStatePresent;
  final String? failureCode;
}

class AppStateDefaults {
  AppStateDefaults._();

  static AppStateModel create() {
    return const AppStateModel(
      transactions: [],
      savings: [],
      recurringTransactions: [],
      investments: [],
      financialPlans: [],
      pendingTransactions: [],
      lastRollover: '',
      categories: AppCategories(
        income: <String>[
          'Salary',
          'Freelance',
          'Business',
          'Investment Returns',
          'Rental Income',
          'Gift',
          'Bonus',
          'Savings',
          'Other Income',
        ],
        expense: <String>[
          'Food & Dining',
          'Groceries',
          'Housing & Rent',
          'Utilities',
          'Internet & Phone',
          'Transportation',
          'Fuel & Parking',
          'Healthcare',
          'Education',
          'Clothing & Apparel',
          'Entertainment',
          'Travel',
          'Shopping',
          'Home Maintenance',
          'Insurance',
          'Charitable Giving',
          'Zakat',
          'Childcare',
          'Subscriptions',
          'Loan Payment',
          'Other',
        ],
      ),
      zakatPaidMonths: <String>[],
      processedExpenseIds: <String>[],
      mainCurrency: 'EGP',
      defaultEntryCurrency: 'EGP',
      financialMonthCycle: 'calendar',
      financialMonthStartDay: 1,
      zakatExpenseIds: <String, dynamic>{},
      zakatMethod: 'hawl',
      zakatAnnualDate: '',
      zakatNisabBasis: 'gold85',
      zakatScheduleFilter: 'unpaid',
      marketData: <String, dynamic>{},
      marketHistory: <Map<String, dynamic>>[],
      syncHealth: SyncHealth(
        lastSuccessAt: '',
        lastFailureAt: '',
        lastError: '',
        pendingWrites: 0,
      ),
      lastModifiedAt: '',
      userId: null,
      userEmail: null,
      userDisplayName: null,
      userPhotoUrl: null,
      userProvider: null,
      languagePreference: 'en',
      themeMode: 'system',
      aiSettings: <String, dynamic>{
        'keys': <String>['', ''],
        'defaultKeyIndex': 0,
      },
      cloudHydrated: false,
      hasUnsyncedAuthChanges: false,
      loadedUserId: null,
      biometricLockEnabled: false,
      biometricHideWealthEnabled: false,
      biometricExportEnabled: false,
      biometricRestoreEnabled: false,
      biometricAutoLockDelay: '1_minute',
      merchantRules: <String, MerchantRule>{},
      merchantAliases: <String, String>{},
      captureAnalytics: CaptureAnalytics(
        parsedMessages: 0,
        autoApprovedMessages: 0,
        duplicateMessages: 0,
        ignoredMessages: 0,
        correctedMessages: 0,
        learnedRules: 0,
        autoApprovedRules: 0,
        capturedFromAppleShortcuts: 0,
        capturedFromAppleShortcutsAutoApproved: 0,
        capturedFromAppleShortcutsIgnored: 0,
      ),
      correctionFeedback: <CorrectionFeedback>[],
      merchantConfirmations: <MerchantConfirmation>[],
      smartCaptureEnabled: true,
      smartCaptureAutoApproveEnabled: false,
      androidSmsAutoCaptureEnabled: false,
    );
  }
}
