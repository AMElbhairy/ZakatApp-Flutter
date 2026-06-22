import '../models/merchant_rule.dart';

class SmartCaptureParseResult {
  const SmartCaptureParseResult({
    required this.type,
    this.amount,
    this.currency,
    required this.confidence,
    this.merchantName,
    this.suggestedCategory,
    this.merchantRuleUsed,
    this.merchantRuleSource,
    this.ignoreReason,
    required this.description,
    this.isValid = true,
  });

  final String type;
  final double? amount;
  final String? currency;
  final double confidence;
  final String? merchantName;
  final String? suggestedCategory;
  final String? merchantRuleUsed;
  final String? merchantRuleSource;
  final String? ignoreReason;
  final String description;
  final bool isValid;
}

class SmartCaptureParser {
  SmartCaptureParser._();

  static SmartCaptureParseResult parse(
    String rawMessage, {
    Map<String, MerchantRule> merchantRules = const <String, MerchantRule>{},
    Map<String, String> merchantAliases = const <String, String>{},
  }) {
    final String text = rawMessage.toLowerCase();

    // 0. Stage 0 — Transaction Status & Exclusions Detection
    final bool isOtpOrVerificationMessage = _hasMatch(text, [
      'otp',
      'one time password',
      'one-time password',
      'verification code',
      'confirmation code',
      'رمز التحقق',
      'كود التحقق',
      'رمز لمرة واحدة',
      'الرمز لمرة واحدة',
      'كلمة مرور لمرة واحدة',
      'رمز الاستخدام لمرة واحدة',
    ]);
    if (isOtpOrVerificationMessage) {
      return const SmartCaptureParseResult(
        type: 'unknown',
        amount: null,
        currency: null,
        confidence: 0.0,
        merchantName: null,
        description: 'Verification Code Message',
        ignoreReason: 'Verification Code Message',
        isValid: false,
      );
    }

    final bool isDeclined = _hasMatch(text, [
      'declined',
      'rejected',
      'failed',
      'unsuccessful',
      'cancelled',
      'timeout',
      'expired',
      'blocked',
      'insufficient funds',
      'مرفوضة',
      'مرفوض',
      'فشلت',
      'غير مكتملة',
      'تم الإلغاء',
      'ألغيت',
      'غير ناجحة',
      'الرصيد غير كاف',
      'رفض',
      'تم رفض',
    ]);
    if (isDeclined) {
      return const SmartCaptureParseResult(
        type: 'unknown',
        amount: null,
        currency: null,
        confidence: 0.0,
        merchantName: null,
        description: 'Declined Transaction',
        ignoreReason: 'Declined Transaction',
        isValid: false,
      );
    }

    final bool isRefund = _hasMatch(text, [
      'refunded',
      'refund',
      'reversal',
      'reversed',
      'chargeback',
      'returned payment',
      'payment returned',
      'reverse transaction',
      'reversed transaction',
      'refunded transaction',
      'استرداد',
      'إرجاع',
      'تم رد المبلغ',
      'عكس العملية',
      'عكس القيد',
      'عملية عكسية',
      'استرجاع',
      'إسترجاع',
      'مرتجع',
      'مسترجع',
      'مسترد',
      'مستردة',
    ]);

    // 1. Stage 2 — Transaction Type Classification (Strict Precedence)
    // Check explicit Expense Overrides first
    final bool isExpenseOverride = _hasMatch(text, [
      'purchase',
      'online purchase',
      'pos',
      'point of sale',
      'apple pay',
      'mada',
      'visa purchase',
      'mastercard purchase',
      'payment',
      'debit card purchase',
      'شراء',
      'شراء دولي',
      'شراء عبر الإنترنت',
      'شراء عبر نقاط البيع',
      'نقاط البيع',
      'مدى',
      'أبل باي',
      'عملية شراء',
    ]);

    final bool hasTransferDepositPattern =
        _hasMatch(text, [
          'تم إضافة مبلغ',
          'تم الإيداع',
          'تم تحويل إليك',
          'credited',
          'received',
          'incoming transfer',
          'deposit',
        ]) &&
        _hasMatch(text, [
          'إلى حساب',
          'to account',
          'from account',
          'between accounts',
          'transfer between accounts',
          'تحويل بين الحسابات',
          'من حساب',
          'لحساب',
          'إلى حسابك',
        ]);

    // Transfers movement between own accounts or credit card settlements
    final bool isTransfer =
        !isExpenseOverride &&
        (hasTransferDepositPattern ||
            _hasMatch(text, [
              'internal transfer',
              'transfer between accounts',
              'account transfer',
              'credit card payment',
              'card settlement',
              'installment payment',
              'تحويل داخلي',
              'تحويل بين الحسابات',
              'سداد البطاقة',
              'تحويل لحساب',
              'دفعة بطاقة',
              'بطاقة ائتمانية',
              'to account',
              'from account',
              'between accounts',
            ]));

    // Income (including local inbound transfers and refunds)
    final bool isIncome =
        !isTransfer &&
        (isRefund ||
            _hasMatch(text, [
              'credit transfer',
              'incoming transfer',
              'deposit',
              'salary',
              'credited',
              'received',
              'transfer received',
              'payment received',
              'inward transfer',
              'cashback',
              'repayment',
              'تم الإيداع',
              'تم إضافة مبلغ',
              'حوالة واردة',
              'تحويل وارد',
              'راتب',
              'تم استلام',
              'تم تحويل إليك',
              'تم إضافة',
              'added',
              'ايداع',
              'إيداع',
              'إيداع نقدي',
              'ايداع نقدي',
              'كاش باك',
            ]));

    // General Transfer (if not captured above and contains transfer words)
    final bool isTransferGeneral =
        !isExpenseOverride &&
        !isTransfer &&
        !isIncome &&
        _hasMatch(text, [
          'transfer',
          'remittance',
          'bank transfer',
          'تحويل',
          'حوالة',
        ]);

    final bool isExpense =
        !isTransfer &&
        !isTransferGeneral &&
        !isIncome &&
        (isExpenseOverride ||
            _hasMatch(text, [
              'pos',
              'payment',
              'debit',
              'spent',
              'withdrawal',
              'خصم',
              'دفع',
              'card',
              'بطاقة',
              'account',
              'حساب',
              'رقم الحساب',
              'مبلغ',
              'amount',
              'amt',
              'value',
              'بقيمة',
              'بقيمه',
              'fee',
              'fees',
              'total due',
              'total charged',
              'charged amount',
              'exchange rate',
            ]));

    String type = 'unknown';
    if (isTransfer || isTransferGeneral) {
      type = 'transfer';
    } else if (isIncome) {
      type = 'income';
    } else if (isExpense) {
      type = 'expense';
    }

    // 2. Stage 1 — Message Cleanup (Scrub sensitive parameters before amount extraction)
    String scrubbed = text;
    // Remove URLs
    scrubbed = scrubbed.replaceAll(RegExp(r'https?://\S+|bit\.ly/\S+'), ' ');
    // Remove Card numbers e.g. card:0669, بطاقة:0669, card 1234, ****1234
    scrubbed = scrubbed.replaceAll(
      RegExp(
        r'(?:card|بطاقة|visa|mastercard)[\s:\-*]*\d+',
        caseSensitive: false,
      ),
      ' ',
    );
    // Remove Account numbers e.g. account:1234, رقم الحساب:5000, account 123456
    scrubbed = scrubbed.replaceAll(
      RegExp(r'(?:account|رقم الحساب|حساب)[\s:\-*]*\d+', caseSensitive: false),
      ' ',
    );
    // Remove Masked identifiers e.g. ****1234, xxxx1234
    scrubbed = scrubbed.replaceAll(
      RegExp(r'\*+\d+|\d+\*+|xxxx\d+|x+\d+', caseSensitive: false),
      ' ',
    );
    // Remove Dates e.g. 12/6/26, 2026-06-12, 26/05/2026
    scrubbed = scrubbed.replaceAll(
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),
      ' ',
    );
    scrubbed = scrubbed.replaceAll(RegExp(r'\b\d{4}-\d{2}-\d{2}\b'), ' ');
    // Remove Times e.g. 00:20, 10:20:30, 10:31 pm
    scrubbed = scrubbed.replaceAll(
      RegExp(r'\b\d{1,2}:\d{2}:\d{2}(?:\s*[ap]m)?\b', caseSensitive: false),
      ' ',
    );
    scrubbed = scrubbed.replaceAll(
      RegExp(r'\b\d{1,2}:\d{2}(?:\s*[ap]m)?\b', caseSensitive: false),
      ' ',
    );
    // Remove Reference IDs / Transaction IDs e.g. REF12345, Transaction ID
    scrubbed = scrubbed.replaceAll(
      RegExp(r'\b(?:ref|transaction id)[\s:\-*]*\w+', caseSensitive: false),
      ' ',
    );

