import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/core/i18n/app_localizations.dart';
import 'package:zakatapp_flutter/core/theme/app_theme.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/features/onboarding/onboarding_gate.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _FakeLocalStorageService extends LocalStorageService {
  _FakeLocalStorageService(this._store);

  final Map<String, String> _store;

  @override
  Future<void> saveString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> loadString(String key) async => _store[key];

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHarness({
    required AppStateController controller,
    required SharedPreferences preferences,
    TargetPlatform platform = TargetPlatform.android,
    bool skipInTests = false,
    List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
  }) {
    return ChangeNotifierProvider<AppStateController>.value(
      value: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          final Locale locale = Locale(controller.state.languagePreference);
          return MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightForLocale(
              locale: locale,
            ).copyWith(platform: platform),
            darkTheme: AppTheme.darkForLocale(
              locale: locale,
            ).copyWith(platform: platform),
            navigatorObservers: navigatorObservers,
            home: OnboardingGate(
              preferences: preferences,
              skipInTests: skipInTests,
              child: const Scaffold(body: Text('Child')),
            ),
          );
        },
      ),
    );
  }

  Future<AppStateController> buildController({
    required Map<String, String> store,
  }) async {
    final AppStateRepository repository = AppStateRepository(
      localStorage: _FakeLocalStorageService(store),
    );
    return AppStateController(repository: repository);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'fresh install shows language selection first and switches locale',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppStateController controller = await buildController(
        store: <String, String>{},
      );

      await tester.pumpWidget(
        buildHarness(controller: controller, preferences: prefs),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('onboarding-language-en')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('onboarding-language-ar')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-language-ar')),
      );
      await tester.pumpAndSettle();

      expect(controller.state.languagePreference, equals('ar'));
      expect(prefs.getString('language_preference'), equals('ar'));
      expect(find.text('اختر اللغة'), findsWidgets);
    },
  );

  testWidgets(
    'existing loaded app state skips onboarding and migrates completion',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_run_before', true);
      final Map<String, String> store = <String, String>{
        StorageKeys.appStateAnonymousKey: jsonEncode(
          AppStateDefaults.create().toJson(),
        ),
      };
      final AppStateController controller = await buildController(store: store);
      await controller.load();

      await tester.pumpWidget(
        buildHarness(controller: controller, preferences: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.text('Child'), findsOneWidget);
      expect(
        prefs.getInt(StorageKeys.onboardingCompletedVersionKey),
        equals(2),
      );
      expect(prefs.getBool(StorageKeys.onboardingCompletedKey), isTrue);
    },
  );

  testWidgets('resume from saved capture step restores the capture screen', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.onboardingStepKey, 3);
    final AppStateController controller = await buildController(
      store: <String, String>{},
    );

    await tester.pumpWidget(
      buildHarness(controller: controller, preferences: prefs),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('onboarding-capture-enable')),
      findsOneWidget,
    );
  });

  testWidgets('Android capture step uses SMS controls and iOS uses shortcuts', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.onboardingStepKey, 3);
    final AppStateController controller = await buildController(
      store: <String, String>{},
    );
    await tester.pumpWidget(
      buildHarness(controller: controller, preferences: prefs),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('onboarding-capture-enable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('onboarding-capture-shortcuts')),
      findsNothing,
    );

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        preferences: prefs,
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('onboarding-capture-shortcuts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('onboarding-capture-enable')),
      findsNothing,
    );
  });

  testWidgets(
    'Android capture step opens the new SMS and battery setup screen',
    (WidgetTester tester) async {
      final _TestNavigatorObserver navigatorObserver = _TestNavigatorObserver();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.onboardingStepKey, 3);
      final AppStateController controller = await buildController(
        store: <String, String>{},
      );

      await tester.pumpWidget(
        buildHarness(
          controller: controller,
          preferences: prefs,
          navigatorObservers: <NavigatorObserver>[navigatorObserver],
        ),
      );
      await tester.pumpAndSettle();

      final Finder enableCapture = find.byKey(
        const ValueKey<String>('onboarding-capture-enable'),
      );
      await tester.ensureVisible(enableCapture);
      await tester.pump();
      await tester.tap(enableCapture);
      await tester.pump();

      expect(navigatorObserver.pushCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('Capture supported messages'), findsOneWidget);
      expect(find.text('Enable SMS Access'), findsNothing);
      expect(find.text('Allow SMS Access'), findsNothing);
    },
  );

  testWidgets('completion persists versioned onboarding state', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.onboardingStepKey, 6);
    final AppStateController controller = await buildController(
      store: <String, String>{},
    );

    await tester.pumpWidget(
      buildHarness(controller: controller, preferences: prefs),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('onboarding-start')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('onboarding-start')));
    await tester.pumpAndSettle();

    expect(prefs.getBool(StorageKeys.onboardingCompletedKey), isTrue);
    expect(prefs.getInt(StorageKeys.onboardingCompletedVersionKey), equals(2));
    expect(prefs.containsKey(StorageKeys.onboardingStepKey), isFalse);
  });

  testWidgets('first-run device with existing app state does not skip onboarding', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Do not set has_run_before to true, simulating a first-run device.
    final Map<String, String> store = <String, String>{
      StorageKeys.appStateAnonymousKey: jsonEncode(
        AppStateDefaults.create().toJson(),
      ),
    };
    final AppStateController controller = await buildController(store: store);
    await controller.load();

    await tester.pumpWidget(
      buildHarness(controller: controller, preferences: prefs),
    );
    await tester.pumpAndSettle();

    // Onboarding should still be shown (e.g. language selection page).
    expect(find.text('Child'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('onboarding-language-en')),
      findsOneWidget,
    );
  });
}

class _TestNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}
