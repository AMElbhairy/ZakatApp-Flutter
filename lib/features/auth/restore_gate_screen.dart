import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/backup_preview.dart';
import '../../services/cloud_backup_controller.dart';
import 'auth_brand_ui.dart';

class RestoreGateScreen extends StatefulWidget {
  const RestoreGateScreen({
    super.key,
    required this.cloudBackupController,
    required this.onRestore,
    required this.onStartFresh,
  });

  final CloudBackupController cloudBackupController;
  final Future<void> Function() onRestore;
  final Future<void> Function() onStartFresh;

  @override
  State<RestoreGateScreen> createState() => _RestoreGateScreenState();
}

class _RestoreGateScreenState extends State<RestoreGateScreen> {
  late Future<BackupPreview?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.cloudBackupController.previewLatestBackup();
  }

  @override
  void didUpdateWidget(covariant RestoreGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudBackupController != widget.cloudBackupController) {
      _previewFuture = widget.cloudBackupController.previewLatestBackup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = dark
        ? tokens.colors.textSecondary
        : tokens.colors.hero;
    final AppLocalizations l10n = context.l10n;
    return FutureBuilder<BackupPreview?>(
      future: _previewFuture,
      builder: (BuildContext context, AsyncSnapshot<BackupPreview?> snapshot) {
        final BackupPreview? preview = snapshot.data;
        final String backupDate = preview == null
            ? l10n.tr('backup_date_unknown')
            : _formatDate(preview.exportedAt, context);
        return AuthBrandShell(
          tone: AuthBackdropTone.shared,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AuthBrandHeader(
                title: l10n.tr('brand_title'),
                subtitle: l10n.tr('cloud_backup_found'),
                logoSize: 68,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthBrandBodyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.tr('cloud_backup_found'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.premiumTokens.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      backupDate,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        AuthStatChip(
                          label: l10n.tr('entries'),
                          value: '${preview?.transactionsCount ?? 0}',
                        ),
                        AuthStatChip(
                          label: l10n.tr('assets'),
                          value:
                              '${(preview?.savingsCount ?? 0) + (preview?.investmentsCount ?? 0)}',
                        ),
                        AuthStatChip(
                          label: l10n.tr('plans'),
                          value: '${preview?.financialPlansCount ?? 0}',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AuthBrandPrimaryButton(
                      label: l10n.tr('restore_backup'),
                      leading: const Icon(
                        Icons.cloud_download_rounded,
                        size: 20,
                      ),
                      onPressed: () async {
                        await widget.onRestore();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AuthBrandSecondaryButton(
                      label: l10n.tr('start_fresh'),
                      foregroundColor: context.premiumTokens.colors.textPrimary,
                      leading: const Icon(Icons.auto_awesome_rounded, size: 20),
                      onPressed: () async {
                        await widget.onStartFresh();
                      },
                    ),
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.tr('loading_backup_preview'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String raw, BuildContext context) {
    final DateTime? value = DateTime.tryParse(raw)?.toLocal();
    if (value == null) return context.l10n.tr('backup_date_unknown');
    final String formatted = MaterialLocalizations.of(
      context,
    ).formatMediumDate(value);
    return '${context.l10n.tr('backup_date')}: $formatted';
  }
}
