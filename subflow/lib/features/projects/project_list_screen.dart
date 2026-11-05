import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../database/dao/project_dao.dart';
import '../../models/enums.dart';
import '../../models/project.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';
import '../../shared/widgets/stat_chip.dart';

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
            tooltip: 'پروژه جدید',
            onPressed: () => context.push('/import'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      child: projects.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (Object error, StackTrace stack) => Center(
          child: Text('$error', style: const TextStyle(color: AppColors.danger)),
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
          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) =>
                _ProjectTile(project: list[index]),
          );
        },
      ),
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project});

  final Project project;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(text: project.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('تغییر نام پروژه'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final String? error = await ref.read(projectsControllerProvider.notifier).rename(
          project.id,
          result,
        );
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('حذف پروژه'),
        content: Text(
          'پروژه «${project.name}» به سطل حذف منتقل می‌شود و قابل بازگردانی است. '
          'فایل ویدئوی اصلی روی گوشی دست‌نخورده می‌ماند.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(projectsControllerProvider.notifier).delete(project.id, permanent: false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${project.name}» حذف شد'),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () =>
              ref.read(projectsControllerProvider.notifier).restore(project.id),
        ),
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(projectsControllerProvider.notifier).duplicate(project.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('کپی پروژه ساخته شد')));
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SfCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: () => context.push('/project/${project.id}'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    StatChip(label: _statusLabel(project.status), tint: AppColors.secondarySoft),
                    StatChip(label: ProjectDao.humanizeEdit(project.lastOpenedAtMs)),
                    if (project.lastEditLabel != null)
                      StatChip(label: project.lastEditLabel!),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            onSelected: (String value) async {
              switch (value) {
                case 'rename':
                  await _rename(context, ref);
                  break;
                case 'duplicate':
                  await _duplicate(context, ref);
                  break;
                case 'delete':
                  await _delete(context, ref);
                  break;
                default:
                  break;
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'rename', child: Text('تغییر نام')),
              PopupMenuItem<String>(value: 'duplicate', child: Text('کپی پروژه')),
              PopupMenuItem<String>(value: 'delete', child: Text('حذف')),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(ProjectStatus status) => switch (status) {
        ProjectStatus.draft => 'پیش‌نویس',
        ProjectStatus.importing => 'در حال ورود',
        ProjectStatus.transcribing => 'تشخیص گفتار',
        ProjectStatus.editing => 'در حال ویرایش',
        ProjectStatus.ready => 'آماده',
        ProjectStatus.exporting => 'در حال خروجی',
      };
}
