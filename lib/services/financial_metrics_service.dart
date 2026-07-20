import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FinancialRecordType { income, expense, transfer }

class FinancialMetricsRecord<T> {
  const FinancialMetricsRecord({
    required this.source,
    required this.type,
    required this.date,
    required this.createdAt,
    required this.amountEgp,
    required this.category,
    required this.label,
    required this.description,
    required this.currencyCode,
  });

  final T source;
  final FinancialRecordType type;
  final DateTime date;
  final DateTime createdAt;
  final double amountEgp;
  final String category;
  final String label;
  final String description;
  final String currencyCode;
}

class FinancialMetricsBucket {
  const FinancialMetricsBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.value,
    required this.isCurrent,
  });

  final DateTime start;
  final DateTime end;
  final String label;
  final double value;
  final bool isCurrent;
}

class FinancialMetricsResult<T> {
  const FinancialMetricsResult({
    required this.selectedPeriod,
    required this.range,
    required this.previousRange,
    required this.granularity,
    required this.currentRecords,
    required this.previousRecords,
    required this.totalCurrent,
    required this.totalPrevious,
    required this.changePct,
    required this.totalsByType,
    required this.previousTotalsByType,
    required this.incomeCurrent,
    required this.incomePrevious,
    required this.expenseCurrent,
    required this.expensePrevious,
    required this.transferCurrent,
    required this.transferPrevious,
    required this.netCashFlow,
    required this.savingsRate,
    required this.transactionCount,
    required this.averageTransaction,
    required this.averageDailySpending,
    required this.dailyTotals,
    required this.highestSpendingDay,
    required this.highestSpendingDayValue,
    required this.chartBuckets,
    required this.chartMax,
    required this.recentRecords,
    required this.largestRecord,
  });

  final String selectedPeriod;
  final DateTimeRange range;
  final DateTimeRange previousRange;
  final String granularity;
  final List<FinancialMetricsRecord<T>> currentRecords;
  final List<FinancialMetricsRecord<T>> previousRecords;
  final double totalCurrent;
  final double totalPrevious;
  final double changePct;
  final Map<FinancialRecordType, double> totalsByType;
  final Map<FinancialRecordType, double> previousTotalsByType;
  final double incomeCurrent;
  final double incomePrevious;
  final double expenseCurrent;
  final double expensePrevious;
  final double transferCurrent;
  final double transferPrevious;
  final double netCashFlow;
  final double savingsRate;
  final int transactionCount;
  final double averageTransaction;
  final double averageDailySpending;
  final Map<DateTime, double> dailyTotals;
  final DateTime? highestSpendingDay;
  final double highestSpendingDayValue;
  final List<FinancialMetricsBucket> chartBuckets;
  final double chartMax;
  final List<FinancialMetricsRecord<T>> recentRecords;
  final FinancialMetricsRecord<T>? largestRecord;

  FinancialMetricsRecord<T>? get highestDayRecord => largestRecord;
}

class FinancialMetricsService {
  const FinancialMetricsService._();

