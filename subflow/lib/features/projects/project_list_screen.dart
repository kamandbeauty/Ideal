import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../models/project.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sf_scaffold.dart';
import '../home/home_screen.dart' show ProjectRow;

/// All projects, in the same row shape the home tab uses.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsControllerProvider);
    return SfScaffold(
      appBar: AppBar(
        title: const Text('پروژه‌ها'),
        actions: <Widget>[
          IconButton(
            tooltip: 'پروژه تازه',
            onPressed: () => context.push('/import'),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      child: projects.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (Object error, StackTrace stack) => Center(
          child: Text(
            '$error',
            style: const TextStyle(color: AppColors.danger, height: 1.8),
          ),
        ),
        data: (List<Project> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'پروژه‌ای نیست',
              message: 'با انتخاب یک ویدئو اولین پروژه SubFlow خودت را بساز.',
              action: FilledButton(
                onPressed: () => context.push('/import'),
                child: const Text('انتخاب ویدئو'),
              ),
            );
          }
          final int active = list.length;
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$active پروژه',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
              ...list.map(
                (Project project) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ProjectRow(
                    project: project,
                    onTap: () => context.push('/project/${project.id}/subtitles'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
