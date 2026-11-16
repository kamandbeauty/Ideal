import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/providers/permission_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/voice_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/job.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/status_chip.dart';

final todayJobsProvider = FutureProvider<List<Job>>((ref) async {
  final jobs = await ref.watch(jobServiceProvider).list();
  final now = DateTime.now();
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return jobs
      .where((job) =>
          job.isActive &&
          job.nextRunAt != null &&
          job.nextRunAt!.isBefore(endOfDay))
      .toList();
});

final todayNotificationsProvider = FutureProvider<List<CapturedNotification>>(
  (ref) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return ref.watch(notificationRepositoryProvider).since(startOfDay);
  },
);

/// A compact dashboard used as the assistant's overview card on the home tab.
class DashboardSummary extends ConsumerWidget {
  const DashboardSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobs = ref.watch(todayJobsProvider).valueOrNull ?? const <Job>[];
    final notifications =
        ref.watch(todayNotificationsProvider).valueOrNull ?? const <CapturedNotification>[];
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final access = ref.watch(notificationAccessProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.alarm_rounded,
                label: 'وظیفهٔ امروز',
                value: toPersianDigits(jobs.length),
                tone: AppColors.indigo,
                onTap: () =>
                    ref.read(selectedTabProvider.notifier).state = AppTab.jobs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.mark_email_unread_rounded,
                label: 'پیام خوانده‌نشده',
                value: toPersianDigits(unread),
                tone: AppColors.mint,
                onTap: () =>
                    ref.read(selectedTabProvider.notifier).state = AppTab.messages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.forum_rounded,
                label: 'پیام امروز',
                value: toPersianDigits(notifications.length),
                tone: AppColors.violetLight,
                onTap: () =>
                    ref.read(selectedTabProvider.notifier).state = AppTab.messages,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          onTap: () => ref
              .read(assistantControllerProvider.notifier)
              .submitText('خلاصهٔ امروز را بگو'),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('خلاصهٔ روزانه', style: theme.textTheme.titleMedium),
                    Text(
                      access
                          ? 'پیام‌ها و وظایف امروز را با صدا برایت می‌خوانم.'
                          : 'دسترسی به اعلان‌ها خاموش است؛ خلاصه فقط از وظایف ساخته می‌شود.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (jobs.isNotEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.today_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('برنامهٔ امروز', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                for (final job in jobs.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        StatusChip(
                          label: PersianDate.clock(job.nextRunAt!),
                          dense: true,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(job.title, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          )),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