  static FinancialMetricsResult<T> calculate<T>({
    required List<FinancialMetricsRecord<T>> records,
    required String selectedPeriod,
    required DateTime now,
    required String locale,
    DateTimeRange? customRange,
    FinancialRecordType? typeFilter,
    String categoryFilter = 'All',
    String searchQuery = '',
    int recentLimit = 5,
  }) {
    final DateTime normalizedNow = _dayOnly(now);
    final List<FinancialMetricsRecord<T>> normalizedRecords = records
        .map(
          (FinancialMetricsRecord<T> record) => FinancialMetricsRecord<T>(
            source: record.source,
            type: record.type,
            date: _dayOnly(record.date),
            createdAt: record.createdAt,
            amountEgp: record.amountEgp,
            category: record.category,
            label: record.label,
            description: record.description,
            currencyCode: record.currencyCode,
          ),
        )
        .toList(growable: false);

    final DateTimeRange selectedRange = _selectedRange<T>(
      selectedPeriod: selectedPeriod,
      customRange: customRange,
      records: normalizedRecords,
      now: normalizedNow,
    );
    final DateTimeRange previousRange = _previousEquivalentRange(
      selectedRange,
      selectedPeriod,
    );

    final String normalizedSearch = searchQuery.trim().toLowerCase();
    final List<FinancialMetricsRecord<T>> currentRecords = _filterRecords(
      normalizedRecords,
      range: selectedRange,
      typeFilter: typeFilter,
      categoryFilter: categoryFilter,
      searchQuery: normalizedSearch,
    );
    final List<FinancialMetricsRecord<T>> previousRecords = _filterRecords(
      normalizedRecords,
      range: previousRange,
      typeFilter: typeFilter,
      categoryFilter: categoryFilter,
      searchQuery: normalizedSearch,
    );

    final Map<FinancialRecordType, double> totalsByType =
        _totalsByType(currentRecords);
    final Map<FinancialRecordType, double> previousTotalsByType =
        _totalsByType(previousRecords);

    final double incomeCurrent = totalsByType[FinancialRecordType.income] ?? 0;
    final double incomePrevious =
        previousTotalsByType[FinancialRecordType.income] ?? 0;
    final double expenseCurrent =
        totalsByType[FinancialRecordType.expense] ?? 0;
    final double expensePrevious =
        previousTotalsByType[FinancialRecordType.expense] ?? 0;
    final double transferCurrent =
        totalsByType[FinancialRecordType.transfer] ?? 0;
    final double transferPrevious =
        previousTotalsByType[FinancialRecordType.transfer] ?? 0;

    final double totalCurrent = currentRecords.fold<double>(
      0,
      (double total, FinancialMetricsRecord<T> record) => total + record.amountEgp,
    );
    final double totalPrevious = previousRecords.fold<double>(
      0,
      (double total, FinancialMetricsRecord<T> record) => total + record.amountEgp,
    );

    final double changePct = totalPrevious == 0
        ? 0
        : ((totalCurrent - totalPrevious) / totalPrevious) * 100;

    final Map<DateTime, double> dailyTotals = <DateTime, double>{};
    for (final FinancialMetricsRecord<T> record in currentRecords) {
      dailyTotals[record.date] = (dailyTotals[record.date] ?? 0) +
          record.amountEgp;
    }

    DateTime? highestSpendingDay;
    double highestSpendingDayValue = 0;
    dailyTotals.forEach((DateTime day, double total) {
      if (highestSpendingDay == null || total > highestSpendingDayValue) {
        highestSpendingDay = day;
        highestSpendingDayValue = total;
      }
    });

    final List<DateTime> days = _daysBetween(selectedRange.start, selectedRange.end);
    final double averageDailySpending = days.isEmpty
        ? 0
        : expenseCurrent / days.length;
    final double averageTransaction = currentRecords.isEmpty
        ? 0
        : totalCurrent / currentRecords.length;
    final double netCashFlow = incomeCurrent - expenseCurrent;
    final double savingsRate = incomeCurrent <= 0
        ? 0
        : ((incomeCurrent - expenseCurrent) / incomeCurrent) * 100;

    final FinancialMetricsRecord<T>? largestRecord = currentRecords.isEmpty
        ? null
        : currentRecords.reduce((FinancialMetricsRecord<T> a, FinancialMetricsRecord<T> b) {
            return a.amountEgp.abs() >= b.amountEgp.abs() ? a : b;
          });

    final List<FinancialMetricsBucket> chartBuckets = _buildChartBuckets(
      records: currentRecords,
      range: selectedRange,
      selectedPeriod: selectedPeriod,
      now: normalizedNow,
      locale: locale,
    );
    final double chartMax = _adaptiveScaleMax(
      chartBuckets.map((FinancialMetricsBucket bucket) => bucket.value).toList(growable: false),
    );

    final List<FinancialMetricsRecord<T>> recentRecords = currentRecords
        .toList(growable: false)
      ..sort((FinancialMetricsRecord<T> a, FinancialMetricsRecord<T> b) {
        final int byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });

    return FinancialMetricsResult<T>(
      selectedPeriod: selectedPeriod,
      range: selectedRange,
      previousRange: previousRange,
      granularity: _trendGranularity(selectedPeriod, selectedRange),
      currentRecords: currentRecords,
      previousRecords: previousRecords,
      totalCurrent: totalCurrent,
      totalPrevious: totalPrevious,
      changePct: changePct,
      totalsByType: totalsByType,
      previousTotalsByType: previousTotalsByType,
      incomeCurrent: incomeCurrent,
      incomePrevious: incomePrevious,
      expenseCurrent: expenseCurrent,
      expensePrevious: expensePrevious,
      transferCurrent: transferCurrent,
      transferPrevious: transferPrevious,
      netCashFlow: netCashFlow,
      savingsRate: savingsRate,
      transactionCount: currentRecords.length,
      averageTransaction: averageTransaction,
      averageDailySpending: averageDailySpending,
      dailyTotals: dailyTotals,
      highestSpendingDay: highestSpendingDay,
      highestSpendingDayValue: highestSpendingDayValue,
      chartBuckets: chartBuckets,
      chartMax: chartMax,
      recentRecords: recentRecords.take(recentLimit).toList(growable: false),
      largestRecord: largestRecord,
    );
  }

