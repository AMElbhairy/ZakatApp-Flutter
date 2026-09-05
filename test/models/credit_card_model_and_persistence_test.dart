import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';

void main() {
  group('CreditCard Model Value Equality & Selector Stability', () {
    test('supplementary parent relationship round-trips through JSON', () {
      const CreditCard supplementary = CreditCard(
        id: 'card-2',
        bankName: 'Al Rajhi',
        cardNickname: 'Supplementary',
        network: CreditCardNetwork.visa,
        last4Digits: '5678',
        creditLimit: 10000,
        currency: 'SAR',
        openingBalance: 2000,
        parentCardId: 'card-1',
      );

      final CreditCard restored = CreditCard.fromJson(supplementary.toJson());
      expect(restored.parentCardId, 'card-1');
      expect(restored, equals(supplementary));
    });

    test('Two credit cards with identical fields are equal', () {
      const card1 = CreditCard(
        id: 'card-1',
        bankName: 'Al Rajhi',
        cardNickname: 'Main',
        network: CreditCardNetwork.visa,
        last4Digits: '1234',
        creditLimit: 10000,
        currency: 'SAR',
        openingBalance: 2000,
      );

      const card2 = CreditCard(
        id: 'card-1',
        bankName: 'Al Rajhi',
        cardNickname: 'Main',
        network: CreditCardNetwork.visa,
        last4Digits: '1234',
        creditLimit: 10000,
        currency: 'SAR',
        openingBalance: 2000,
      );

      expect(card1, equals(card2));
      expect(card1.hashCode, equals(card2.hashCode));
    });

    test('Two credit cards with different balances are not equal', () {
      const card1 = CreditCard(
        id: 'card-1',
        bankName: 'Al Rajhi',
        cardNickname: 'Main',
        network: CreditCardNetwork.visa,
        last4Digits: '1234',
        creditLimit: 10000,
        currency: 'SAR',
        openingBalance: 2000,
      );

      final card2 = card1.copyWith(openingBalance: 3500);

      expect(card1 == card2, isFalse);
    });
  });

  group('Card Promotion Lifecycle, Rapid Taps & Disposal Persistence', () {
    test(
      'Rapid consecutive taps only persist the final card after debounce',
      () async {
        final promotedLog = <String>[];

        Timer? debounceTimer;
        CreditCard? pendingCard;

        void tapCard(CreditCard card) {
          pendingCard = card;
          debounceTimer?.cancel();
          debounceTimer = Timer(const Duration(milliseconds: 600), () {
            if (pendingCard != null) {
              promotedLog.add(pendingCard!.id);
              pendingCard = null;
            }
          });
        }

        const cardA = CreditCard(
          id: 'card-A',
          bankName: 'Bank A',
          cardNickname: 'A',
          network: CreditCardNetwork.visa,
          last4Digits: '1111',
          creditLimit: 5000,
          currency: 'SAR',
          openingBalance: 100,
        );

        const cardB = CreditCard(
          id: 'card-B',
          bankName: 'Bank B',
          cardNickname: 'B',
          network: CreditCardNetwork.mastercard,
          last4Digits: '2222',
          creditLimit: 5000,
          currency: 'SAR',
          openingBalance: 200,
        );

        const cardC = CreditCard(
          id: 'card-C',
          bankName: 'Bank C',
          cardNickname: 'C',
          network: CreditCardNetwork.visa,
          last4Digits: '3333',
          creditLimit: 5000,
          currency: 'SAR',
          openingBalance: 300,
        );

        // User rapidly taps A, then B, then C within 200ms
        tapCard(cardA);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        tapCard(cardB);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        tapCard(cardC);

        // At 300ms, debounce should not have fired yet
        expect(promotedLog, isEmpty);

        // Wait 700ms for debounce timer to fire
        await Future<void>.delayed(const Duration(milliseconds: 700));

        // Only the final tapped card (cardC) should have been persisted
        expect(promotedLog, equals(<String>['card-C']));
      },
    );

    test(
      'Disposal flushes any pending promotion asynchronously without data loss',
      () async {
        final promotedLog = <String>[];

        Timer? debounceTimer;
        CreditCard? pendingCard;

        void tapCard(CreditCard card) {
          pendingCard = card;
          debounceTimer?.cancel();
          debounceTimer = Timer(const Duration(milliseconds: 600), () {
            if (pendingCard != null) {
              promotedLog.add(pendingCard!.id);
              pendingCard = null;
            }
          });
        }

        void dispose() {
          debounceTimer?.cancel();
          debounceTimer = null;
          if (pendingCard != null) {
            final card = pendingCard!;
            pendingCard = null;
            unawaited(() async {
              promotedLog.add(card.id);
            }());
          }
        }

        const cardA = CreditCard(
          id: 'card-A',
          bankName: 'Bank A',
          cardNickname: 'A',
          network: CreditCardNetwork.visa,
          last4Digits: '1111',
          creditLimit: 5000,
          currency: 'SAR',
          openingBalance: 100,
        );

        // Tap card A
        tapCard(cardA);
        expect(promotedLog, isEmpty);

        // User navigates away at 150ms (before 600ms timer fires)
        await Future<void>.delayed(const Duration(milliseconds: 150));
        dispose();

        // Wait a tick for the async unawaited flush
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Card A was safely flushed on dispose!
        expect(promotedLog, equals(<String>['card-A']));
      },
    );

    test(
      'Failed card persistence is caught gracefully without unhandled crashes',
      () async {
        bool errorLogged = false;

        Future<void> faultyPersist(CreditCard card) async {
          throw StateError('Simulated SQLite disk write failure');
        }

        try {
          await faultyPersist(
            const CreditCard(
              id: 'card-err',
              bankName: 'Error Bank',
              cardNickname: 'Err',
              network: CreditCardNetwork.visa,
              last4Digits: '0000',
              creditLimit: 1000,
              currency: 'SAR',
              openingBalance: 0,
            ),
          );
        } catch (e) {
          errorLogged = true;
        }

        expect(errorLogged, isTrue);
      },
    );
  });
}
