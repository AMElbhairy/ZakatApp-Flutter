import 'package:flutter/material.dart';

@immutable
class AppColorTokens {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.hero,
    required this.emerald,
    required this.gold,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color hero;
  final Color emerald;
  final Color gold;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color success;
  final Color warning;
  final Color danger;

  Color get primarySurface => background;
  Color get secondarySurface => surface;
  Color get heroSurface => hero;
  Color get cardSurface => card;
  Color get primaryText => textPrimary;
  Color get secondaryText => textSecondary;
  Color get disabledText => textSecondary.withValues(alpha: 0.62);
  Color get border => divider;
  Color get borderStrong => divider.withValues(alpha: 0.86);
  Color get dividerWeak => divider.withValues(alpha: 0.58);
  Color get selected => gold;
  Color get unselected => textSecondary;
  Color get income => AppColors.income;
  Color get expense => AppColors.expense;
  Color get transfer => AppColors.transfer;
  Color get badgeSuccess => AppColors.badgeSuccessBackground;
  Color get badgeWarning => AppColors.badgeWarningBackground;
  Color get badgeError => AppColors.badgeErrorBackground;
  Color get onHero => AppColors.white;
  Color get onHeroMuted => AppColors.white70;
  Color get onHeroSubtle => AppColors.white60;
  Color get onHeroDisabled => AppColors.white38;
  Color get onHeroBorder => AppColors.white24;
  Color get onPrimarySurface => textPrimary;
  Color get onSecondarySurface => textPrimary;
}

class AppColors {
  AppColors._();

  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white38 = Color(0x61FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black87 = Color(0xDD000000);
  static const Color black54 = Color(0x8A000000);
  static const Color black38 = Color(0x61000000);
  static const Color black26 = Color(0x42000000);
  static const Color black12 = Color(0x1F000000);

  static const Color deepEmerald = Color(0xFF01332B);
  static const Color emeraldCore = Color(0xFF00221C);
  static const Color tealAccent = Color(0xFF0F766E);
  static const Color mintAccent = Color(0xFF14B8A6);
  static const Color emeraldSuccess = Color(0xFF047857);
  static const Color emeraldSuccessLight = Color(0xFF10B981);
  static const Color emeraldStrong = Color(0xFF2E7D32);
  static const Color emeraldSoft = Color(0xFF176B55);
  static const Color deepTeal = Color(0xFF0B4A43);
  static const Color brandForest = Color(0xFF063B35);
  static const Color brandForestAlt = Color(0xFF075E54);
  static const Color brandTeal = Color(0xFF0A5A52);
  static const Color brandTealAlt = Color(0xFF0C6B60);
  static const Color brandSand = Color(0xFFF2EFE7);
  static const Color brandSandAlt = Color(0xFFF6F3EA);
  static const Color brandSandSoft = Color(0xFFF3F0E8);
  static const Color brandSandSoftAlt = Color(0xFFF6F3EB);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldMuted = Color(0xFFC5A059);
  static const Color goldWarm = Color(0xFFC8A75B);
  static const Color goldBright = Color(0xFFFFC928);
  static const Color goldSoft = Color(0xFFFFE08A);
  static const Color redStrong = Color(0xFFC62828);
  static const Color redAccent = Color(0xFFBE123C);
  static const Color redSoft = Color(0xFFFF7A7A);
  static const Color redTint = Color(0xFFF87171);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeDeep = Color(0xFFEA580C);
  static const Color orangeMuted = Color(0xFFD97706);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBright = Color(0xFF3B82F6);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFF8B5CF6);
  static const Color lavender = Color(0xFFA78BFA);
  static const Color gray = Color(0xFF64748B);
  static const Color slate = Color(0xFF94A3B8);
  static const Color slateSoft = Color(0xFF9CA3AF);
  static const Color slateMuted = Color(0xFFA3B8B5);
  static const Color slateDark = Color(0xFF6B7280);
  static const Color olive = Color(0xFF6B8E23);
  static const Color brown = Color(0xFF8E6A4B);
  static const Color rose = Color(0xFFB54747);
  static const Color neutralInk = Color(0xFF111111);
  static const Color neutral900 = Color(0xFF0F1720);
  static const Color neutral800 = Color(0xFF1E1E1E);
  static const Color neutral700 = Color(0xFF17231F);
  static const Color neutral600 = Color(0xFF5C6675);
  static const Color neutral500 = Color(0xFF6D7974);
  static const Color neutral400 = Color(0xFF9CA8A3);
  static const Color neutral300 = Color(0xFFB7C3CF);
  static const Color neutral200 = Color(0xFFE6E3D9);
  static const Color neutral150 = Color(0xFFDCE4DF);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral90 = Color(0xFFF1F5F9);
  static const Color neutral80 = Color(0xFFF4F2EA);
  static const Color neutral70 = Color(0xFFF0F4F3);
  static const Color neutral60 = Color(0xFFF2E5BF);
  static const Color neutral50 = Color(0xFFF9F0DB);
  static const Color neutral40 = Color(0xFFEBE8E0);
  static const Color neutral30 = Color(0xFFE8E8E8);
  static const Color surfaceInk = Color(0xFF1E2725);
  static const Color surfacePale = Color(0xFFF0F4F3);
  static const Color surfaceWarmDark = Color(0xFF172422);
  static const Color surfaceWarmLight = Color(0xFFF4F2EA);
  static const Color surfaceGold = Color(0xFFF2E5BF);
  static const Color surfaceRose = Color(0xFFFFE4E6);
  static const Color surfaceMint = Color(0xFFD1FAE5);
  static const Color surfaceAmber = Color(0xFFFEF3C7);
  static const Color surfaceNeutral = Color(0xFFF3F4F6);
  static const Color surfaceLavender = Color(0xFFF3E8FF);
  static const Color surfaceOrange = Color(0xFFFFEDD5);
  static const Color greenAccent = Color(0xFF21D99B);
  static const Color greenAccentSoft = Color(0xFF66DFB4);
  static const Color redAccentSoft = Color(0xFFFFB4AB);
  static const Color goldAccent = Color(0xFFFFC928);
  static const Color goldAccentSoft = Color(0xFFFFE08A);

  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color successContainerAlt = Color(0xFFE5F1E9);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color warningContainerAlt = Color(0xFFF9F0DB);
  static const Color errorContainer = Color(0xFFFFE4E6);
  static const Color infoContainer = Color(0xFFE1EFF6);
  static const Color neutralContainer = Color(0xFFF3F4F6);
  static const Color mutedContainer = Color(0xFFF0EBE0);
  static const Color sharedContainer = Color(0xFFFAF8F2);

