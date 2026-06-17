import 'package:flutter/material.dart';

import '../services/zakat_engine.dart';

class CurrencyDropdownFormField extends StatelessWidget {
  const CurrencyDropdownFormField({
    super.key,
    required this.value,
    required this.labelText,
    required this.currencies,
    required this.onChanged,
  });

  final String value;
  final String labelText;
  final List<String> currencies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    String currencyLabel(String currency) {
      final String symbol = ZakatEngineService.getCurrencySymbol(
        currency,
        isArabic: isArabic,
      );
      return symbol == currency ? currency : '$symbol  $currency';
    }

    return DropdownButtonFormField<String>(
      key: ValueKey<String>('currencyDropdown_${labelText}_$value'),
      initialValue: value,
      isExpanded: true,
      alignment: AlignmentDirectional.centerStart,
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      selectedItemBuilder: (BuildContext context) => currencies
          .map(
            (String currency) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                currencyLabel(currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      items: currencies
          .map(
            (String currency) => DropdownMenuItem<String>(
              value: currency,
              child: Text(
                currencyLabel(currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (String? currency) {
        if (currency != null) onChanged(currency);
      },
    );
  }
}
