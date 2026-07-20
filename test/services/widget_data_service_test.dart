import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/widget_data_service.dart';

const MethodChannel _homeWidgetChannel = MethodChannel('home_widget');
const MethodChannel _homeWidgetUpdatesChannel = MethodChannel(
  'home_widget/updates',
);
const MethodChannel _widgetRefreshChannel = MethodChannel(
  'com.zakahwealth.widgets',
);

Map<String, dynamic> _buildStateJson({
  required String mainCurrency,
  required double amountEgp,
}) {
  final DateTime now = DateTime.now();
  final DateTime today = now.subtract(const Duration(hours: 1));
  final Map<String, dynamic> json = AppStateDefaults.create().toJson();
  json['mainCurrency'] = mainCurrency;
  json['defaultEntryCurrency'] = mainCurrency;
  json['transactions'] = <Map<String, dynamic>>[
    Transaction(
      id: 'income-1',
      type: 'income',
      date: _dayKey(today),
      amount: amountEgp,
      currency: 'EGP',
      category: 'Salary',
      description: '',
      createdAt: today.toUtc().toIso8601String(),
      rolledOver: false,
    ).toJson(),
  ];
  json['marketData'] = MarketSnapshot(
    gold24kPricePerGramEgp: 5000,
    silverPricePerGramEgp: 60,
    usdToEgp: 5,
    sarToEgp: 1.33,
    aedToEgp: 1.36,
    kwdToEgp: 16.2,
    qarToEgp: 1.37,
    eurToEgp: 5.4,
    gbpToEgp: 6.3,
    bhdToEgp: 13.2,
    omrToEgp: 13.0,
    jodToEgp: 7.0,
    tryToEgp: 0.155,
    myrToEgp: 1.06,
    pkrToEgp: 0.018,
    idrToEgp: 0.00031,
    lastUpdated: now.toUtc().toIso8601String(),
  ).toAppStateJson();
  return json;
}

Map<String, dynamic> _buildHistoryEntry({
  required double amountEgp,
  required Map<String, double> amountsByCurrency,
}) {
  return <String, dynamic>{
    'amountEgp': amountEgp,
    'currencyCode': 'EGP',
    'rateToEgp': 1,
    'amountsByCurrency': amountsByCurrency,
  };
}

