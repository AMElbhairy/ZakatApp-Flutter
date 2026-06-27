import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/zakat_engine.dart';
import '../../core/utils/currency_presentation.dart';
import '../../models/market_snapshot.dart';
import '../../services/app_state_controller.dart';

class MarketSnapshotScreen extends StatelessWidget {
  const MarketSnapshotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController controller = context.watch<AppStateController>();
    final MarketSnapshot snapshot = controller.currentMarketSnapshot;
    final MarketData marketData = MarketData.fromJson(controller.state.marketData);
    final String displayCurrency = controller.state.mainCurrency.trim().isEmpty
        ? 'EGP'
        : controller.state.mainCurrency.trim();
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('market_data_section'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          _HeaderCard(
            title: isArabic ? 'قراءة فقط' : 'Read only',
            subtitle: isArabic
                ? 'أسعار الذهب والعملات الحالية'
                : 'Current gold and currency prices',
          ),
          const SizedBox(height: 12),
          _PriceSection(
            title: isArabic ? 'المعادن' : 'Metals',
            children: <Widget>[
              _PriceRow(
                label: isArabic ? 'ذهب 24K' : 'Gold 24K',
                value: _pricePerGram(
                  snapshot.gold24kPricePerGramEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: isArabic ? 'فضة' : 'Silver',
                value: _pricePerGram(
                  snapshot.silverPricePerGramEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PriceSection(
            title: isArabic ? 'العملات' : 'Currencies',
            children: <Widget>[
              _PriceRow(
                label: CurrencyPresentation.label('EGP'),
                value: _rate(
                  1,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('SAR'),
                value: _rate(
                  snapshot.sarToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('USD'),
                value: _rate(
                  snapshot.usdToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('AED'),
                value: _rate(
                  snapshot.aedToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('KWD'),
                value: _rate(
                  snapshot.kwdToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('QAR'),
                value: _rate(
                  snapshot.qarToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('EUR'),
                value: _rate(
                  snapshot.eurToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('GBP'),
                value: _rate(
                  snapshot.gbpToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('BHD'),
                value: _rate(
                  snapshot.bhdToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('OMR'),
                value: _rate(
                  snapshot.omrToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('JOD'),
                value: _rate(
                  snapshot.jodToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('TRY'),
                value: _rate(
                  snapshot.tryToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('MYR'),
                value: _rate(
                  snapshot.myrToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('PKR'),
                value: _rate(
                  snapshot.pkrToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
              _PriceRow(
                label: CurrencyPresentation.label('IDR'),
                value: _rate(
                  snapshot.idrToEgp,
                  currency: displayCurrency,
                  marketData: marketData,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HeaderCard(
            title: context.l10n.tr('last_updated'),
            subtitle: _formatLastUpdated(snapshot.lastUpdated),
          ),
        ],
      ),
    );
  }

  String _pricePerGram(
    double valueEgp, {
    required String currency,
    required MarketData marketData,
  }) {
    if (valueEgp <= 0) return '-';
    final double converted = ZakatEngineService.convertFromEgp(
      valueEgp,
      currency,
      marketData,
    );
    if (converted.isNaN) return '-';
    return '${ZakatEngineService.formatCurrency(converted, currency)}/g';
  }

  String _rate(
    double valueEgp, {
    required String currency,
    required MarketData marketData,
  }) {
    if (valueEgp <= 0) return '-';
    final double converted = ZakatEngineService.convertFromEgp(
      valueEgp,
      currency,
      marketData,
    );
    if (converted.isNaN) return '-';
    return ZakatEngineService.formatCurrency(converted, currency);
  }

  String _formatLastUpdated(String raw) {
    if (raw.trim().isEmpty) return '-';
    try {
      return DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.parse(raw).toLocal());
    } catch (_) {
      final RegExp legacy = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$',
      );
      final Match? match = legacy.firstMatch(raw.trim());
      if (match == null) return raw;
      final DateTime parsed = DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
      return DateFormat('yyyy-MM-dd HH:mm').format(parsed);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
