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
    if (value.contains('declined') || value.contains('rejected')) {
      return l10n.tr('smart_capture_reason_declined');
    }
    if (value.contains('invalid') || value.contains('unrecognized')) {
      return l10n.tr('smart_capture_reason_invalid');
    }
    return l10n.tr('smart_capture_reason_unknown');
  }

  static bool isPossibleDuplicate(String? internalReason) =>
      (internalReason ?? '').toLowerCase().contains('possible duplicate');
}