  static List<FinancialMetricsRecord<T>> _filterRecords<T>(
    List<FinancialMetricsRecord<T>> records, {
    required DateTimeRange range,
    required FinancialRecordType? typeFilter,
    required String categoryFilter,
    required String searchQuery,
  }) {
    final DateTime start = _dayOnly(range.start);
    final DateTime end = _dayOnly(range.end);
    return records.where((FinancialMetricsRecord<T> record) {
      if (record.date.isBefore(start) || record.date.isAfter(end)) return false;
      if (typeFilter != null && record.type != typeFilter) return false;
      if (categoryFilter.trim().isNotEmpty && categoryFilter != 'All') {
        if (record.category != categoryFilter) return false;
      }
      if (searchQuery.isNotEmpty) {
        final String haystack = '${record.label} ${record.description}'
            .trim()
            .toLowerCase();
        if (!haystack.contains(searchQuery)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  static Map<FinancialRecordType, double> _totalsByType<T>(
    List<FinancialMetricsRecord<T>> records,
  ) {
    final Map<FinancialRecordType, double> totals =
        <FinancialRecordType, double>{
      FinancialRecordType.income: 0,
      FinancialRecordType.expense: 0,
      FinancialRecordType.transfer: 0,
    };
    for (final FinancialMetricsRecord<T> record in records) {
      totals[record.type] = (totals[record.type] ?? 0) + record.amountEgp;
    }
    return totals;
  }

  static DateTimeRange _selectedRange<T>({
    required String selectedPeriod,
    required DateTimeRange? customRange,
    required List<FinancialMetricsRecord<T>> records,
    required DateTime now,
  }) {
    if (selectedPeriod == 'Custom' && customRange != null) {
      return DateTimeRange(
        start: _dayOnly(customRange.start),
        end: _dayOnly(customRange.end),
      );
    }

    switch (selectedPeriod) {
      case 'All':
        final DateTime start = records.isEmpty
            ? now.subtract(const Duration(days: 30))
            : records.map((FinancialMetricsRecord<T> e) => e.date).reduce(
                  (DateTime a, DateTime b) => a.isBefore(b) ? a : b,
                );
        final DateTime end = records.isEmpty
            ? now
            : records.map((FinancialMetricsRecord<T> e) => e.date).reduce(
                  (DateTime a, DateTime b) => a.isAfter(b) ? a : b,
                );
        return DateTimeRange(start: _dayOnly(start), end: _dayOnly(end));
      case '90D':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 90)),
          end: now,
        );
      case '6M':
        return DateTimeRange(start: DateTime(now.year, now.month - 6, now.day), end: now);
      case 'YTD':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case '30D':
      default:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  static DateTimeRange _previousEquivalentRange(
    DateTimeRange range,
    String selectedPeriod,
  ) {
    final DateTime start = _dayOnly(range.start);
    final DateTime end = _dayOnly(range.end);
    final int days = end.difference(start).inDays;
    final DateTime previousStart = start.subtract(Duration(days: days == 0 ? 1 : days));
    final DateTime previousEnd = start.subtract(const Duration(days: 1));
    return DateTimeRange(start: previousStart, end: previousEnd);
  }

  static List<DateTime> _daysBetween(DateTime start, DateTime end) {
    final DateTime startDay = _dayOnly(start);
    final DateTime endDay = _dayOnly(end);
    final int count = endDay.difference(startDay).inDays;
    return List<DateTime>.generate(
      math.max(1, count + 1),
      (int index) => startDay.add(Duration(days: index)),
    );
  }

  static List<FinancialMetricsBucket> _buildChartBuckets<T>({
    required List<FinancialMetricsRecord<T>> records,
    required DateTimeRange range,
    required String selectedPeriod,
    required DateTime now,
    required String locale,
  }) {
    final DateTime start = _dayOnly(range.start);
    final DateTime end = _dayOnly(range.end);
    final String granularity = _trendGranularity(selectedPeriod, range);
    final List<_BucketRange> ranges = _buildBucketRanges(
      start: start,
      end: end,
      granularity: granularity,
      locale: locale,
    );
    final List<FinancialMetricsBucket> buckets = <FinancialMetricsBucket>[];
    for (final _BucketRange bucket in ranges) {
      double total = 0;
      for (final FinancialMetricsRecord<T> record in records) {
        if (!record.date.isBefore(bucket.start) && !record.date.isAfter(bucket.end)) {
          total += record.amountEgp;
        }
      }
      buckets.add(
        FinancialMetricsBucket(
          start: bucket.start,
          end: bucket.end,
          label: bucket.label,
          value: total,
          isCurrent: !now.isBefore(bucket.start) && !now.isAfter(bucket.end),
        ),
      );
    }
    return buckets;
  }

  static List<_BucketRange> _buildBucketRanges({
    required DateTime start,
    required DateTime end,
    required String granularity,
    required String locale,
  }) {
    final List<_BucketRange> buckets = <_BucketRange>[];

    if (granularity == 'monthly') {
      DateTime cursor = DateTime(start.year, start.month, 1);
      while (!cursor.isAfter(end)) {
        final DateTime bucketStart = DateTime(cursor.year, cursor.month, 1);
        final DateTime bucketEnd = DateTime(cursor.year, cursor.month + 1, 0);
        buckets.add(
          _BucketRange(
            start: bucketStart,
            end: bucketEnd.isAfter(end) ? end : bucketEnd,
            label: DateFormat('MMM', locale).format(bucketStart),
          ),
        );
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
      return buckets;
    }

    final int stepDays = switch (granularity) {
      'daily' => 1,
      'biweekly' => 14,
      _ => 7,
    };
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      final DateTime bucketStart = _dayOnly(cursor);
      final DateTime bucketEnd = _dayOnly(cursor.add(Duration(days: stepDays - 1)));
      final String label = granularity == 'monthly'
          ? DateFormat('MMM', locale).format(bucketStart)
          : DateFormat('d MMM', locale).format(bucketStart);
      buckets.add(
        _BucketRange(
          start: bucketStart,
          end: bucketEnd.isAfter(end) ? end : bucketEnd,
          label: label,
        ),
      );
      cursor = cursor.add(Duration(days: stepDays));
    }
    return buckets;
  }

  static String _trendGranularity(String selectedPeriod, DateTimeRange range) {
    final int spanDays = _dayOnly(range.end).difference(_dayOnly(range.start)).inDays + 1;
    switch (selectedPeriod) {
      case '30D':
        return 'daily';
      case '90D':
        return 'weekly';
      case '6M':
        return 'biweekly';
      case 'YTD':
      case 'All':
        return 'monthly';
      default:
        if (spanDays <= 45) return 'daily';
        if (spanDays <= 120) return 'weekly';
        if (spanDays <= 240) return 'biweekly';
        return 'monthly';
    }
  }

  static double _adaptiveScaleMax(List<double> values) {
    final List<double> positives =
        values.where((double value) => value > 0).toList()..sort();
    if (positives.isEmpty) return 1;
    if (positives.length == 1) return positives.first * 1.2;

    final double maxValue = positives.last;
    final double secondHighest = positives[positives.length - 2];
    final double median = positives[positives.length ~/ 2];
    final double average = positives.fold<double>(
          0,
          (double total, double value) => total + value,
        ) /
        positives.length;
    final bool outlier = maxValue >= math.max(secondHighest * 2.5, median * 3.5);
    if (!outlier) return maxValue * 1.12;

    final double candidate = math.max(
      math.max(secondHighest * 1.35, median * 3.0),
      average * 2.5,
    );
    return candidate.clamp(maxValue * 0.35, maxValue);
  }

  static DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _BucketRange {
  const _BucketRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}
