import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/job.dart';
import '../../data/models/job_run.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/status_chip.dart';

final jobRunsProvider =
    FutureProvider.family<List<JobRun>, String>((ref, jobId) async {
  return ref.watch(jobServiceProvider).runsFor(jobId);
});

class JobHistoryScreen extends ConsumerWidget {
  const JobHistoryScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(jobRunsProvider(job.id));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('تاریخچهٔ «${job.title}»')),
      body: SafeArea(
        child: runs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'خواندن تاریخچه ممکن نشد',
            description: '$error',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'هنوز اجرایی ثبت نشده',
                description: 'پس از اولین اجرا، نتیجه و خروجی همین‌جا نمایش داده می‌شود.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final run = items[index];
                final color = switch (run.status) {
                  JobStatus.success => AppColors.mint,
                  JobStatus.failed => AppColors.coral,
                  JobStatus.running => AppColors.indigo,
                  JobStatus.pending => theme.colorScheme.primary,
                };
                return SurfaceCard(
                  accent: color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: switch (run.status) {
                              JobStatus.success => 'موفق',
                              JobStatus.failed => 'ناموفق',
                              JobStatus.running => 'در حال اجرا',
                              JobStatus.pending => 'در انتظار',
                            },
                            color: color,
                            dense: true,
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: switch (run.trigger) {
                              JobRunTrigger.scheduled => 'زمان‌بندی‌شده',
                              JobRunTrigger.manual => 'دستی',
                              JobRunTrigger.retry => 'تلاش دوباره',
                            },
                            dense: true,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          const Spacer(),
                          Text(
                            PersianDate.relative(run.startedAt),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (run.output != null && run.output!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(run.output!, style: theme.textTheme.bodySmall),
                        ),
                      if (run.error != null && run.error!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            run.error!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.coral),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
