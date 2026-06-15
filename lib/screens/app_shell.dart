import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_theme_extensions.dart';
import '../core/widgets/app_ui.dart';
import '../services/cloud_backup_controller.dart';

import 'account/account_screen.dart';
import 'activity/activity_screen.dart';
import 'assets/assets_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'entry/add_investment_screen.dart';
import 'entry/add_financial_plan_screen.dart';
import 'entry/add_saving_screen.dart';
import 'entry/add_transaction_screen.dart';
import 'plans/plans_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 2;
  final GlobalKey<ActivityScreenState> _activityKey =
      GlobalKey<ActivityScreenState>();
  final List<ScrollController> _tabScrollControllers =
      List<ScrollController>.generate(
        5,
        (int index) => ScrollController(
          debugLabel: 'app-shell-tab-$index',
          keepScrollOffset: true,
        ),
      );
  bool _restorePromptVisible = false;
  double? _edgeDragDistance;

  @override
  void dispose() {
    for (final ScrollController controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTabTap(int index) {
    if (index != _index) {
      setState(() => _index = index);
      return;
    }

    final ScrollController controller = _tabScrollControllers[index];
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final CloudBackupController? cloudBackupController = context
        .watch<CloudBackupController?>();
    _maybeShowRestorePrompt(context, cloudBackupController);
    final List<Widget> tabContents = <Widget>[
      AssetsScreen(
        onViewAllActivity: () {
          setState(() => _index = 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _activityKey.currentState?.showTransactions();
          });
        },
      ),
      ActivityScreen(key: _activityKey),
      DashboardScreen(
        onViewAllActivity: () {
          setState(() => _index = 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _activityKey.currentState?.showTransactions();
          });
        },
        onOpenAddActions: () => _showAddActions(context),
        onOpenZakatSchedule: () {
          setState(() => _index = 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _activityKey.currentState?.showSchedule();
          });
        },
        onOpenAddTransaction: (String type) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddTransactionScreen(initialType: type),
            ),
          );
        },
        onOpenAddAsset: () => _showAddAssetActions(context),
        onViewAssets: () => setState(() => _index = 0),
      ),
      const PlansScreen(),
      const AccountScreen(),
    ];
    final List<Widget> tabs = List<Widget>.generate(
      tabContents.length,
      (int index) => PrimaryScrollController(
        controller: _tabScrollControllers[index],
        child: tabContents[index],
      ),
    );

    final double navTouchBlockHeight = 90 + bottomInset;
    final bool allowEdgeSwipe = defaultTargetPlatform == TargetPlatform.iOS;
    return PopScope<void>(
      canPop: _index == 2,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop && _index != 2) {
          setState(() => _index = 2);
        }
      },
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: IndexedStack(index: _index, children: tabs),
            ),
            if (allowEdgeSwipe && _index != 2)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: navTouchBlockHeight,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    _edgeDragDistance = 0;
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    final bool isRtl =
                        Directionality.of(context) == TextDirection.rtl;
                    final double delta = details.primaryDelta ?? 0;
                    _edgeDragDistance =
                        (_edgeDragDistance ?? 0) + (isRtl ? -delta : delta);
                    if ((_edgeDragDistance ?? 0) > 56) {
                      setState(() => _index = 2);
                      _edgeDragDistance = null;
                    }
                  },
                  onHorizontalDragEnd: (DragEndDetails details) {
                    final bool isRtl =
                        Directionality.of(context) == TextDirection.rtl;
                    final double velocity = details.primaryVelocity ?? 0;
                    final bool swipedBack = isRtl
                        ? velocity < -500
                        : velocity > 500;
                    if (swipedBack) {
                      setState(() => _index = 2);
                    }
                    _edgeDragDistance = null;
                  },
                  onHorizontalDragCancel: () {
                    _edgeDragDistance = null;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: navTouchBlockHeight,
              child: const AbsorbPointer(
                absorbing: true,
                child: SizedBox.expand(),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 2 + bottomInset,
              child: SizedBox(
                key: const Key('premiumBottomNav'),
                height: 86,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final List<_NavItemData> items = <_NavItemData>[
                      _NavItemData(
                        icon: AppIcons.assets,
                        label: context.l10n.tr('assets'),
                      ),
                      _NavItemData(
                        icon: AppIcons.activity,
                        label: context.l10n.tr('activity'),
                      ),
                      _NavItemData(
                        icon: AppIcons.dashboard,
                        label: context.l10n.tr('dashboard'),
                      ),
                      _NavItemData(
                        icon: AppIcons.plans,
                        label: context.l10n.tr('plans'),
                      ),
                      _NavItemData(
                        icon: AppIcons.account,
                        label: context.l10n.tr('account'),
                      ),
                    ];
                    const double navHeight = 58;
                    const double dashboardRaisedHeight = 66;
                    const double dashboardRaisedWidth = 97;
                    final double slotWidth =
                        constraints.maxWidth / items.length;
                    const int dashboardIndex = 2;
                    final double selectedLeft =
                        (slotWidth * dashboardIndex) +
                        ((slotWidth - dashboardRaisedWidth) / 2);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: navHeight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.pill,
                              color: const Color(0xFF02201A),
                              border: Border.all(
                                color: const Color(
                                  0xFFC5A059,
                                ).withValues(alpha: 0.30),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                  offset: const Offset(0, 1),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: List<Widget>.generate(items.length, (
                                int i,
                              ) {
                                final bool selected = i == _index;
                                final _NavItemData item = items[i];
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      end: i == 1 ? 12 : 0,
                                      start: i == 3 ? 12 : 0,
                                    ),
                                    child: GestureDetector(
                                      key: Key('bottomNavTab_$i'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _handleTabTap(i),
                                      child: i == dashboardIndex
                                          ? const SizedBox.shrink()
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                Container(
                                                  decoration: selected
                                                      ? BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: <BoxShadow>[
                                                            BoxShadow(
                                                              color:
                                                                  const Color(
                                                                    0xFFD4AF37,
                                                                  ).withValues(
                                                                    alpha: 0.18,
                                                                  ),
                                                              blurRadius: 8,
                                                              spreadRadius: 0.2,
                                                            ),
                                                          ],
                                                        )
                                                      : null,
                                                  child: Icon(
                                                    item.icon,
                                                    size: 18,
                                                    color: selected
                                                        ? const Color(
                                                            0xFFD4AF37,
                                                          )
                                                        : const Color(
                                                            0xFFA3B8B5,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontSize: 10.5,
                                                        fontWeight: selected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: selected
                                                            ? const Color(
                                                                0xFFD4AF37,
                                                              )
                                                            : const Color(
                                                                0xFFA3B8B5,
                                                              ),
                                                        shadows: selected
                                                            ? <Shadow>[
                                                                Shadow(
                                                                  color:
                                                                      const Color(
                                                                        0xFFD4AF37,
                                                                      ).withValues(
                                                                        alpha:
                                                                            0.28,
                                                                      ),
                                                                  blurRadius: 8,
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        Positioned(
                          left: selectedLeft,
                          bottom: -4,
                          child: GestureDetector(
                            key: const Key('bottomNavDashboardTab'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _handleTabTap(dashboardIndex),
                            child: _dashboardRaisedItem(
                              item: items[dashboardIndex],
                              selected: _index == dashboardIndex,
                              width: dashboardRaisedWidth,
                              height: dashboardRaisedHeight,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            PositionedDirectional(
              start: 22,
              bottom: 75 + bottomInset,
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  key: const Key('addEntryFab'),
                  onPressed: () => _showAddActions(context),
                  backgroundColor: const Color(0xFF012E26),
                  foregroundColor: const Color(0xFFD4AF37),
                  elevation: 0,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: const Color(0xFFC5A059).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(AppIcons.add, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybeShowRestorePrompt(
    BuildContext context,
    CloudBackupController? cloudBackupController,
  ) {
    if (_restorePromptVisible || cloudBackupController == null) return;
    if (!cloudBackupController.shouldPromptRestore) return;
    _restorePromptVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bool? restore = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Cloud backup found'),
          content: Text(
            cloudBackupController.latestBackup?.effectiveUpdatedAt == null
                ? 'A Google Drive backup was found. Restore now?'
                : 'A Google Drive backup was found from '
                      '${cloudBackupController.latestBackup!.effectiveUpdatedAt!.toLocal()}. Restore now?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (restore == true) {
        final bool ok = await cloudBackupController.restoreLatestBackup();
        if (!mounted) return;
        showTopSnackBar(
          this.context,
          ok ? 'Cloud restore completed.' : cloudBackupController.statusMessage,
        );
      } else {
        cloudBackupController.dismissRestorePrompt();
      }
      _restorePromptVisible = false;
    });
  }

  Widget _dashboardRaisedItem({
    required _NavItemData item,
    required bool selected,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: const Color(0xFF012E26),
        border: Border.all(
          color: selected
              ? const Color(0xFFC5A059)
              : const Color(0xFF0B4A43).withValues(alpha: 0.85),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          if (selected)
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
              blurRadius: 12,
              spreadRadius: 1.0,
              offset: const Offset(0, 1),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.25 : 0.12),
            blurRadius: selected ? 8 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            decoration: selected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                        blurRadius: 6,
                        spreadRadius: 0.15,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              item.icon,
              color: selected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFA3B8B5),
              size: 23,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFA3B8B5),
              shadows: selected
                  ? <Shadow>[
                      Shadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: context.l10n.tr('add_entry'),
                  bottomSpacing: 8,
                ),
                // Add Income
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  key: const Key('actionAddIncome'),
                  leading: const Icon(Icons.trending_up_outlined),
                  title: Text(context.l10n.tr('add_income')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const AddTransactionScreen(initialType: 'income'),
                      ),
                    );
                  },
                ),
                // Add Expense
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  key: const Key('actionAddExpense'),
                  leading: const Icon(Icons.trending_down_outlined),
                  title: Text(context.l10n.tr('add_expense')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const AddTransactionScreen(initialType: 'expense'),
                      ),
                    );
                  },
                ),
                // Add Savings
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  key: const Key('actionAddSaving'),
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(context.l10n.tr('add_saving')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddSavingScreen(),
                      ),
                    );
                  },
                ),
                // Add Investment
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  key: const Key('actionAddInvestment'),
                  leading: const Icon(Icons.business_outlined),
                  title: Text(context.l10n.tr('add_investment')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddInvestmentScreen(),
                      ),
                    );
                  },
                ),
                // Add Plan
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  key: const Key('actionAddPlan'),
                  leading: const Icon(Icons.auto_graph_outlined),
                  title: Text(context.l10n.tr('add_plan')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddFinancialPlanScreen(),
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

  Future<void> _showAddAssetActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: context.l10n.tr('add_asset'),
                  bottomSpacing: 8,
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(context.l10n.tr('add_saving')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddSavingScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.business_outlined),
                  title: Text(context.l10n.tr('add_investment')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddInvestmentScreen(),
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

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
