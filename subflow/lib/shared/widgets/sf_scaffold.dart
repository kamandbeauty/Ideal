import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gradient background + safe area. Used by every screen so the app has one
/// visual rhythm instead of per-screen gradients.
class SfScaffold extends StatelessWidget {
  const SfScaffold({
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padded = true,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.screenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          child: padded ? Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child) : child,
        ),
      ),
    );
  }
}
