import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_extensions.dart';
import 'auth_brand_ui.dart';

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({
    super.key,
    required this.isAccountVerified,
    required this.isCheckingCloudBackup,
    required this.isLoadingEntries,
    required this.isLoadingAssets,
    required this.isLoadingPlans,
    this.statusMessage,
  });

  final bool isAccountVerified;
  final bool isCheckingCloudBackup;
  final bool isLoadingEntries;
  final bool isLoadingAssets;
  final bool isLoadingPlans;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.premiumTokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = dark
        ? tokens.colors.textSecondary
        : tokens.colors.hero;
    final AppLocalizations l10n = context.l10n;
    return AuthBrandShell(
      tone: AuthBackdropTone.shared,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AuthBrandHeader(
            title: l10n.tr('brand_title'),
            subtitle: l10n.tr('loading_title'),
            logoSize: 68,
            compact: true,
            framedLogo: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (statusMessage != null) ...<Widget>[
            Text(
              statusMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AuthChecklistItem(
                  label: l10n.tr('verifying_account'),
                  isDone: isAccountVerified,
                  isActive: !isAccountVerified,
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthChecklistItem(
                  label: l10n.tr('checking_cloud_backup'),
                  isDone: isAccountVerified && !isCheckingCloudBackup,
                  isActive: isAccountVerified && isCheckingCloudBackup,
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthChecklistItem(
                  label: l10n.tr('loading_entries'),
                  isDone: !isLoadingEntries,
                  isActive: isLoadingEntries,
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthChecklistItem(
                  label: l10n.tr('loading_assets'),
                  isDone: !isLoadingAssets,
                  isActive: isLoadingAssets,
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthChecklistItem(
                  label: l10n.tr('loading_plans'),
                  isDone: !isLoadingPlans,
                  isActive: isLoadingPlans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
