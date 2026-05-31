import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeMarketDataApiService implements MarketDataApiService {
  _FakeMarketDataApiService({
    this.fxRates,
    this.goldPrice,
    this.silverPrice,
    this.throwFx = false,
  });

  final Map<String, double>? fxRates;
  final double? goldPrice;
  final double? silverPrice;
  final bool throwFx;

  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    if (throwFx) {
      throw Exception('fx error');
    }
    return fxRates;
  }

  @override
  Future<double?> fetchGold24kPerGramEgp() async => goldPrice;

  @override
  Future<double?> fetchSilverPerGramEgp() async => silverPrice;
}

void main() {
  late AppStateRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    repository = AppStateRepository(localStorage: localStorage);
  });

  test('successful FX refresh updates snapshot', () async {
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(
        fxRates: <String, double>{'USD': 50, 'SAR': 13.3, 'AED': 13.6},
      ),
    );
    await controller.load();

    final result = await controller.refreshMarketData();
    final snapshot = controller.currentMarketSnapshot;

    expect(result.success, isTrue);
    expect(snapshot.usdToEgp, 50);
    expect(snapshot.sarToEgp, 13.3);
    expect(snapshot.aedToEgp, 13.6);
  });

  test('failed API does not crash', () async {
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(throwFx: true),
    );
    await controller.load();

    final result = await controller.refreshMarketData();
    expect(result.success, isFalse);
  });

  test('null metals preserve manual values', () async {
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(
        fxRates: <String, double>{'USD': 50, 'SAR': 13.3},
        goldPrice: null,
        silverPrice: null,
      ),
    );
    await controller.load();
    await controller.updateMarketSnapshot(
      const MarketSnapshot(
        gold24kPricePerGramEgp: 5100,
        silverPricePerGramEgp: 61,
        usdToEgp: 0,
        sarToEgp: 0,
        aedToEgp: 0,
        kwdToEgp: 0,
        qarToEgp: 0,
        eurToEgp: 0,
        gbpToEgp: 0,
        bhdToEgp: 0,
        omrToEgp: 0,
        jodToEgp: 0,
        tryToEgp: 0,
        myrToEgp: 0,
        pkrToEgp: 0,
        idrToEgp: 0,
        lastUpdated: '2026-01-01T00:00:00Z',
      ),
    );

    await controller.refreshMarketData();
    final snapshot = controller.currentMarketSnapshot;
    expect(snapshot.gold24kPricePerGramEgp, 5100);
    expect(snapshot.silverPricePerGramEgp, 61);
  });

  test('refresh updates lastUpdated only on success', () async {
    final controllerFail = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(),
    );
    await controllerFail.load();
    await controllerFail.updateMarketSnapshot(
      const MarketSnapshot(
        gold24kPricePerGramEgp: 5100,
        silverPricePerGramEgp: 61,
        usdToEgp: 0,
        sarToEgp: 0,
        aedToEgp: 0,
        kwdToEgp: 0,
        qarToEgp: 0,
        eurToEgp: 0,
        gbpToEgp: 0,
        bhdToEgp: 0,
        omrToEgp: 0,
        jodToEgp: 0,
        tryToEgp: 0,
        myrToEgp: 0,
        pkrToEgp: 0,
        idrToEgp: 0,
        lastUpdated: '2026-01-01T00:00:00Z',
      ),
    );
    await controllerFail.refreshMarketData();
    expect(controllerFail.currentMarketSnapshot.lastUpdated, '2026-01-01T00:00:00Z');

    final controllerSuccess = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(
        fxRates: <String, double>{'USD': 50, 'SAR': 13.3},
      ),
    );
    await controllerSuccess.load();
    await controllerSuccess.updateMarketSnapshot(
      const MarketSnapshot(
        gold24kPricePerGramEgp: 5100,
        silverPricePerGramEgp: 61,
        usdToEgp: 0,
        sarToEgp: 0,
        aedToEgp: 0,
        kwdToEgp: 0,
        qarToEgp: 0,
        eurToEgp: 0,
        gbpToEgp: 0,
        bhdToEgp: 0,
        omrToEgp: 0,
        jodToEgp: 0,
        tryToEgp: 0,
        myrToEgp: 0,
        pkrToEgp: 0,
        idrToEgp: 0,
        lastUpdated: '2026-01-01T00:00:00Z',
      ),
    );
    await controllerSuccess.refreshMarketData();
    expect(controllerSuccess.currentMarketSnapshot.lastUpdated, isNot('2026-01-01T00:00:00Z'));
  });
}