    // 3. Stage 3 & 5 — Structured Amount & Currency Selection
    double? amount;
    String? currency;

    // Find all numbers in the scrubbed text
    final RegExp numberRegex = RegExp(r'\b([0-9,]+(?:\.[0-9]+)?)\b');
    final List<Match> numberMatches = numberRegex.allMatches(scrubbed).toList();

    double bestScore = -9999.0;
    int selectedPriority = 99;

    for (final Match m in numberMatches) {
      final String rawNumStr = m.group(1) ?? '';
      final double val = double.tryParse(rawNumStr.replaceAll(',', '')) ?? 0.0;
      if (val == 0.0) continue;

      final int start = m.start;
      final int end = m.end;

      // Limit context to the same line to avoid crossing boundaries
      final int lineStart = scrubbed.lastIndexOf('\n', start);
      final int limitBefore = lineStart == -1 ? 0 : lineStart;
      final String contextBefore = scrubbed.substring(
        start - 25 >= limitBefore ? start - 25 : limitBefore,
        start,
      );

      final int lineEnd = scrubbed.indexOf('\n', end);
      final int limitAfter = lineEnd == -1 ? scrubbed.length : lineEnd;
      final String contextAfter = scrubbed.substring(
        end,
        end + 25 <= limitAfter ? end + 25 : limitAfter,
      );

      // Check for Ignored Financial Fields (Priority 5 must NEVER win)
      final bool isIgnored =
          _hasMatch(contextBefore, [
            'الرصيد',
            'رصيدك الحالي',
            'حد الصرف',
            'حد الصرف المتبقي',
            'سعر الصرف',
            'exchange rate',
            'available balance',
            'remaining balance',
            'credit limit',
          ]) ||
          _hasMatch(contextAfter, [
            'الرصيد',
            'رصيدك الحالي',
            'حد الصرف',
            'حد الصرف المتبقي',
            'سعر الصرف',
            'exchange rate',
            'available balance',
            'remaining balance',
            'credit limit',
          ]);

      if (isIgnored) continue; // Skip ignored fields immediately

      // Classify priority groups (5-tier layout)
      int priority = 5; // Default lowest fallback
      double score = 0.0;

      if (_hasMatch(contextBefore, [
            'total due',
            'total charged',
            'إجمالي المبلغ المستحق',
            'المبلغ النهائي',
            'إجمالي المبلغ',
          ]) ||
          _hasMatch(contextAfter, [
            'total due',
            'total charged',
            'إجمالي المبلغ المستحق',
            'المبلغ النهائي',
            'إجمالي المبلغ',
          ])) {
        priority = 1;
        score = 10000.0;
      } else if (_hasMatch(contextBefore, [
            'charged amount',
            'المبلغ المطلوب',
            'total charged amount',
          ]) ||
          _hasMatch(contextAfter, [
            'charged amount',
            'المبلغ المطلوب',
            'total charged amount',
          ])) {
        priority = 2;
        score = 8000.0;
      } else if (_hasMatch(contextBefore, [
            'مبلغ',
            'amount',
            'amt',
            'value',
            'بقيمة',
            'بقيمه',
            'purchase amount',
            'transaction amount',
          ]) ||
          _hasMatch(contextAfter, [
            'مبلغ',
            'amount',
            'amt',
            'value',
            'بقيمة',
            'بقيمه',
            'purchase amount',
            'transaction amount',
          ])) {
        priority = 3;
        score = 6000.0;
      } else if (_hasMatch(contextBefore, [
            'purchase',
            'pos',
            'payment',
            'debit',
            'credit',
            'شراء',
            'دفع',
            'خصم',
            'سحب',
          ]) ||
          _hasMatch(contextAfter, [
            'purchase',
            'pos',
            'payment',
            'debit',
            'credit',
            'شراء',
            'دفع',
            'خصم',
            'سحب',
          ])) {
        priority = 3;
        score = 5500.0;
      } else if (_hasMatch(contextBefore, [
            'fee',
            'fees',
            'رسوم',
            'رسوم العملية',
          ]) ||
          _hasMatch(contextAfter, ['fee', 'fees', 'رسوم', 'رسوم العملية'])) {
        priority = 4;
        score = 4000.0;
      } else if (_hasMatch(contextBefore, [
            'balance',
            'remaining',
            'spending limit',
          ]) ||
          _hasMatch(contextAfter, ['balance', 'remaining', 'spending limit'])) {
        priority = 5;
        score = 2000.0;
      }

      // Check for nearby currency inside the context windows
      String? localCurrency;
      final String fullContext = '$contextBefore $contextAfter';
      final RegExp curFinder = RegExp(
        r'(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م)',
        caseSensitive: false,
      );
      final Match? curMatch = curFinder.firstMatch(fullContext);
      if (curMatch != null) {
        localCurrency = _normalizeCurrency(curMatch.group(1));
        score += 2.0; // Bonus for having a currency next to it
      }

      // Stage 5 International Purchases Precedence:
      // If the matched currency is EGP or SAR, boost it to prioritize local charged amount over foreign currency
      if (localCurrency == 'SAR' || localCurrency == 'EGP') {
        score += 30.0;
      }

      if (priority < selectedPriority ||
          (priority == selectedPriority && score > bestScore)) {
        selectedPriority = priority;
        bestScore = score;
        amount = val;
        if (localCurrency != null) {
          currency = localCurrency;
        }
      }
    }

