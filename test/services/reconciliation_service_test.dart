import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/reconciliation_service.dart';

void main() {
  final ReconciliationService service = ReconciliationService();

  AppStateModel makeState({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> savings,
    List<String>? processedExpenseIds,
  }) {
    final AppStateModel base = AppStateDefaults.create();
    return AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': transactions,
      'savings': savings,
      'processedExpenseIds': processedExpenseIds ?? <String>[],
    });
  }

  test('expense with enough wallet does not reduce savings', () {
    final AppStateModel state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'i1',
          'type': 'income',
          'date': '2024-01-01',
          'amount': 100,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-02',
          'amount': 20,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 50,
          'remainingAmount': 50,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.first.remainingAmount, 50);
  });

  test('expense with insufficient wallet reduces oldest cash saving first', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'i1',
          'type': 'income',
          'date': '2024-01-02',
          'amount': 10,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 30,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 25,
          'remainingAmount': 25,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.first.remainingAmount, 5);
  });

  test('multiple savings lots reduce FIFO', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 25,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'old',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 10,
          'remainingAmount': 10,
          'dateAcquired': '2024-01-01',
        },
        <String, dynamic>{
          'id': 'new',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-02',
        },
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.firstWhere((s) => s.id == 'old').remainingAmount, 0);
    expect(out.savings.firstWhere((s) => s.id == 'new').remainingAmount, 5);
  });

  test('processedExpenseIds prevents double deduction', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 10,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final once = service.reconcileExpensesWithSavings(state).state;
    final twice = service.reconcileExpensesWithSavings(once).state;
    expect(once.savings.first.remainingAmount, 10);
    expect(twice.savings.first.remainingAmount, 10);
    expect(twice.processedExpenseIds, contains('e1'));
  });

  test('post-rollover expense deducts from savings exactly once', () {
    final AppStateModel base = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2026-06-02',
          'amount': 20,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 100,
          'remainingAmount': 100,
          'dateAcquired': '2026-05-01',
        },
      ],
    );
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'lastRollover': '2026-05-31',
    });

    final AppStateModel once = service
        .reconcileExpensesWithSavings(state)
        .state;
    final AppStateModel twice = service
        .reconcileExpensesWithSavings(once)
        .state;

    expect(once.savings.single.remainingAmount, 80);
    expect(twice.savings.single.remainingAmount, 80);
    expect(twice.processedExpenseIds, contains('e1'));
  });

  test('deleting expense restores remainingAmount after reconciliation', () {
    final initial = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 10,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final deducted = service.reconcileExpensesWithSavings(initial).state;
    final restored = service
        .reconcileExpensesWithSavings(
          makeState(
            transactions: const <Map<String, dynamic>>[],
            savings: deducted.savings
                .map((s) => s.toJson())
                .toList(growable: false),
          ),
        )
        .state;

    expect(restored.savings.first.remainingAmount, 20);
  });

  test('updating expense recalculates correctly', () {
    final state1 = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 5,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
      ],
    );
    final once = service.reconcileExpensesWithSavings(state1).state;

    final state2 = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 15,
          'currency': 'EGP',
        },
      ],
      savings: once.savings.map((s) => s.toJson()).toList(growable: false),
    );
    final twice = service.reconcileExpensesWithSavings(state2).state;

    expect(twice.savings.first.remainingAmount, 5);
  });

  test('different currencies are isolated', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 10,
          'currency': 'USD',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
        <String, dynamic>{
          'id': 's2',
          'assetType': 'cash',
          'unit': 'USD',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;
    expect(out.savings.firstWhere((s) => s.unit == 'EGP').remainingAmount, 20);
    expect(out.savings.firstWhere((s) => s.unit == 'USD').remainingAmount, 10);
  });

  test(
    'imported backup missing remainingAmount normalized then reconciled',
    () {
      final state = makeState(
        transactions: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e1',
            'type': 'expense',
            'date': '2024-01-03',
            'amount': 10,
            'currency': 'EGP',
          },
        ],
        savings: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 's1',
            'assetType': 'cash',
            'unit': 'EGP',
            'amount': 20,
            'dateAcquired': '2024-01-01',
          },
        ],
      );

      final out = service.reconcileExpensesWithSavings(state).state;
      expect(out.savings.first.remainingAmount, 10);
    },
  );

  test('zakat wealth changes after reconciliation', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'type': 'expense',
          'date': '2024-01-03',
          'amount': 10,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 's1',
          'assetType': 'cash',
          'unit': 'EGP',
          'amount': 20,
          'remainingAmount': 20,
          'dateAcquired': '2024-01-01',
        },
      ],
    );

    final before = state.savings.first.remainingAmount;
    final after = service
        .reconcileExpensesWithSavings(state)
        .state
        .savings
        .first
        .remainingAmount;
    expect(after, lessThan(before));
  });

  test('net income lots deduct expenses from newest income first', () {
    final lots = service.getNetIncomeLotsForCurrency(
      currency: 'EGP',
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'income_mar',
          'type': 'income',
          'date': '2025-03-01',
          'amount': 100000,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'expense_mar',
          'type': 'expense',
          'date': '2025-03-15',
          'amount': 50000,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'income_apr',
          'type': 'income',
          'date': '2025-04-01',
          'amount': 100000,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'expense_may',
          'type': 'expense',
          'date': '2025-05-15',
          'amount': 125000,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'income_jun',
          'type': 'income',
          'date': '2025-06-01',
          'amount': 50000,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'expense_jun',
          'type': 'expense',
          'date': '2025-06-20',
          'amount': 25000,
          'currency': 'EGP',
        },
      ],
    );

    expect(
      lots
          .firstWhere((IncomeLot lot) => lot.id == 'income_mar')
          .remainingAmount,
      25000,
    );
    expect(
      lots
          .firstWhere((IncomeLot lot) => lot.id == 'income_apr')
          .remainingAmount,
      0,
    );
    expect(
      lots
          .firstWhere((IncomeLot lot) => lot.id == 'income_jun')
          .remainingAmount,
      25000,
    );
  });

  test(
    'metal funding allocation reduces source cash saving remaining amount',
    () {
      final state = makeState(
        transactions: const <Map<String, dynamic>>[],
        savings: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cash1',
            'assetType': 'cash',
            'unit': 'EGP',
            'amount': 1000,
            'remainingAmount': 1000,
            'dateAcquired': '2025-02-01',
          },
          <String, dynamic>{
            'id': 'gold1',
            'assetType': 'gold',
            'unit': '24',
            'amount': 10,
            'remainingAmount': 10,
            'dateAcquired': '2025-06-01',
            'purchaseCurrency': 'EGP',
            'purchaseAmount': 300,
            'fundingAllocations': <Map<String, dynamic>>[
              <String, dynamic>{
                'sourceType': 'savings',
                'sourceId': 'cash1',
                'sourceDate': '2025-02-01',
                'currency': 'EGP',
                'amount': 300,
              },
            ],
          },
        ],
      );

      final out = service.reconcileExpensesWithSavings(state).state;

      expect(
        out.savings.firstWhere((Saving s) => s.id == 'cash1').remainingAmount,
        700,
      );
      expect(
        out.savings.firstWhere((Saving s) => s.id == 'gold1').remainingAmount,
        10,
      );
    },
  );

  test('mark installment paid creates transaction and reduces liability', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'investments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inv1',
          'investmentType': 'real_estate',
          'assetSubtype': 'property',
          'ownershipType': 'installment',
          'valuationMode': 'manual',
          'currency': 'EGP',
          'originalPrice': 1000,
          'totalInterest': 0,
          'totalPayable': 1000,
          'paidAmount': 0,
          'remainingAmount': 1000,
          'installmentPlan': <Map<String, dynamic>>[
            <String, dynamic>{
              'recurrenceDate': '2026-01-01',
              'amount': 200,
              'currency': 'EGP',
              'isPaid': false,
            },
          ],
          'valuationDate': '2026-01-01',
          'marketValue': 1000,
          'marketValueDate': '2026-01-01',
          'valuationSource': 'manual',
          'loanBalance': 1000,
          'loanAsOfDate': '2026-01-01',
          'paidAmountToDate': 0,
          'ownershipSharePct': 100,
          'country': '',
          'location': 'Test',
          'inflationRateAnnual': 0,
          'estimatedCurrentValue': 1000,
          'description': '',
          'noZakat': false,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    });

    final out = service
        .toggleInstallmentPaid(
          input: state,
          assetId: 'inv1',
          installmentIndex: 0,
          paymentCategory: 'Housing & Rent',
          marketData: const MarketData(
            goldPrice24kEgp: 0,
            silverPriceEgp: 0,
            usdToEgp: 50,
            sarToEgp: 13,
            ratesToEgp: <String, double>{'EGP': 1},
          ),
        )
        .state;

    expect(
      out.transactions
          .where((t) => t.description.contains('Installment payment'))
          .length,
      1,
    );
    expect(
      out.transactions
          .firstWhere((t) => t.description.contains('Installment payment'))
          .date,
      '2026-01-01',
    );
    expect(out.investments.first.installmentPlan.single['date'], '2026-01-01');
    expect(out.investments.first.loanBalance, lessThan(1000));
  });

  test('duplicate installment payment prevented via toggle', () {
    final base = AppStateDefaults.create();
    final state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'investments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inv1',
          'investmentType': 'company_investment',
          'assetSubtype': 'company',
          'ownershipType': 'installment',
          'valuationMode': 'manual',
          'currency': 'EGP',
          'originalPrice': 1000,
          'totalInterest': 0,
          'totalPayable': 1000,
          'paidAmount': 0,
          'remainingAmount': 1000,
          'installmentPlan': <Map<String, dynamic>>[
            <String, dynamic>{
              'date': '2026-01-01',
              'amount': 200,
              'currency': 'EGP',
              'isPaid': false,
            },
          ],
          'valuationDate': '2026-01-01',
          'marketValue': 1000,
          'marketValueDate': '2026-01-01',
          'valuationSource': 'manual',
          'loanBalance': 1000,
          'loanAsOfDate': '2026-01-01',
          'paidAmountToDate': 0,
          'ownershipSharePct': 100,
          'country': '',
          'location': 'Test',
          'inflationRateAnnual': 0,
          'estimatedCurrentValue': 1000,
          'description': '',
          'noZakat': false,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    });
    final market = const MarketData(
      goldPrice24kEgp: 0,
      silverPriceEgp: 0,
      usdToEgp: 50,
      sarToEgp: 13,
      ratesToEgp: <String, double>{'EGP': 1},
    );

    final once = service
        .toggleInstallmentPaid(
          input: state,
          assetId: 'inv1',
          installmentIndex: 0,
          paymentCategory: 'Housing & Rent',
          marketData: market,
        )
        .state;
    final twice = service
        .toggleInstallmentPaid(
          input: once,
          assetId: 'inv1',
          installmentIndex: 0,
          paymentCategory: 'Housing & Rent',
          marketData: market,
        )
        .state;
    expect(
      twice.transactions.where(
        (t) => t.description.contains('Installment payment'),
      ),
      isEmpty,
    );
  });

  test(
    'mark zakat paid creates expense and duplicate prevented via toggle',
    () {
      final state = AppStateDefaults.create();
      final once = service
          .toggleZakatPaid(
            input: state,
            monthKey: '2026-06',
            zakatAmountMainCurrency: 500,
            mainCurrency: 'EGP',
            paymentDate: '2026-06-01',
          )
          .state;
      expect(once.transactions.where((t) => t.category == 'Zakat').length, 1);
      expect(once.zakatPaidMonths, contains('2026-06'));

      final twice = service
          .toggleZakatPaid(
            input: once,
            monthKey: '2026-06',
            zakatAmountMainCurrency: 500,
            mainCurrency: 'EGP',
            paymentDate: '2026-06-01',
          )
          .state;
      expect(twice.transactions.where((t) => t.category == 'Zakat'), isEmpty);
      expect(twice.zakatPaidMonths, isNot(contains('2026-06')));
    },
  );

  test('currency exchange creates linked pair and moves balances', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'i1',
          'type': 'income',
          'date': '2026-01-01',
          'amount': 100,
          'currency': 'USD',
          'category': 'Salary',
          'description': '',
        },
      ],
    });

    final out = service
        .executeCurrencyExchange(
          input: state,
          date: '2026-06-01',
          sourceCurrency: 'USD',
          targetCurrency: 'EGP',
          sourceAmount: 40,
          targetAmount: 2000,
        )
        .state;

    final expense = out.transactions.firstWhere((t) => t.type == 'expense');
    final income = out.transactions.firstWhere(
      (t) => t.type == 'income' && t.id != 'i1',
    );
    expect(expense.exchangePairId, isNotEmpty);
    expect(income.exchangePairId, expense.exchangePairId);
    expect(expense.activityType, 'transfer');
    expect(income.activityType, 'transfer');
    expect(expense.amount, 40);
    expect(income.amount, 2000);
  });

  test('savings currency exchange records a current activity timestamp', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cash-1',
          'assetType': 'cash',
          'dateAcquired': '2024-01-01',
          'amount': 100,
          'remainingAmount': 100,
          'unit': 'USD',
          'description': 'Old cash',
          'createdAt': '2024-01-01T00:00:00.000Z',
        },
      ],
    });

    final AppStateModel out = service
        .executeCurrencyExchange(
          input: state,
          date: '2026-06-01',
          sourceCurrency: 'USD',
          targetCurrency: 'EGP',
          sourceAmount: 40,
          targetAmount: 2000,
        )
        .state;

    final Saving exchanged = out.savings.firstWhere(
      (Saving saving) => saving.exchangeSourceSavingId == 'cash-1',
    );
    expect(exchanged.dateAcquired, '2024-01-01');
    expect(exchanged.createdAt, isNot('2024-01-01T00:00:00.000Z'));
    expect(exchanged.transferActivityId, isNotEmpty);
  });

  test('combined cash sources include income and legacy cash savings', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'income-1',
          'type': 'income',
          'date': '2026-02-01',
          'amount': 100,
          'currency': 'USD',
          'category': 'Salary',
          'description': 'Income source',
        },
      ],
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'legacy-cash',
          'assetType': 'cash',
          'dateAcquired': '2025-01-01',
          'amount': 75,
          'remainingAmount': 75,
          'unit': 'USD',
          'description': 'Legacy imported cash',
          'sourceIncomeId': 'legacy-income',
        },
      ],
    });

    final List<CashSource> sources = service.getAvailableCashSources(
      state: state,
      currency: 'USD',
    );

    expect(sources.map((CashSource source) => source.id), <String>[
      'legacy-cash',
      'income-1',
    ]);
    expect(
      sources.fold<double>(
        0,
        (double total, CashSource source) => total + source.availableAmount,
      ),
      175,
    );
    expect(service.getAvailableCashBalance(state: state, currency: 'USD'), 175);
    expect(service.getCashByCurrency(state)['USD'], 175);
  });

  test('positive legacy cash balance without a source row remains visible', () {
    final AppStateModel state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'legacy-income',
          'type': 'income',
          'date': '2026-06-01',
          'amount': 100,
          'currency': 'EGP',
        },
        <String, dynamic>{
          'id': 'legacy-expense',
          'type': 'expense',
          'date': '2026-06-02',
          'amount': 100,
          'currency': 'EGP',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'consumed-legacy-cash',
          'assetType': 'cash',
          'dateAcquired': '2026-05-01',
          'amount': 100,
          'remainingAmount': 0,
          'unit': 'EGP',
        },
      ],
    );

    final List<CashSource> sources = service.getAvailableCashSources(
      state: state,
      currency: 'EGP',
    );

    expect(service.getAvailableCashBalance(state: state, currency: 'EGP'), 100);
    expect(sources, hasLength(1));
    expect(sources.single.sourceType, 'legacy');
    expect(sources.single.availableAmount, 100);
  });

  test('currency exchange automatically deducts across all cash sources', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'income-1',
          'type': 'income',
          'date': '2026-02-01',
          'amount': 100,
          'currency': 'USD',
          'category': 'Salary',
          'description': '',
        },
      ],
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cash-1',
          'assetType': 'cash',
          'dateAcquired': '2025-01-01',
          'amount': 50,
          'remainingAmount': 50,
          'unit': 'USD',
          'description': '',
        },
      ],
    });

    final AppStateModel out = service
        .executeCurrencyExchange(
          input: state,
          date: '2026-06-01',
          sourceCurrency: 'USD',
          targetCurrency: 'EGP',
          sourceAmount: 70,
          targetAmount: 3500,
        )
        .state;

    expect(
      out.savings.where((Saving saving) => saving.id == 'cash-1'),
      isEmpty,
    );
    expect(
      out.transactions
          .where(
            (transaction) =>
                transaction.type == 'expense' &&
                transaction.sourceIncomeId == 'income-1',
          )
          .single
          .amount,
      20,
    );
    expect(service.getAvailableCashBalance(state: out, currency: 'USD'), 80);
  });

  test('combined cash balance reflects metal funding deductions', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cash-1',
          'assetType': 'cash',
          'dateAcquired': '2026-01-01',
          'amount': 100,
          'remainingAmount': 80,
          'unit': 'USD',
          'description': '',
        },
        <String, dynamic>{
          'id': 'gold-1',
          'assetType': 'gold',
          'dateAcquired': '2026-02-01',
          'amount': 1,
          'remainingAmount': 1,
          'unit': '24',
          'description': '',
          'fundingAllocations': <Map<String, dynamic>>[
            <String, dynamic>{
              'sourceType': 'savings',
              'sourceId': 'cash-1',
              'currency': 'USD',
              'amount': 20,
            },
          ],
        },
      ],
    });

    expect(service.getAvailableCashBalance(state: state, currency: 'USD'), 80);
    expect(service.getCashByCurrency(state)['USD'], 80);
  });

  test('combined cash source amounts equal the shared displayed balance', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'expense-1',
          'type': 'expense',
          'date': '2026-06-02',
          'amount': 20,
          'currency': 'USD',
          'category': 'Expense',
          'description': '',
        },
        <String, dynamic>{
          'id': 'income-1',
          'type': 'income',
          'date': '2026-06-03',
          'amount': 50,
          'currency': 'USD',
          'category': 'Salary',
          'description': '',
        },
      ],
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cash-1',
          'assetType': 'cash',
          'dateAcquired': '2026-01-01',
          'amount': 100,
          'remainingAmount': 80,
          'unit': 'USD',
          'description': '',
        },
      ],
    });

    final List<CashSource> sources = service.getAvailableCashSources(
      state: state,
      currency: 'USD',
    );
    final double sourceTotal = sources.fold<double>(
      0,
      (double total, CashSource source) => total + source.availableAmount,
    );

    expect(
      sourceTotal,
      service.getAvailableCashBalance(state: state, currency: 'USD'),
    );
    expect(sourceTotal, 130);
  });

  test('available cash sources hide fully consumed entries', () {
    final AppStateModel base = AppStateDefaults.create();
    final AppStateModel state = AppStateModel.fromJson(<String, dynamic>{
      ...base.toJson(),
      'savings': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'available',
          'assetType': 'cash',
          'dateAcquired': '2026-01-01',
          'amount': 100,
          'remainingAmount': 25,
          'unit': 'USD',
          'description': '',
        },
        <String, dynamic>{
          'id': 'consumed',
          'assetType': 'cash',
          'dateAcquired': '2026-01-02',
          'amount': 100,
          'remainingAmount': 0,
          'unit': 'USD',
          'description': '',
        },
      ],
    });

    expect(
      service
          .getAvailableCashSources(state: state, currency: 'USD')
          .map((CashSource source) => source.id),
      <String>['available'],
    );
  });

  test('gold sale reduces gold saving remaining amount', () {
    final state = makeState(
      transactions: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'tx-sale-1',
          'type': 'income',
          'date': '2026-06-02',
          'amount': 30000,
          'currency': 'EGP',
          'category': 'Gold Sale',
          'description': 'Sold 10 g of 24k gold',
          'exchangePairId': 'gold-1',
        },
      ],
      savings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gold-1',
          'assetType': 'gold',
          'unit': '24',
          'amount': 25.5,
          'remainingAmount': 25.5,
          'dateAcquired': '2026-01-01',
        },
      ],
    );

    final out = service.reconcileExpensesWithSavings(state).state;

    expect(
      out.savings.firstWhere((Saving s) => s.id == 'gold-1').remainingAmount,
      15.5,
    );
  });
}
