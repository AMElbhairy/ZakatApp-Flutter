import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_controller.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const List<String> _supportedCurrencies = <String>[
    'EGP',
    'SAR',
    'USD',
    'AED',
    'KWD',
    'QAR',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.state;

    final String mainCurrency = state.mainCurrency.isEmpty ? 'EGP' : state.mainCurrency;
    final String defaultEntryCurrency =
        state.defaultEntryCurrency.isEmpty ? 'EGP' : state.defaultEntryCurrency;
    final String zakatMethod = state.zakatMethod == 'annual' ? 'annual' : 'hawl';

    final _AnnualDate annualDate = _AnnualDate.parse(state.zakatAnnualDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Account',
          child: const Text('Sign-in and profile settings will be available in a later phase.'),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Currency',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const Key('settingsMainCurrencyField'),
                initialValue: _supportedCurrencies.contains(mainCurrency)
                    ? mainCurrency
                    : 'EGP',
                decoration: const InputDecoration(
                  labelText: 'Main Currency',
                  border: OutlineInputBorder(),
                ),
                items: _supportedCurrencies
                    .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value == null) return;
                  context.read<AppStateController>().updateMainCurrency(value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('settingsDefaultEntryCurrencyField'),
                initialValue: _supportedCurrencies.contains(defaultEntryCurrency)
                    ? defaultEntryCurrency
                    : 'EGP',
                decoration: const InputDecoration(
                  labelText: 'Default Entry Currency',
                  border: OutlineInputBorder(),
                ),
                items: _supportedCurrencies
                    .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value == null) return;
                  context
                      .read<AppStateController>()
                      .updateDefaultEntryCurrency(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Zakat Calculation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const Key('settingsZakatMethodField'),
                initialValue: zakatMethod,
                decoration: const InputDecoration(
                  labelText: 'Method',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'hawl',
                    child: Text('Monthly / Hawl'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'annual',
                    child: Text('Annual'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  context.read<AppStateController>().updateZakatMethod(value);
                },
              ),
              if (zakatMethod == 'annual') ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  key: const Key('settingsAnnualDateSection'),
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const Key('settingsHijriMonthField'),
                        initialValue: annualDate.month,
                        decoration: const InputDecoration(
                          labelText: 'Hijri Month',
                          border: OutlineInputBorder(),
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          12,
                          (int index) {
                            final int m = index + 1;
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(m.toString()),
                            );
                          },
                          growable: false,
                        ),
                        onChanged: (int? value) {
                          if (value == null) return;
                          final int d = annualDate.day > _hijriMonthLength(value)
                              ? _hijriMonthLength(value)
                              : annualDate.day;
                          _updateAnnualDate(value, d);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const Key('settingsHijriDayField'),
                        initialValue: annualDate.day,
                        decoration: const InputDecoration(
                          labelText: 'Hijri Day',
                          border: OutlineInputBorder(),
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          _hijriMonthLength(annualDate.month),
                          (int index) {
                            final int d = index + 1;
                            return DropdownMenuItem<int>(
                              value: d,
                              child: Text(d.toString()),
                            );
                          },
                          growable: false,
                        ),
                        onChanged: (int? value) {
                          if (value == null) return;
                          _updateAnnualDate(annualDate.month, value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Appearance',
          child: const Text('Theme mode (System / Light / Dark) will be wired in a later phase.'),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Backup & Sync',
          child: const Text('Backup and sync options will be available in a later phase.'),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'About',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('ZakatApp'),
              SizedBox(height: 4),
              Text('Version: 1.0.0 (placeholder)'),
              SizedBox(height: 4),
              Text('Build/Branch: local-dev (placeholder)'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateAnnualDate(int month, int day) {
    final String mm = month.toString().padLeft(2, '0');
    final String dd = day.toString().padLeft(2, '0');
    return context.read<AppStateController>().updateZakatAnnualDate('$mm-$dd');
  }

  static int _hijriMonthLength(int month) {
    // Reuses the same convention used in engine/schedule code.
    return month == 12 ? 30 : ((month % 2 == 1) ? 30 : 29);
  }
}

class _AnnualDate {
  const _AnnualDate({required this.month, required this.day});

  final int month;
  final int day;

  factory _AnnualDate.parse(String raw) {
    final List<String> parts = raw.split('-');
    final int m = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final int d = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final int safeMonth = m.clamp(1, 12);
    final int maxDay = _AccountScreenState._hijriMonthLength(safeMonth);
    final int safeDay = d.clamp(1, maxDay);
    return _AnnualDate(month: safeMonth, day: safeDay);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