    // Fallback general currency finder in the entire message if not found near the best amount
    if (currency == null) {
      final RegExp currencyFinder = RegExp(
        r'(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م)',
        caseSensitive: false,
      );
      final Match? curMatch = currencyFinder.firstMatch(scrubbed);
      if (curMatch != null) {
        currency = _normalizeCurrency(curMatch.group(1));
      }
    }

    // 4. Stage 4 — Merchant Extraction. Explicit merchant fields always win.
    final Map<String, String> effectiveAliases = _effectiveAliases(
      merchantRules,
      merchantAliases,
    );
    final String merchantText = text.replaceAllMapped(
      RegExp(r'(\d)(?=[a-zA-Z\u0600-\u06FF])'),
      (Match match) => '${match.group(1)} ',
    );
    String? merchantName;
    final RegExp explicitMerchantRegex = RegExp(
      r'^(?:من|merchant(?:\s+name)?|store|التاجر|عند|لدى|at|from)\s*:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    );
    final Match? explicitMatch = explicitMerchantRegex.firstMatch(rawMessage);
    if (explicitMatch != null) {
      merchantName = _validatedMerchant(
        explicitMatch.group(1),
        effectiveAliases,
      );
    }

    merchantName ??= _merchantFromPriorityPatterns(
      rawMessage,
      effectiveAliases,
    );

    // Some banks omit the colon but still provide an unambiguous relation.
    if (merchantName == null) {
      final RegExp relationMerchantRegex = RegExp(
        r'(?:^|\s)(?:من|لدى|عند|from|at)\s+([a-zA-Z0-9*\-\s\u0600-\u06FF\.]+?)(?=\s+(?:amount|balance|date|card|يوم|اليوم|الرصيد|المتاح|لمزيد|المعلومات|link|الرابط)|\b\d|$)',
        caseSensitive: false,
      );
      merchantName = _validatedMerchant(
        relationMerchantRegex.firstMatch(merchantText)?.group(1),
        effectiveAliases,
      );
    }

    // A known alias can identify a merchant even when a bank uses no label.
    merchantName ??= _merchantFromKnownAlias(text, effectiveAliases);

    if (merchantName == null) {
      final RegExp fallbackMerchantRegex = RegExp(
        r'(?:^|\s|\b)(?:purchase|pos purchase|pos|payment|spent|شراء|خصم|دفع|at|from|merchant|من|لدى|عند):?\s+([a-zA-Z0-9*\-\s\u0600-\u06FF\.]+?)(?=\s+(?:sar|egp|usd|\$|aed|درهم|ريال|جنيه|amount|balance|date|card|يوم|اليوم|الرصيد|المتاح|لمزيد|المعلومات|link|الرابط)|\b\d|$)',
        caseSensitive: false,
      );
      final Match? fallbackMatch = fallbackMerchantRegex.firstMatch(
        merchantText,
      );
      merchantName = _validatedMerchant(
        fallbackMatch?.group(1),
        effectiveAliases,
      );
    }

    // Line-by-line fallback for merchant name extraction (e.g. multi-line alerts without strong/weak prefix labels)
    if (merchantName == null) {
      final List<String> lines = rawMessage
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      for (final line in lines) {
        final String lineLower = line.toLowerCase();
        if (RegExp(
          r'^(?:في|داخل|الدولة|country)\s*:',
          caseSensitive: false,
        ).hasMatch(lineLower)) {
          continue;
        }
        // Skip lines that are just transaction type keywords, currency/numbers, or payment methods
        if (_hasMatch(lineLower, [
              'شراء',
              'دفع',
              'خصم',
              'سداد',
              'عملية',
              'purchase',
              'payment',
              'pos',
              'debit',
              'transfer',
              'remittance',
              'تحويل',
              'حوالة',
              'تم',
              'دولي',
              'محلي',
              'بطاقة',
              'الخصم',
              'المباشر',
              'رقم',
              'المتاح',
              'الرصيد',
              'الحساب',
              'اليوم',
              'الساعة',
              'عملية',
              'merchant',
              'by',
            ]) ||
            _hasMatch(lineLower, [
              'apple pay',
              'mada',
              'مدى',
              'card',
              'بطاقة',
              'حساب',
              'account',
              'visa',
              'mastercard',
            ]) ||
            _hasMatch(lineLower, [
              'sar',
              'sr',
              's.r',
              'egp',
              'usd',
              'aed',
              'درهم',
              'ريال',
              'جنيه',
              'ر.س',
              'ج.م',
              'fee',
              'رسوم',
              'total',
              'due',
              'balance',
              'الرصيد',
              'مبلغ',
              'amount',
            ]) ||
            RegExp(r'\d').hasMatch(line)) {
          continue;
        }
        // If a line is clean and has alphabetical or Arabic characters, it's the merchant!
        if (RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(line)) {
          final String cleanL = line.trim();
          if (cleanL.isNotEmpty) {
            merchantName = _validatedMerchant(cleanL, effectiveAliases);
            if (merchantName != null) break;
          }
        }
      }
    }

    String? suggestedCategory;
    String? merchantRuleUsed;
    String? merchantRuleSource;
    if (merchantName != null) {
      final String key = merchantName.toLowerCase().trim();
      final MerchantRule? persistedRule = _findPersistedRule(
        merchantName,
        merchantRules,
      );
      if (persistedRule != null && persistedRule.enabled) {
        suggestedCategory = persistedRule.categoryId;
        merchantRuleUsed = persistedRule.merchantName;
        merchantRuleSource = persistedRule.source;
      } else if (persistedRule == null &&
          builtinMerchantCategoryMap.containsKey(key)) {
        suggestedCategory = builtinMerchantCategoryMap[key];
        merchantRuleUsed = merchantName;
        merchantRuleSource = 'builtin';
      }
      if (_isInvalidMerchantCandidate(merchantName)) {
        merchantName = null;
        suggestedCategory = null;
        merchantRuleUsed = null;
        merchantRuleSource = null;
      }
    }

    // 5. Stage 6 — Confidence Scoring
    double confidence =
        ((amount != null ? 25 : 0) +
            (currency != null ? 15 : 0) +
            (type != 'unknown' ? 20 : 0) +
            (merchantName != null ? 25 : 0) +
            (merchantRuleSource != null ? 15 : 0)) /
        100;
    if (merchantRuleSource != null && confidence < 0.95) {
      confidence = 0.95;
    }

    // 6. Stage 7 — Description Generation
    String description = 'Captured message';
    if (type == 'expense') {
      if (merchantName != null) {
        if (merchantName.toLowerCase().contains('talabat')) {
          description = 'Talabat Purchase';
        } else if (merchantName.toLowerCase().contains('whoop')) {
          description = 'WHOOP Subscription';
        } else if (merchantName.toLowerCase().contains('toyou')) {
          description = 'ToYou Order';
        } else {
          description = 'Purchase at $merchantName';
        }
      } else {
        description = 'Expense Capture';
      }
    } else if (type == 'income') {
      if (merchantName != null) {
        description = 'Income from $merchantName';
      } else if (text.contains('salary') ||
          text.contains('راتب') ||
          text.contains('payroll')) {
        description = 'Salary Deposit';
      } else {
        description = 'Account Deposit';
      }
    } else if (type == 'transfer') {
      // Find transfer recipient if any (e.g. to Mohamed Elliethy)
      final RegExp toRecipientRegex = RegExp(
        r'\b(?:to|إلى)\s+([a-zA-Z\s\u0600-\u06FF]+)',
        caseSensitive: false,
      );
      final Match? recipientMatch = toRecipientRegex.firstMatch(text);
      if (recipientMatch != null) {
        final String name = _capitalizeWords(recipientMatch.group(1)!.trim());
        if (name.isNotEmpty &&
            !name.toLowerCase().contains('account') &&
            !name.toLowerCase().contains('card')) {
          description = 'Internal Transfer To $name';
        } else {
          description = 'Bank Transfer';
        }
      } else if (_hasMatch(text, [
        'تم إضافة مبلغ',
        'تم الإيداع',
        'deposit',
        'credited',
        'received',
        'incoming transfer',
        'تم تحويل إليك',
      ])) {
        description = 'Account Deposit';
      } else {
        description = 'Bank Transfer';
      }
    }

    return SmartCaptureParseResult(
      type: type,
      amount: amount,
      currency: currency,
      confidence: confidence,
      merchantName: merchantName,
      suggestedCategory: suggestedCategory,
      merchantRuleUsed: merchantRuleUsed,
      merchantRuleSource: merchantRuleSource,
      description: description,
    );
  }

