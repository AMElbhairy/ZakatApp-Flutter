import 'package:flutter/widgets.dart';

import '../../core/errors/user_facing_error_mapper.dart';
import '../../core/i18n/app_localizations.dart';

class BackupErrorPresenter {
  const BackupErrorPresenter._();

  static String getFriendlyMessage(
    String? technicalError,
    BuildContext context,
  ) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (technicalError == null || technicalError.trim().isEmpty) {
      return '';
    }

    final lower = technicalError.toLowerCase();

    // 1. Storage Full (Google & Local)
    if (lower.contains('storage') && lower.contains('full')) {
      if (lower.contains('google') || lower.contains('drive')) {
        return isArabic
            ? 'مساحة تخزين Google الخاصة بك ممتلئة.'
            : 'Your Google storage is full.';
      }
      return isArabic
          ? 'لا توجد مساحة كافية على الجهاز لإنشاء نسخة احتياطية.'
          : 'Not enough device storage to create a backup.';
    }

    // 2. Auth / 401
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('session expired') ||
        lower.contains('auth missing') ||
        lower.contains('authorization is missing')) {
      return isArabic
          ? 'انتهت صلاحية اتصال حساب Google الخاص بك. يرجى إعادة الاتصال.'
          : 'Your Google account connection expired. Please reconnect.';
    }

    // 3. Permission Denied / 403
    if (lower.contains('403') ||
        lower.contains('permissiondenied') ||
        lower.contains('permission_denied')) {
      return isArabic
          ? 'الوصول إلى Google Drive غير متاح. يرجى إعادة ربط حسابك.'
          : 'Google Drive access is unavailable. Please reconnect your account.';
    }

    // 4. Rate Limiting / 429
    if (lower.contains('429') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests')) {
      return isArabic
          ? 'جوجل درايف مشغول مؤقتاً. سنحاول مرة أخرى قريباً.'
          : 'Google Drive is temporarily busy. We\'ll try again shortly.';
    }

    // 5. Google Drive Server Down / 5xx
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('servererror') ||
        lower.contains('unavailable')) {
      return isArabic
          ? 'جوجل درايف غير متاح مؤقتاً. سنقوم بإعادة المحاولة تلقائياً.'
          : 'Google Drive is temporarily unavailable. We\'ll retry automatically.';
    }

    // 6. Offline / No Internet
    if (lower.contains('network') ||
        lower.contains('offline') ||
        lower.contains('no internet')) {
      return isArabic
          ? 'أنت غير متصل بالإنترنت. ستستمر النسخة الاحتياطية عند الاتصال.'
          : 'You\'re offline. Backup will continue when you\'re connected.';
    }

    // 7. Timeout
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('errno = 60')) {
      return isArabic
          ? 'انتهت مهلة الاتصال. حاول مرة أخرى.'
          : 'Connection timed out. Try again.';
    }

    // 8. Corrupt / Damaged backup
    if (lower.contains('corrupt') ||
        lower.contains('damaged') ||
        lower.contains('checksum mismatch') ||
        lower.contains('mac check failed')) {
      return isArabic
          ? 'تعذر استعادة هذه النسخة الاحتياطية لأنها تبدو تالفة.'
          : 'This backup couldn\'t be restored because it appears damaged.';
    }

    // 9. Incompatible backup / Schema / App version
    if (lower.contains('incompatible') ||
        lower.contains('schema') ||
        lower.contains('app version') ||
        lower.contains('update the app')) {
      return isArabic
          ? 'يرجى تحديث التطبيق قبل استعادة هذه النسخة الاحتياطية.'
          : 'Update the app before restoring this backup.';
    }

    // Preserve the specific classifications above, but use the shared mapper
    // for all future/unknown provider errors.
    return UserFacingErrorMapper.message(
      AppLocalizations.of(context),
      technicalError,
      context: 'backup',
    );
  }
}
