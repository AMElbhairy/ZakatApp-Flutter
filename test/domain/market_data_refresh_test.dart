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
    this.throwGold = false,
    this.throwSilver = false,
  });

  final Map<String, double>? fxRates;
  final double? goldPrice;
  final double? silverPrice;
  final bool throwFx;
  final bool throwGold;
  final bool throwSilver;
  int callOrder = 0;
  int? fxOrder;
  int? goldOrder;
  int? silverOrder;
  double? lastUsdToEgpForGold;
  double? lastUsdToEgpForSilver;

  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    callOrder += 1;
    fxOrder ??= callOrder;
    if (throwFx) {
      throw Exception('fx error');
    }
    return fxRates;
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    if (throwGold) throw Exception('gold error');
    callOrder += 1;
    goldOrder ??= callOrder;
    lastUsdToEgpForGold = usdToEgp;
    return goldPrice;
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    if (throwSilver) throw Exception('silver error');
    callOrder += 1;
    silverOrder ??= callOrder;
    lastUsdToEgpForSilver = usdToEgp;
    return silverPrice;
  }
}

void main() {
  late AppStateRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    repository = AppStateRepository(localStorage: localStorage);
  });

  test('successful FX refresh updates snapshot', () async {
    final fake = _FakeMarketDataApiService(
      fxRates: <String, double>{'USD': 50, 'SAR': 13.3, 'AED': 13.6},
    );
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: fake,
    );
    await controller.load();

    final result = await controller.refreshMarketData();
    final snapshot = controller.currentMarketSnapshot;

    expect(result.success, isTrue);
    expect(snapshot.usdToEgp, 50);
    expect(snapshot.sarToEgp, 13.3);
    expect(snapshot.aedToEgp, 13.6);
    expect(fake.lastUsdToEgpForGold, 50);
    expect(fake.lastUsdToEgpForSilver, 50);
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

  test('FX is fetched before metals conversion', () async {
    final fake = _FakeMarketDataApiService(
      fxRates: <String, double>{'USD': 49.5, 'SAR': 13.2},
      goldPrice: 5000,
      silverPrice: 60,
    );
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: fake,
    );
    await controller.load();

    await controller.refreshMarketData();

    expect(fake.fxOrder != null, isTrue);
    expect(fake.goldOrder != null, isTrue);
    expect(fake.silverOrder != null, isTrue);
    expect(fake.fxOrder! < fake.goldOrder!, isTrue);
    expect(fake.fxOrder! < fake.silverOrder!, isTrue);
    expect(fake.lastUsdToEgpForGold, 49.5);
    expect(fake.lastUsdToEgpForSilver, 49.5);
  });

  test('failed metals API preserves manual values', () async {
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: _FakeMarketDataApiService(
        fxRates: <String, double>{'USD': 50, 'SAR': 13.3},
        throwGold: true,
        throwSilver: true,
      ),
    );
    await controller.load();
    await controller.updateMarketSnapshot(
      const MarketSnapshot(
        gold24kPricePerGramEgp: 5300,
        silverPricePerGramEgp: 65,
        usdToEgp: 48,
        sarToEgp: 12.8,
        aedToEgp: 13.1,
        kwdToEgp: 157,
        qarToEgp: 13.1,
        eurToEgp: 53,
        gbpToEgp: 61,
        bhdToEgp: 132,
        omrToEgp: 128,
        jodToEgp: 70,
        tryToEgp: 1.4,
        myrToEgp: 10.7,
        pkrToEgp: 0.17,
        idrToEgp: 0.003,
        lastUpdated: '2026-01-01T00:00:00Z',
      ),
    );

    await controller.refreshMarketData();
    final snapshot = controller.currentMarketSnapshot;
    expect(snapshot.gold24kPricePerGramEgp, 5300);
    expect(snapshot.silverPricePerGramEgp, 65);
  });

  test('auto refresh startup trigger runs and schedule can start safely', () async {
    final fake = _FakeMarketDataApiService(
      fxRates: <String, double>{'USD': 50, 'SAR': 13.3},
    );
    final controller = AppStateController(
      repository: repository,
      marketDataApiService: fake,
    );
    await controller.load();
    await controller.startMarketAutoRefresh();

    final snapshot = controller.currentMarketSnapshot;
    expect(snapshot.usdToEgp, 50);

    // Idempotent repeated startup call.
    await controller.startMarketAutoRefresh();
    expect(AppStateController.marketRefreshInterval, const Duration(minutes: 5));
  });
}