  static const Map<String, String> builtinMerchantCategoryMap = {
    'talabat': 'Food & Dining',
    'toyou': 'Food & Dining',
    'hungerstation': 'Food & Dining',
    'jahez': 'Food & Dining',
    'amazon': 'Shopping',
    'noon': 'Shopping',
    'jarir': 'Shopping',
    'uber': 'Transportation',
    'careem': 'Transportation',
    'nile air': 'Travel',
    'flynas': 'Travel',
    'saudia': 'Travel',
    'fitness time': 'Healthcare',
    'whoop': 'Healthcare',
    'fitness plan': 'Healthcare',
    'stc': 'Utilities',
    'mobily': 'Utilities',
    'zain': 'Utilities',
    'tamimi market': 'Groceries',
  };

  static String normalizeMerchantName(String merchant) {
    final String normalized = merchant.toLowerCase().trim();
    if (normalized == 'talabat.com' ||
        normalized == 'talabat app' ||
        normalized == 'talabat maa' ||
        normalized == 'talabat pay' ||
        normalized == 'talabat mart' ||
        normalized.startsWith('talabat')) {
      return 'Talabat';
    }
    if (normalized.startsWith('amazon') ||
        normalized == 'amazon.sa' ||
        normalized == 'amazon.ae') {
      return 'Amazon';
    }
    if (normalized.startsWith('toyou')) {
      return 'ToYou';
    }
    if (normalized.startsWith('hungerstation')) {
      return 'HungerStation';
    }
    if (normalized.startsWith('jahez')) {
      return 'Jahez';
    }
    if (normalized.startsWith('noon')) {
      return 'Noon';
    }
    if (normalized.startsWith('jarir')) {
      return 'Jarir';
    }
    if (normalized.startsWith('uber')) {
      return 'Uber';
    }
    if (normalized.startsWith('careem')) {
      return 'Careem';
    }
    if (normalized.startsWith('e-finance') ||
        normalized.startsWith('efinance')) {
      return 'E-Finance';
    }
    if (normalized.startsWith('nile air')) {
      return 'Nile Air';
    }
    if (normalized.startsWith('flynas')) {
      return 'Flynas';
    }
    if (normalized.startsWith('saudia')) {
      return 'Saudia';
    }
    if (normalized.startsWith('fitness time')) {
      return 'Fitness Time';
    }
    if (normalized.startsWith('whoop')) {
      return 'WHOOP';
    }
    if (normalized.startsWith('fitness plan')) {
      return 'Fitness Plan';
    }
    if (normalized.startsWith('stc')) {
      return 'STC';
    }
    if (normalized.startsWith('mobily')) {
      return 'Mobily';
    }
    if (normalized.startsWith('zain')) {
      return 'Zain';
    }
    if (RegExp(r'^(?:s\d+\s+)?tamimi market').hasMatch(normalized)) {
      return 'Tamimi Market';
    }
    return _capitalizeWords(merchant);
  }

