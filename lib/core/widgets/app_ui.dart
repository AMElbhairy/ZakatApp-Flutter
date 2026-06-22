import 'package:flutter/material.dart';

import '../theme/app_component_tokens.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = hero ? AppRadii.hero : AppRadii.card;
    final Widget content = Ink(
      decoration: hero
          ? AppComponentTokens.heroCard(context)
          : AppComponentTokens.premiumCard(context),
      child: Padding(padding: padding, child: child),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.bottomSpacing = AppSpacing.sm,
  });

  final String title;
  final Widget? trailing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (trailing != null) ...<Widget>[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    this.cardKey,
    required this.title,
    required this.message,
    this.action,
    this.icon,
  });

  final Key? cardKey;
  final String title;
  final String message;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      key: cardKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(label),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _NotificationItem {
  final String message;
  final AppToastKind kind;
  final Duration duration;

  _NotificationItem({
    required this.message,
    required this.kind,
    required this.duration,
  });
}

final List<_NotificationItem> _notificationQueue = [];
bool _isShowingNotification = false;
OverlayEntry? _activeTopToastEntry;
VoidCallback? _activeDismissCallback;

void showTopSnackBar(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.info,
  Duration duration = const Duration(seconds: 3),
}) {
  if (_notificationQueue.length >= 5) {
    _notificationQueue.removeAt(0);
  }
  _notificationQueue.add(
    _NotificationItem(message: message, kind: kind, duration: duration),
  );

  if (_isShowingNotification) {
    if (_activeDismissCallback != null) {
      _activeDismissCallback!();
    }
  } else {
    _showNextNotification(context);
  }
}

void _showNextNotification(BuildContext context) {
  if (_isShowingNotification || _notificationQueue.isEmpty) return;
  if (!context.mounted) {
    _notificationQueue.clear();
    _isShowingNotification = false;
    return;
  }
  _isShowingNotification = true;

  final item = _notificationQueue.removeAt(0);
  final OverlayState overlayState = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _TopToastWidget(
        message: item.message,
        kind: item.kind,
        duration: item.duration,
        onDismiss: () {
          if (_activeTopToastEntry == entry) {
            _activeTopToastEntry = null;
          }
          try {
            entry.remove();
          } catch (_) {}
          _isShowingNotification = false;
          Future.delayed(const Duration(milliseconds: 150), () {
            _showNextNotification(context);
          });
        },
      );
    },
  );

  _activeTopToastEntry = entry;
  overlayState.insert(entry);
}

enum AppToastKind { info, success, warning, error }

class _TopToastWidget extends StatefulWidget {
  const _TopToastWidget({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final AppToastKind kind;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _activeDismissCallback = _dismiss;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    if (_activeDismissCallback == _dismiss) {
      _activeDismissCallback = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double adjustedTop = topPadding > 0 ? topPadding + 12.0 : 36.0;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.premiumTokens;

    final Color accent = switch (widget.kind) {
      AppToastKind.success => tokens.colors.success,
      AppToastKind.warning => tokens.colors.warning,
      AppToastKind.error => tokens.colors.danger,
      AppToastKind.info => tokens.colors.emerald,
    };

    final Color bgColor = dark
        ? Color.lerp(
            tokens.colors.surface,
            accent,
            0.12,
          )!.withValues(alpha: 0.98)
         : Colors.white.withValues(alpha: 0.98);
    final Color textColor = tokens.colors.textPrimary;
    final Color borderColor = accent.withValues(alpha: dark ? 0.35 : 0.24);
    final IconData icon = switch (widget.kind) {
      AppToastKind.success => Icons.check_circle_rounded,
      AppToastKind.warning => Icons.report_rounded,
      AppToastKind.error => Icons.error_rounded,
      AppToastKind.info => Icons.info_rounded,
    };

    return Positioned(
      top: adjustedTop,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.34 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
