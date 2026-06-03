import re

with open('lib/screens/dashboard/dashboard_screen.dart', 'r') as f:
    content = f.read()

start_marker = "class _PremiumHeroCard extends StatelessWidget {"
end_marker = "class _QuickActionsRow extends StatelessWidget {"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Markers not found!")
    exit(1)

new_hero = """class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.totalWealthEgp,
    required this.netPositionEgp,
    required this.dues,
    required this.nisabMet,
    required this.hasMarketData,
    required this.hasFxData,
    required this.state,
    required this.market,
    required this.nextZakatDate,
    required this.balancesHidden,
    required this.heroGrowth,
  });

  final double totalWealthEgp;
  final double netPositionEgp;
  final _Dues dues;
  final bool nisabMet;
  final bool hasMarketData;
  final bool hasFxData;
  final dynamic state;
  final MarketData market;
  final String? nextZakatDate;
  final bool balancesHidden;
  final _HeroGrowthData? heroGrowth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final textTheme = Theme.of(context).textTheme;
    final String nisabLabel = hasMarketData
        ? (nisabMet
              ? context.l10n.tr('above_nisab')
              : context.l10n.tr('below_nisab'))
        : (hasFxData
              ? context.l10n.tr('gold_silver_required')
              : context.l10n.tr('market_data_required'));
    final String hiddenValue = '••••••';
    final bool showGrowth = heroGrowth != null && !balancesHidden;

    final List<_HeroSupportItem> supportItems = <_HeroSupportItem>[
      _HeroSupportItem(
        label: context.l10n.tr('net_position'),
        icon: Icons.shield_outlined,
        value: balancesHidden
            ? hiddenValue
            : _DashboardScreenState._formatCompactOrMissing(
                context,
                netPositionEgp,
                hasMarketData,
                state.mainCurrency,
                market,
              ),
      ),
      _HeroSupportItem(
        label: context.l10n.tr('total_upcoming_dues'),
        icon: Icons.calendar_today_outlined,
        value: balancesHidden
            ? hiddenValue
            : _DashboardScreenState._formatCompactOrMissing(
                context,
                dues.totalUpcoming,
                hasMarketData,
                state.mainCurrency,
                market,
              ),
      ),
      _HeroSupportItem(
        label: context.l10n.tr('next_zakat_date'),
        icon: Icons.nightlight_round,
        value: balancesHidden ? hiddenValue : (nextZakatDate ?? '--'),
      ),
    ];

    return PremiumCard(
      key: const Key('dashboardHeroCard'),
      hero: true,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 380;
          final bool tablet = constraints.maxWidth >= 700;
          final double heroHeight = tablet ? 380 : (compact ? 360 : 380);
          final double artworkWidth = constraints.maxWidth * (tablet ? 0.35 : 0.40);

          return SizedBox(
            height: heroHeight,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                tokens.colors.emerald.withValues(alpha: 0.1),
                                tokens.colors.emerald.withValues(alpha: 0.2),
                                tokens.colors.gold.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        bottom: 0,
                        width: artworkWidth,
                        child: IgnorePointer(
                          child: _HeroArtwork(width: artworkWidth),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    context.l10n.tr('total_wealth').toUpperCase(),
                                    style: textTheme.titleSmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FractionallySizedBox(
                                    widthFactor: compact ? 1.0 : 0.9,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: _AnimatedAmountText(
                                      valueEgp: totalWealthEgp,
                                      hasMarketData: hasMarketData,
                                      mainCurrency: state.mainCurrency,
                                      marketData: market,
                                      hidden: balancesHidden,
                                    ),
                                  ),
                                  if (showGrowth) ...<Widget>[
                                    const SizedBox(height: 12),
                                    _HeroGrowthRow(growth: heroGrowth!),
                                  ],
                                  const SizedBox(height: 16),
                                  _HeroStatusPanel(
                                    label: nisabLabel,
                                    subtitle: hasMarketData && nisabMet
                                        ? 'Wealth Protected'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: artworkWidth),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _HeroMetricsBar(items: supportItems),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroSupportItem {
  const _HeroSupportItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _HeroGrowthData {
  const _HeroGrowthData({required this.changePct, required this.points});

  final double changePct;
  final List<double> points;
}

class _WealthHistoryPoint {
  const _WealthHistoryPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            right: width * 0.1,
            top: width * 0.1,
            child: Icon(
              Icons.nightlight_round,
              size: width * 0.15,
              color: tokens.colors.gold.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            right: width * 0.35,
            top: width * 0.05,
            child: Icon(
              Icons.auto_awesome,
              size: width * 0.06,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            right: width * 0.15,
            top: width * 0.3,
            child: Icon(
              Icons.auto_awesome,
              size: width * 0.04,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          Positioned.fill(
            top: width * 0.1,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 1.0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/hero_mosque_watermark.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAmountText extends StatelessWidget {
  const _AnimatedAmountText({
    required this.valueEgp,
    required this.hasMarketData,
    required this.mainCurrency,
    required this.marketData,
    required this.hidden,
  });

  final double valueEgp;
  final bool hasMarketData;
  final String mainCurrency;
  final MarketData marketData;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return Text(
        '••••••',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -1.0,
        ),
      );
    }
    if (!hasMarketData) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    final String currency = mainCurrency.trim().isEmpty
        ? 'EGP'
        : mainCurrency.trim();
    final double displayValue = ZakatEngineService.convertFromEgp(
      valueEgp,
      currency,
      marketData,
    );
    if (displayValue.isNaN) {
      return Text(
        context.l10n.tr('market_data_required'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: displayValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, double value, Widget? child) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _DashboardScreenState._formatCompactDisplay(value, currency),
            maxLines: 1,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        );
      },
    );
  }
}

class _HeroSupportMetric extends StatelessWidget {
  const _HeroSupportMetric({required this.item});

  final _HeroSupportItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            item.icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGrowthRow extends StatelessWidget {
  const _HeroGrowthRow({required this.growth});

  final _HeroGrowthData growth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.trending_up_rounded, size: 18, color: tokens.colors.success),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '↑ ${_DashboardScreenState._formatPct(growth.changePct)} this year',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFCFF8E8),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (growth.points.length >= 2) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            height: 18,
            child: _HeroSparkline(points: growth.points),
          ),
        ],
      ],
    );
  }
}

class _HeroSparkline extends StatelessWidget {
  const _HeroSparkline({required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final double min = points.reduce((a, b) => a < b ? a : b);
    final double max = points.reduce((a, b) => a > b ? a : b);
    final double spread = (max - min).abs();
    final List<Offset> offsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final double x = points.length == 1 ? 0 : i / (points.length - 1);
      final double normalizedY = spread == 0
          ? 0.5
          : ((points[i] - min) / spread);
      offsets.add(Offset(x, 1 - normalizedY));
    }

    return CustomPaint(
      painter: _HeroSparklinePainter(
        points: offsets,
        color: const Color(0xFF7BE0B4),
      ),
    );
  }
}

class _HeroSparklinePainter extends CustomPainter {
  const _HeroSparklinePainter({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final Path path = Path();

    for (int i = 0; i < points.length; i++) {
      final Offset point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroSparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _HeroStatusPanel extends StatelessWidget {
  const _HeroStatusPanel({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.workspace_premium_rounded,
          size: 20,
          color: tokens.colors.gold,
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.colors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroMetricsBar extends StatelessWidget {
  const _HeroMetricsBar({required this.items});

  final List<_HeroSupportItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: List<Widget>.generate(items.length * 2 - 1, (int index) {
            if (index.isOdd) {
              return Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.1),
              );
            }

            final _HeroSupportItem item = items[index ~/ 2];
            return Expanded(child: _HeroSupportMetric(item: item));
          }),
        ),
      ),
    );
  }
}

"""

with open('lib/screens/dashboard/dashboard_screen.dart', 'w') as f:
    f.write(content[:start_idx] + new_hero + content[end_idx:])