  static String _resolveAlias(
    String merchant,
    Map<String, String> merchantAliases,
  ) {
    final String key = merchant.toLowerCase().trim();
    return merchantAliases[key] ?? merchant;
  }

  static Iterable<String> aliasesForMerchant(String merchantName) sync* {
    final String normalized = normalizeMerchantName(merchantName).toLowerCase();
    for (final MapEntry<String, List<String>> entry
        in builtinMerchantAliases.entries) {
      if (entry.key == normalized) {
        yield* entry.value;
      }
    }
  }

  static const Map<String, List<String>> builtinMerchantAliases = {
    'talabat': <String>[
      'talabat',
      'talabat.com',
      'talabat app',
      'talabat maa',
      'talabat pay',
      'talabat mart',
      'طلبات',
    ],
    'amazon': <String>['amazon', 'amazon.sa', 'amazon.ae'],
    'toyou': <String>['toyou', 'toyou app'],
    'tamimi market': <String>[
      'tamimi market',
      's505 tamimi market',
      'al tamimi market',
    ],
  };

  static Map<String, String> _effectiveAliases(
    Map<String, MerchantRule> merchantRules,
    Map<String, String> merchantAliases,
  ) {
    final Map<String, String> aliases = <String, String>{};
    for (final MapEntry<String, List<String>> entry
        in builtinMerchantAliases.entries) {
      for (final String alias in entry.value) {
        aliases[alias.toLowerCase().trim()] = entry.key;
      }
    }
    aliases.addAll(
      merchantAliases.map(
        (String alias, String merchant) =>
            MapEntry(alias.toLowerCase().trim(), merchant),
      ),
    );
    for (final MerchantRule rule in merchantRules.values) {
      if (rule.builtinKey != null) {
        for (final String alias
            in builtinMerchantAliases[rule.builtinKey] ?? const <String>[]) {
          aliases[alias.toLowerCase().trim()] = rule.merchantName;
        }
      }
      for (final String alias in rule.aliases) {
        aliases[alias.toLowerCase().trim()] = rule.merchantName;
      }
    }
    return aliases;
  }

