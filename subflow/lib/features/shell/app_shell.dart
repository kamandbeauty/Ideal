import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_colors.dart';

/// App frame: the three things a person actually does, always one tap away.
///
/// This is the short-form-editor pattern (CapCut, VN, InShot): a persistent
/// bottom bar over a project grid, with every deeper screen pushed on top so the
/// tab state survives. No drawer, no welcome carousel.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination(icon: Icons.video_library_outlined, activeIcon: Icons.video_library_rounded, label: 'پروژه‌ها'),
    _ShellDestination(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'استایل‌ها'),
    _ShellDestination(icon: Icons.tune_outlined, activeIcon: Icons.tune_rounded, label: 'تنظیمات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.screenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: List<Widget>.generate(_destinations.length, (int index) {
                  final _ShellDestination destination = _destinations[index];
                  final bool selected = navigationShell.currentIndex == index;
                  return Expanded(
                    child: InkWell(
                      onTap: () => navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            selected ? destination.activeIcon : destination.icon,
                            size: 22,
                            color: selected ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destination.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
