import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_component_tokens.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/pending_transaction.dart';
import '../../models/app_state.dart';
import '../../services/app_state_controller.dart';
import 'review_pending_transaction_screen.dart';
import 'add_smart_capture_message_screen.dart';
import 'merchant_rules_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const NotificationsScreen(),
      transitionsBuilder: (_, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _screenTitle = 'Capture Inbox';
  String _selectedTab = 'Needs Review'; // Needs Review, Approved, Ignored
  bool _isEditMode = false;
  bool _isReady = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppStateController>().markPendingTransactionsAsRead();
      setState(() {
        _isReady = true;
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

  Widget _buildAnalyticsCard(AppStateModel state) {
    final tokens = context.premiumTokens;
    // Derived stats from actual state to avoid mistrust
    int rulesLearned = state.merchantRules.values
        .where((r) => r.source == 'learned')
        .length;
    int autoApprovedCount = state.pendingTransactions
        .where((t) => t.approvalSource == ApprovalSource.auto)
        .length;
    int ignoredCount = state.pendingTransactions
        .where((t) => t.status == CaptureStatus.ignored)
        .length;
    int pendingCount = state.pendingTransactions
        .where((t) => t.status == CaptureStatus.pendingReview)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppComponentTokens.heroCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smart Capture Stats',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              Icon(
                Icons.analytics_outlined,
                color: tokens.colors.gold,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Rules Learned', '$rulesLearned'),
              _buildStatItem('Auto Approved', '$autoApprovedCount'),
              _buildStatItem('Ignored', '$ignoredCount'),
              _buildStatItem('Pending', '$pendingCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final tokens = context.premiumTokens;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: tokens.colors.gold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
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

    if (!_isReady) {
      return Scaffold(
        backgroundColor: tokens.colors.background,
        appBar: AppBar(title: const Text(_screenTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: tokens.colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            ...List<Widget>.generate(
              4,
              (int index) => Padding(
                padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
                child: Container(
                  height: 108,
                  decoration: BoxDecoration(
                    color: tokens.colors.hero,
                    borderRadius: AppRadii.card,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Filter lists according to new CaptureStatus enums
    final List<PendingTransaction> reviewItems = state.pendingTransactions
        .where((t) => t.status == CaptureStatus.pendingReview)
        .toList();

    final List<PendingTransaction> approvedItems = state.pendingTransactions
        .where(
          (t) =>
              t.status == CaptureStatus.autoApproved ||
              t.status == CaptureStatus.manuallyApproved,
        )
        .toList();

    final List<PendingTransaction> ignoredItems = state.pendingTransactions
        .where((t) => t.status == CaptureStatus.ignored)
        .toList();

    List<PendingTransaction> activeList = [];
    if (_selectedTab == 'Needs Review') {
      activeList = reviewItems;
    } else if (_selectedTab == 'Approved') {
      activeList = approvedItems;
    } else if (_selectedTab == 'Ignored') {
      activeList = ignoredItems;
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? '${_selectedIds.length} Selected' : _screenTitle,
        ),
        actions: [
          if (!_isEditMode) ...[
            TextButton(
              onPressed: activeList.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _isEditMode = true;
                        _selectedIds.clear();
                      });
                    },
              child: Text(
                'Select',
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          ] else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _selectedIds.clear();
                });
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _isEditMode
          ? Container(
              color: tokens.colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedIds.length == activeList.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(
                            activeList.map((item) => item.id),
                          );
                        }
                      });
                    },
                    child: Text(
                      _selectedIds.length == activeList.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: TextStyle(
                        color: tokens.colors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (_selectedTab == 'Ignored')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.colors.gold,
                            foregroundColor: tokens.colors.hero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () {
                                  controller.restorePendingTransactionsBulk(
                                    _selectedIds.toList(),
                                  );
                                  setState(() {
                                    _isEditMode = false;
                                    _selectedIds.clear();
                                  });
                                },
                          child: const Text('Restore'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.colors.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                controller.deletePendingTransactionsBulk(
                                  _selectedIds.toList(),
                                );
                                setState(() {
                                  _isEditMode = false;
                                  _selectedIds.clear();
                                });
                              },
                        child: const Text('Delete Selected'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
      body: Column(
        children: [
          if (state.smartCaptureEnabled) _buildAnalyticsCard(state),

          // Tabs layout
          Container(
            color: tokens.colors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabButton('Needs Review', count: reviewItems.length),
                _buildTabButton('Approved', count: approvedItems.length),
                _buildTabButton('Ignored', count: ignoredItems.length),
              ],
            ),
          ),

          if (_selectedTab == 'Ignored' &&
              ignoredItems.isNotEmpty &&
              !_isEditMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    'Clear Ignored',
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
            child: activeList.isEmpty
                ? Center(
                    child: Text(
                      'No items in this section',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    itemCount: activeList.length,
                    itemBuilder: (context, index) {
                      final item = activeList[index];
                      return _buildCardWrapper(context, item, controller);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, {int? count}) {
    final tokens = context.premiumTokens;
    final bool isSelected = _selectedTab == label;
    final String displayLabel = count != null && count > 0
        ? '$label ($count)'
        : label;

    return ChoiceChip(
      label: Text(displayLabel),
      selected: isSelected,
      selectedColor: tokens.colors.gold,
      backgroundColor: tokens.colors.hero,
      labelStyle: TextStyle(
        color: isSelected ? tokens.colors.hero : Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? tokens.colors.gold : tokens.colors.divider,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedTab = label;
            _isEditMode = false;
            _selectedIds.clear();
          });
        }
      },
    );
  }

  Widget _buildCardWrapper(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller,
  ) {
    final tokens = context.premiumTokens;
    if (_isEditMode) {
      final isSelected = _selectedIds.contains(item.id);
      return Card(
        color: tokens.colors.hero,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(
            color: isSelected ? tokens.colors.gold : tokens.colors.divider,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadii.card,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(item.id);
              } else {
                _selectedIds.add(item.id);
              }
            });
          },
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected
                      ? tokens.colors.gold
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              Expanded(
                child: _buildInnerCard(
                  context,
                  item,
                  controller,
                  displayActions: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildInnerCard(context, item, controller, displayActions: true);
  }

  Widget _buildInnerCard(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller, {
    required bool displayActions,
  }) {
    if (_selectedTab == 'Needs Review') {
      return _buildPendingCard(
        context,
        item,
        controller,
        displayActions: displayActions,
      );
    } else if (_selectedTab == 'Approved') {
      return _buildApprovedCard(
        context,
        item,
        controller,
        displayActions: displayActions,
      );
    } else {
      return _buildIgnoredCard(
        context,
        item,
        controller,
        displayActions: displayActions,
      );
    }
  }

  Widget _buildPendingCard(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller, {
    required bool displayActions,
  }) {
    final tokens = context.premiumTokens;
    final sourceIdText =
        item.sourceIdentifier != null &&
            item.sourceIdentifier != item.sourceDisplayLabel
        ? ' • ${item.sourceIdentifier}'
        : '';
    return Card(
      color: tokens.colors.hero,
      elevation: 0,
      margin: displayActions
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      shape: displayActions
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.card,
              side: BorderSide(color: tokens.colors.divider),
            )
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.sourceDisplayLabel}$sourceIdText',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                Text(
                  _formatRelativeDate(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.merchantName ?? 'Unknown Merchant',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suggested Type: ${item.suggestedType.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      if (item.suggestedCategory != null)
                        Text(
                          'Category: ${item.suggestedCategory}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                        ),
                      Text(
                        'Confidence: ${(item.confidence * 100).toStringAsFixed(0)}%'
                        '${item.merchantRuleSource != null ? ' • Rule: ${_ruleSourceLabel(item.merchantRuleSource!)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.suggestedAmount != null)
                  Text(
                    '${item.suggestedCurrency ?? 'EGP'} ${item.suggestedAmount!.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.colors.gold,
                      fontSize: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.colors.hero,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.sm),
                ),
                border: Border.all(color: tokens.colors.divider),
              ),
              child: Text(
                item.rawMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (displayActions) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      controller.rejectPendingTransaction(item.id);
                    },
                    child: Text(
                      'Ignore',
                      style: TextStyle(color: tokens.colors.danger),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.colors.gold,
                      foregroundColor: tokens.colors.hero,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewPendingTransactionScreen(
                            pendingTransaction: item,
                          ),
                        ),
                      );
                    },
                    child: const Text('Review →'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCard(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller, {
    required bool displayActions,
  }) {
    final tokens = context.premiumTokens;
    final bool isAuto = item.approvalSource == ApprovalSource.auto;
    final badgeColor = isAuto
        ? tokens.colors.success
        : Theme.of(context).colorScheme.primary;
    final badgeText = isAuto ? 'AUTO' : 'MANUAL';

    return Card(
      color: tokens.colors.hero,
      elevation: 0,
      margin: displayActions
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      shape: displayActions
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.card,
              side: BorderSide(color: tokens.colors.divider),
            )
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.18),
                    border: Border.all(color: badgeColor, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.merchantName ?? 'Unknown Merchant',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  '${item.suggestedType.toUpperCase()} • Category: ${item.suggestedCategory ?? "Other"}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                ),
                Text(
                  'Confidence: ${(item.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                ),
                if (item.reviewedAt != null)
                  Text(
                    'Processed: ${_formatRelativeDate(item.reviewedAt!)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
              ],
            ),
            trailing: item.suggestedAmount != null
                ? Text(
                    '${item.suggestedCurrency ?? 'EGP'} ${item.suggestedAmount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: tokens.colors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          if (displayActions) ...[
            Divider(color: tokens.colors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewPendingTransactionScreen(
                            pendingTransaction: item,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.edit, size: 16, color: tokens.colors.gold),
                    label: Text(
                      'Edit',
                      style: TextStyle(color: tokens.colors.gold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () {
                      controller.undoPendingTransaction(item.id);
                      showTopSnackBar(
                        context,
                        'Approval undone. Transaction returned to Needs Review.',
                        kind: AppToastKind.info,
                      );
                    },
                    icon: Icon(
                      Icons.undo,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    label: Text(
                      'Undo Approval',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIgnoredCard(
    BuildContext context,
    PendingTransaction item,
    AppStateController controller, {
    required bool displayActions,
  }) {
    final tokens = context.premiumTokens;
    return Card(
      color: tokens.colors.hero,
      elevation: 0,
      margin: displayActions
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      shape: displayActions
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.card,
              side: BorderSide(color: tokens.colors.divider),
            )
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          item.merchantName ?? 'Unknown Merchant',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Ignored\nReason: ${item.ignoreReason ?? 'Unknown'}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
            ),
            Text(
              'Confidence: ${(item.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.rawMessage,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.suggestedAmount != null)
              Text(
                '${item.suggestedCurrency ?? 'EGP'} ${item.suggestedAmount!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            if (displayActions) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.restore, color: tokens.colors.gold, size: 20),
                tooltip: 'Restore to Pending',
                onPressed: () {
                  controller.restorePendingTransactionsBulk(<String>[item.id]);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ruleSourceLabel(String source) {
    switch (source) {
      case 'builtin':
        return 'Built-in';
      case 'custom':
        return 'Custom';
      case 'learned':
        return 'Learned';
      default:
        return source;
    }
  }
}
