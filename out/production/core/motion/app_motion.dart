import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Curve curve = Curves.easeOutCubic;
  static const Duration microDuration = Duration(milliseconds: 100);
  static const Duration smallDuration = Duration(milliseconds: 160);
  static const Duration pageDuration = Duration(milliseconds: 240);
  static const Duration largeDuration = Duration(milliseconds: 300);
  static const Duration valueDuration = Duration(milliseconds: 400);
  static const Duration sectionDuration = Duration(milliseconds: 180);
  static const Duration listItemDuration = Duration(milliseconds: 180);
  static const Duration dialogDuration = Duration(milliseconds: 180);
  static const Duration bottomSheetDuration = Duration(milliseconds: 240);
  static const Duration snackBarDuration = Duration(milliseconds: 240);
  static const Duration pressDuration = Duration(milliseconds: 90);

  static bool reduceMotion(BuildContext context) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
  }
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduceMotion(context)) {
      return child;
    }

    final Animation<double> fade = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
    );
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0.045, 0),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class AnimatedSection extends StatefulWidget {
  const AnimatedSection({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.sectionDuration,
    this.offsetY = 8,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<AnimatedSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.delay == Duration.zero) {
        setState(() => _visible = true);
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) setState(() => _visible = true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return widget.child;

    final double offset = _visible ? 0 : widget.offsetY;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: AppMotion.curve,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: offset, end: 0),
        duration: widget.duration,
        curve: AppMotion.curve,
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.translate(offset: Offset(0, value), child: child);
        },
        child: widget.child,
      ),
    );
  }
}

class AnimatedCard extends StatelessWidget {
  const AnimatedCard({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.sectionDuration,
    this.offsetY = 8,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return AnimatedSection(
      delay: delay,
      duration: duration,
      offsetY: offsetY,
      child: child,
    );
  }
}

class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    this.duration = AppMotion.listItemDuration,
    this.offsetY = 10,
  });

  final Widget child;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return AnimatedSection(duration: duration, offsetY: offsetY, child: child);
  }
}

class AnimatedValue extends StatefulWidget {
  const AnimatedValue({
    super.key,
    required this.value,
    required this.builder,
    this.duration = AppMotion.valueDuration,
  });

  final double value;
  final Duration duration;
  final Widget Function(BuildContext context, double value, Widget? child)
  builder;

  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue> {
  late double _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return widget.builder(context, widget.value, null);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previousValue, end: widget.value),
      duration: widget.duration,
      curve: AppMotion.curve,
      builder: widget.builder,
    );
  }
}

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = AppMotion.pressDuration,
  });

  final Widget child;
  final bool enabled;
  final Duration duration;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduceMotion(context)) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: widget.duration,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
