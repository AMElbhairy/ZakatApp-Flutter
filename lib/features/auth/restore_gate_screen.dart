import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/errors/user_facing_error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import '../../models/backup_preview.dart';
import '../../services/cloud_backup_controller.dart';
import '../../services/startup_restore_discovery.dart';
import 'auth_brand_ui.dart';

class RestoreGateScreen extends StatefulWidget {
  const RestoreGateScreen({
    super.key,
    required this.cloudBackupController,
    required this.onRestore,
    required this.onStartFresh,
    required this.discovery,
    this.onOpenBackupSync,
  });

  final CloudBackupController? cloudBackupController;
  final Future<void> Function() onRestore;
  final Future<void> Function() onStartFresh;
  final StartupRestoreDiscoveryResult discovery;
  final Future<void> Function()? onOpenBackupSync;

  @override
  State<RestoreGateScreen> createState() => _RestoreGateScreenState();
}

class _RestoreGateScreenState extends State<RestoreGateScreen> {
  late Future<BackupPreview?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.discovery.isLocalBackup
        ? Future<BackupPreview?>.value(widget.discovery.preview)
        : widget.discovery.hasRestorableBackup
        ? widget.cloudBackupController?.previewLatestBackup() ??
              Future<BackupPreview?>.value(widget.discovery.preview)
        : Future<BackupPreview?>.value(widget.discovery.preview);
  }

  @override
  void didUpdateWidget(covariant RestoreGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudBackupController != widget.cloudBackupController ||
        oldWidget.discovery.source != widget.discovery.source ||
        oldWidget.discovery.preview != widget.discovery.preview) {
      _previewFuture = widget.discovery.isLocalBackup
          ? Future<BackupPreview?>.value(widget.discovery.preview)
          : widget.discovery.hasRestorableBackup
          ? widget.cloudBackupController?.previewLatestBackup() ??
                Future<BackupPreview?>.value(widget.discovery.preview)
          : Future<BackupPreview?>.value(widget.discovery.preview);
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
    final bool restoreAvailable = widget.discovery.hasRestorableBackup;
    final bool needsDrivePermission = widget.discovery.needsDrivePermission;
    final bool needsKeyRecovery = widget.discovery.needsKeyRecovery;
    final bool isLocalBackup = widget.discovery.isLocalBackup;
    final String subtitle = isLocalBackup
        ? widget.discovery.message
        : needsDrivePermission
        ? l10n.tr('restore_backup_may_exist')
        : needsKeyRecovery
        ? widget.discovery.message
        : l10n.tr('cloud_backup_found');
    return FutureBuilder<BackupPreview?>(
      future: _previewFuture,
      builder: (BuildContext context, AsyncSnapshot<BackupPreview?> snapshot) {
        final BackupPreview? preview = snapshot.data;
        final String backupDate = preview == null
            ? l10n.tr('backup_date_unknown')
            : _formatDate(preview.exportedAt, context);
        return AuthBrandShell(
          tone: AuthBackdropTone.shared,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AuthBrandHeader(
                  title: l10n.tr('brand_title'),
                  subtitle: subtitle,
                  logoSize: 68,
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthBrandBodyCard(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          isLocalBackup
                              ? 'Local backup found'
                              : needsDrivePermission
                              ? l10n.tr('restore_backup_may_exist_title')
                              : needsKeyRecovery
                              ? l10n.tr('restore_backup_key_required')
                              : l10n.tr('cloud_backup_found'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: context.premiumTokens.colors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          isLocalBackup
                              ? widget.discovery.message
                              : needsDrivePermission
                              ? l10n.tr('restore_open_backup_sync')
                              : needsKeyRecovery
                              ? widget.discovery.message
                              : backupDate,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: secondaryTextColor),
                        ),
                        if (widget.discovery.hasError) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            UserFacingErrorMapper.message(
                              l10n,
                              widget.discovery.error,
                              context: 'restore',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        if (restoreAvailable) ...<Widget>[
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
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        if (restoreAvailable)
                          AuthBrandPrimaryButton(
                            label: l10n.tr('restore_backup'),
                            leading: Icon(
                              isLocalBackup
                                  ? Icons.backup_rounded
                                  : Icons.cloud_download_rounded,
                              size: 20,
                            ),
                            onPressed: () async {
                              await widget.onRestore();
                            },
                          )
                        else if (needsDrivePermission)
                          AuthBrandPrimaryButton(
                            label: l10n.tr('restore_open_backup_sync_button'),
                            leading: const Icon(
                              Icons.cloud_queue_rounded,
                              size: 20,
                            ),
                            onPressed: widget.onOpenBackupSync == null
                                ? null
                                : () async {
                                    await widget.onOpenBackupSync!();
                                  },
                          )
                        else
                          AuthBrandPrimaryButton(
                            label: l10n.tr('start_fresh'),
                            leading: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                            ),
                            onPressed: () async {
                              await widget.onStartFresh();
                            },
                          ),
                        if (restoreAvailable ||
                            needsDrivePermission) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          AuthBrandSecondaryButton(
                            label: l10n.tr('start_fresh'),
                            foregroundColor:
                                context.premiumTokens.colors.textPrimary,
                            leading: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                            ),
                            onPressed: () async {
                              await widget.onStartFresh();
                            },
                          ),
                        ],
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            restoreAvailable) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.tr('loading_backup_preview'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: secondaryTextColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
