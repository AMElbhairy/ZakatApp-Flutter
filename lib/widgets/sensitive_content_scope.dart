import 'package:flutter/material.dart';

class SensitiveContentScope extends StatelessWidget {
  const SensitiveContentScope({
    super.key,
    required this.child,
    this.active = true,
  });

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) => child;
}
