import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SfCard extends StatelessWidget {
  const SfCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? AppColors.surface : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
