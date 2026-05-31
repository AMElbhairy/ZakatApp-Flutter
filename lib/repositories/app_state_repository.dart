import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../models/app_state.dart';
import '../services/local_storage_service.dart';

class AppStateRepository {
  const AppStateRepository({
    required this.localStorage,
  });

  final LocalStorageService localStorage;

  Future<AppStateModel> loadAppState() async {
    final String? raw =
        await localStorage.loadString(StorageKeys.appStateAnonymousKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppStateDefaults.create();
    }

    try {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return AppStateModel.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'AppStateRepository.loadAppState: failed to parse persisted app state. '
        'Falling back to default state. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return AppStateDefaults.create();
    }
  }

  Future<void> saveAppState(AppStateModel state) async {
    final String raw = jsonEncode(state.toJson());
    await localStorage.saveString(StorageKeys.appStateAnonymousKey, raw);
  }

  Future<void> clearLocalData() async {
    await localStorage.remove(StorageKeys.appStateAnonymousKey);
  }
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
          'Other Income'
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
          'Other'
        ],
      ),
      zakatPaidMonths: <String>[],
      processedExpenseIds: <String>[],
      mainCurrency: 'EGP',
      defaultEntryCurrency: 'EGP',
      zakatExpenseIds: <String, dynamic>{},
      zakatMethod: 'hawl',
      zakatAnnualDate: '',
      zakatScheduleFilter: 'unpaid',
      marketData: <String, dynamic>{},
      marketHistory: <Map<String, dynamic>>[],
      syncHealth: SyncHealth(
        lastSuccessAt: '',
        lastFailureAt: '',
        lastError: '',
        pendingWrites: 0,
      ),
      languagePreference: 'en',
      aiSettings: <String, dynamic>{
        'keys': <String>['', ''],
        'defaultKeyIndex': 0,
      },
      cloudHydrated: false,
      hasUnsyncedAuthChanges: false,
      loadedUserId: null,
    );
  }
}
