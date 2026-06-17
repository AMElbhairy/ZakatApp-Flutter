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
}

class AppColors {
  AppColors._();

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
    card: Color(0xFF0A1D19),
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
