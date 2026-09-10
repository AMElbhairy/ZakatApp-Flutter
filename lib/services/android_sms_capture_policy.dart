class AndroidSmsCapturePolicy {
  AndroidSmsCapturePolicy._();

  static const List<String> supportedCurrencyCodes = <String>[
    'EGP',
    'USD',
    'SAR',
    'EUR',
    'GBP',
    'AED',
    'KWD',
    'QAR',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'MYR',
    'PKR',
    'IDR',
  ];

  static const List<String> currencyMarkers = <String>[
    r'$',
    '€',
    '£',
    '₺',
    '⃁',
    '﷼',
    'e£',
    'le',
    'l.e',
    'l.e.',
    'ج.م',
    'جنيه',
    'جنيه مصري',
    'ريال',
    'ر.س',
    'sr',
    's.r',
    's.r.',
    'درهم',
    'د.إ',
    'دينار',
    'دينار كويتي',
    'دينار بحريني',
    'دينار أردني',
    'دينار عماني',
    'يورو',
    'جنيه استرليني',
    'ليرة',
    'رينجيت',
    'روبية',
    'روبيه',
    'rupiah',
    'dollar',
    'dollars',
    'pound',
    'pounds',
  ];

  static bool isLikelyOtpOrSecurityMessage(String message) {
    final String lower = message.toLowerCase();
    return <String>[
      'otp',
      'one time password',
      'one-time password',
      'verification code',
      'confirmation code',
      'security code',
      'authentication code',
      'login code',
      'passcode',
      'purchase code',
      'رمز التحقق',
      'كود التحقق',
      'رمز لمرة واحدة',
      'كلمة مرور لمرة واحدة',
      'رمز الاستخدام لمرة واحدة',
      'رمز شراء',
      'رمز شراء أونلاين',
      'تأكيد الدخول',
    ].any(lower.contains);
  }

  static bool isLikelyFinancialMessage(String message) {
    final String lower = message.toLowerCase();
    if (isLikelyOtpOrSecurityMessage(lower)) return false;
    if (_containsSubscriptionActivationIndicators(lower)) return false;
    if (_containsAnyCurrencyMarker(lower)) return true;
    return <String>[
      'bank',
      'transfer',
      'payment',
      'purchase',
      'debit',
      'credit',
      'card',
      'amount',
      'balance',
      'salary',
      'deposit',
      'withdrawal',
      'wallet',
      'invoice',
      'statement',
      'تحويل',
      'حوالة',
      'سداد',
      'شراء',
      'مبلغ',
      'الرصيد',
      'إيداع',
      'خصم',
      'سحب',
      'محفظة',
      'فاتورة',
    ].any(lower.contains);
  }

  static bool _containsAnyCurrencyMarker(String message) {
    final String lower = message.toLowerCase();
    for (final String marker in currencyMarkers) {
      if (marker.isEmpty) continue;
      if (marker == r'$' ||
          marker == '€' ||
          marker == '£' ||
          marker == '₺' ||
          marker == '⃁' ||
          marker == '﷼') {
        if (lower.contains(marker)) return true;
        continue;
      }
      final String normalizedMarker = marker.toLowerCase();
      if (normalizedMarker.length == 2) {
        final RegExp codePattern = RegExp(
          r'(^|[^a-z0-9])' +
              RegExp.escape(normalizedMarker) +
              r'([^a-z0-9]|$)',
        );
        if (codePattern.hasMatch(lower)) return true;
      } else if (lower.contains(normalizedMarker)) {
        return true;
      }
    }

    for (final String code in supportedCurrencyCodes) {
      final RegExp codePattern = RegExp(
        r'(^|[^a-z0-9])' + code.toLowerCase() + r'([^a-z0-9]|$)',
      );
      if (codePattern.hasMatch(lower)) return true;
    }

    return false;
  }

  static bool _containsSubscriptionActivationIndicators(String message) {
    return <String>[
      'subscribe',
      'subscription',
      'subscribed',
      'welcome prepaid',
      'welcome package',
      'new activation',
      'activation successful',
      'activated successfully',
      'package details',
      'bundle price',
      'service number',
      'econtract',
      'contract',
      'mobily welcome prepaid',
      'اشتراك',
      'تم تفعيل اشتراكك',
      'تم الاشتراك',
      'تفعيل الاشتراك',
      'الباقة',
      'الباقة الترحيبية',
      'الباقة مسبقة الدفع',
      'تفاصيل الباقة',
      'سعر الباقة',
      'رقم الخدمة',
      'العقد الإلكتروني',
      'العقد الالكتروني',
      'تطبيق موبايلي',
      'حمّل تطبيق',
      'حمل تطبيق',
    ].any(message.contains);
  }
}
