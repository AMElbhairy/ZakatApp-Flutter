import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/currency_dropdown_form_field.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/credit_card.dart';
import '../../services/app_state_controller.dart';

class AddCreditCardScreen extends StatefulWidget {
  const AddCreditCardScreen({super.key, this.initialCurrency = 'EGP'});

  final String initialCurrency;

  @override
  State<AddCreditCardScreen> createState() => _AddCreditCardScreenState();
}

class _AddCreditCardScreenState extends State<AddCreditCardScreen> {
  final _formKey = GlobalKey<FormState>();

  final _bankController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _limitController = TextEditingController();
  final _owedController = TextEditingController();
  final _notesController = TextEditingController();

  CreditCardNetwork _network = CreditCardNetwork.visa;
  late String _currency;
  String _themeId = 'emerald';
  bool _isSupplementary = false;
  String? _parentCardId;

  int? _statementDay;
  int? _paymentDueDay;
  int? _expiryMonth;
  int? _expiryYear;

  bool _remindEnabled = false;
  int _reminderDaysBefore = 3;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency.trim().isEmpty
        ? 'EGP'
        : widget.initialCurrency.trim();
  }

  @override
  void dispose() {
    _bankController.dispose();
    _nicknameController.dispose();
    _last4Controller.dispose();
    _limitController.dispose();
    _owedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const Map<String, List<Color>> _colorThemes = <String, List<Color>>{
    'emerald': <Color>[Color(0xFF0B6B58), Color(0xFF032F29)],
    'obsidian': <Color>[Color(0xFF30343B), Color(0xFF0D0F12)],
    'graphite': <Color>[Color(0xFF62666D), Color(0xFF25272B)],
    'gold': <Color>[Color(0xFFB88A2E), Color(0xFF49300B)],
    'sapphire': <Color>[Color(0xFF1769AA), Color(0xFF08233F)],
    'ruby': <Color>[Color(0xFFB52A43), Color(0xFF420F1B)],
    'platinum': <Color>[Color(0xFFB8C1C9), Color(0xFF4A525A)],
    'copper': <Color>[Color(0xFFB86B45), Color(0xFF4A2418)],
  };

  static const Map<String, String> _colorNames = <String, String>{
    'emerald': 'Emerald',
    'obsidian': 'Obsidian',
    'graphite': 'Graphite',
    'gold': 'Gold',
    'sapphire': 'Sapphire',
    'ruby': 'Ruby',
    'platinum': 'Platinum',
    'copper': 'Copper',
  };

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _reminderOffsetLabel(int days, BuildContext context) {
    switch (days) {
      case 0:
        return context.l10n.tr('on_due_date');
      case 1:
        return context.l10n.tr('1_day_before');
      case 2:
        return context.l10n.tr('2_days_before');
      case 3:
        return context.l10n.tr('3_days_before');
      case 5:
        return context.l10n.tr('5_days_before');
      case 7:
        return context.l10n.tr('7_days_before');
      default:
        return '$days days before';
    }
  }

  void _selectParent(String? parentId, List<CreditCard> parents) {
    final CreditCard? parent = parents
        .where((CreditCard card) => card.id == parentId)
        .firstOrNull;
    setState(() {
      _parentCardId = parentId;
      if (parent != null) {
        _currency = parent.currency;
        _limitController.text = parent.creditLimit.toString();
        _owedController.text = parent.openingBalance.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final List<CreditCard> parentCards = context
        .read<AppStateController>()
        .state
        .creditCards
        .where(
          (CreditCard card) => !card.isArchived && card.parentCardId == null,
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(title: Text(context.l10n.tr('add_credit_card'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.compactHorizontalPadding(context),
            16,
            ResponsiveLayout.compactHorizontalPadding(context),
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // CARD INFORMATION
                _buildSectionHeader(
                  context,
                  context.l10n.tr('card_information'),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: _bankController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.tr('bank_issuer')} *',
                          hintText: 'e.g. Alinma, Al Rajhi, Chase',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bank name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nicknameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('card_nickname'),
                          hintText: 'e.g. Signature Sub1, Everyday Card',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<CreditCardNetwork>(
                        value: _network,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.tr('card_network')} *',
                        ),
                        items: CreditCardNetwork.values.map((network) {
                          return DropdownMenuItem<CreditCardNetwork>(
                            value: network,
                            child: Text(network.displayName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _network = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _last4Controller,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.tr('last_4_digits')} *',
                          hintText: '0973',
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last 4 digits are required';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                            return 'Enter exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Supplementary card'),
                        subtitle: const Text(
                          'Shares the main card limit and balance',
                        ),
                        value: _isSupplementary,
                        onChanged: (bool value) {
                          setState(() {
                            _isSupplementary = value;
                            _parentCardId = value ? _parentCardId : null;
                          });
                        },
                      ),
                      if (_isSupplementary)
                        DropdownButtonFormField<String>(
                          value: _parentCardId,
                          decoration: const InputDecoration(
                            labelText: 'Main card *',
                          ),
                          items: parentCards
                              .map((CreditCard parent) {
                                return DropdownMenuItem<String>(
                                  value: parent.id,
                                  child: Text(
                                    '${parent.bankName} •••• ${parent.last4Digits}',
                                  ),
                                );
                              })
                              .toList(growable: false),
                          validator: (String? value) =>
                              _isSupplementary && value == null
                              ? 'Select the main card'
                              : null,
                          onChanged: (String? value) =>
                              _selectParent(value, parentCards),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // FINANCIAL DETAILS
                _buildSectionHeader(
                  context,
                  context.l10n.tr('financial_details'),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: CurrencyDropdownFormField(
                          value: _currency,
                          labelText: context.l10n.tr('currency'),
                          currencies: ZakatEngineService.supportedCurrencies,
                          onChanged: (String value) =>
                              setState(() => _currency = value),
                        ),
                      ),
                      TextFormField(
                        controller: _limitController,
                        readOnly: _isSupplementary,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '${context.l10n.tr('credit_limit')} *',
                          hintText: '0.00',
                          prefixText: '$_currency ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Credit limit is required';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _owedController,
                        readOnly: _isSupplementary,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${context.l10n.tr('current_balance_owed')} *',
                          hintText: '0.00',
                          prefixText: '$_currency ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Current balance owed is required';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // BILLING CYCLE
                _buildSectionHeader(context, context.l10n.tr('billing_cycle')),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<int?>(
                        value: _statementDay,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('statement_day'),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Not specified',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          ...List<int>.generate(31, (i) => i + 1).map((day) {
                            return DropdownMenuItem<int?>(
                              value: day,
                              child: Text('Day $day of the month'),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _statementDay = val),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        value: _paymentDueDay,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('payment_due_day'),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Not specified',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          ...List<int>.generate(31, (i) => i + 1).map((day) {
                            return DropdownMenuItem<int?>(
                              value: day,
                              child: Text('Day $day of the month'),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _paymentDueDay = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // PAYMENT REMINDER
                _buildSectionHeader(
                  context,
                  context.l10n.tr('payment_reminder'),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  context.l10n.tr('remind_me_about_payment'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Get reminded before payment due date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _remindEnabled,
                            activeColor: tokens.colors.gold,
                            onChanged: (bool val) {
                              setState(() => _remindEnabled = val);
                            },
                          ),
                        ],
                      ),
                      if (_remindEnabled) ...<Widget>[
                        const Divider(height: 24),
                        DropdownButtonFormField<int>(
                          value: _reminderDaysBefore,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('remind_me'),
                          ),
                          items: const <int>[0, 1, 2, 3, 5, 7].map((days) {
                            return DropdownMenuItem<int>(
                              value: days,
                              child: Text(_reminderOffsetLabel(days, context)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _reminderDaysBefore = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.l10n.tr('reminder_time'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tokens.colors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(_reminderTime),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tokens.colors.gold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: tokens.colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime,
                            );
                            if (picked != null) {
                              setState(() => _reminderTime = picked);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // OPTIONAL DETAILS
                _buildSectionHeader(
                  context,
                  context.l10n.tr('optional_details'),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.tr('expiry_date'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: _expiryMonth,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('expiry_month'),
                                hintText: 'MM',
                              ),
                              items: <DropdownMenuItem<int?>>[
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'MM',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ),
                                ...List<int>.generate(12, (i) => i + 1).map((
                                  m,
                                ) {
                                  return DropdownMenuItem<int?>(
                                    value: m,
                                    child: Text(m.toString().padLeft(2, '0')),
                                  );
                                }),
                              ],
                              onChanged: (val) =>
                                  setState(() => _expiryMonth = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: _expiryYear,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('expiry_year'),
                                hintText: 'YYYY',
                              ),
                              items: <DropdownMenuItem<int?>>[
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'YYYY',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ),
                                ...List<int>.generate(
                                  20,
                                  (i) => DateTime.now().year + i,
                                ).map((y) {
                                  return DropdownMenuItem<int?>(
                                    value: y,
                                    child: Text(y.toString()),
                                  );
                                }),
                              ],
                              onChanged: (val) =>
                                  setState(() => _expiryYear = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: context.l10n.tr('notes'),
                          hintText: 'e.g. Main everyday card, travel rewards',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD APPEARANCE
                _buildSectionHeader(
                  context,
                  context.l10n.tr('card_appearance'),
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _colorThemes.entries.map((entry) {
                          final isSelected = entry.key == _themeId;
                          final name = _colorNames[entry.key] ?? entry.key;
                          return GestureDetector(
                            onTap: () => setState(() => _themeId = entry.key),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: entry.value,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? tokens.colors.gold
                                          : Colors.white24,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: tokens.colors.gold
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? tokens.colors.gold
                                        : tokens.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // SUBMIT BUTTON
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.l10n.tr('add_card'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final tokens = context.premiumTokens;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: tokens.colors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final double? limit = double.tryParse(_limitController.text.trim());
    final double? owed = double.tryParse(_owedController.text.trim());
    if (limit == null ||
        owed == null ||
        limit < 0 ||
        owed < 0 ||
        (_isSupplementary && _parentCardId == null)) {
      return;
    }

    final String now = DateTime.now().toUtc().toIso8601String();
    final newCard = CreditCard(
      id: const Uuid().v4(),
      bankName: _bankController.text.trim(),
      cardNickname: _nicknameController.text.trim(),
      network: _network,
      last4Digits: _last4Controller.text.trim(),
      creditLimit: limit,
      currency: _currency,
      openingBalance: owed,
      statementDay: _statementDay,
      paymentDueDay: _paymentDueDay,
      paymentReminderEnabled: _remindEnabled,
      reminderDaysBefore: _reminderDaysBefore,
      reminderTimeHour: _reminderTime.hour,
      reminderTimeMinute: _reminderTime.minute,
      expiryMonth: _expiryMonth,
      expiryYear: _expiryYear,
      notes: _notesController.text.trim(),
      themeId: _themeId,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      parentCardId: _isSupplementary ? _parentCardId : null,
    );

    FocusScope.of(context).unfocus();
    final AppStateController controller = context.read<AppStateController>();
    Navigator.of(context).pop();
    unawaited(() async {
      try {
        await controller.addCreditCard(newCard);
      } catch (e, st) {
        debugPrint('Failed to add credit card: $e\n$st');
      }
    }());
  }
}
