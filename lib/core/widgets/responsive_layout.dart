import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  const ResponsiveLayout._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= 390;

  static bool isVeryCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static double compactHorizontalPadding(
    BuildContext context, {
    double wide = 16,
    double compact = 12,
    double veryCompact = 10,
  }) {
    if (isVeryCompact(context)) return veryCompact;
    if (isCompact(context)) return compact;
    return wide;
  }

  static EdgeInsetsGeometry chipPadding(
    BuildContext context, {
    double wideHorizontal = 10,
    double compactHorizontal = 8,
    double veryCompactHorizontal = 6,
    double vertical = 7,
  }) {
    final double horizontal = isVeryCompact(context)
        ? veryCompactHorizontal
        : isCompact(context)
        ? compactHorizontal
        : wideHorizontal;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }
}
