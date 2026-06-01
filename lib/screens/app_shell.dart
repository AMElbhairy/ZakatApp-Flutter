import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme_extensions.dart';
import '../core/widgets/app_ui.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      const AssetsScreen(),
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
      ),
      const PlansScreen(),
      const AccountScreen(),
    ];

    final tokens = context.premiumTokens;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: SafeArea(
        bottom: true,
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          height: 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.pill,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        tokens.colors.hero,
                        tokens.colors.emerald,
                      ],
                    ),
                    border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.25)),
                    boxShadow: tokens.mediumShadow,
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      indicatorColor: tokens.colors.gold.withValues(alpha: 0.22),
                      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
                        final bool selected = states.contains(WidgetState.selected);
                        return Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? tokens.colors.gold
                                  : Colors.white.withValues(alpha: 0.84),
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (int i) => setState(() => _index = i),
                      backgroundColor: Colors.transparent,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: <NavigationDestination>[
                        NavigationDestination(
                          icon: Icon(
                            AppIcons.assets,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          selectedIcon: Icon(AppIcons.assets, color: tokens.colors.gold),
                          label: context.l10n.tr('assets'),
                        ),
                        NavigationDestination(
                          icon: Icon(
                            AppIcons.activity,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          selectedIcon: Icon(AppIcons.activity, color: tokens.colors.gold),
                          label: context.l10n.tr('activity'),
                        ),
                        NavigationDestination(
                          icon: Icon(
                            AppIcons.dashboard,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          selectedIcon: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.pill,
                              color: Colors.black.withValues(alpha: 0.18),
                              border: Border.all(
                                color: tokens.colors.gold.withValues(alpha: 0.7),
                              ),
                              boxShadow: tokens.softShadow,
                            ),
                            child: Icon(AppIcons.dashboard, color: tokens.colors.gold, size: 22),
                          ),
                          label: context.l10n.tr('dashboard'),
                        ),
                        NavigationDestination(
                          icon: Icon(
                            AppIcons.plans,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          selectedIcon: Icon(AppIcons.plans, color: tokens.colors.gold),
                          label: context.l10n.tr('plans'),
                        ),
                        NavigationDestination(
                          icon: Icon(
                            AppIcons.account,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          selectedIcon: Icon(AppIcons.account, color: tokens.colors.gold),
                          label: context.l10n.tr('account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                bottom: 74,
                child: FloatingActionButton(
                  key: const Key('addEntryFab'),
                  onPressed: () => _showAddActions(context),
                  backgroundColor: tokens.colors.hero,
                  foregroundColor: tokens.colors.gold,
                  shape: const CircleBorder(),
                  child: const Icon(AppIcons.add, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddActions(BuildContext context) async {
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
                SectionHeader(title: context.l10n.tr('add_entry'), bottomSpacing: 8),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  key: const Key('actionAddTransaction'),
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(context.l10n.tr('add_income_expense')),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddTransactionScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}
