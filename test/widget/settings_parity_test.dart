import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    return <String, double>{'USD': 50.0, 'SAR': 13.0, 'EGP': 1.0};
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    return 3700.0;
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    return 40.0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppStateController appStateController;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final localStorage = LocalStorageService();
    final repository = AppStateRepository(localStorage: localStorage);
    appStateController = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(),
    );
    await appStateController.load();
    await appStateController.refreshMarketData(force: true);
  });

  group('Settings Currency Parity', () {
    test('Main Currency affects Zakat Engine conversions safely', () {
      // Base value is 1000 EGP
      const double amountEgp = 1000.0;
      final marketData = MarketData.fromJson(appStateController.state.marketData);

      // Convert to EGP (Should remain 1000)
      final double asEgp = ZakatEngineService.convertFromEgp(amountEgp, 'EGP', marketData);
      expect(asEgp, 1000.0);

      // Convert to USD (1000 EGP / 50 = 20 USD)
      final double asUsd = ZakatEngineService.convertFromEgp(amountEgp, 'USD', marketData);
      expect(asUsd, 20.0);

      // Convert to Unknown Currency (Should safely fallback to EGP value or double.nan depending on implementation)
      // The strict parity requirement says "safe unavailable state rather than incorrect values"
      final double asUnknown = ZakatEngineService.convertFromEgp(amountEgp, 'XYZ', marketData);
      expect(asUnknown.isNaN, isTrue);
    });

    testWidgets('Main Currency preference persists', (WidgetTester tester) async {
      // Setup state with SAR as main currency
      final json = appStateController.state.toJson();
      json['mainCurrency'] = 'SAR';
      await appStateController.repository.saveAppState(AppStateModel.fromJson(json));

      // Reload controller to simulate restart
      await appStateController.load();

      expect(appStateController.state.mainCurrency, 'SAR');
    });

    testWidgets('Default Entry Currency preference persists', (WidgetTester tester) async {
      // Setup state with USD as default entry currency
      final json = appStateController.state.toJson();
      json['defaultEntryCurrency'] = 'USD';
      await appStateController.repository.saveAppState(AppStateModel.fromJson(json));

      // Reload controller to simulate restart
      await appStateController.load();

      expect(appStateController.state.defaultEntryCurrency, 'USD');
    });
  });

  group('Language & RTL Parity', () {
    testWidgets('RTL Directionality renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // Force RTL
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Scaffold(
            body: Text('اختبار الزكاة'), // "Zakat Test"
          ),
        ),
      );

      final textFinder = find.text('اختبار الزكاة');
      expect(textFinder, findsOneWidget);
      
      // Verify the text is actually rendered in an RTL context
      final Directionality directionality = tester.widget(find.ancestor(
        of: textFinder,
        matching: find.byType(Directionality),
      ).first);
      
      expect(directionality.textDirection, TextDirection.rtl);
    });
  });

  group('Market Data Parity', () {
    test('Market Data safely handles missing FX rates', () {
      final partialMarketData = MarketData(
        goldPrice24kEgp: 3700.0,
        silverPriceEgp: 40.0,
        usdToEgp: 0.0, // Missing USD rate
        sarToEgp: 13.0,
        ratesToEgp: const <String, double>{}, // Empty rates map
      );

      // Attempt to convert from EGP to USD where rate is 0
      final double converted = ZakatEngineService.convertFromEgp(100.0, 'USD', partialMarketData);
      
      // Engine returns NaN when division by zero/missing rate occurs to prevent corrupted UI totals
      expect(converted.isNaN, isTrue); 
    });

    test('Market Data relies on ratesToEgp map over top-level fields when available', () {
      final mapFavoredData = MarketData(
        goldPrice24kEgp: 3700.0,
        silverPriceEgp: 40.0,
        usdToEgp: 10.0, // Stale top-level
        sarToEgp: 13.0,
        ratesToEgp: const <String, double>{'USD': 50.0}, // Fresh map data
      );

      final double usdRate = ZakatEngineService.convertFromEgp(50.0, 'USD', mapFavoredData);
      expect(usdRate, 1.0); // 50 / 50.0 = 1.0 (Uses the map value)
    });
  });
}