  static const Color badgeSuccessBackground = successContainer;
  static const Color badgeSuccessForeground = emeraldSuccess;
  static const Color badgeWarningBackground = warningContainer;
  static const Color badgeWarningForeground = goldMuted;
  static const Color badgeErrorBackground = errorContainer;
  static const Color badgeErrorForeground = redStrong;

  static const Color income = emeraldStrong;
  static const Color expense = redStrong;
  static const Color transfer = gold;
  static const Color selected = gold;
  static const Color unselected = slateMuted;
  static const Color border = neutral200;
  static const Color borderDark = Color(0xFF181E24);
  static const Color surfaceDark = Color(0xFF071714);
  static const Color cardDark = Color(0xFF0D221D);
  static const Color heroDark = Color(0xFF062F31);
  static const Color backgroundDark = Color(0xFF04110F);
  static const Color backgroundHeroDark = Color(0xFF021815);
  static const Color backgroundHero = Color(0xFF01332B);

  static const AppColorTokens light = AppColorTokens(
    background: Color(0xFFF9F8F3),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    hero: Color(0xFF01332B),
    emerald: Color(0xFF00221C),
    gold: Color(0xFFD4AF37),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFFA3B8B5),
    divider: Color(0xFFE6E3D9),
    success: Color(0xFF047857),
    warning: Color(0xFFB7791F),
    danger: Color(0xFFDC2626),
  );

  static const AppColorTokens dark = AppColorTokens(
    background: Color(0xFF04110F),
    surface: Color(0xFF071714),
    card: Color(0xFF0D221D),
    hero: Color(0xFF062F31),
    emerald: Color(0xFF0FA18F),
    gold: Color(0xFFC8A75B),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFA3B0BF),
    divider: Color(0xFF181E24),
    success: Color(0xFF10B981),
    warning: Color(0xFFE0A53A),
    danger: Color(0xFFF87171),
  );
}
