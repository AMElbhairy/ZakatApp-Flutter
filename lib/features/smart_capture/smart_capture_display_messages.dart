import '../../core/i18n/app_localizations.dart';

class SmartCaptureDisplayMessages {
  const SmartCaptureDisplayMessages._();

  static String reason(AppLocalizations l10n, String? internalReason) {
    final String value = (internalReason ?? '').trim().toLowerCase();
    if (value.contains('possible duplicate')) {
      return l10n.tr('smart_capture_reason_possible_duplicate');
    }
    if (value.contains('duplicate')) {
      return l10n.tr('smart_capture_reason_duplicate');
    }
    if (value.contains('verification') ||
        value.contains('otp') ||
        value.contains('security')) {
      return l10n.tr('smart_capture_reason_security');
    }
    if (value.contains('subscription activation')) {
      return l10n.tr('smart_capture_reason_subscription');
    }
    if (value.contains('manually ignored') ||
        value.contains('manually rejected')) {
      return l10n.tr('smart_capture_reason_manually_rejected');
    }
    if (value.contains('declined') || value.contains('rejected')) {
      return l10n.tr('smart_capture_reason_declined');
    }
    if (value.contains('invalid') || value.contains('unrecognized')) {
      return l10n.tr('smart_capture_reason_invalid');
    }
    if (value.contains('deleted from activity') ||
        value.contains('deleted by user')) {
      return l10n.tr('smart_capture_reason_deleted_by_user');
    }
    // Preserve a custom rejection reason instead of replacing it with the
    // generic parser fallback.
    final String raw = (internalReason ?? '').trim();
    return raw.isEmpty ? l10n.tr('smart_capture_reason_unknown') : raw;
  }

  static bool isPossibleDuplicate(String? internalReason) =>
      (internalReason ?? '').toLowerCase().contains('possible duplicate');
}