  static MerchantRule? _findPersistedRule(
    String merchantName,
    Map<String, MerchantRule> merchantRules,
  ) {
    final String key = merchantName.toLowerCase().trim();
    final MerchantRule? direct = merchantRules[key];
    if (direct != null) return direct;
    for (final MerchantRule rule in merchantRules.values) {
      if (rule.merchantName.toLowerCase().trim() == key) return rule;
    }
    return null;
  }

  static String? _merchantFromKnownAlias(
    String text,
    Map<String, String> aliases,
  ) {
    final List<String> orderedAliases = aliases.keys.toList()
      ..sort((String a, String b) => b.length.compareTo(a.length));
    final String searchText = _merchantSearchToken(text);
    for (final String alias in orderedAliases) {
      if (RegExp(
        '(?<![a-z0-9])${RegExp.escape(alias)}(?![a-z0-9])',
        caseSensitive: false,
      ).hasMatch(text)) {
        return _validatedMerchant(aliases[alias], aliases);
      }
      final String aliasToken = _merchantSearchToken(alias);
      if (aliasToken.isNotEmpty && searchText.contains(aliasToken)) {
        return _validatedMerchant(aliases[alias], aliases);
      }
    }
    return null;
  }

  static const Set<String> _merchantStopWords = <String>{
    'bank',
    'card',
    'payment',
    'purchase',
    'pos',
    'debit',
    'credit',
    'account',
    'balance',
    'amount',
    'merchant',
    'mobile',
    'by',
    'from',
    'at',
    'with',
    'cardholder',
    'transaction',
    'trans',
    'cash',
    'invoice',
    'receipt',
    'بطاقة',
    'الخصم',
    'المباشر',
    'رقم',
    'المتاح',
    'الرصيد',
    'الحساب',
    'اليوم',
    'الساعة',
    'عملية',
    'شراء',
    'دفع',
    'سداد',
    'تم',
    'من',
    'لدى',
    'عند',
    'في',
    'داخل',
    'المبلغ',
    'المستحق',
    'العملية',
  };

