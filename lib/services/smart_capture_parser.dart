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
    this.paymentMethod,
    this.cardReference,
    this.accountReference,
    this.senderName,
    this.recipientName,
    this.direction,
    this.balance,
    this.remainingAmount,
    this.capturedAt,
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
  final String? paymentMethod;
  final String? cardReference;
  final String? accountReference;
  final String? senderName;
  final String? recipientName;
  final String? direction;
  final double? balance;
  final double? remainingAmount;
  final DateTime? capturedAt;
  final bool isValid;
}

class _AmountCandidate {
  const _AmountCandidate({
    required this.amount,
    required this.score,
    this.currency,
  });

  final double amount;
  final String? currency;
  final double score;
}

class _IntentLabel {
  const _IntentLabel({required this.regex, required this.merchant});

  final RegExp regex;
  final String merchant;
}

class _TransferDetails {
  const _TransferDetails({
    required this.direction,
    this.senderName,
    this.recipientName,
    required this.isTransferMessage,
  });

  final String direction;
  final String? senderName;
  final String? recipientName;
  final bool isTransferMessage;
}

class SmartCaptureParser {
  SmartCaptureParser._();

  static SmartCaptureParseResult parse(
    String rawMessage, {
    Map<String, MerchantRule> merchantRules = const <String, MerchantRule>{},
    Map<String, String> merchantAliases = const <String, String>{},
    String? currentUserName,
  }) {
    final String text = rawMessage.toLowerCase();

    // 0. Stage 0 — Transaction Status & Exclusions Detection
    final bool isSubscriptionActivationMessage =
        _isSubscriptionActivationMessage(text);
    if (isSubscriptionActivationMessage) {
      return const SmartCaptureParseResult(
        type: 'unknown',
        amount: null,
        currency: null,
        confidence: 0.0,
        merchantName: null,
        description: 'Subscription Activation Message',
        ignoreReason: 'Subscription Activation Message',
        isValid: false,
      );
    }

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
      'decline',
      'rejected',
      'reject',
      'failed',
      'failure',
      'unsuccessful',
      'not approved',
      'not authorized',
      'not authorised',
      'authorization failed',
      'authorisation failed',
      'authorization declined',
      'authorisation declined',
      'authorization rejected',
      'authorisation rejected',
      'payment declined',
      'transaction declined',
      'card declined',
      'unable to process',
      'unable to complete',
      'could not be completed',
      'cannot be completed',
      'could not process',
      'not completed',
      'failed to process',
      'cancelled',
      'timeout',
      'expired',
      'blocked',
      'insufficient funds',
      'مرفوضة',
      'مرفوض',
      'رفض',
      'تم الرفض',
      'عملية مرفوضة',
      'تم رفض العملية',
      'فشلت',
      'فشل',
      'فشل الدفع',
      'فشل العملية',
      'غير مكتملة',
      'تم الإلغاء',
      'ألغيت',
      'غير ناجحة',
      'الرصيد غير كاف',
      'غير مصرح',
      'غير مصرح به',
      'تعذر',
      'تعذرت',
      'لم تتم الموافقة',
      'لم يتم الموافقة',
      'لم يتم إتمام العملية',
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

    final bool isAccountDepositMessage = _isAccountDepositMessage(text);
    final bool isWalletTopUp =
        _isWalletTopUpMessage(text) &&
        _hasMatch(text, ['apple pay', 'applepay']);

    // 1. Stage 2 — Transaction Type Classification (Strict Precedence)
    // Check explicit Expense Overrides first
    final bool isExpenseOverride =
        !isWalletTopUp &&
        _hasMatch(text, [
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
    final _TransferDetails transferDetails = _extractTransferDetails(
      rawMessage,
      currentUserName: currentUserName,
    );

    final bool hasTransferKeywords = _hasMatch(text, [
      'transfer',
      'remittance',
      'bank transfer',
      'تحويل',
      'حوالة',
    ]);

    final bool isInternalTransfer =
        _hasMatch(text, [
          'internal transfer',
          'transfer between accounts',
          'account transfer',
          'تحويل داخلي',
          'تحويل بين الحسابات',
          'بين حساباتي',
          'between accounts',
          'between my accounts',
        ]) ||
        (_hasMatch(text, [
              'from account',
              'to account',
              'من حساب',
              'إلى حساب',
            ]) &&
            !hasTransferKeywords);

    final String transferDirection =
        isWalletTopUp && transferDetails.direction == 'unknown'
        ? 'out'
        : transferDetails.direction;
    final bool isOutgoingTransfer = transferDirection == 'out';
    final bool isIncomingTransfer = transferDirection == 'in';

    // Income (including local inbound transfers and refunds)
    final bool isIncome =
        !isAccountDepositMessage &&
        (isIncomingTransfer ||
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
              'تم الايداع',
              'تم إضافة مبلغ',
              'تم اضافة مبلغ',
              'حوالة واردة',
              'تحويل وارد',
              'راتب',
              'تم استلام',
              'تم تحويل إليك',
              'تم تحويل اليك',
              'تم إضافة',
              'تم اضافة',
              'added',
              'ايداع',
              'إيداع',
              'إيداع نقدي',
              'ايداع نقدي',
              'كاش باك',
            ])));

