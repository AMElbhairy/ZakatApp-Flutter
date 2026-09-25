import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/saving.dart';
import '../../services/app_state_controller.dart';
import '../entry/add_saving_screen.dart';
import 'category_details_screen.dart';

class MetalsScreen extends StatelessWidget {
  const MetalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final MarketData market = MarketData.fromJson(controller.state.marketData);
    final String mainCurrency = controller.state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : controller.state.mainCurrency.trim();
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment gradientBegin =
        isRtl ? Alignment.centerLeft : Alignment.centerRight;
    final Alignment gradientEnd =
        isRtl ? Alignment.centerRight : Alignment.centerLeft;

    final bool balancesHidden =
        controller.state.aiSettings?['privacyMode'] == true ||
        controller.state.aiSettings?['hideBalances'] == true ||
        controller.state.aiSettings?['balancesHidden'] == true;

    final List<Saving> savings = controller.state.savings;

    // Gold calculations
    final List<Saving> goldList =
        savings.where((s) => s.assetType == 'gold').toList();
    final double gold24k = goldList.fold<double>(
      0,
      (sum, s) =>
          sum + ZakatEngineService.convertToGold24k(s.remainingAmount, s.unit),
    );
    final double goldTotalEgp = gold24k * market.goldPrice24kEgp;
    final double goldTotalMain = ZakatEngineService.convertFromEgp(
      goldTotalEgp,
      mainCurrency,
      market,
    );

    // Silver calculations
    final List<Saving> silverList =
        savings.where((s) => s.assetType == 'silver').toList();
    final double silverGrams = silverList.fold<double>(
      0,
      (sum, s) =>
          sum + ZakatEngineService.convertToSilverGrams(s.remainingAmount),
    );
    final double silverTotalEgp = silverGrams * market.silverPriceEgp;
    final double silverTotalMain = ZakatEngineService.convertFromEgp(
      silverTotalEgp,
      mainCurrency,
      market,
    );

    // Total Metals
    final double metalsTotalEgp = goldTotalEgp + silverTotalEgp;
    final double metalsTotalMain = goldTotalMain + silverTotalMain;

    final double totalWealthEgp = ZakatEngineService.calculateTotalWealthEgp(
      transactions: controller.state.transactions,
      savings: savings,
      investments: controller.state.investments,
      marketData: market,
      lastRollover: controller.state.lastRollover,
    );

    double pct(double catEgp) => totalWealthEgp > 0
        ? ((catEgp / totalWealthEgp) * 100).clamp(0, 100)
        : 0.0;

    final Color borderColor = isDark
        ? const Color(0xFFFFC928).withValues(alpha: 0.45)
        : const Color(0xFFC5A059).withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.tr('metals')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMetalOptions(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          ResponsiveLayout.compactHorizontalPadding(context),
          16,
          ResponsiveLayout.compactHorizontalPadding(context),
          MediaQuery.paddingOf(context).bottom + 96,
        ),
        children: <Widget>[
          // Hero Summary Card
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
                              Text(
                                context.l10n.tr('metals').toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFFFC928),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  balancesHidden
                                      ? '••••••'
                                      : ZakatEngineService.formatCurrency(
                                          metalsTotalMain,
                                          mainCurrency,
                                          isArabic: isArabic,
                                        ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${gold24k.toStringAsFixed(1)} g 24K • ${silverGrams.toStringAsFixed(1)} g Ag',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                    '${goldList.length + silverList.length} ${context.l10n.tr('entries')}',
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
                                '${pct(metalsTotalEgp).toStringAsFixed(1)}% ${context.l10n.tr('of_total')}',
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

          // 1. Gold Card
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategoryDetailsScreen(
                    categoryType: 'gold',
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    radius: 20,
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFB7791F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.tr('gold'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${gold24k.toStringAsFixed(2)} g 24K',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        balancesHidden
                            ? '••••••'
                            : ZakatEngineService.formatCurrency(
                                goldTotalMain,
                                mainCurrency,
                                isArabic: isArabic,
                              ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pct(goldTotalEgp).toStringAsFixed(1)}% ${context.l10n.tr('of_total')}',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).hintColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 2. Silver Card
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategoryDetailsScreen(
                    categoryType: 'silver',
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    backgroundColor: Color(0xFFF3F4F6),
                    radius: 20,
                    child: Icon(
                      Icons.layers,
                      color: Color(0xFF4B5563),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.tr('silver'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${silverGrams.toStringAsFixed(1)} g',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        balancesHidden
                            ? '••••••'
                            : ZakatEngineService.formatCurrency(
                                silverTotalMain,
                                mainCurrency,
                                isArabic: isArabic,
                              ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pct(silverTotalEgp).toStringAsFixed(1)}% ${context.l10n.tr('of_total')}',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).hintColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMetalOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.auto_awesome, color: Color(0xFFB7791F)),
                  ),
                  title: Text('${context.l10n.tr('add_saving')} - ${context.l10n.tr('gold')}'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddSavingScreen(initialAssetType: 'gold'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3F4F6),
                    child: Icon(Icons.layers, color: Color(0xFF4B5563)),
                  ),
                  title: Text('${context.l10n.tr('add_saving')} - ${context.l10n.tr('silver')}'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddSavingScreen(initialAssetType: 'silver'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
