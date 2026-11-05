import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../database/dao/project_dao.dart';
import '../../models/project.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsControllerProvider);
    return SfScaffold(
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(SubFlowInfo.appName,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const Text(
                      'زیرنویس آفلاین با هوش مصنوعی',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'تنظیمات',
              ),
            ],
          ),
          const SizedBox(height: 22),
          SfCard(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF241A47), Color(0xFF10213F)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('پروژه تازه بساز',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text(
                  'یک ویدئو انتخاب کن؛ کیفیت، رزولوشن و کدک آن به‌طور خودکار خوانده می‌شود.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
                ),
                const SizedBox(height: 16),
                SfPrimaryButton(
                  label: 'انتخاب ویدئو',
                  icon: Icons.video_library_outlined,
                  onPressed: () => context.push('/import'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Text('پروژه‌های اخیر', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/projects'),
                child: const Text('همه'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          projects.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (Object error, StackTrace stack) => SfCard(
              child: Text(
                'خواندن پروژه‌ها ناموفق بود.\n$error',
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            data: (List<Project> list) {
              if (list.isEmpty) {
                return const SfCard(
                  child: Text(
                    'هنوز پروژه‌ای نداری. اولین ویدئو را انتخاب کن تا زیرنویس بسازیم.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.8),
                  ),
                );
              }
              return Column(
                children: list
                    .take(3)
                    .map(
                      (Project project) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SfCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: () => context.push('/project/${project.id}'),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.movie_outlined,
                                  color: AppColors.secondarySoft, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(project.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall),
                                    Text(
                                      ProjectDao.humanizeEdit(project.lastOpenedAtMs),
                                      style: const TextStyle(
                                          color: AppColors.textMuted, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_left, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
