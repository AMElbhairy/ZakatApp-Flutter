import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/widgets/currency_dropdown_form_field.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.themeMode, required this.initialValue});

  final ThemeMode themeMode;
  final String initialValue;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: widget.themeMode,
      theme: ThemeData.light().copyWith(splashFactory: NoSplash.splashFactory),
      darkTheme: ThemeData.dark().copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 220,
            child: CurrencyDropdownFormField(
              value: value,
              labelText: 'Target Currency',
              currencies: const <String>['EGP', 'USD', 'SAR'],
              onChanged: (String nextValue) {
                setState(() => value = nextValue);
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final ThemeMode themeMode in <ThemeMode>[
    ThemeMode.light,
    ThemeMode.dark,
  ]) {
    testWidgets('currency dropdown keeps floating label clear in $themeMode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _Harness(themeMode: themeMode, initialValue: 'EGP'),
      );
      await tester.pumpAndSettle();

      final InputDecorator decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(
        decorator.decoration.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      expect(
        decorator.decoration.contentPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      );
      expect(find.textContaining('EGP'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('USD').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.text('Target Currency'), findsOneWidget);
    });
  }

  testWidgets('currency dropdown reopened with selected value stays stable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(themeMode: ThemeMode.light, initialValue: 'SAR'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SAR'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const _Harness(themeMode: ThemeMode.light, initialValue: 'SAR'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SAR'), findsOneWidget);
    expect(find.text('Target Currency'), findsOneWidget);
  });
}
