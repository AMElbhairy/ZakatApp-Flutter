import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' as image_picker;

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';

bool isTransientReceiptScanStatus(int statusCode) {
  return statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;
}

String receiptScanFailureMessage(int? statusCode, {required bool isArabic}) {
  if (<int>[500, 502, 503, 504].contains(statusCode)) {
    return isArabic
        ? 'خدمة Gemini مشغولة حالياً. حاول مرة أخرى بعد قليل.'
        : 'Gemini is busy right now. Please try again shortly.';
  }
  if (statusCode == 429) {
    return isArabic
        ? 'تم الوصول إلى حد استخدام Gemini. حاول مرة أخرى لاحقاً.'
        : 'Gemini usage limit reached. Please try again later.';
  }
  if (statusCode == 401 || statusCode == 403) {
    return isArabic
        ? 'تعذر استخدام مفتاح Gemini. تحقق من المفتاح في الإعدادات.'
        : 'Gemini API key was rejected. Check it in Settings.';
  }
  return isArabic
      ? 'تعذر تحليل الفاتورة. تحقق من الاتصال وحاول مرة أخرى.'
      : 'Could not analyze the receipt. Check your connection and try again.';
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialTransaction,
    this.initialType,
    this.cashMode = false,
  });

  final Transaction? initialTransaction;
  final String? initialType;

  /// When true: titled 'Add Cash', no expense toggle, always income type.
  final bool cashMode;

  bool get isEditMode => initialTransaction != null;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late String _type;
  late String _currency;
  String? _category;
  late DateTime _selectedDate;
  bool _saving = false;
  bool _scanningReceipt = false;

  @override
  void initState() {
    super.initState();
    final Transaction? tx = widget.initialTransaction;
    final String defaultEntryCurrency = context
        .read<AppStateController>()
        .state
        .defaultEntryCurrency;
    // In cashMode always use income type
    _type =
        tx?.type ??
        widget.initialType ??
        (widget.cashMode ? 'income' : 'income');
    _currency =
        tx?.currency ??
        (defaultEntryCurrency.trim().isEmpty ? 'EGP' : defaultEntryCurrency);
    _category = tx?.category;
    _selectedDate = _tryParseDate(tx?.date) ?? DateTime.now();
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(
        tx.amount.truncateToDouble() == tx.amount ? 0 : 2,
      );
      _notesController.text = tx.description;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final String defaultEntryCurrency =
        controller.state.defaultEntryCurrency.trim().isEmpty
        ? 'EGP'
        : controller.state.defaultEntryCurrency;
    if (!widget.isEditMode &&
        _currency == 'EGP' &&
        defaultEntryCurrency != 'EGP') {
      _currency = defaultEntryCurrency;
    }
    final List<String> categories = _type == 'income'
        ? controller.state.categories.income
        : controller.state.categories.expense;

    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? context.l10n.tr(
                  widget.cashMode ? 'edit_cash_title' : 'edit_transaction',
                )
              : context.l10n.tr(
                  widget.cashMode ? 'add_cash_title' : 'add_transaction',
                ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Show income/expense toggle only when NOT in cashMode
                if (!widget.cashMode) ...[
                  SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'income',
                        label: Text(context.l10n.tr('income')),
                      ),
                      ButtonSegment<String>(
                        value: 'expense',
                        label: Text(context.l10n.tr('expense')),
                      ),
                    ],
                    selected: <String>{_type},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() {
                        _type = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                if (!widget.cashMode && _type == 'expense') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('scanReceiptAiButton'),
                      onPressed: _scanningReceipt ? null : _scanReceiptWithAi,
                      icon: _scanningReceipt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'مسح الفاتورة بالذكاء الاصطناعي'
                            : 'Scan Receipt with AI',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('amountField'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('amount'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final double amount =
                        double.tryParse((value ?? '').trim()) ?? 0;
                    if (amount <= 0) return context.l10n.tr('amount_gt_zero');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('currencyField'),
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('currency'),
                    border: OutlineInputBorder(),
                  ),
                  items: ZakatEngineService.supportedCurrencies
                      .map(
                        (String currency) => DropdownMenuItem<String>(
                          value: currency,
                          child: Text(
                            ZakatEngineService.getCurrencySymbol(
                              currency,
                              isArabic:
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode.toLowerCase() ==
                                  'ar',
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('categoryField'),
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('category'),
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (String category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(context.l10n.translateCategory(category)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() => _category = value);
                  },
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.tr('category_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('notesField'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('notes'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.tr('date')),
                  subtitle: Text(_dateLabel(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    key: const Key('saveTransactionButton'),
                    onPressed: _saving
                        ? null
                        : () async {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setState(() => _saving = true);
                            final double amount = double.parse(
                              _amountController.text.trim(),
                            );

                            if (!widget.isEditMode && _type == 'expense') {
                              final double availableBalance = context
                                  .read<AppStateController>()
                                  .getAvailableBalance(currency: _currency);
                              if (availableBalance <= 0) {
                                setState(() => _saving = false);
                                _showError(
                                  _expenseBlockedMessage(context, _currency),
                                );
                                return;
                              }
                            }

                            final Transaction? original =
                                widget.initialTransaction;
                            final Transaction transaction = Transaction(
                              id: original?.id ?? _uuid.v4(),
                              type: _type,
                              date: _dateIso(_selectedDate),
                              amount: amount,
                              currency: _currency,
                              category: _category!,
                              description: _notesController.text.trim(),
                              createdAt:
                                  original?.createdAt ??
                                  DateTime.now().toIso8601String(),
                              rolledOver: original?.rolledOver ?? false,
                              rolledAmount: original?.rolledAmount,
                              sourceIncomeId: original?.sourceIncomeId,
                              exchangePairId: original?.exchangePairId,
                              exchangeSourceIncomeId:
                                  original?.exchangeSourceIncomeId,
                              remainingAmount: original?.remainingAmount,
                            );

                            final AppStateController appStateController =
                                context.read<AppStateController>();
                            if (widget.isEditMode) {
                              await appStateController.updateTransaction(
                                transaction,
                              );
                            } else {
                              await appStateController.addTransaction(
                                transaction,
                              );
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                    label: _saving
                        ? context.l10n.tr('saving_progress')
                        : (widget.isEditMode
                              ? context.l10n.tr(
                                  widget.cashMode
                                      ? 'update_cash'
                                      : 'update_transaction',
                                )
                              : context.l10n.tr(
                                  widget.cashMode
                                      ? 'save_cash'
                                      : 'save_transaction',
                                )),
                    icon: Icons.check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String _dateIso(DateTime date) {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _dateLabel(DateTime date) {
    return _dateIso(date);
  }

  void _showError(String message) {
    if (!mounted) return;
    showTopSnackBar(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showTopSnackBar(context, message);
  }

  static String _expenseBlockedMessage(
    BuildContext context,
    String currency,
  ) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final String normalizedCurrency = currency.trim().toUpperCase();
    if (isArabic) {
      return normalizedCurrency.isEmpty
          ? 'لا يوجد رصيد متاح لإضافة هذا المصروف.'
          : 'لا يوجد رصيد متاح بعملة $normalizedCurrency لإضافة هذا المصروف.';
    }
    return normalizedCurrency.isEmpty
        ? 'No available balance to add this expense.'
        : 'No available balance in $normalizedCurrency to add this expense.';
  }

  Future<void> _scanReceiptWithAi() async {
    final controller = context.read<AppStateController>();
    final aiSettings = controller.state.aiSettings;
    if (aiSettings == null) {
      _showError(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'الرجاء إعداد مفاتيح Gemini أولاً في الإعدادات'
            : 'Please configure Gemini API Keys in settings first',
      );
      return;
    }
    final List<dynamic>? keysList = aiSettings['keys'] as List<dynamic>?;
    final int defaultKeyIndex = (aiSettings['defaultKeyIndex'] as int?) ?? 0;
    String apiKey = '';
    if (keysList != null && keysList.isNotEmpty) {
      if (defaultKeyIndex < keysList.length) {
        apiKey = keysList[defaultKeyIndex]?.toString() ?? '';
      }
    }
    if (apiKey.isEmpty) {
      _showError(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'الرجاء إعداد مفاتيح Gemini أولاً في الإعدادات'
            : 'Please configure Gemini API Keys in settings first',
      );
      return;
    }

    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String? source = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(isArabic ? 'الكاميرا' : 'Camera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(isArabic ? 'معرض الصور' : 'Photo Gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(isArabic ? 'ملف مستند / صورة' : 'Document / File Picker'),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    Uint8List? bytes;
    String mimeType = 'image/jpeg';

    if (source == 'camera' || source == 'gallery') {
      final imagePicker = image_picker.ImagePicker();
      final image_picker.XFile? pickedFile = await imagePicker.pickImage(
        source: source == 'camera'
            ? image_picker.ImageSource.camera
            : image_picker.ImageSource.gallery,
      );
      if (pickedFile == null) return;
      bytes = await pickedFile.readAsBytes();
      final String ext = pickedFile.name.split('.').last.toLowerCase();
      mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    } else {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final PlatformFile file = result.files.first;
      final Uint8List? fileBytes = file.bytes;
      final String? filePath = file.path;

      if (fileBytes != null) {
        bytes = fileBytes;
      } else if (filePath != null) {
        bytes = await File(filePath).readAsBytes();
      }
      final String ext = (file.extension ?? '').toLowerCase();
      if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'pdf') {
        mimeType = 'application/pdf';
      } else {
        mimeType = 'image/jpeg';
      }
    }

    if (bytes == null) return;

    setState(() => _scanningReceipt = true);

    try {
      final String base64Image = base64Encode(bytes);
      final List<String> expenseCategories =
          controller.state.categories.expense;

      final String prompt =
          'Analyze this receipt image. Extract all individual transactions. '
          'CRITICAL: If the invoice or receipt contains multiple separate items, DO NOT combine them into a single transaction. '
          'Extract each itemized purchase or category entry as a separate transaction in the list so they can be reviewed individually.\n'
          'For each transaction, identify:\n'
          '- merchant (name of store/vendor)\n'
          '- date (YYYY-MM-DD format, estimate based on current date if missing or metadata)\n'
          '- amount (decimal value)\n'
          '- category (classify into one of these expense categories: ${expenseCategories.join(", ")})\n'
          '- currency (3-letter code, e.g., EGP, SAR, USD, AED, KWD, QAR)\n'
          '- description (brief summary of item purchased)\n\n'
          'Return ONLY a valid JSON object matching this schema:\n'
          '{\n'
          '  "transactions": [\n'
          '    {\n'
          '      "merchant": "...",\n'
          '      "date": "YYYY-MM-DD",\n'
          '      "amount": 12.34,\n'
          '      "category": "...",\n'
          '      "currency": "...",\n'
          '      "description": "..."\n'
          '    }\n'
          '  ]\n'
          '}\n'
          'Do not wrap the response in markdown blocks or any text other than the raw JSON.';

      final Uri endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );
      final String requestBody = jsonEncode(<String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': prompt},
              <String, dynamic>{
                'inlineData': <String, dynamic>{
                  'mimeType': mimeType,
                  'data': base64Image,
                },
              },
            ],
          },
        ],
      });
      http.Response response = await http.post(
        endpoint,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: requestBody,
      );
      if (isTransientReceiptScanStatus(response.statusCode)) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        response = await http.post(
          endpoint,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: requestBody,
        );
      }

      if (response.statusCode == 200) {
        if (!mounted) return;
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? candidates = body['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final Map<String, dynamic> candidate =
              candidates.first as Map<String, dynamic>;
          final Map<String, dynamic> content =
              candidate['content'] as Map<String, dynamic>;
          final List<dynamic> parts = content['parts'] as List<dynamic>;
          if (parts.isNotEmpty) {
            String text = parts.first['text']?.toString() ?? '';

            // Clean up json blocks if present
            if (text.contains('```')) {
              final regExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
              final match = regExp.firstMatch(text);
              if (match != null) {
                text = match.group(1) ?? text;
              }
            }

            final Map<String, dynamic> data =
                jsonDecode(text.trim()) as Map<String, dynamic>;
            final List<dynamic>? transactionsList =
                data['transactions'] as List<dynamic>?;

            if (transactionsList != null && transactionsList.isNotEmpty) {
              if (transactionsList.length == 1) {
                final tx = transactionsList.first;
                final String scannedCategory = _matchedExpenseCategory(
                  tx['category'],
                  expenseCategories,
                );
                setState(() {
                  _amountController.text = _normalizedAmountText(tx['amount']);
                  _notesController.text =
                      '${tx['merchant'] ?? ''} - ${tx['description'] ?? ''}'
                          .trim();
                  final String rawCurrency = (tx['currency'] ?? '')
                      .toString()
                      .toUpperCase();
                  if (ZakatEngineService.supportedCurrencies.contains(
                    rawCurrency,
                  )) {
                    _currency = rawCurrency;
                  }
                  _category = scannedCategory;
                  final String rawDate = (tx['date'] ?? '').toString();
                  final parsedDate = _tryParseDate(rawDate);
                  if (parsedDate != null) {
                    _selectedDate = parsedDate;
                  }
                });
                if (!mounted) return;
                _showSuccess(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'تم تعبئة البيانات تلقائياً!'
                      : 'Data filled automatically!',
                );
              } else {
                if (!mounted) return;
                final bool? saved = await showDialog<bool>(
                  context: context,
                  builder: (context) => ScannedTransactionsConfirmationDialog(
                    transactions: transactionsList.cast<Map<String, dynamic>>(),
                    categories: expenseCategories,
                    onSave: (List<Map<String, dynamic>> confirmedList) =>
                        _saveScannedTransactions(
                          confirmedList,
                          expenseCategories,
                        ),
                  ),
                );

                if (saved == true && mounted) {
                  Navigator.of(context).pop();
                }
              }
            } else {
              throw Exception('No transactions found in response JSON.');
            }
          }
        }
      } else {
        debugPrint(
          'Receipt scan failed with Gemini status ${response.statusCode}: '
          '${response.body}',
        );
        if (!mounted) return;
        _showError(
          receiptScanFailureMessage(
            response.statusCode,
            isArabic:
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar',
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Receipt scan failed: $e');
      _showError(
        receiptScanFailureMessage(
          null,
          isArabic:
              Localizations.localeOf(context).languageCode.toLowerCase() ==
              'ar',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _scanningReceipt = false);
      }
    }
  }

  static double _asPositiveDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  static String _normalizedAmountText(dynamic value) {
    final double amount = _asPositiveDouble(value);
    if (amount <= 0) return '';
    return amount == amount.truncateToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toString();
  }

  static String _matchedExpenseCategory(
    dynamic value,
    List<String> categories,
  ) {
    final String requested = (value ?? '').toString().trim();
    for (final String category in categories) {
      if (category.toLowerCase() == requested.toLowerCase()) return category;
    }
    return categories.isNotEmpty ? categories.first : requested;
  }

  Future<void> _saveScannedTransactions(
    List<Map<String, dynamic>> confirmedList,
    List<String> expenseCategories,
  ) async {
    final List<Transaction> transactions = confirmedList
        .map((tx) {
          final DateTime txDate =
              _tryParseDate((tx['date'] ?? '').toString()) ?? DateTime.now();
          return Transaction(
            id: _uuid.v4(),
            type: 'expense',
            date: _dateIso(txDate),
            amount: _asPositiveDouble(tx['amount']),
            currency: (tx['currency'] ?? _currency).toString(),
            category: _matchedExpenseCategory(
              tx['category'],
              expenseCategories,
            ),
            description: (tx['description'] ?? '').toString(),
            createdAt: DateTime.now().toUtc().toIso8601String(),
            rolledOver: false,
          );
        })
        .where((Transaction tx) => tx.amount > 0)
        .toList(growable: false);

    if (transactions.isEmpty) {
      throw Exception('No valid selected transactions to save.');
    }
    await context.read<AppStateController>().addTransactions(transactions);
  }
}

class ScannedTransactionsConfirmationDialog extends StatefulWidget {
  const ScannedTransactionsConfirmationDialog({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onSave,
  });

  final List<Map<String, dynamic>> transactions;
  final List<String> categories;
  final Future<void> Function(List<Map<String, dynamic>> transactions) onSave;

  @override
  State<ScannedTransactionsConfirmationDialog> createState() =>
      _ScannedTransactionsConfirmationDialogState();
}

class _ScannedTransactionsConfirmationDialogState
    extends State<ScannedTransactionsConfirmationDialog> {
  late List<Map<String, dynamic>> _list;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _list = widget.transactions.map((tx) {
      return <String, dynamic>{
        'merchant': tx['merchant'] ?? '',
        'description': tx['description'] ?? '',
        'amountController': TextEditingController(
          text: tx['amount']?.toString() ?? '0',
        ),
        'descriptionController': TextEditingController(
          text: '${tx['merchant'] ?? ''} - ${tx['description'] ?? ''}'.trim(),
        ),
        'dateController': TextEditingController(text: tx['date']?.toString()),
        'category': widget.categories.contains(tx['category'])
            ? tx['category']
            : (widget.categories.isNotEmpty ? widget.categories.first : ''),
        'currency':
            ZakatEngineService.supportedCurrencies.contains(
              (tx['currency'] ?? '').toString().toUpperCase(),
            )
            ? (tx['currency'] ?? '').toString().toUpperCase()
            : 'EGP',
        'date': tx['date'] ?? '',
        'selected': true,
      };
    }).toList();
  }

  @override
  void dispose() {
    for (final item in _list) {
      (item['amountController'] as TextEditingController).dispose();
      (item['descriptionController'] as TextEditingController).dispose();
      (item['dateController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return AlertDialog(
      title: Text(
        isArabic ? 'تعديل المعاملات المستخرجة' : 'Edit Extracted Transactions',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _list.length,
          itemBuilder: (context, index) {
            final item = _list[index];
            final amountCtrl =
                item['amountController'] as TextEditingController;
            final descCtrl =
                item['descriptionController'] as TextEditingController;
            final dateCtrl = item['dateController'] as TextEditingController;

            return Card(
              key: Key('scannedTransactionCard_$index'),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          key: Key('scannedTransactionSelected_$index'),
                          value: item['selected'] as bool,
                          onChanged: (val) {
                            setState(() {
                              item['selected'] = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['merchant'] ?? '').toString().isEmpty
                                    ? (isArabic
                                          ? 'معاملة مستخرجة'
                                          : 'Extracted transaction')
                                    : (item['merchant'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: Key('scannedDescription_$index'),
                                controller: descCtrl,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'الوصف' : 'Description',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: Key('scannedDate_$index'),
                      controller: dateCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'التاريخ' : 'Date',
                        hintText: 'YYYY-MM-DD',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: Key('scannedAmount_$index'),
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: isArabic ? 'المبلغ' : 'Amount',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            key: Key('scannedCurrency_$index'),
                            initialValue: item['currency'] as String,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'العملة' : 'Currency',
                              border: OutlineInputBorder(),
                            ),
                            items: ZakatEngineService.supportedCurrencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                item['currency'] = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: Key('scannedCategory_$index'),
                      initialValue: item['category'] as String,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'التصنيف' : 'Category',
                        border: const OutlineInputBorder(),
                      ),
                      items: widget.categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(context.l10n.translateCategory(c)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          item['category'] = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          key: const Key('saveSelectedScannedTransactions'),
          onPressed: _saving
              ? null
              : () async {
                  final results = <Map<String, dynamic>>[];
                  for (final item in _list) {
                    if (item['selected'] as bool) {
                      final double amt =
                          _AddTransactionScreenState._asPositiveDouble(
                            (item['amountController'] as TextEditingController)
                                .text,
                          );
                      if (amt <= 0) continue;
                      results.add({
                        'amount': amt,
                        'description':
                            (item['descriptionController']
                                    as TextEditingController)
                                .text
                                .trim(),
                        'category': item['category'],
                        'currency': item['currency'],
                        'date':
                            (item['dateController'] as TextEditingController)
                                .text
                                .trim(),
                      });
                    }
                  }
                  if (results.isEmpty) {
                    showTopSnackBar(
                      context,
                      isArabic
                          ? 'حدد معاملة واحدة صالحة على الأقل'
                          : 'Select at least one valid transaction.',
                    );
                    return;
                  }
                  setState(() => _saving = true);
                  try {
                    await widget.onSave(results);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (error) {
                    if (!context.mounted) return;
                    setState(() => _saving = false);
                    showTopSnackBar(
                      context,
                      isArabic
                          ? 'فشل حفظ المعاملات: $error'
                          : 'Failed to save transactions: $error',
                    );
                  }
                },
          child: Text(
            _saving
                ? (isArabic ? 'جارٍ الحفظ...' : 'Saving...')
                : (isArabic ? 'حفظ المحدد' : 'Save Selected'),
          ),
        ),
      ],
    );
  }
}
