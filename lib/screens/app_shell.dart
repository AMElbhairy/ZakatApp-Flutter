import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
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
  int _index = 0;
  final GlobalKey<ActivityScreenState> _activityKey =
      GlobalKey<ActivityScreenState>();

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      DashboardScreen(
        onViewAllActivity: () {
          setState(() => _index = 2);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _activityKey.currentState?.showTransactions();
          });
        },
        onOpenAddActions: () => _showAddActions(context),
        onOpenZakatSchedule: () {
          setState(() => _index = 2);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _activityKey.currentState?.showSchedule();
          });
        },
      ),
      const AssetsScreen(),
      ActivityScreen(key: _activityKey),
      const PlansScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: false,
      body: SafeArea(
        bottom: true,
        child: IndexedStack(index: _index, children: tabs),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        key: const Key('addEntryFab'),
        onPressed: () => _showAddActions(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int i) => setState(() => _index = i),
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: context.l10n.tr('dashboard'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: context.l10n.tr('assets'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: context.l10n.tr('activity'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_graph_outlined),
              selectedIcon: const Icon(Icons.auto_graph),
              label: context.l10n.tr('plans'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.l10n.tr('account'),
            ),
          ],
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
