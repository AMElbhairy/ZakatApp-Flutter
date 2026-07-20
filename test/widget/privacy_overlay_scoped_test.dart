import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/main.dart';
import 'package:zakatapp_flutter/widgets/sensitive_content_scope.dart';
import 'package:zakatapp_flutter/features/auth/auth_brand_ui.dart';

void main() {
  group('AppPrivacyOverlayController Unit Tests', () {
    test('initial state', () {
      final controller = AppPrivacyOverlayController();
      expect(controller.visible, isFalse);
      expect(controller.sensitiveContentVisible, isFalse);
    });

    test('increment and decrement sensitive count', () {
      final controller = AppPrivacyOverlayController();
      controller.incrementSensitiveCount();
      expect(controller.sensitiveContentVisible, isTrue);

      controller.incrementSensitiveCount();
      expect(controller.sensitiveContentVisible, isTrue);

      controller.decrementSensitiveCount();
      expect(controller.sensitiveContentVisible, isTrue);

      controller.decrementSensitiveCount();
      expect(controller.sensitiveContentVisible, isFalse);

      // Decrementing past 0 should stay at 0
      controller.decrementSensitiveCount();
      expect(controller.sensitiveContentVisible, isFalse);
    });

    test('forceOff resets state', () {
      final controller = AppPrivacyOverlayController();
      controller.incrementSensitiveCount();
      controller.setVisible(true);
      expect(controller.visible, isTrue);
      expect(controller.sensitiveContentVisible, isTrue);

      controller.forceOff();
      expect(controller.visible, isFalse);
      expect(controller.sensitiveContentVisible, isFalse);
    });
  });

  group('SensitiveContentScope Widget Tests', () {
    testWidgets('passes through its child without adding overlay chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SensitiveContentScope(
            active: true,
            child: Text('Child content'),
          ),
        ),
      );

      expect(find.text('Child content'), findsOneWidget);
      expect(find.byType(SensitiveContentScope), findsOneWidget);
    });
  });

  group('AuthPrivacyOverlay Widget Tests', () {
    testWidgets('renders only the centered logo and no text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuthPrivacyOverlay())),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
