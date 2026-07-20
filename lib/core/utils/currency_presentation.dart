class CurrencyPresentation {
  const CurrencyPresentation._();

  static const List<String> marketCurrencyCodes = <String>[
    'EGP',
    'SAR',
    'USD',
    'AED',
    'KWD',
    'QAR',
    'EUR',
    'GBP',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'MYR',
    'PKR',
    'IDR',
  ];

  static String label(String currencyCode) {
    final String code = currencyCode.trim().toUpperCase();
    return '${flagEmoji(code)} $code';
  }

  static String selectorLabel(
    String currencyCode, {
    required bool isRtl,
  }) {
    final String code = currencyCode.trim().toUpperCase();
    final String flag = flagEmoji(code);
    return isRtl ? '$code $flag' : '$flag $code';
  }

  static String flagEmoji(String currencyCode) {
    switch (currencyCode.trim().toUpperCase()) {
      case 'EGP':
        return '🇪🇬';
      case 'SAR':
        return '🇸🇦';
      case 'USD':
        return '🇺🇸';
      case 'AED':
        return '🇦🇪';
      case 'KWD':
        return '🇰🇼';
      case 'QAR':
        return '🇶🇦';
      case 'EUR':
        return '🇪🇺';
      case 'GBP':
        return '🇬🇧';
      case 'BHD':
        return '🇧🇭';
      case 'OMR':
        return '🇴🇲';
      case 'JOD':
        return '🇯🇴';
      case 'TRY':
        return '🇹🇷';
      case 'MYR':
        return '🇲🇾';
      case 'PKR':
        return '🇵🇰';
      case 'IDR':
        return '🇮🇩';
      default:
        return '🏳️';
    }
  }
}
