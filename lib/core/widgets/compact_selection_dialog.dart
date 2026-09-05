import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../theme/app_colors.dart';

Future<T?> showCompactSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T value) optionLabel,
  String? selectedValueLabel,
}) {
  final ThemeData theme = Theme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.black54,
    transitionDuration: AppMotion.dialogDuration,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          final bool isLargeScreen =
              MediaQuery.sizeOf(dialogContext).width >= 420;
          final double maxWidth = isLargeScreen ? 420 : 360;
          final double maxHeight =
              MediaQuery.sizeOf(dialogContext).height * 0.72;
          final bool scrollable = options.length > 5;
          return Center(
            child: RepaintBoundary(
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        if (scrollable)
                          SizedBox(
                            height: maxHeight * 0.55,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              physics: const ClampingScrollPhysics(),
                              itemCount: options.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (BuildContext context, int index) {
                                final T value = options[index];
                                final String label = optionLabel(value);
                                final bool selected =
                                    selectedValueLabel == label;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  title: Text(
                                    label,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(value),
                                );
                              },
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 2),
                            itemBuilder: (BuildContext context, int index) {
                              final T value = options[index];
                              final String label = optionLabel(value);
                              final bool selected = selectedValueLabel == label;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: Text(
                                  label,
                                  style: theme.textTheme.titleMedium,
                                ),
                                trailing: selected
                                    ? const Icon(Icons.check_rounded, size: 18)
                                    : null,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(value),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          if (AppMotion.reduceMotion(context)) return child;

          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.curve,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
}
