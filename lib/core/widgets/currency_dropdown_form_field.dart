import 'package:flutter/material.dart';

import 'compact_selection_dialog.dart';
import '../utils/currency_presentation.dart';

class CurrencyDropdownFormField extends StatelessWidget {
  const CurrencyDropdownFormField({
    super.key,
    required this.value,
    required this.labelText,
    required this.currencies,
    required this.onChanged,
    this.floatingLabelBehavior = FloatingLabelBehavior.always,
  });

  final String value;
  final String labelText;
  final List<String> currencies;
  final ValueChanged<String> onChanged;
  final FloatingLabelBehavior floatingLabelBehavior;

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    String currencyLabel(String currency) {
      return CurrencyPresentation.selectorLabel(currency, isRtl: isArabic);
    }

    return FormField<String>(
      initialValue: value,
      builder: (FormFieldState<String> field) {
        final String currentValue = field.value ?? value;
        return InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: floatingLabelBehavior,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            errorText: field.errorText,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final String? selected = await showCompactSelectionDialog<String>(
                context: context,
                title: labelText,
                options: currencies,
                optionLabel: currencyLabel,
                selectedValueLabel: currencyLabel(currentValue),
              );
              if (selected != null) {
                field.didChange(selected);
                onChanged(selected);
              }
            },
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    currencyLabel(currentValue),
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}
