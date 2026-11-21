import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/job_providers.dart';
import '../core/providers/repository_providers.dart';
import '../core/providers/service_providers.dart';
import '../core/theme/app_colors.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/settings/settings_screen.dart';
import '../services/job_runner.dart';

/// Bottom navigation destinations, in Persian.
enum AppTab {
  assistant(Icons.graphic_eq_rounded, 'دستیار'),
  notes(Icons.sticky_note_2_rounded, 'یادداشت‌ها'),
  jobs(Icons.alarm_rounded, 'وظایف'),
  messages(Icons.forum_rounded, 'پیام‌ها'),
  settings(Icons.tune_rounded, 'تنظیمات');

  const AppTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

final selectedTabProvider = StateProvider<AppTab>((ref) => AppTab.assistant);

/// The five-tab shell. Every tab is a real screen; nothing is a placeholder.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final _pages = const <Widget>[
    AssistantScreen(),
    NotesScreen(),
    JobsScreen(),
    MessagesScreen(),
    SettingsScreen(),
  ];

  /// The scheduler lives as long as the shell: a foreground timer while the UI
  /// is alive, plus the native alarm that covers the app being closed.
  late final JobTicker _scheduler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduler = ref.read(jobSchedulerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startScheduler());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduler.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resuming (or an unlock) is exactly when missed jobs matter: catch up
    // immediately instead of waiting for the next timer tick. Deliberately not
    // awaited — the lifecycle callback must not block the frame pipeline.
    if (state == AppLifecycleState.resumed) {
      unawaited(_startScheduler());
    }
  }

  Future<void> _startScheduler() async {
    if (!mounted) return;
    if (!_scheduler.isRunning) await _scheduler.start();
    final result = await _scheduler.tick();
    if (!mounted || result == null || result.isEmpty) return;
    ref.invalidate(jobsProvider);
    ref.invalidate(assistantMessagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedTabProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.gradientBackground
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.surfaceLight, Color(0xFFEDEBF7)],
                ),
        ),
        child: SafeArea(
          bottom: false,
          // `IndexedStack` keeps each tab mounted but offstage: the scroll
          // position and any loaded data survive a tab switch, and only one
          // page is ever painted. Wrapping tabs in `AnimatedSwitcher` is what
          // broke semantics: every tab is a CustomScrollView, and animating a
          // sliver out of the tree invalidates parent data mid-flush.
          child: IndexedStack(index: tab.index, children: _pages),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: Theme.of(context).navigationBarTheme.copyWith(
              shadowColor: Colors.black26,
            ),
        child: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (index) =>
              ref.read(selectedTabProvider.notifier).state = AppTab.values[index],
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final destination in AppTab.values)
              NavigationDestination(
                icon: _BadgeIcon(
                  icon: destination.icon,
                  count: destination == AppTab.messages ? unread : 0,
                ),
                selectedIcon: _BadgeIcon(
                  icon: destination.icon,
                  count: destination == AppTab.messages ? unread : 0,
                  selected: true,
                ),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count, this.selected = false});

  final IconData icon;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    if (count <= 0) return Icon(icon, color: color);
    return Badge(
      label: Text('$count'),
      backgroundColor: AppColors.coral,
      child: Icon(icon, color: color),
    );
  }
}
