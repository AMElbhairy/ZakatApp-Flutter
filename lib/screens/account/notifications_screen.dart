import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/pending_transaction.dart';
import '../../services/app_state_controller.dart';
import 'review_pending_transaction_screen.dart';
import 'add_smart_capture_message_screen.dart';
import 'merchant_rules_screen.dart';

enum _CaptureStatusFilter { pending, approved, rejected }

enum _CaptureDateFilter {
  allTime,
  today,
  thisWeek,
  thisMonth,
  previousMonth,
  custom,
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() {
    return CupertinoPageRoute<void>(
      builder: (_) => const NotificationsScreen(),
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _screenTitle = 'Capture Inbox';
  _CaptureStatusFilter _selectedStatus = _CaptureStatusFilter.approved;
  _CaptureDateFilter _selectedDateFilter = _CaptureDateFilter.allTime;
  DateTimeRange? _customRange;
  final bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 250), () async {
        if (!mounted) return;
        final AppStateController controller = context
            .read<AppStateController>();
        final bool hasUnread = controller.state.pendingTransactions.any(
          (PendingTransaction t) => !t.isRead,
        );
        if (hasUnread) {
          await controller.markPendingTransactionsAsRead();
        }
      });
    });
  }

  String _formatRelativeDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      final DateTime now = DateTime.now();
      final int diffDays = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (diffDays == 0) return 'Today';
      if (diffDays == 1) return 'Yesterday';
      if (diffDays > 0 && diffDays < 7) return '$diffDays days ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  DateTime _entryTimestamp(PendingTransaction item) {
    final DateTime? reviewed = _tryParseDate(item.reviewedAt);
    final DateTime? created = _tryParseDate(item.createdAt);
    return reviewed ?? created ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _tryParseDate(String? value) {
    final String clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    return DateTime.tryParse(clean);
  }

  String _dateKey(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(String dateKey) {
    try {
      final DateTime dt = DateTime.parse(dateKey);
      return '${dt.day.toString().padLeft(2, '0')} '
          '${_monthShort(dt.month)} ${dt.year}';
    } catch (_) {
      return dateKey;
    }
  }

  String _monthShort(int month) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  bool _matchesDateFilter(PendingTransaction item) {
    final DateTime ts = _entryTimestamp(item);
    final DateTime now = DateTime.now();
    switch (_selectedDateFilter) {
      case _CaptureDateFilter.allTime:
        return true;
      case _CaptureDateFilter.today:
        return ts.year == now.year &&
            ts.month == now.month &&
            ts.day == now.day;
      case _CaptureDateFilter.thisWeek:
        return ts.isAfter(now.subtract(const Duration(days: 7))) ||
            ts.isAtSameMomentAs(now.subtract(const Duration(days: 7)));
      case _CaptureDateFilter.thisMonth:
        return ts.year == now.year && ts.month == now.month;
      case _CaptureDateFilter.previousMonth:
        final DateTime firstOfThisMonth = DateTime(now.year, now.month, 1);
        final DateTime firstOfPreviousMonth = DateTime(
          firstOfThisMonth.year,
          firstOfThisMonth.month - 1,
          1,
        );
        return ts.year == firstOfPreviousMonth.year &&
            ts.month == firstOfPreviousMonth.month;
      case _CaptureDateFilter.custom:
        if (_customRange == null) return true;
        return (ts.isAfter(_customRange!.start) ||
                ts.isAtSameMomentAs(_customRange!.start)) &&
            (ts.isBefore(_customRange!.end) ||
                ts.isAtSameMomentAs(_customRange!.end));
    }
  }

  bool _matchesStatusFilter(PendingTransaction item) {
    switch (_selectedStatus) {
      case _CaptureStatusFilter.pending:
        return item.status == CaptureStatus.pendingReview;
      case _CaptureStatusFilter.approved:
        return item.status == CaptureStatus.autoApproved ||
            item.status == CaptureStatus.manuallyApproved;
      case _CaptureStatusFilter.rejected:
        return item.status == CaptureStatus.ignored;
    }
  }

  List<PendingTransaction> _sortedNewestFirst(
    Iterable<PendingTransaction> items,
  ) {
    final List<PendingTransaction> list = items.toList(growable: false);
    list.sort((PendingTransaction a, PendingTransaction b) {
      final int byCreated = _entryTimestamp(b).compareTo(_entryTimestamp(a));
      if (byCreated != 0) return byCreated;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  List<_LogRow> _buildRows(List<PendingTransaction> items) {
    final List<_LogRow> rows = <_LogRow>[];
    String? lastDate;
    for (final PendingTransaction item in items) {
      final String dateKey = _dateKey(_entryTimestamp(item));
      if (dateKey != lastDate) {
        rows.add(_LogRow.header(dateKey));
        lastDate = dateKey;
      }
      rows.add(_LogRow.item(item));
    }
    return rows;
  }

  void _clearIgnoredWithConfirmation(AppStateController controller) {
    final tokens = context.premiumTokens;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.colors.hero,
        title: const Text('Clear Ignored Captures'),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
        content: Text(
          'Are you sure you want to permanently clear all ignored captures?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              controller.deleteIgnoredPendingTransactions();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateController>().state;
    final controller = context.read<AppStateController>();
    final tokens = context.premiumTokens;

    final List<PendingTransaction> newestFirst = _sortedNewestFirst(
      state.pendingTransactions,
    );
    final List<PendingTransaction> dateFiltered = newestFirst
        .where(_matchesDateFilter)
        .toList(growable: false);
    final List<PendingTransaction> activeList = dateFiltered
        .where(_matchesStatusFilter)
        .toList(growable: false);

    final int pendingCount = dateFiltered
        .where(
          (PendingTransaction t) => t.status == CaptureStatus.pendingReview,
        )
        .length;
    final int approvedCount = dateFiltered
        .where(
          (PendingTransaction t) =>
              t.status == CaptureStatus.autoApproved ||
              t.status == CaptureStatus.manuallyApproved,
        )
        .length;
    final int rejectedCount = dateFiltered
        .where((PendingTransaction t) => t.status == CaptureStatus.ignored)
        .length;
    final List<PendingTransaction> ignoredItems = dateFiltered
        .where((PendingTransaction t) => t.status == CaptureStatus.ignored)
        .toList(growable: false);
    final List<_LogRow> activeRows = _buildRows(activeList);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(_screenTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range_rounded, color: tokens.colors.gold),
            tooltip: 'Filter by date',
            onPressed: () => _showDateFilterSheet(context),
          ),
          IconButton(
            icon: Icon(Icons.rule, color: tokens.colors.gold),
            tooltip: 'Rules Config',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MerchantRulesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: tokens.colors.gold),
            tooltip: 'Test Message',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddSmartCaptureMessageScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCaptureHeader(
            controller,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
          ),

          if (_selectedStatus == _CaptureStatusFilter.rejected &&
              ignoredItems.isNotEmpty &&
              !_isEditMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _clearIgnoredWithConfirmation(controller),
                  icon: Icon(
                    Icons.delete_sweep,
                    color: tokens.colors.danger,
                    size: 18,
                  ),
                  label: Text(
                    'Clear Rejected',
                    style: TextStyle(
                      color: tokens.colors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          Expanded(
            child: activeRows.isEmpty
                ? Center(
                    child: Text(
                      'No items match the selected filters',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      120,
                    ),
                    itemCount: activeRows.length,
                    itemBuilder: (context, index) {
                      final row = activeRows[index];
                      if (row.header != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 8),
                          child: Text(
                            _formatDateHeader(row.header!),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: tokens.colors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        );
                      }
                      return _buildCaptureRow(context, row.item!, controller);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureHeader(
    AppStateController controller, {
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = dark
        ? tokens.colors.surface.withValues(alpha: 0.74)
        : const Color(0xFFF9F7F0);
    final Color fieldColor = dark
        ? tokens.colors.card.withValues(alpha: 0.88)
        : const Color(0xFFEBE7DD);
    final int resultsCount = _sortedNewestFirst(
      controller.state.pendingTransactions,
    ).where(_matchesDateFilter).where(_matchesStatusFilter).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppRadii.card,
        border: Border.all(
          color: tokens.colors.divider.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Smart Capture Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$resultsCount',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tokens.colors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildStatusTab(
                  label: 'Pending',
                  count: pendingCount,
                  selected: _selectedStatus == _CaptureStatusFilter.pending,
                  onTap: () => setState(
                    () => _selectedStatus = _CaptureStatusFilter.pending,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildStatusTab(
                  label: 'Approved',
                  count: approvedCount,
                  selected: _selectedStatus == _CaptureStatusFilter.approved,
                  onTap: () => setState(
                    () => _selectedStatus = _CaptureStatusFilter.approved,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildStatusTab(
                  label: 'Rejected',
                  count: rejectedCount,
                  selected: _selectedStatus == _CaptureStatusFilter.rejected,
                  onTap: () => setState(
                    () => _selectedStatus = _CaptureStatusFilter.rejected,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            readOnly: true,
            onTap: () => _showDateFilterSheet(context),
            decoration: InputDecoration(
              hintText: _dateFilterLabel(),
              prefixIcon: Icon(Icons.tune_rounded, color: tokens.colors.gold),
              filled: true,
              fillColor: fieldColor,
              border: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide(
                  color: tokens.colors.divider.withValues(alpha: 0.50),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.card,
                borderSide: BorderSide(color: tokens.colors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateFilterLabel() {
    switch (_selectedDateFilter) {
      case _CaptureDateFilter.allTime:
        return 'All Time';
      case _CaptureDateFilter.today:
        return 'Today';
      case _CaptureDateFilter.thisWeek:
        return 'This Week';
      case _CaptureDateFilter.thisMonth:
        return 'This Month';
      case _CaptureDateFilter.previousMonth:
        return 'Previous Month';
      case _CaptureDateFilter.custom:
        return 'Custom Range';
    }
  }

  Future<void> _showDateFilterSheet(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    final AppStateController controller = context.read<AppStateController>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final tokens = context.premiumTokens;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Filter by Date',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...<Widget>[
                  _dateOptionTile(
                    context,
                    label: 'All Time',
                    onTap: () => _applyDateFilter(
                      controller,
                      context,
                      _CaptureDateFilter.allTime,
                    ),
                  ),
                  _dateOptionTile(
                    context,
                    label: 'Today',
                    onTap: () => _applyDateFilter(
                      controller,
                      context,
                      _CaptureDateFilter.today,
                    ),
                  ),
                  _dateOptionTile(
                    context,
                    label: 'This Week',
                    onTap: () => _applyDateFilter(
                      controller,
                      context,
                      _CaptureDateFilter.thisWeek,
                    ),
                  ),
                  _dateOptionTile(
                    context,
                    label: 'This Month',
                    onTap: () => _applyDateFilter(
                      controller,
                      context,
                      _CaptureDateFilter.thisMonth,
                    ),
                  ),
                  _dateOptionTile(
                    context,
                    label: 'Previous Month',
                    onTap: () => _applyDateFilter(
                      controller,
                      context,
                      _CaptureDateFilter.previousMonth,
                    ),
                  ),
                  _dateOptionTile(
                    context,
                    label: 'Custom Range',
                    onTap: () async {
                      Navigator.pop(context);
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: this.context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange:
                            _customRange ??
                            DateTimeRange(
                              start: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              end: DateTime.now(),
                            ),
                      );
                      if (!mounted || picked == null) return;
                      setState(() {
                        _customRange = picked;
                        _selectedDateFilter = _CaptureDateFilter.custom;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateOptionTile(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final tokens = context.premiumTokens;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: tokens.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.colors.gold),
      onTap: onTap,
    );
  }

  void _applyDateFilter(
    AppStateController controller,
    BuildContext context,
    _CaptureDateFilter filter,
  ) {
    Navigator.pop(context);
    setState(() {
      _selectedDateFilter = filter;
      if (filter != _CaptureDateFilter.custom) {
        _customRange = null;
      }
    });
  }

  Widget _buildCaptureRow(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller,
  ) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = dark
        ? tokens.colors.surface.withValues(alpha: 0.78)
        : const Color(0xFFFAF8F2);
    final Color titleColor = dark
        ? tokens.colors.textPrimary
        : const Color(0xFF042F2B);
    final Color subtitleColor = tokens.colors.textSecondary;
    final String amount = item.suggestedAmount != null
        ? '${item.suggestedCurrency ?? 'EGP'} ${item.suggestedAmount!.toStringAsFixed(2)}'
        : '';
    final String statusLabel = switch (item.status) {
      CaptureStatus.pendingReview => 'PENDING',
      CaptureStatus.autoApproved => 'AUTO',
      CaptureStatus.manuallyApproved => 'MANUAL',
      CaptureStatus.ignored => 'REJECTED',
    };
    final Color statusColor = switch (item.status) {
      CaptureStatus.pendingReview => tokens.colors.warning,
      CaptureStatus.autoApproved => tokens.colors.success,
      CaptureStatus.manuallyApproved => tokens.colors.emerald,
      CaptureStatus.ignored => tokens.colors.danger,
    };

    final SlidableActionData actions = switch (item.status) {
      CaptureStatus.pendingReview => SlidableActionData(
        actions: <Widget>[
          _slideAction(
            context,
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: tokens.colors.gold,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReviewPendingTransactionScreen(pendingTransaction: item),
                ),
              );
            },
          ),
          _slideAction(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: tokens.colors.danger,
            onTap: () {
              controller.deletePendingTransactionsBulk(<String>[item.id]);
            },
          ),
        ],
      ),
      CaptureStatus.autoApproved ||
      CaptureStatus.manuallyApproved => SlidableActionData(
        actions: <Widget>[
          _slideAction(
            context,
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: tokens.colors.gold,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReviewPendingTransactionScreen(pendingTransaction: item),
                ),
              );
            },
          ),
          _slideAction(
            context,
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: tokens.colors.warning,
            onTap: () {
              controller.undoPendingTransaction(item.id);
              showTopSnackBar(
                context,
                'Approval undone. Transaction returned to Needs Review.',
                kind: AppToastKind.info,
              );
            },
          ),
          _slideAction(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: tokens.colors.danger,
            onTap: () {
              controller.deletePendingTransactionsBulk(<String>[item.id]);
            },
          ),
        ],
      ),
      CaptureStatus.ignored => SlidableActionData(
        actions: <Widget>[
          _slideAction(
            context,
            icon: Icons.restore_rounded,
            label: 'Restore',
            color: tokens.colors.gold,
            onTap: () {
              controller.restorePendingTransactionsBulk(<String>[item.id]);
            },
          ),
          _slideAction(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: tokens.colors.danger,
            onTap: () {
              controller.deletePendingTransactionsBulk(<String>[item.id]);
            },
          ),
        ],
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Slidable(
        key: Key('capture_${item.id}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: actions.actions.length == 2 ? 0.42 : 0.60,
          children: actions.actions,
        ),
        child: Material(
          color: surfaceColor,
          borderRadius: AppRadii.card,
          child: InkWell(
            borderRadius: AppRadii.card,
            onTap: () {
              if (item.status == CaptureStatus.ignored) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReviewPendingTransactionScreen(pendingTransaction: item),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.merchantName ?? item.sourceDisplayLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: titleColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      height: 1.15,
                                    ),
                              ),
                            ),
                            if (amount.isNotEmpty) ...<Widget>[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                amount,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: tokens.colors.gold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.suggestedType.toUpperCase()} • ${item.suggestedCategory ?? 'Other'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: subtitleColor, height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _badge(context, statusLabel, statusColor),
                            _badge(
                              context,
                              'Confidence ${(item.confidence * 100).toStringAsFixed(0)}%',
                              tokens.colors.textSecondary,
                            ),
                            _badge(
                              context,
                              _formatRelativeDate(item.createdAt),
                              tokens.colors.textSecondary,
                            ),
                          ],
                        ),
                        if (item.rawMessage.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            item.rawMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: subtitleColor,
                                  fontStyle: FontStyle.italic,
                                  height: 1.25,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slideAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CustomSlidableAction(
      onPressed: (BuildContext context) => onTap(),
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundColor: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    final tokens = context.premiumTokens;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? tokens.colors.gold : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count != null ? '$label ($count)' : label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected
                    ? tokens.colors.gold
                    : (isDark ? Colors.white : tokens.colors.hero),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow {
  _LogRow.header(this.header) : item = null;
  _LogRow.item(this.item) : header = null;

  final String? header;
  final PendingTransaction? item;
}

class SlidableActionData {
  SlidableActionData({required this.actions});

  final List<Widget> actions;
}