    final bool isExpense =
        !isInternalTransfer &&
        (isOutgoingTransfer || (!hasTransferKeywords && !isIncome)) &&
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
    if (isInternalTransfer) {
      type = 'expense';
    } else if (isAccountDepositMessage) {
      type = 'expense';
    } else if (isWalletTopUp) {
      type = 'expense';
    } else if (isOutgoingTransfer) {
      type = 'expense';
    } else if (isIncomingTransfer) {
      type = 'income';
    } else if (isIncome) {
      type = 'income';
    } else if (isExpense) {
      type = 'expense';
    } else if (hasTransferKeywords) {
      type = 'unknown';
    }
    if (_hasMatch(text, ['تم سداد البطاقة الائتمانية'])) {
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
      RegExp(r'(?:account|رقم\s*الحساب|لحسابكم|حسابكم|حساب)(?:\s*رقم)?[\s:\-*]*\d+', caseSensitive: false),
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

    final _AmountCandidate? explicitCandidate = _selectExplicitAmountCandidate(
      scrubbed,
    );
    if (explicitCandidate != null) {
      amount = explicitCandidate.amount;
      currency = explicitCandidate.currency;
    }

    // Find all numbers in the scrubbed text
    final RegExp numberRegex = RegExp(r'\b([0-9,]+(?:\.[0-9]+)?)\b');
    final List<Match> numberMatches = numberRegex.allMatches(scrubbed).toList();

    double bestScore = -9999.0;
    int selectedPriority = 99;

    if (amount == null) {
      for (final Match m in numberMatches) {
        final String rawNumStr = m.group(1) ?? '';
        final double val =
            double.tryParse(rawNumStr.replaceAll(',', '')) ?? 0.0;
        if (val == 0.0) continue;

        // Skip obvious date fragments once we have a better amount candidate.
        if (val < 100 &&
            _looksLikeDateNumberCandidate(scrubbed, m.start, m.end, val)) {
          continue;
        }

        final int start = m.start;
        final int end = m.end;

        // Limit context to the same line to avoid crossing boundaries
        final int lineStart = scrubbed.lastIndexOf('\n', start);
        final int limitBefore = lineStart == -1 ? 0 : lineStart;
        final int lineEnd = scrubbed.indexOf('\n', end);
        final int limitAfter = lineEnd == -1 ? scrubbed.length : lineEnd;
        final String lineContext = scrubbed
            .substring(limitBefore, limitAfter)
            .toLowerCase();
        final String amountContext = scrubbed
            .substring(
              start - 18 >= limitBefore ? start - 18 : limitBefore,
              end + 18 <= limitAfter ? end + 18 : limitAfter,
            )
            .toLowerCase();
        final String contextBefore = scrubbed.substring(
          start - 25 >= limitBefore ? start - 25 : limitBefore,
          start,
        );
        final String contextAfter = scrubbed.substring(
          end,
          end + 25 <= limitAfter ? end + 25 : limitAfter,
        );

        // Check for Ignored Financial Fields (Priority 5 must NEVER win)
        final bool isIgnored = _hasMatch(amountContext, [
          'الرصيد',
          'رصيدك الحالي',
          'حد الصرف',
          'حد الصرف المتبقي',
          'remaining amount',
          'remaining limit',
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

        if (_hasMatch(amountContext, [
              'total due',
              'total charged',
              'إجمالي المبلغ المستحق',
              'المبلغ النهائي',
              'إجمالي المبلغ',
            ]) ||
            _hasMatch(lineContext, [
              'total due',
              'total charged',
              'إجمالي المبلغ المستحق',
              'المبلغ النهائي',
              'إجمالي المبلغ',
            ])) {
          priority = 1;
          score = 10000.0;
        } else if (_hasMatch(amountContext, [
              'charged amount',
              'المبلغ المطلوب',
              'total charged amount',
            ]) ||
            _hasMatch(lineContext, [
              'charged amount',
              'المبلغ المطلوب',
              'total charged amount',
            ])) {
          priority = 2;
          score = 8000.0;
        } else if (_hasMatch(amountContext, [
              'مبلغ',
              'amount',
              'amt',
              'value',
              'بقيمة',
              'بقيمه',
              'purchase amount',
              'transaction amount',
            ]) ||
            _hasMatch(lineContext, [
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
        } else if (_hasMatch(amountContext, [
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
            _hasMatch(lineContext, [
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
        } else if (_hasMatch(amountContext, [
              'fee',
              'fees',
              'رسوم',
              'رسوم العملية',
            ]) ||
            _hasMatch(lineContext, ['fee', 'fees', 'رسوم', 'رسوم العملية'])) {
          priority = 4;
          score = 4000.0;
        } else if (_hasMatch(amountContext, [
              'balance',
              'remaining',
              'spending limit',
              'remaining amount',
              'remaining limit',
            ]) ||
            _hasMatch(lineContext, [
              'balance',
              'remaining',
              'spending limit',
              'remaining amount',
              'remaining limit',
            ])) {
          priority = 5;
          score = 2000.0;
        }

        // Check for nearby currency inside the context windows
        String? localCurrency;
        final String fullContext = '$contextBefore $contextAfter';
        final RegExp curFinder = RegExp(
          r'(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم)',
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
    }

    // Fallback general currency finder in the entire message if not found near the best amount
    if (currency == null) {
      final RegExp currencyFinder = RegExp(
        r'(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم)',
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
    final bool hasPurchaseIntent = _hasMatch(text, [
      'purchase',
      'online purchase',
      'pos',
      'point of sale',
      'apple pay',
      'mada',
      'visa purchase',
      'mastercard purchase',
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
    final String? intentMerchant = _merchantFromIntentLabel(rawMessage);
    String? merchantName;
    if (intentMerchant != null) {
      merchantName = normalizeMerchantName(intentMerchant);
    } else {
      final String? inlineMerchant = _merchantFromInlinePatterns(
        rawMessage,
        effectiveAliases,
      );
      if (inlineMerchant != null) {
        merchantName = inlineMerchant;
      } else if (transferDetails.direction == 'out') {
        merchantName = transferDetails.recipientName == null
            ? null
            : _resolveAlias(transferDetails.recipientName!, effectiveAliases);
      } else if (transferDetails.direction == 'in') {
        merchantName = transferDetails.senderName == null
            ? null
            : _resolveAlias(transferDetails.senderName!, effectiveAliases);
      } else if (!transferDetails.isTransferMessage &&
          !isWalletTopUp &&
          !isAccountDepositMessage) {
        merchantName ??= _merchantFromTransactionField(
          rawMessage,
          effectiveAliases,
          hasPurchaseIntent: hasPurchaseIntent,
        );
        merchantName ??= _merchantFromPriorityPatterns(
          rawMessage,
          effectiveAliases,
        );

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
            if (RegExp(
              r'^(?:to|إلى|الى)\s*:',
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
                RegExp(
                  r'^\s*(?:from|من)\s*[:\-]?\s*\d+\s*$',
                  caseSensitive: false,
                ).hasMatch(lineLower) ||
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

        // A known alias can identify a merchant even when a bank uses no label.
        merchantName ??= _merchantFromKnownAlias(text, effectiveAliases);
      }
    }

    if (isAccountDepositMessage) {
      merchantName = null;
    }

    final bool isTransferMessage =
        type == 'transfer' ||
        isInternalTransfer;
    if (isTransferMessage && !isWalletTopUp) {
      merchantName = null;
    }

    final DateTime? capturedAt = _extractCapturedAt(rawMessage);
    final String? paymentMethod = _extractPaymentMethod(rawMessage);
    final String? cardReference = _extractCardReference(rawMessage);
    final String? senderName = transferDetails.senderName;
    final String? recipientName = transferDetails.recipientName;
    final String direction = transferDirection;
    final String? accountReference = _extractLabeledValue(rawMessage, <RegExp>[
      RegExp(
        r'^\s*(?:account|حساب)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
        multiLine: true,
      ),
      RegExp(
        r'^\s*(?:from|من)\s*[:\-]?\s*(\d+)\s*$',
        caseSensitive: false,
        multiLine: true,
      ),
    ]);
    final double? balance = _extractLabeledAmount(rawMessage, <RegExp>[
      RegExp(
        r'^\s*(?:current balance|wallet balance|available balance|balance|الرصيد)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
        multiLine: true,
      ),
    ]);
    final double? remainingAmount = _extractLabeledAmount(rawMessage, <RegExp>[
      RegExp(
        r'^\s*(?:remaining amount|remaining balance|حد الصرف المتبقي|remaining limit|حد الصرف)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
        multiLine: true,
      ),
    ]);

    String? suggestedCategory;
    String? merchantRuleUsed;
    String? merchantRuleSource;
    if (merchantName != null) {
      final String key = merchantName.toLowerCase().trim();
      final MerchantRule? persistedRule = _findPersistedRule(
        merchantName,
        merchantRules,
      );
      if (persistedRule != null &&
          persistedRule.enabled &&
          _ruleAppliesToType(
            ruleType: persistedRule.defaultType,
            parsedType: type,
          )) {
        suggestedCategory = persistedRule.categoryId;
        merchantRuleUsed = persistedRule.merchantName;
        merchantRuleSource = persistedRule.source;
      } else if (persistedRule == null &&
          builtinMerchantCategoryMap.containsKey(key)) {
        final String builtinType = 'expense';
        if (_ruleAppliesToType(ruleType: builtinType, parsedType: type)) {
          suggestedCategory = builtinMerchantCategoryMap[key];
          merchantRuleUsed = merchantName;
          merchantRuleSource = 'builtin';
        }
      }
      final bool merchantFromIntent = intentMerchant != null;
      if (!merchantFromIntent && _isInvalidMerchantCandidate(merchantName)) {
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
    if (isAccountDepositMessage) {
      description = 'Account Deposit';
    } else if (isWalletTopUp ||
        isInternalTransfer ||
        type == 'transfer' ||
        transferDetails.isTransferMessage) {
      if (isWalletTopUp) {
        description = 'Wallet Top Up';
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
    } else if (type == 'expense') {
      if (direction == 'out') {
        description = merchantName != null
            ? 'Transfer to $merchantName'
            : 'Outgoing Transfer';
      } else if (merchantName != null) {
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
      if (direction == 'in') {
        description = merchantName != null
            ? 'Transfer from $merchantName'
            : 'Incoming Transfer';
      } else if (merchantName != null) {
        description = 'Income from $merchantName';
      } else if (text.contains('salary') ||
          text.contains('راتب') ||
          text.contains('payroll')) {
        description = 'Salary Deposit';
      } else {
        description = 'Account Deposit';
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
      paymentMethod: paymentMethod,
      cardReference: cardReference,
      accountReference: accountReference,
      senderName: senderName,
      recipientName: recipientName,
      direction: direction,
      balance: balance,
      remainingAmount: remainingAmount,
      capturedAt: capturedAt,
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
    'stc': 'Internet & Phone',
    'mobily': 'Internet & Phone',
    'zain': 'Internet & Phone',
    'vodafone': 'Internet & Phone',
    'etisalat': 'Internet & Phone',
    'orange': 'Internet & Phone',
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
    if (normalized.startsWith('stc pay')) {
      return 'STC Pay';
    }
    if (normalized.startsWith('stc')) {
      return 'STC';
    }
    if (normalized.startsWith('mobily pay')) {
      return 'Mobily Pay';
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
      if (!rule.enabled) continue;
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
      if (rule.merchantName.toLowerCase().trim() == key) {
        return rule;
      }
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
    'يوم',
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
      RegExp(
        r'^\s*عند\s+([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})',
        caseSensitive: false,
      ),
      RegExp(
        r'^\s*At\s*[:-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})',
        caseSensitive: false,
      ),
      RegExp(
        r'^\s*Merchant\s*[:-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})',
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

  static String? _merchantFromInlinePatterns(
    String rawMessage,
    Map<String, String> aliases,
  ) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r'(?:(?<![A-Za-z0-9])(?:at|merchant|store)(?![A-Za-z0-9])|(?<![\u0600-\u06FF0-9])(?:لدى|عند|في)(?![\u0600-\u06FF0-9]))\s*[:\-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})',
        caseSensitive: false,
      ),
    ];
    for (final RegExp pattern in patterns) {
      final Match? match = pattern.firstMatch(rawMessage);
      if (match == null) continue;
      final String? candidate = _validatedMerchant(match.group(1), aliases);
      if (candidate != null) {
        return candidate;
      }
    }
    return null;
  }

  static _TransferDetails _extractTransferDetails(
    String rawMessage, {
    String? currentUserName,
  }) {
    final List<String> lines = rawMessage
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    String? senderName = _extractTransferParty(lines, <String>[
      'sender',
      'from account',
      'from',
      'المرسل',
      'مرسل',
      'من حساب',
      'من',
    ]);
    String? recipientName = _extractTransferParty(lines, <String>[
      'to account',
      'to',
      'recipient',
      'beneficiary',
      'المستفيد',
      'إلى حساب',
      'إلى',
      'الى',
    ]);

    if (senderName == null) {
      final Match? match = RegExp(
        r'(?:\bfrom\b|من)\s+([A-Za-z\u0600-\u06FF\*\s]{2,80})',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (match != null) {
        final String candidate = match.group(1)?.trim() ?? '';
        if (candidate.isNotEmpty && !_isTransferPartyNoise(candidate)) {
          senderName = _trimMerchantCandidate(candidate);
          if (senderName.isEmpty) senderName = null;
        }
      }
    }
    if (recipientName == null) {
      final Match? match = RegExp(
        r'(?:\bto\b|إلى|الى)\s+([A-Za-z\u0600-\u06FF\*\s]{2,80})',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      if (match != null) {
        final String candidate = match.group(1)?.trim() ?? '';
        if (candidate.isNotEmpty && !_isTransferPartyNoise(candidate)) {
          recipientName = _trimMerchantCandidate(candidate);
          if (recipientName.isEmpty) recipientName = null;
        }
      }
    }

    final bool hasExplicitTransferPartyLabels =
        _hasMatch(rawMessage.toLowerCase(), <String>[
          'sender:',
          'recipient:',
          'beneficiary:',
          'from account',
          'to account',
          'المرسل',
          'مرسل',
          'المستفيد',
          'من حساب',
          'إلى حساب',
        ]);
    final bool hasTransferKeywords = _hasMatch(
      rawMessage.toLowerCase(),
      <String>['transfer', 'remittance', 'bank transfer', 'تحويل', 'حوالة', 'واردة', 'وارد', 'صادرة', 'صادر'],
    );
    final bool isInternalTransfer =
        _hasMatch(rawMessage.toLowerCase(), <String>[
          'internal transfer',
          'transfer between accounts',
          'account transfer',
          'تحويل داخلي',
          'تحويل بين الحسابات',
          'بين حساباتي',
          'between accounts',
          'between my accounts',
        ]) ||
        (_hasMatch(rawMessage.toLowerCase(), <String>[
              'from account',
              'to account',
              'من حساب',
              'إلى حساب',
            ]) &&
            (_looksLikeOwnAccountReference(senderName) ||
                _looksLikeOwnAccountReference(recipientName)));
    final bool isTransferMessage =
        hasTransferKeywords ||
        hasExplicitTransferPartyLabels ||
        isInternalTransfer;
    final String direction = isTransferMessage
        ? _transferDirection(
            rawMessage,
            senderName: senderName,
            recipientName: recipientName,
            currentUserName: currentUserName,
            isInternalTransfer: isInternalTransfer,
          )
        : 'unknown';
    return _TransferDetails(
      direction: direction,
      senderName: senderName,
      recipientName: recipientName,
      isTransferMessage: isTransferMessage,
    );
  }

  static bool _ruleAppliesToType({
    required String ruleType,
    required String parsedType,
  }) {
    final String normalizedRuleType = ruleType.trim().toLowerCase();
    final String normalizedParsedType = parsedType.trim().toLowerCase();
    if (normalizedParsedType.isEmpty || normalizedParsedType == 'unknown') {
      return true;
    }
    if (normalizedRuleType.isEmpty || normalizedRuleType == 'unknown') {
      return true;
    }
    return normalizedRuleType == normalizedParsedType;
  }

  static String? _extractTransferParty(
    List<String> lines,
    List<String> labels,
  ) {
    for (final String line in lines) {
      for (final String label in labels) {
        final Match? match = RegExp(
          '^\\s*${RegExp.escape(label)}\\s*[:\\-]?\\s*(.+)\$',
          caseSensitive: false,
        ).firstMatch(line);
        if (match == null) continue;
        final String? candidate = match.group(1)?.trim();
        if (candidate == null || candidate.isEmpty) continue;
        if (_isTransferPartyNoise(candidate)) continue;
        return candidate;
      }
    }
    return null;
  }

  static bool _isTransferPartyNoise(String value) {
    final String lower = value.toLowerCase().trim();
    return _hasMatch(lower, <String>[
          'balance',
          'الرصيد',
          'amount',
          'مبلغ',
          'account',
          'حساب',
          'card',
          'بطاقة',
          'visa',
          'mastercard',
          'apple pay',
          'mada',
          'stc pay',
          'stcpay',
        ]) ||
        RegExp(r'^\d+$').hasMatch(lower);
  }

  static bool _looksLikeOwnAccountReference(String? value) {
    if (value == null) return false;
    final String lower = value.toLowerCase().trim();
    return _hasMatch(lower, <String>['account', 'حساب', 'card', 'بطاقة']) ||
        RegExp(r'^\*+\d+$').hasMatch(lower) ||
        RegExp(r'^\d+$').hasMatch(lower);
  }

  static String _transferDirection(
    String rawMessage, {
    String? senderName,
    String? recipientName,
    String? currentUserName,
    required bool isInternalTransfer,
  }) {
    if (isInternalTransfer) return 'internal';

    final String lower = rawMessage.toLowerCase();
    final String? normalizedUser = currentUserName == null
        ? null
        : _merchantSearchToken(currentUserName);
    final String? normalizedSender = senderName == null
        ? null
        : _merchantSearchToken(senderName);
    final String? normalizedRecipient = recipientName == null
        ? null
        : _merchantSearchToken(recipientName);

    if (normalizedUser != null) {
      if (normalizedSender != null && normalizedSender == normalizedUser) {
        return 'out';
      }
      if (normalizedRecipient != null &&
          normalizedRecipient == normalizedUser) {
        return 'in';
      }
    }

    if (_hasMatch(lower, <String>[
      'debit transfer intl',
      'debit transfer',
      'transfer sent',
      'paid to',
      'sent to',
      'outgoing transfer',
      'خصم',
      'سحب',
      'دفع',
      'تحويل صادر',
      'حوالة صادرة',
      'حوالة صادر',
      'صادرة',
      'صادر',
      'تم التحويل إلى',
      'تم تنفيذ تحويل',
      'من حسابكم',
      'تحويل لحظي من',
    ])) {
      return 'out';
    }

    if (_hasMatch(lower, <String>[
      'credit transfer',
      'transfer received',
      'received from',
      'transfer from',
      'incoming transfer',
      'إيداع',
      'تحويل وارد',
      'حوالة واردة',
      'حوالة وارد',
      'واردة',
      'وارد',
      'تم استلام تحويل من',
      'تم الإيداع',
      'تم استلام',
      'credited',
      'received',
      'تم إضافة تحويل',
      'تم اضافة تحويل',
      'تحويل لحظي لحسابكم',
      'تحويل لحسابكم',
      'تم إضافة',
      'تم اضافة',
    ])) {
      return 'in';
    }

    return 'unknown';
  }

  static String? _merchantFromTransactionField(
    String rawMessage,
    Map<String, String> aliases, {
    required bool hasPurchaseIntent,
  }) {
    final List<String> lines = rawMessage
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    if (hasPurchaseIntent) {
      final String? purchaseMerchant = _merchantFromFieldLines(
        lines,
        aliases,
        labels: <String>['من', 'from', 'at', 'merchant', 'store', 'لدى', 'عند'],
      );
      if (purchaseMerchant != null) {
        return purchaseMerchant;
      }
    }

    final String? fallbackField = _merchantFromFieldLines(
      lines,
      aliases,
      labels: <String>['merchant', 'store', 'at'],
    );
    if (fallbackField != null) {
      return fallbackField;
    }

    if (_hasMatch(rawMessage.toLowerCase(), <String>[
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
    ])) {
      return _merchantFromFieldLines(
        lines,
        aliases,
        labels: <String>['from', 'من', 'لدى', 'عند'],
      );
    }

    return null;
  }

  static String? _merchantFromFieldLines(
    List<String> lines,
    Map<String, String> aliases, {
    required List<String> labels,
  }) {
    for (final String line in lines) {
      for (final String label in labels) {
        final Match? match = RegExp(
          '^\\s*${RegExp.escape(label)}\\s*[:\\-]?\\s*(.+)\$',
          caseSensitive: false,
        ).firstMatch(line);
        if (match == null) continue;
        final String? candidate = _validatedMerchant(match.group(1), aliases);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  static String? _merchantFromIntentLabel(String rawMessage) {
    final String lower = rawMessage.toLowerCase();
    final List<_IntentLabel> labels = <_IntentLabel>[
      _IntentLabel(
        regex: RegExp(
          r'credit\s*card\s*:\s*payment',
          caseSensitive: false,
          multiLine: true,
        ),
        merchant: 'Credit Card Payment',
      ),
      _IntentLabel(
        regex: RegExp(
          r'debit\s*:\s*loan\s+instalment',
          caseSensitive: false,
          multiLine: true,
        ),
        merchant: 'Loan Instalment',
      ),
      _IntentLabel(
        regex: RegExp(
          r'تم\s+سداد\s+البطاقة\s+الائتمانية',
          caseSensitive: false,
          multiLine: true,
        ),
        merchant: 'سداد البطاقة الائتمانية',
      ),
    ];
    for (final _IntentLabel label in labels) {
      if (label.regex.hasMatch(lower)) {
        return label.merchant;
      }
    }
    return null;
  }

  static String? _extractPaymentMethod(String rawMessage) {
    final Match? found = RegExp(
      r'\b(apple pay|mada|visa|mastercard|stc pay|stcpay)\b',
      caseSensitive: false,
    ).firstMatch(rawMessage);
    if (found == null) return null;
    return _capitalizeWords(
      found.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' '),
    );
  }

  static bool _isWalletTopUpMessage(String text) {
    return _hasMatch(text, <String>[
      'wallet top up',
      'wallet top-up',
      'wallet topup',
      'top up wallet',
      'top-up wallet',
      'topup wallet',
      'wallet recharge',
      'recharge wallet',
      'wallet reload',
      'load wallet',
      'wallet load',
      'wallet refill',
      'add money to wallet',
      'add funds to wallet',
      'fund wallet',
      'wallet funding',
      'account funding',
      'funding via apple pay',
      'wallet deposit',
      'deposit to wallet',
      'cash in wallet',
      'wallet cash in',
      'شحن المحفظة',
      'شحن رصيد المحفظة',
      'شحن المحفظه',
      'شحن رصيد المحفظه',
      'تعبئة المحفظة',
      'تعبئة المحفظه',
      'إعادة شحن المحفظة',
      'اعادة شحن المحفظة',
      'إعادة شحن المحفظه',
      'اعادة شحن المحفظه',
      'إضافة رصيد للمحفظة',
      'اضافة رصيد للمحفظة',
      'إضافة رصيد للمحفظه',
      'اضافة رصيد للمحفظه',
      'إيداع في المحفظة',
      'إيداع في المحفظه',
      'إضافة إلى المحفظة',
      'اضافة إلى المحفظة',
      'إضافة الى المحفظة',
      'اضافة الى المحفظة',
      'تم شحن المحفظة',
      'تم شحن المحفظه',
      'تم تعبئة المحفظة',
      'تم تعبئة المحفظه',
      'تمويل المحفظة',
      'تمويل المحفظه',
      'تمويل الحساب',
      'تم تعبئة الحساب',
      'شحن الحساب',
      'إضافة رصيد للحساب',
      'اضافة رصيد للحساب',
    ]);
  }

  static String? _extractLabeledValue(
    String rawMessage,
    List<RegExp> patterns,
  ) {
    for (final RegExp pattern in patterns) {
      final Match? match = pattern.firstMatch(rawMessage);
      if (match == null) continue;
      final String? candidate = match.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  static String? _extractCardReference(String rawMessage) {
    final List<String> lines = rawMessage
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r'(?:^|\s)(?:البطاقة\s+الائتمانية|بطاقة\s+ائتمانية)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'(?:^|\s)بطاقة\s*[:\-]?\s*(.+)$', caseSensitive: false),
      RegExp(
        r'(?:^|\s)(?:card|visa|mastercard)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final String line in lines) {
      final String lower = line.toLowerCase();
      if (_hasMatch(lower, <String>[
        'credit card:payment',
        'debit: loan instalment',
      ])) {
        continue;
      }
      for (final RegExp pattern in patterns) {
        final Match? match = pattern.firstMatch(line);
        if (match == null) continue;
        final String candidate = match.group(1)?.trim() ?? '';
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }
    return null;
  }

  static double? _extractLabeledAmount(
    String rawMessage,
    List<RegExp> patterns,
  ) {
    final RegExp amountRegex = RegExp(r'([0-9,]+(?:\.[0-9]+)?)');
    for (final RegExp pattern in patterns) {
      final Match? match = pattern.firstMatch(rawMessage);
      if (match == null) continue;
      final String? value = match.group(1);
      if (value == null) continue;
      final Match? amountMatch = amountRegex.firstMatch(value);
      if (amountMatch == null) continue;
      final double? parsed = double.tryParse(
        amountMatch.group(1)!.replaceAll(',', ''),
      );
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static DateTime? _extractCapturedAt(String rawMessage) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r'(\d{4}-\d{2}-\d{2})\s+(\d{1,2}:\d{2}(?:\s*[ap]m)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{4}-\d{2}-\d{2})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,2}:\d{2}(?:\s*[ap]m)?)\s+(\d{4}-\d{2}-\d{2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?)\s+at\s+(\d{4}-\d{2}-\d{2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(?:at\s+)?(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?)\s+(?:at\s+)?(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        caseSensitive: false,
      ),
    ];
    for (final RegExp pattern in patterns) {
      final Match? match = pattern.firstMatch(rawMessage);
      if (match == null) continue;
      final String first = match.group(1) ?? '';
      final String second = match.group(2) ?? '';
      final DateTime? date = _looksLikeDateToken(first)
          ? _parseDateToken(first)
          : _parseDateToken(second);
      final DateTime? time = _looksLikeDateToken(first)
          ? _parseTimeToken(second)
          : _parseTimeToken(first);
      if (date != null && time != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          time.second,
        );
      }
    }
    return null;
  }

  static bool _looksLikeDateToken(String value) {
    return RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$').hasMatch(value) ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  static DateTime? _parseDateToken(String value) {
    final String trimmed = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      final List<String> parts = trimmed.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    final Match? match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(trimmed);
    if (match == null) return null;
    final int first = int.parse(match.group(1)!);
    final int second = int.parse(match.group(2)!);
    int year = int.parse(match.group(3)!);
    if (year < 100) {
      year += 2000;
    }
    final bool monthFirst = first <= 12 && second > 12;
    final int month = monthFirst ? first : second;
    final int day = monthFirst ? second : first;
    return DateTime(year, month, day);
  }

  static DateTime? _parseTimeToken(String value) {
    final Match? match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([ap]m))?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final int second = int.parse(match.group(3) ?? '0');
    final String? meridiem = match.group(4)?.toLowerCase();
    if (meridiem == 'pm' && hour < 12) {
      hour += 12;
    } else if (meridiem == 'am' && hour == 12) {
      hour = 0;
    }
    return DateTime(1970, 1, 1, hour, minute, second);
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
    if (normalized.isEmpty) return false;
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
        searchToken.contains('بطاقة') ||
        searchToken.startsWith('visa') ||
        searchToken.startsWith('mastercard') ||
        searchToken.startsWith('mada') ||
        searchToken.startsWith('applepay') ||
        searchToken.startsWith('stcpay') ||
        searchToken.contains('الرصيد') ||
        searchToken.contains('balance') ||
        searchToken.contains('amount') ||
        searchToken.contains('مبلغ') ||
        searchToken.contains('رقم')) {
      return true;
    }
    return false;
  }

  static _AmountCandidate? _selectExplicitAmountCandidate(String scrubbed) {
    final List<_AmountCandidate> candidates = <_AmountCandidate>[];

    void addCandidates({
      required RegExp regex,
      required bool currencyAfterAmount,
    }) {
      for (final Match match in regex.allMatches(scrubbed)) {
        final bool hasTwoGroups = match.groupCount >= 2;
        final String rawAmount = currencyAfterAmount
            ? match.group(1) ?? ''
            : hasTwoGroups
            ? match.group(2) ?? ''
            : match.group(1) ?? '';
        final double? parsedAmount = double.tryParse(
          rawAmount.replaceAll(',', ''),
        );
        if (parsedAmount == null || parsedAmount == 0.0) continue;
        final String? rawCurrency = currencyAfterAmount
            ? match.group(2)
            : hasTwoGroups
            ? match.group(1)
            : null;

        final int start = match.start;
        final int end = match.end;
        final int lineStart = scrubbed.lastIndexOf('\n', start);
        final int limitBefore = lineStart == -1 ? 0 : lineStart;
        final int lineEnd = scrubbed.indexOf('\n', end);
        final int limitAfter = lineEnd == -1 ? scrubbed.length : lineEnd;
        final String lineContext = scrubbed
            .substring(limitBefore, limitAfter)
            .toLowerCase();

        if (_hasMatch(lineContext, <String>[
          'الرصيد',
          'رصيدك الحالي',
          'حد الصرف',
          'حد الصرف المتبقي',
          'remaining amount',
          'remaining limit',
          'سعر الصرف',
          'exchange rate',
          'available balance',
          'remaining balance',
          'credit limit',
        ])) {
          continue;
        }

        double score = 0.0;
        if (_hasMatch(lineContext, <String>[
          'total due',
          'total charged',
          'charged amount',
          'إجمالي المبلغ',
          'إجمالي المبلغ المستحق',
          'المبلغ النهائي',
          'المبلغ المطلوب',
        ])) {
          score += 1500.0;
        }
        if (_hasMatch(lineContext, <String>[
          'مبلغ',
          'amount',
          'amt',
          'value',
          'بقيمة',
          'بقيمه',
          'purchase amount',
          'transaction amount',
        ])) {
          score += 1000.0;
        }
        if (_hasMatch(lineContext, <String>[
          'purchase',
          'payment',
          'debit',
          'credit',
          'transfer',
          'withdrawal',
          'spent',
          'شراء',
          'دفع',
          'خصم',
          'سحب',
          'تحويل',
          'حوالة',
          'سداد',
        ])) {
          score += 200.0;
        }
        if (_hasMatch(lineContext, <String>[
          'balance',
          'remaining',
          'limit',
          'remaining amount',
          'remaining limit',
          'الرصيد',
          'المتاح',
          'المتبقي',
        ])) {
          score -= 900.0;
        }
        if (parsedAmount < 100 &&
            _looksLikeDateNumberCandidate(scrubbed, start, end, parsedAmount)) {
          score -= 500.0;
        }

        final String? localCurrency = rawCurrency == null
            ? null
            : _normalizeCurrency(rawCurrency);
        if (localCurrency == 'SAR' || localCurrency == 'EGP') {
          score += 30.0;
        } else if (localCurrency != null) {
          score += 5.0;
        }

        candidates.add(
          _AmountCandidate(
            amount: parsedAmount,
            currency: localCurrency,
            score: score,
          ),
        );
      }
    }

    addCandidates(
      regex: RegExp(
        r'(?<!\d)((?:sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم))\s*(?:amount|المبلغ|مبلغ)\s*[:\-]?\s*(\d+(?:[,\s]\d{3})*(?:\.\d+)?)',
        caseSensitive: false,
      ),
      currencyAfterAmount: false,
    );
    addCandidates(
      regex: RegExp(
        r'(?<!\d)(?:sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم)\s*(?:amount|المبلغ|مبلغ)\s*[:\-]?\s*(\d+(?:[,\s]\d{3})*(?:\.\d+)?)',
        caseSensitive: false,
      ),
      currencyAfterAmount: false,
    );
    addCandidates(
      regex: RegExp(
        r'(?<!\d)(\d+(?:[,\s]\d{3})*(?:\.\d+)?)\s*(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم)\b',
        caseSensitive: false,
      ),
      currencyAfterAmount: true,
    );
    addCandidates(
      regex: RegExp(
        r'(?:\b(sar|sr|s\.r|egp|usd|\$|aed|درهم|ريال|جنيه|ر\.س|ج\.م|جم)\b\s*)(\d+(?:[,\s]\d{3})*(?:\.\d+)?)',
        caseSensitive: false,
      ),
      currencyAfterAmount: false,
    );

    if (candidates.isEmpty) return null;
    candidates.sort((_AmountCandidate a, _AmountCandidate b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.amount.compareTo(a.amount);
    });
    return candidates.first;
  }

  static bool _looksLikeDateNumberCandidate(
    String scrubbed,
    int start,
    int end,
    double value,
  ) {
    if (value >= 100) return false;

    final String before = scrubbed
        .substring(start - 12 >= 0 ? start - 12 : 0, start)
        .toLowerCase();
    final String after = scrubbed
        .substring(
          end,
          end + 12 <= scrubbed.length ? end + 12 : scrubbed.length,
        )
        .toLowerCase();
    final String around = '$before $after';

    return _hasMatch(around, <String>[
          'jan',
          'feb',
          'mar',
          'apr',
          'may',
          'jun',
          'jul',
          'aug',
          'sep',
          'oct',
          'nov',
          'dec',
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'ابريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'اغسطس',
          'سبتمبر',
          'أكتوبر',
          'اكتوبر',
          'نوفمبر',
          'ديسمبر',
        ]) ||
        after.contains('-') ||
        after.contains('/') ||
        before.contains('-') ||
        before.contains('/');
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
        .replaceFirst(
          RegExp(
            r'\s*[-–]\s*(?:sa|ksa|uae|eg|us|usa|uk)$',
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
      'apple',
      'apple pay',
      'applepay',
      'mada',
      'مدى',
      'visa',
      'mastercard',
      'stc pay',
      'stcpay',
      'bank transfer',
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
        (_hasMatch(key, <String>[
              'card',
              'account',
              'balance',
              'remaining',
              'visa',
              'mastercard',
              'mada',
              'apple pay',
              'stc pay',
              'stcpay',
            ]) &&
            RegExp(r'\d').hasMatch(key)) ||
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

  static bool _isSubscriptionActivationMessage(String text) {
    return _hasMatch(text, [
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
    ]);
  }

  static bool _isAccountDepositMessage(String text) {
    if (_hasMatch(text, [
      'salary',
      'راتب',
      'payroll',
      'cashback',
      'كاش باك',
      'transfer',
      'تحويل',
      'حوالة',
      'instant transfer',
      'التحويل اللحظي',
      'التحويل الفوري',
    ])) {
      return false;
    }
    final bool hasDepositIntent = _hasMatch(text, [
      'deposit to account',
      'deposit into account',
      'account deposit',
      'wallet deposit',
      'deposit to wallet',
      'fund account',
      'funding account',
      'top up account',
      'cash in account',
      'deposit',
      'إيداع إلى حساب',
      'إيداع الى حساب',
      'إيداع في حساب',
      'إيداع إلى المحفظة',
      'إيداع في المحفظة',
      'إيداع',
      'تم الإيداع',
      'تم الايداع',
      'تم إضافة مبلغ',
      'تم اضافة مبلغ',
      'إضافة مبلغ',
      'اضافة مبلغ',
      'إضافة رصيد',
      'اضافة رصيد',
      'تم تمويل الحساب',
      'تم تمويل المحفظة',
    ]);
    final bool hasTargetAccount = _hasMatch(text, [
      'account',
      'حساب',
      'investment',
      'استثماري',
      'wallet',
      'محفظة',
    ]);
    return hasDepositIntent && hasTargetAccount;
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
