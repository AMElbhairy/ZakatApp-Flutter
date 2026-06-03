import 'package:flutter/material.dart';

import '../theme/app_component_tokens.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

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
      decoration: hero ? AppComponentTokens.heroCard(context) : AppComponentTokens.premiumCard(context),
      child: Padding(padding: padding, child: child),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: content,
            ),
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
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
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
          if (action != null) ...<Widget>[const SizedBox(height: AppSpacing.sm), action!],
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

OverlayEntry? _activeTopToastEntry;

void showTopSnackBar(BuildContext context, String message) {
  if (_activeTopToastEntry != null) {
    try {
      _activeTopToastEntry!.remove();
    } catch (_) {}
    _activeTopToastEntry = null;
  }

  final OverlayState overlayState = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return _TopToastWidget(
        message: message,
        onDismiss: () {
          if (_activeTopToastEntry == entry) {
            _activeTopToastEntry = null;
          }
          try {
            entry.remove();
          } catch (_) {}
        },
      );
    },
  );

  _activeTopToastEntry = entry;
  overlayState.insert(entry);
}

class _TopToastWidget extends StatefulWidget {
  const _TopToastWidget({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = dark
        ? const Color(0xFF1E293B).withValues(alpha: 0.95)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.95);
    final Color textColor = dark ? Colors.white : const Color(0xFF1E293B);
    final Color borderColor = dark
        ? const Color(0xFF334155).withValues(alpha: 0.5)
        : const Color(0xFFE2E8F0);

    return Positioned(
      top: topPadding + 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
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

