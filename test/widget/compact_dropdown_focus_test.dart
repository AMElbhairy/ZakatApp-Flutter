import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/widgets/compact_dropdown.dart';

void main() {
  testWidgets(
    'opening a compact selector releases amount focus without changing text',
    (WidgetTester tester) async {
      final TextEditingController amountController = TextEditingController(
        text: '123.45',
      );
      final FocusNode amountFocusNode = FocusNode();
      addTearDown(amountController.dispose);
      addTearDown(amountFocusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                TextField(
                  key: const Key('amountField'),
                  controller: amountController,
                  focusNode: amountFocusNode,
                ),
                CompactDropdownFormField<String>(
                  key: const Key('currencyField'),
                  value: 'EGP',
                  labelText: 'Currency',
                  items: const <String>['EGP', 'SAR'],
                  itemLabel: (String value) => value,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('amountField')));
      await tester.pump();
      expect(amountFocusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('currencyField')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(amountController.text, '123.45');
      expect(amountFocusNode.hasFocus, isFalse);
      expect(find.text('SAR'), findsOneWidget);
    },
  );
}