Map<String, dynamic> _decodeJson(String raw) {
  return Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

String _dayKey(DateTime date) {
  final DateTime local = date.toLocal();
  final String year = local.year.toString().padLeft(4, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Future<void> _prepareChannels({
  required Map<String, dynamic> savedWidgetData,
  List<Map<String, dynamic>>? updateWidgetCalls,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_homeWidgetChannel, (MethodCall call) async {
        switch (call.method) {
          case 'setAppGroupId':
          case 'updateWidget':
            if (call.method == 'updateWidget' && updateWidgetCalls != null) {
              updateWidgetCalls.add(
                Map<String, dynamic>.from(call.arguments as Map),
              );
            }
            return true;
          case 'saveWidgetData':
            final Map<String, dynamic> arguments = Map<String, dynamic>.from(
              call.arguments as Map,
            );
            savedWidgetData[arguments['id'].toString()] = arguments['data'];
            return true;
          case 'getWidgetData':
            final Map<String, dynamic> arguments = Map<String, dynamic>.from(
              call.arguments as Map,
            );
            return savedWidgetData[arguments['id'].toString()];
        }
        return null;
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_homeWidgetUpdatesChannel, (
        MethodCall call,
      ) async {
        if (call.method == 'reloadAllTimelines') {
          return null;
        }
        return null;
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _widgetRefreshChannel,
        (MethodCall call) async => null,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetUpdatesChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_widgetRefreshChannel, null);
  });

  Future<void> runScenario({
    required String mainCurrency,
    required double expectedPercent,
    required String expectedSymbol,
    required double expectedRateToEgp,
  }) async {
    final Map<String, dynamic> savedWidgetData = <String, dynamic>{};
    await _prepareChannels(savedWidgetData: savedWidgetData);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime today = DateTime.now();
    final String yesterdayKey = _dayKey(
      today.subtract(const Duration(days: 1)),
    );
    final String todayKey = _dayKey(today);

    await prefs.setString(
      WidgetDataService.wealthHistoryKey,
      jsonEncode(<String, dynamic>{
        yesterdayKey: _buildHistoryEntry(
          amountEgp: 900,
          amountsByCurrency: <String, double>{'EGP': 900, 'USD': 200},
        ),
      }),
    );

    final AppStateModel state = AppStateModel.fromJson(
      _buildStateJson(mainCurrency: mainCurrency, amountEgp: 1000),
    );

    await WidgetDataService.syncFromState(state);

    final Map<String, dynamic> snapshot = _decodeJson(
      savedWidgetData[WidgetDataService.widgetDataKey] as String,
    );
    expect(snapshot['mainCurrencyCode'], mainCurrency);
    expect(snapshot['currencySymbol'], expectedSymbol);
    expect(
      snapshot['mainCurrencyRateToEgp'],
      closeTo(expectedRateToEgp, 0.001),
    );
    expect(
      (snapshot['netAssetsChangePercentToday'] as num).toDouble(),
      closeTo(expectedPercent, 0.001),
    );

    final Map<String, dynamic> storedHistory = _decodeJson(
      prefs.getString(WidgetDataService.wealthHistoryKey)!,
    );
    final Map<String, dynamic> todayEntry = Map<String, dynamic>.from(
      storedHistory[todayKey] as Map,
    );
    final Map<String, dynamic> currencies = Map<String, dynamic>.from(
      todayEntry['amountsByCurrency'] as Map,
    );
    expect(currencies['EGP'], closeTo(1000, 0.001));
    expect(currencies['USD'], closeTo(200, 0.001));
    expect(currencies['SAR'], isA<num>());
  }

  test(
    'daily wealth percent is evaluated in EGP when EGP is the main currency',
    () async {
      await runScenario(
        mainCurrency: 'EGP',
        expectedPercent: 11.1111,
        expectedSymbol: 'E£',
        expectedRateToEgp: 1,
      );
    },
  );

  test(
    'daily wealth percent is evaluated in USD when USD is the main currency',
    () async {
      await runScenario(
        mainCurrency: 'USD',
        expectedPercent: 0,
        expectedSymbol: r'$',
        expectedRateToEgp: 5,
      );
    },
  );

  test(
    'daily wealth percent is evaluated in SAR with a compact currency symbol',
    () async {
      await runScenario(
        mainCurrency: 'SAR',
        expectedPercent: 11.1111,
        expectedSymbol: '⃁',
        expectedRateToEgp: 1.33,
      );
    },
  );

  test(
    'recent activity summary uses compact million formatting with one decimal',
    () async {
      final Map<String, dynamic> savedWidgetData = <String, dynamic>{};
      await _prepareChannels(savedWidgetData: savedWidgetData);
      final AppStateModel state = AppStateModel.fromJson(
        _buildStateJson(mainCurrency: 'EGP', amountEgp: 1_500_000),
      );

      await WidgetDataService.syncFromState(state);

      final Map<String, dynamic> snapshot = _decodeJson(
        savedWidgetData[WidgetDataService.widgetDataKey] as String,
      );
      expect(snapshot['currencySymbol'], 'E£');
      expect(snapshot['recentActivitySummary'] as String, contains('E£ 1.5M'));
    },
  );

  test('android widget refresh targets both widget receiver classes', () async {
    final Map<String, dynamic> savedWidgetData = <String, dynamic>{};
    final List<Map<String, dynamic>> updateWidgetCalls =
        <Map<String, dynamic>>[];
    await _prepareChannels(
      savedWidgetData: savedWidgetData,
      updateWidgetCalls: updateWidgetCalls,
    );

    final AppStateModel state = AppStateModel.fromJson(
      _buildStateJson(mainCurrency: 'EGP', amountEgp: 1000),
    );

    await WidgetDataService.syncFromState(state);

    final Set<String> androidTargets = updateWidgetCalls.map((
      Map<String, dynamic> call,
    ) {
      return (call['qualifiedAndroidName'] ?? call['android'] ?? call['name'])
          .toString();
    }).toSet();
    expect(
      androidTargets,
      containsAll(<String>[
        WidgetDataService.androidWidgetClass,
        WidgetDataService.androidMediumWidgetClass,
      ]),
    );
  });
}
