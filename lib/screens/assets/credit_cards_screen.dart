import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/compact_dropdown.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/credit_card.dart';
import '../../models/transaction.dart';
import '../../services/app_state_controller.dart';
import 'add_credit_card_screen.dart';
import 'credit_card_details_screen.dart';
import 'edit_credit_card_screen.dart';

Future<String?> _chooseStandaloneBalanceOwner(
  BuildContext context,
  List<CreditCard> children,
) async {
  if (children.isEmpty) return null;
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => SimpleDialog(
      title: const Text('Choose card to keep existing balance'),
      children: children
          .map(
            (CreditCard card) => SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(card.id),
              child: Text('${card.bankName} •••• ${card.last4Digits}'),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class CreditCardsScreen extends StatelessWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.read<AppStateController>();
    final List<CreditCard> allCards = context
        .select<AppStateController, List<CreditCard>>(
          (AppStateController c) => c.state.creditCards,
        );
    final List<CreditCard> cards = allCards
        .where((CreditCard card) => !card.isArchived)
        .toList(growable: false);
    final String currency = context.select<AppStateController, String>(
      (AppStateController c) =>
          c.state.mainCurrency.isEmpty ? 'EGP' : c.state.mainCurrency,
    );
    final Map<String, dynamic> rawMarket = context
        .select<AppStateController, Map<String, dynamic>>(
          (AppStateController c) => c.state.marketData,
        );
    final MarketData market = MarketData.fromJson(rawMarket);
    double normalized(double amount, String cardCurrency) =>
        ZakatEngineService.convertFromEgp(
          ZakatEngineService.convertToEgp(amount, cardCurrency, market),
          currency,
          market,
        );
    final double owed = cards.fold<double>(
      0,
      (double sum, CreditCard card) => card.parentCardId == null
          ? sum + normalized(card.openingBalance, card.currency)
          : sum,
    );
    final double limit = cards.fold<double>(
      0,
      (double sum, CreditCard card) => card.parentCardId == null
          ? sum + normalized(card.creditLimit, card.currency)
          : sum,
    );
    final double available = (limit - owed).clamp(0, double.infinity);
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin = isRtl
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment gradientEnd = isRtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bool balancesHidden =
        controller.state.aiSettings?['privacyMode'] == true ||
        controller.state.aiSettings?['hideBalances'] == true ||
        controller.state.aiSettings?['balancesHidden'] == true;
    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(title: Text(context.l10n.tr('credit_cards'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddCreditCardScreen(initialCurrency: currency),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ResponsiveLayout.compactHorizontalPadding(context),
          16,
          ResponsiveLayout.compactHorizontalPadding(context),
          MediaQuery.paddingOf(context).bottom + 96,
        ),
        children: <Widget>[
          PremiumCard(
            hero: true,
            padding: EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.hero,
                border: Border.all(color: borderColor, width: 1.5),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xFF01332B), Color(0xFF00221C)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: gradientBegin,
                            end: gradientEnd,
                            colors: <Color>[
                              Colors.white.withValues(
                                alpha: isDark ? 0.18 : 0.34,
                              ),
                              Colors.white.withValues(
                                alpha: isDark ? 0.0 : 0.04,
                              ),
                            ],
                            stops: const <double>[0.0, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          'assets/images/hero_pattern_watermark.png',
                          fit: BoxFit.cover,
                          alignment: AlignmentDirectional.topEnd,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.15,
                                    ),
                                    radius: 16,
                                    child: const Icon(
                                      Icons.credit_card_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.l10n
                                          .tr('credit_cards')
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC928),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: <Widget>[
                                  Text(
                                    context.l10n.tr('total_owed'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        balancesHidden
                                            ? '••••••'
                                            : ZakatEngineService.formatCurrency(
                                                owed,
                                                currency,
                                                isArabic: isArabic,
                                              ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${context.l10n.tr('available_credit')}: ${balancesHidden ? '••••••' : ZakatEngineService.formatCurrency(available, currency, isArabic: isArabic)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsetsDirectional.only(start: 12),
                          decoration: const BoxDecoration(
                            border: BorderDirectional(
                              start: BorderSide(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.layers_outlined,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${cards.length} ${context.l10n.tr('cards')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${context.l10n.tr('utilization')}: ${limit <= 0 ? 0 : (owed / limit * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showPayCard(context, cards),
              icon: const Icon(Icons.payments_outlined),
              label: Text(context.l10n.tr('pay_credit_card')),
            ),
            const SizedBox(height: 28),
          ] else
            const SizedBox(height: 16),
          _WalletCardStack(
            cards: cards,
            onCardPromoted: (CreditCard card) async {
              try {
                await controller.promoteCreditCard(card.id);
              } catch (e, st) {
                debugPrint('Failed to promote credit card: $e\n$st');
              }
            },
            onCardEdited: (CreditCard card) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditCreditCardScreen(card: card),
              ),
            ),
            onCardDismissed: (CreditCard card) async {
              try {
                final String? balanceOwnerId =
                    await _chooseStandaloneBalanceOwner(
                      context,
                      controller.supplementaryCardsFor(card.id),
                    );
                if (controller.supplementaryCardsFor(card.id).isNotEmpty &&
                    balanceOwnerId == null) {
                  return;
                }
                await controller.archiveCreditCard(
                  card.id,
                  balanceOwnerId: balanceOwnerId,
                );
              } catch (e, st) {
                debugPrint('Failed to archive credit card: $e\n$st');
              }
            },
          ),
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('No credit cards added yet.')),
            ),
        ],
      ),
    );
  }

  Future<void> _showPayCard(
    BuildContext context,
    List<CreditCard> cards,
  ) async {
    final CreditCardPaymentRequest? request =
        await showModalBottomSheet<CreditCardPaymentRequest>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PayCreditCardSheet(cards: cards),
        );
    if (request == null || !context.mounted) return;
    final CreditCard card = cards.firstWhere(
      (CreditCard item) => item.id == request.cardId,
    );
    try {
      final DateTime now = DateTime.now();
      final String dateIso = _dateIso(now);
      final bool addAsExpense = request.addAsExpense;
      await context.read<AppStateController>().addTransaction(
        Transaction(
          id: const Uuid().v4(),
          type: addAsExpense ? 'expense' : 'transfer',
          date: dateIso,
          amount: request.amount,
          currency: card.currency,
          category: 'Credit Card Payment',
          description: 'Payment for ${card.bankName} •••• ${card.last4Digits}',
          createdAt: now.toUtc().toIso8601String(),
          rolledOver: false,
          creditCardPaymentId: addAsExpense ? card.id : null,
          transferSourceId: addAsExpense ? null : 'cash',
          transferDestinationId: addAsExpense ? null : card.id,
          activityType: addAsExpense ? null : 'transfer',
        ),
      );
    } catch (e, st) {
      debugPrint('Failed to save credit card payment transaction: $e\n$st');
    }
  }

  static String _dateIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class CreditCardPaymentRequest {
  const CreditCardPaymentRequest({
    required this.cardId,
    required this.amount,
    required this.addAsExpense,
  });

  final String cardId;
  final double amount;
  final bool addAsExpense;
}

class _PayCreditCardSheet extends StatefulWidget {
  const _PayCreditCardSheet({required this.cards});

  final List<CreditCard> cards;

  @override
  State<_PayCreditCardSheet> createState() => _PayCreditCardSheetState();
}

class _PayCreditCardSheetState extends State<_PayCreditCardSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  late String _cardId;
  late String _mode;

  @override
  void initState() {
    super.initState();
    _cardId = widget.cards.first.id;
    _mode = 'transfer';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreditCard card = widget.cards.firstWhere(
      (CreditCard item) => item.id == _cardId,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.tr('pay_credit_card'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            CompactDropdownFormField<String>(
              value: _cardId,
              labelText: context.l10n.tr('credit_card'),
              items: widget.cards.map((CreditCard item) => item.id).toList(),
              itemLabel: (String id) {
                final CreditCard item = widget.cards.firstWhere(
                  (CreditCard card) => card.id == id,
                );
                return '${item.bankName} •••• ${item.last4Digits}';
              },
              onChanged: (String value) => setState(() => _cardId = value),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'transfer',
                  label: Text(context.l10n.tr('transfer')),
                ),
                ButtonSegment<String>(
                  value: 'expense',
                  label: Text(context.l10n.tr('expense')),
                ),
              ],
              selected: <String>{_mode},
              onSelectionChanged: (Set<String> selected) {
                setState(() => _mode = selected.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    '${context.l10n.tr('payment_amount')} (${card.currency})',
              ),
              validator: (String? value) {
                final double amount = double.tryParse(value ?? '') ?? 0;
                return amount > 0 ? null : context.l10n.tr('amount_gt_zero');
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop(
                  CreditCardPaymentRequest(
                    cardId: _cardId,
                    amount: double.parse(_amount.text),
                    addAsExpense: _mode == 'expense',
                  ),
                );
              },
              child: Text(context.l10n.tr('payment')),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCardStack extends StatefulWidget {
  const _WalletCardStack({
    required this.cards,
    required this.onCardPromoted,
    required this.onCardEdited,
    required this.onCardDismissed,
  });

  final List<CreditCard> cards;
  final Future<void> Function(CreditCard) onCardPromoted;
  final ValueChanged<CreditCard> onCardEdited;
  final Future<void> Function(CreditCard) onCardDismissed;

  @override
  State<_WalletCardStack> createState() => _WalletCardStackState();
}

class _WalletCardStackState extends State<_WalletCardStack> {
  static const double _cardStep = 66.0;
  static const double _cardHeight = 210.0;
  static const Duration _cardAnimationDuration = Duration(milliseconds: 220);
  late List<CreditCard> _orderedCards;
  Timer? _promoteDebounceTimer;
  CreditCard? _pendingCardToPromote;

  @override
  void initState() {
    super.initState();
    _orderedCards = List<CreditCard>.from(widget.cards);
  }

  @override
  void didUpdateWidget(covariant _WalletCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Map<String, CreditCard> latestMap = <String, CreditCard>{
      for (final CreditCard card in widget.cards) card.id: card,
    };
    final List<CreditCard> next = <CreditCard>[];
    for (final CreditCard card in _orderedCards) {
      if (latestMap.containsKey(card.id)) {
        next.add(latestMap.remove(card.id)!);
      }
    }
    next.addAll(latestMap.values);
    _orderedCards = next;
  }

  @override
  void dispose() {
    _promoteDebounceTimer?.cancel();
    _promoteDebounceTimer = null;
    if (_pendingCardToPromote != null) {
      final CreditCard cardToPromote = _pendingCardToPromote!;
      _pendingCardToPromote = null;
      unawaited(() async {
        try {
          await widget.onCardPromoted(cardToPromote);
        } catch (e, st) {
          debugPrint('Failed to persist card promotion on dispose: $e\n$st');
        }
      }());
    }
    super.dispose();
  }

  void _onCardTapped(int index) {
    if (index == 0) {
      final CreditCard topCard = _orderedCards[0];
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) =>
              CreditCardDetailsScreen(cardId: topCard.id, initialCard: topCard),
        ),
      );
      return;
    }

    final CreditCard tappedCard = _orderedCards[index];

    // 1. Immediate local reorder for 0ms visual responsiveness
    setState(() {
      _orderedCards = <CreditCard>[
        tappedCard,
        ..._orderedCards.where((CreditCard c) => c.id != tappedCard.id),
      ];
    });

    _pendingCardToPromote = tappedCard;

    // 2. Cancel any pending persistence timer
    _promoteDebounceTimer?.cancel();

    // 3. Defer controller persistence until user is completely idle (600ms)
    _promoteDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _promoteDebounceTimer = null;
      final CreditCard? cardToSave = _pendingCardToPromote;
      _pendingCardToPromote = null;
      if (cardToSave != null && mounted) {
        unawaited(() async {
          try {
            await widget.onCardPromoted(cardToSave);
          } catch (e, st) {
            debugPrint('Failed to persist card promotion on debounce: $e\n$st');
          }
        }());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedCards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 222 + ((_orderedCards.length - 1) * _cardStep),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = _orderedCards.length - 1; i >= 0; i--)
            _positionedCard(context, i),
        ],
      ),
    );
  }

  Widget _positionedCard(BuildContext context, int index) {
    final bool isSelected = index == 0;
    final double top = index * _cardStep;
    final CreditCard card = _orderedCards[index];

    // Keep each card's layout slot stable while it moves. Paint-time
    // translation avoids relayouting the whole stack on every animation tick.
    return Positioned.fill(
      key: ValueKey<String>(card.id),
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedSlide(
          offset: Offset(0, top / _cardHeight),
          duration: _cardAnimationDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: isSelected ? 1 : 0.94,
            duration: _cardAnimationDuration,
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(
              child: Slidable(
                key: ValueKey<String>(card.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.32,
                  children: <Widget>[
                    SlidableAction(
                      onPressed: (_) => widget.onCardEdited(card),
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      icon: Icons.edit_outlined,
                      label: context.l10n.tr('edit'),
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.32,
                  children: <Widget>[
                    SlidableAction(
                      onPressed: (_) async {
                        if (await _confirmDismiss(context)) {
                          await widget.onCardDismissed(card);
                        }
                      },
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: context.l10n.tr('delete'),
                    ),
                  ],
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onCardTapped(index),
                  child: _WalletCard(card: card, isCollapsed: !isSelected),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDismiss(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.tr('delete_credit_card')),
        content: Text(dialogContext.l10n.tr('delete_credit_card_message')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.tr('delete')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.card, this.isCollapsed = false});

  final CreditCard card;
  final bool isCollapsed;

  static const Map<String, List<Color>> _cardThemes = <String, List<Color>>{
    'emerald': <Color>[Color(0xFF0B6B58), Color(0xFF032F29)],
    'obsidian': <Color>[Color(0xFF30343B), Color(0xFF0D0F12)],
    'graphite': <Color>[Color(0xFF62666D), Color(0xFF25272B)],
    'gold': <Color>[Color(0xFFB88A2E), Color(0xFF49300B)],
    'sapphire': <Color>[Color(0xFF1769AA), Color(0xFF08233F)],
    'ruby': <Color>[Color(0xFFB52A43), Color(0xFF420F1B)],
    'platinum': <Color>[Color(0xFFB8C1C9), Color(0xFF4A525A)],
    'copper': <Color>[Color(0xFFB86B45), Color(0xFF4A2418)],
  };

  static const BorderRadius _cardBorderRadius = BorderRadius.all(
    Radius.circular(22),
  );

  static const List<BoxShadow> _cardShadows = <BoxShadow>[
    BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8)),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Color> colors =
        _cardThemes[card.themeId] ?? _cardThemes['emerald']!;
    final String nickname = card.cardNickname.trim().isNotEmpty
        ? card.cardNickname.trim()
        : card.bankName;

    Widget buildCardHeader() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  card.bankName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                card.network.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '•••• ${card.last4Digits}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildFinancialDetails() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Limit  ${ZakatEngineService.formatCurrency(card.creditLimit, card.currency)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                'Owed  ${ZakatEngineService.formatCurrency(card.openingBalance, card.currency)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Available  ${ZakatEngineService.formatCurrency(card.availableCredit, card.currency)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                card.currency,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: _cardBorderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: _cardShadows,
      ),
      child: ClipRRect(
        borderRadius: _cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: buildCardHeader(),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: buildFinancialDetails(),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: isCollapsed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  child: buildCardHeader(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
