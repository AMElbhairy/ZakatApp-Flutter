import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakatapp_flutter/core/motion/app_motion.dart';

void main() {
  testWidgets('AnimatedValue can count up from zero smoothly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedValue(
              value: 100,
              animateFromZero: true,
              duration: const Duration(milliseconds: 200),
              builder: _buildAnimatedNumberText,
            ),
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('100'), findsOneWidget);
  });
}

Widget _buildAnimatedNumberText(BuildContext context, double value, Widget? _) {
  return Text(value.toStringAsFixed(0), textDirection: TextDirection.ltr);
}
