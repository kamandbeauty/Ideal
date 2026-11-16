import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/job.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import 'job_editor_screen.dart';
import 'job_history_screen.dart';

final jobsRevisionProvider = StateProvider<int>((ref) => 0);

/// Tab 3 — scheduled jobs with enable/disable, history and manual run.
class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, Job job) async {
    final service = ref.read(jobServiceProvider);
    try {
      await service.setEnabled(job, !job.isActive);
      ref.read(jobsRevisionProvider.notifier).state++;
    } on JobValidationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف وظیفه'),
        content: Text('وظیفهٔ «${job.title}» و تاریخچهٔ اجرای آن حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(jobServiceProvider).delete(job.id);
    ref.read(jobsRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(jobsRevisionProvider);
    final jobs = ref.watch(jobsProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(jobsProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('وظایف', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'یادآوری‌ها و کارهای دوره‌ای دستیار',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'وظیفهٔ جدید',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(builder: (_) => const JobEditorScreen()),
                    ),
                    icon: const Icon(Icons.add_alarm_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _ReliabilityNotice(),
            ),
          ),
          jobs.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'خواندن وظایف ممکن نشد',
                description: '$error',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.alarm_add_outlined,
                    title: 'هنوز وظیفه‌ای نداری',
                    description: 'بگو «هر روز ساعت ۸ خلاصهٔ پیام‌ها را بگو» '
                        'یا با دکمهٔ بالا یکی بساز.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(builder: (_) => const JobEditorScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('وظیفهٔ جدید'),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                sliver: SliverList.separated(
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return SectionHeader(
                        title: '${items.length} وظیفه',
                        subtitle: '${items.where((job) => job.isActive).length} فعال',
                        icon: Icons.alarm_rounded,
                      );
                    }
                    final job = items[index - 1];
                    return _JobCard(
                      job: job,
                      onToggle: () => _toggle(context, ref, job),
                      onDelete: () => _delete(context, ref, job),
                      onHistory: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JobHistoryScreen(job: job),
                        ),
                      ),
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => JobEditorScreen(job: job),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReliabilityNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      accent: AppColors.amber,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.battery_alert_rounded, color: AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'اندروید ممکن است اجرای وظایف را در پس‌زمینه به تأخیر بیندازد. برای '
              'دقت بیشتر، محدودیت باتری را در تنظیمات غیرفعال کن. هیچ وظیفه‌ای '
              'بدون اطلاع تو اجرا نمی‌شود و نتیجه‌اش در تاریخچه ثبت می‌گردد.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onToggle,
    required this.onDelete,
    required this.onHistory,
    required this.onEdit,
  });

  final Job job;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (job.lastStatus) {
      JobStatus.success => AppColors.mint,
      JobStatus.failed => AppColors.coral,
      JobStatus.running => AppColors.indigo,
      JobStatus.pending => theme.colorScheme.primary,
    };
    final statusLabel = switch (job.lastStatus) {
      JobStatus.success => 'موفق',
      JobStatus.failed => 'ناموفق',
      JobStatus.running => 'در حال اجرا',
      JobStatus.pending => job.isActive ? 'در انتظار' : 'غیرفعال',
    };

    return SurfaceCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Switch(
                value: job.isActive,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          Text(
            job.scheduleLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (job.nextRunAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'اجرای بعدی: ${PersianDate.scheduleLabel(job.nextRunAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (job.lastStatus == JobStatus.failed && job.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'آخرین خطا: ${job.lastError}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.coral),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(label: statusLabel, color: statusColor, dense: true),
              const SizedBox(width: 6),
              StatusChip(
                label: '${job.runCount} اجرا',
                dense: true,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('تاریخچه'),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
