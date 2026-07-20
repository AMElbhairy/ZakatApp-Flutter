import 'package:flutter/material.dart';
import '../../screens/entry/currency_exchange_screen.dart';

Future<void> openEditCurrencyExchangeDialog(
  BuildContext context,
  dynamic item,
  {String? activityId}
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CurrencyExchangeScreen(
        initialItem: item,
        initialActivityId: activityId,
      ),
    ),
  );
}
