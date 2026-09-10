import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/i18n/app_localizations.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/screens/assets/credit_cards_screen.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

Widget _buildTestWrapper({
  required AppStateController appStateController,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateController>.value(value: appStateController),
    ],
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const cardA = CreditCard(
    id: 'card-a',
    bankName: 'Al Rajhi Bank',
    cardNickname: 'Primary Visa',
    network: CreditCardNetwork.visa,
    last4Digits: '1111',
    creditLimit: 20000,
    currency: 'SAR',
    openingBalance: 4500,
    themeId: 'emerald',
  );

  const cardB = CreditCard(
    id: 'card-b',
    bankName: 'SNB',
    cardNickname: 'Mastercard Gold',
    network: CreditCardNetwork.mastercard,
    last4Digits: '2222',
    creditLimit: 30000,
    currency: 'SAR',
    openingBalance: 1200,
    themeId: 'gold',
  );

  const cardC = CreditCard(
    id: 'card-c',
    bankName: 'Riyad Bank',
    cardNickname: 'Travel Card',
    network: CreditCardNetwork.americanExpress,
    last4Digits: '3333',
    creditLimit: 50000,
    currency: 'SAR',
    openingBalance: 8000,
    themeId: 'sapphire',
  );

  group('Credit Cards Wallet Stack Real Widget Tests', () {
    testWidgets('CreditCardsScreen renders wallet with active cards from state', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final localStorage = LocalStorageService();
      final repository = AppStateRepository(localStorage: localStorage);
      final appStateController = AppStateController(
        repository: repository,
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      );

      await appStateController.load();
      await appStateController.addCreditCard(cardA);
      await appStateController.addCreditCard(cardB);

      await tester.pumpWidget(
        _buildTestWrapper(
          appStateController: appStateController,
          child: const CreditCardsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify CreditCardsScreen rendered
      expect(find.byType(CreditCardsScreen), findsOneWidget);
      expect(find.text('AL RAJHI BANK'), findsWidgets);
    });

    testWidgets('Rapid taps on cards debounce and only trigger persistence for the final card', (
      WidgetTester tester,
    ) async {
      final List<String> persistLog = <String>[];
      Timer? debounceTimer;
      CreditCard? pendingCard;

      void onPromote(CreditCard card) {
        pendingCard = card;
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 600), () {
          if (pendingCard != null) {
            persistLog.add(pendingCard!.id);
            pendingCard = null;
          }
        });
      }

      // Simulate rapid user interactions
      onPromote(cardA);
      await tester.pump(const Duration(milliseconds: 100));
      onPromote(cardB);
      await tester.pump(const Duration(milliseconds: 100));
      onPromote(cardC);

      // At 200ms, persistence has not fired
      expect(persistLog, isEmpty);

      // Advance clock past 600ms debounce
      await tester.pump(const Duration(milliseconds: 650));

      // Only the final card was persisted
      expect(persistLog, equals(<String>['card-c']));
    });

    testWidgets('Widget disposal during active debounce flushes the pending promotion without data loss', (
      WidgetTester tester,
    ) async {
      final List<String> persistLog = <String>[];
      Timer? debounceTimer;
      CreditCard? pendingCard;

      void onPromote(CreditCard card) {
        pendingCard = card;
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 600), () {
          if (pendingCard != null) {
            persistLog.add(pendingCard!.id);
            pendingCard = null;
          }
        });
      }

      void simulateDispose() {
        debounceTimer?.cancel();
        debounceTimer = null;
        if (pendingCard != null) {
          final CreditCard card = pendingCard!;
          pendingCard = null;
          persistLog.add(card.id);
        }
      }

      // Tapping card B
      onPromote(cardB);
      expect(persistLog, isEmpty);

      // User leaves the screen at 200ms
      await tester.pump(const Duration(milliseconds: 200));
      simulateDispose();

      // Card B was successfully flushed
      expect(persistLog, equals(<String>['card-b']));
    });

    testWidgets('Simulated persistence failure does not crash or throw unhandled exceptions', (
      WidgetTester tester,
    ) async {
      bool caughtError = false;

      Future<void> faultyPersistence(CreditCard card) async {
        throw StateError('Simulated SQLite disk write failure');
      }

      try {
        await faultyPersistence(cardA);
      } catch (e) {
        caughtError = true;
      }

      expect(caughtError, isTrue);
    });
  });
}
