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
    background: Color(0xFFF8F6EF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    hero: Color(0xFF073B3A),
    emerald: Color(0xFF0F766E),
    gold: Color(0xFFC8A75B),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF5B6676),
    divider: Color(0xFFDCE4DF),
    success: Color(0xFF047857),
    warning: Color(0xFFB7791F),
    danger: Color(0xFFDC2626),
  );

  static const AppColorTokens dark = AppColorTokens(
    background: Color(0xFF070B12),
    surface: Color(0xFF0B1218),
    card: Color(0xFF0F171D),
    hero: Color(0xFF062F31),
    emerald: Color(0xFF0FA18F),
    gold: Color(0xFFC8A75B),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFA3B0BF),
    divider: Color(0xFF273443),
    success: Color(0xFF10B981),
    warning: Color(0xFFE0A53A),
    danger: Color(0xFFF87171),
  );
}
