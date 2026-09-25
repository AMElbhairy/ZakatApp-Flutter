import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';

void main() {
  group('InvestmentAsset Installment Ordering', () {
    test('sortInstallmentPlan orders installments chronologically by date', () {
      final List<Map<String, dynamic>> rawPlan = <Map<String, dynamic>>[
        <String, dynamic>{'amount': 5000, 'date': '2026-09-15', 'isPaid': false},
        <String, dynamic>{'amount': 3000, 'date': '2026-06-15', 'isPaid': true},
        <String, dynamic>{'amount': 4000, 'date': '2026-07-15', 'isPaid': false},
      ];

      final List<Map<String, dynamic>> sorted =
          InvestmentAsset.sortInstallmentPlan(rawPlan);

      expect(sorted.length, 3);
      expect(sorted[0]['date'], '2026-06-15');
      expect(sorted[0]['amount'], 3000);
      expect(sorted[1]['date'], '2026-07-15');
      expect(sorted[1]['amount'], 4000);
      expect(sorted[2]['date'], '2026-09-15');
      expect(sorted[2]['amount'], 5000);
    });

    test('changing date from this month to 3 months back shifts it back in order', () {
      final List<Map<String, dynamic>> plan = <Map<String, dynamic>>[
        <String, dynamic>{'amount': 1000, 'date': '2026-07-01'},
        <String, dynamic>{'amount': 2000, 'date': '2026-08-01'},
        <String, dynamic>{'amount': 3000, 'date': '2026-09-01'},
      ];

      // User changes the 3rd installment (2026-09-01) to 3 months back (2026-06-01)
      final List<Map<String, dynamic>> updatedPlan =
          plan.map((e) => Map<String, dynamic>.from(e)).toList();
      updatedPlan[2]['date'] = '2026-06-01';
      updatedPlan[2]['recurrenceDate'] = '2026-06-01';

      final List<Map<String, dynamic>> sorted =
          InvestmentAsset.sortInstallmentPlan(updatedPlan);

      expect(sorted.length, 3);
      expect(sorted[0]['date'], '2026-06-01');
      expect(sorted[0]['amount'], 3000);
      expect(sorted[1]['date'], '2026-07-01');
      expect(sorted[1]['amount'], 1000);
      expect(sorted[2]['date'], '2026-08-01');
      expect(sorted[2]['amount'], 2000);
    });

    test('normalizeInstallmentPlan automatically returns chronologically sorted list', () {
      final dynamic raw = [
        {'amount': '2500', 'recurrenceDate': '2027-01-01', 'isPaid': 'false'},
        {'amount': '1500', 'date': '2026-05-01', 'isPaid': 'true'},
        {'amount': '2000', 'dueDate': '2026-11-01', 'isPaid': false},
      ];

      final List<Map<String, dynamic>> normalized =
          InvestmentAsset.normalizeInstallmentPlan(raw);

      expect(normalized.length, 3);
      expect(normalized[0]['date'], '2026-05-01');
      expect(normalized[0]['amount'], 1500.0);
      expect(normalized[0]['isPaid'], true);

      expect(normalized[1]['date'], '2026-11-01');
      expect(normalized[1]['amount'], 2000.0);
      expect(normalized[1]['isPaid'], false);

      expect(normalized[2]['date'], '2027-01-01');
      expect(normalized[2]['amount'], 2500.0);
      expect(normalized[2]['isPaid'], false);
    });
  });

  group('Obligations Rollover Logic', () {
    final MarketData market = MarketData.fromJson(<String, dynamic>{
      'goldPrice24kEgp': 3000.0,
      'silverPriceEgp': 40.0,
      'usdToEgp': 50.0,
    });

    test('unpaid previous months zakat and installments roll over into thisMonth dues', () {
      final DateTime now = DateTime.now();
      final String thisMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final DateTime prevMonth = DateTime(now.year, now.month - 2, 1);
      final String prevMonthKey =
          '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';
      final DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
      final String nextMonthKey =
          '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}';

      // Zakat schedule with:
      // 1 past unpaid month (prevMonthKey): 1000 EGP
      // 1 past paid month: 1500 EGP
      // 1 this month (thisMonthKey): 2000 EGP
      // 1 next month (nextMonthKey): 2500 EGP
      final List<Map<String, dynamic>> schedule = <Map<String, dynamic>>[
        <String, dynamic>{
          'monthKey': prevMonthKey,
          'paymentDate': '$prevMonthKey-01',
          'totalZakat': 1000.0,
        },
        <String, dynamic>{
          'monthKey': '${prevMonth.year}-${(prevMonth.month - 1).toString().padLeft(2, '0')}',
          'paymentDate': '${prevMonth.year}-${(prevMonth.month - 1).toString().padLeft(2, '0')}-01',
          'totalZakat': 1500.0,
        },
        <String, dynamic>{
          'monthKey': thisMonthKey,
          'paymentDate': '$thisMonthKey-01',
          'totalZakat': 2000.0,
        },
        <String, dynamic>{
          'monthKey': nextMonthKey,
          'paymentDate': '$nextMonthKey-01',
          'totalZakat': 2500.0,
        },
      ];

      final List<String> zakatPaidMonths = <String>[
        '${prevMonth.year}-${(prevMonth.month - 1).toString().padLeft(2, '0')}',
      ];

      // Investments with installments:
      // 1 past unpaid installment: 3000 EGP
      // 1 past paid installment: 4000 EGP
      // 1 this month installment: 5000 EGP
      // 1 next month installment: 6000 EGP
      final List<InvestmentAsset> investments = <InvestmentAsset>[
        InvestmentAsset(
          id: 'inv1',
          investmentType: 'property',
          assetSubtype: 'Apartment',
          ownershipType: 'sole',
          valuationMode: 'market',
          currency: 'EGP',
          originalPrice: 100000,
          totalInterest: 0,
          totalPayable: 100000,
          paidAmount: 50000,
          remainingAmount: 50000,
          installmentPlan: <Map<String, dynamic>>[
            <String, dynamic>{
              'amount': 3000.0,
              'date': '$prevMonthKey-10',
              'currency': 'EGP',
              'isPaid': false,
            },
            <String, dynamic>{
              'amount': 4000.0,
              'date': '$prevMonthKey-05',
              'currency': 'EGP',
              'isPaid': true,
            },
            <String, dynamic>{
              'amount': 5000.0,
              'date': '$thisMonthKey-15',
              'currency': 'EGP',
              'isPaid': false,
            },
            <String, dynamic>{
              'amount': 6000.0,
              'date': '$nextMonthKey-15',
              'currency': 'EGP',
              'isPaid': false,
            },
          ],
          valuationDate: '2026-01-01',
          marketValue: 100000,
          marketValueDate: '2026-01-01',
          valuationSource: 'manual',
          loanBalance: 14000,
          loanAsOfDate: '2026-01-01',
          paidAmountToDate: 50000,
          ownershipSharePct: 100,
          country: 'EG',
          location: 'Cairo',
          inflationRateAnnual: 0,
          estimatedCurrentValue: 100000,
          description: 'Apartment',
          noZakat: false,
          createdAt: '2026-01-01',
        ),
      ];

      // Simulate the _computeDues logic
      double thisMonthDues = 0;
      double nextMonthDues = 0;

      // 1. Zakat dues
      for (final item in schedule) {
        final String monthKey = (item['monthKey'] ?? '').toString();
        final String paymentDateRaw = (item['paymentDate'] ?? '').toString();
        final DateTime? paymentDate = DateTime.tryParse(paymentDateRaw);
        final String scheduleMonthKey = paymentDate == null
            ? monthKey.length >= 7
                ? monthKey.substring(0, 7)
                : monthKey
            : '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}';
        final double value = ((item['totalZakat'] ?? 0) as num).toDouble();

        if (scheduleMonthKey.isNotEmpty &&
            scheduleMonthKey.compareTo(thisMonthKey) <= 0) {
          if (!zakatPaidMonths.contains(monthKey)) {
            thisMonthDues += value;
          }
        } else if (scheduleMonthKey == nextMonthKey) {
          if (!zakatPaidMonths.contains(monthKey)) {
            nextMonthDues += value;
          }
        }
      }

      // 2. Installments dues
      for (final asset in investments) {
        for (final installment in asset.installmentPlan) {
          final bool isPaid = installment['isPaid'] == true;
          if (isPaid) continue;

          final String rawDate =
              InvestmentAsset.installmentDueDate(installment);
          final DateTime? parsedDate = DateTime.tryParse(rawDate);
          if (parsedDate == null) continue;

          final String installmentMonthKey =
              '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}';

          final double amount =
              (installment['amount'] as num?)?.toDouble() ?? 0.0;
          final String currency =
              (installment['currency'] ?? asset.currency).toString();
          final double amountEgp = ZakatEngineService.convertToEgp(
            amount,
            currency,
            market,
          );

          if (installmentMonthKey.isNotEmpty &&
              installmentMonthKey.compareTo(thisMonthKey) <= 0) {
            thisMonthDues += amountEgp;
          } else if (installmentMonthKey == nextMonthKey) {
            nextMonthDues += amountEgp;
          }
        }
      }

      // Expected thisMonth:
      // Past unpaid Zakat (1000) + This Month Zakat (2000) + Past unpaid Installment (3000) + This Month Installment (5000) = 11000
      expect(thisMonthDues, 11000.0);

      // Expected nextMonth:
      // Next Month Zakat (2500) + Next Month Installment (6000) = 8500
      expect(nextMonthDues, 8500.0);
    });

    test('obligations list filter logic properly partitions items by filterMode', () {
      final DateTime now = DateTime.now();
      final String thisMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final DateTime prevMonth = DateTime(now.year, now.month - 1, 1);
      final String prevMonthKey =
          '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';
      final DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
      final String nextMonthKey =
          '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}';

      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[
        {'id': '1', 'monthKey': prevMonthKey, 'isPaid': false}, // Past unpaid
        {'id': '2', 'monthKey': prevMonthKey, 'isPaid': true},  // Past paid
        {'id': '3', 'monthKey': thisMonthKey, 'isPaid': false}, // Current unpaid
        {'id': '4', 'monthKey': thisMonthKey, 'isPaid': true},  // Current paid
        {'id': '5', 'monthKey': nextMonthKey, 'isPaid': false}, // Next unpaid
      ];

      List<Map<String, dynamic>> filter(String mode) {
        return items.where((item) {
          final String itemMonthKey = item['monthKey'];
          final bool isPaid = item['isPaid'];
          if (mode == 'this_month') {
            if (itemMonthKey == thisMonthKey) return true;
            if (itemMonthKey.compareTo(thisMonthKey) < 0) return !isPaid;
            return false;
          } else if (mode == 'next_month') {
            return itemMonthKey == nextMonthKey;
          } else {
            if (itemMonthKey == thisMonthKey || itemMonthKey == nextMonthKey) {
              return true;
            }
            if (itemMonthKey.compareTo(thisMonthKey) < 0) return !isPaid;
            return false;
          }
        }).toList();
      }

      final thisMonthItems = filter('this_month');
      // Should include: 1 (past unpaid), 3 (current unpaid), 4 (current paid). NOT 2 (past paid) or 5 (next).
      expect(thisMonthItems.map((e) => e['id']).toList(), ['1', '3', '4']);

      final nextMonthItems = filter('next_month');
      // Should include: 5
      expect(nextMonthItems.map((e) => e['id']).toList(), ['5']);

      final totalItems = filter('total');
      // Should include: 1 (past unpaid), 3 (current unpaid), 4 (current paid), 5 (next)
      expect(totalItems.map((e) => e['id']).toList(), ['1', '3', '4', '5']);
    });
  });
}