  static String? _merchantFromPriorityPatterns(
    String rawMessage,
    Map<String, String> aliases,
  ) {
    final List<String> lines = rawMessage
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'^\s*عند\s+([A-Za-z0-9*\-\s]+)', caseSensitive: false),
      RegExp(r'^\s*At\s*[:-]?\s*([A-Za-z0-9*\-\s]+)', caseSensitive: false),
      RegExp(
        r'^\s*Merchant\s*[:-]?\s*([A-Za-z0-9*\-\s]+)',
        caseSensitive: false,
      ),
    ];

    for (final String line in lines) {
      for (final RegExp pattern in patterns) {
        final Match? match = pattern.firstMatch(line);
        if (match == null) continue;
        final String? candidate = _validatedMerchant(match.group(1), aliases);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  static String _trimMerchantCandidate(String rawMerchant) {
    final List<String> tokens = rawMerchant
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    final List<String> kept = <String>[];
    for (final String token in tokens) {
      final String cleaned = token.trim();
      if (cleaned.isEmpty) continue;
      if (_isMerchantStopWord(cleaned)) break;
      kept.add(cleaned);
    }
    return kept.join(' ').trim();
  }

  static bool _isMerchantStopWord(String token) {
    final String normalized = _merchantSearchToken(token);
    if (normalized.isEmpty) return true;
    if (RegExp(r'^\d+(?:[\/\-:]\d+)*$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) return true;
    return _merchantStopWords.contains(normalized);
  }

  static bool _isInvalidMerchantCandidate(String merchant) {
    final String normalized = merchant.toLowerCase().trim();
    final String searchToken = _merchantSearchToken(merchant);
    const Set<String> invalidExact = <String>{
      'account',
      'bank',
      'balance',
      'amount',
      'card',
      'merchant',
      'payment',
      'purchase',
      'pos',
      'debit',
      'credit',
      'cash',
      'transfer',
      'expense',
      'income',
      'بطاقة',
      'حساب',
      'الرصيد',
      'مبلغ',
      'عملية',
      'شراء',
      'دفع',
      'سداد',
      'رقم',
      'المتاح',
      'المباشر',
      'الخصم',
      'إلى',
      'الى',
      'من',
      'لدى',
      'عند',
      'في',
      'داخل',
    };
    if (invalidExact.contains(normalized) ||
        invalidExact.contains(searchToken)) {
      return true;
    }
    if (searchToken.contains('حساب') ||
        searchToken.contains('account') ||
        searchToken.contains('card') ||
        searchToken.contains('بطاقة') ||
        searchToken.contains('الرصيد') ||
        searchToken.contains('balance') ||
        searchToken.contains('amount') ||
        searchToken.contains('مبلغ') ||
        searchToken.contains('رقم')) {
      return true;
    }
    return false;
  }

  static String? _validatedMerchant(
    String? rawMerchant,
    Map<String, String> aliases,
  ) {
    if (rawMerchant == null) return null;
    String clean = _trimMerchantCandidate(rawMerchant)
        .split(RegExp(r'\r?\n'))
        .first
        .trim()
        .replaceFirst(
          RegExp(
            r'^(?:purchase|pos purchase|pos|payment|spent|withdrawal|debit|شراء|عملية شراء|سداد|خصم|دفع|transfer|تحويل|حوالة|تم|وارد|merchant|at|from|من|لدى|عند)\s*[:\-]?\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'\s+(?:sar|egp|usd|aed|ريال|جنيه|درهم|ر\.س|ج\.م)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    clean = _resolveAlias(clean, aliases);
    final String normalized = normalizeMerchantName(clean);
    final String key = normalized.toLowerCase().trim();
    const Set<String> blacklist = <String>{
      'sa',
      'ksa',
      'uae',
      'eg',
      'sar',
      'egp',
      'usd',
      'aed',
      'eur',
      'gbp',
      'ريال',
      'جنيه',
      'درهم',
      'dollar',
      'apple pay',
      'applepay',
      'mada',
      'مدى',
      'visa',
      'mastercard',
      'stc pay',
      'stcpay',
      'urpay',
      'ur pay',
      'hsbc',
      'cib',
      'alrajhi',
      'al rajhi',
      'ahli',
      'al ahli',
      'bank',
      'purchase',
      'pos purchase',
      'pos',
      'payment',
      'spent',
      'withdrawal',
      'debit',
      'شراء',
      'عملية شراء',
      'سداد',
      'خصم',
      'دفع',
      'amount',
      'مبلغ',
    };
    if (clean.isEmpty ||
        key.length <= 2 ||
        blacklist.contains(key) ||
        RegExp(r'^[\d\s\.,]+$').hasMatch(key) ||
        RegExp(r'^(?:في|داخل|الدولة|country)\s*:').hasMatch(key)) {
      return null;
    }
    return normalized;
  }

  static String _merchantSearchToken(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
  }

  static bool _hasMatch(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static String? _normalizeCurrency(String? raw) {
    if (raw == null) return null;
    final String clean = raw
        .trim()
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(' ', '');
    if (clean == 'sar' ||
        clean == 'sr' ||
        clean == 's.r' ||
        clean == 'ريال' ||
        clean == 'ریال' ||
        clean == 'رس') {
      return 'SAR';
    }
    if (clean == 'egp' || clean == 'جنيه' || clean == 'جم') {
      return 'EGP';
    }
    if (clean == 'usd' || clean == '\$') {
      return 'USD';
    }
    if (clean == 'aed' || clean == 'درهم') {
      return 'AED';
    }
    return raw.toUpperCase();
  }

  static String _capitalizeWords(String str) {
    if (str.isEmpty) return str;
    return str
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
