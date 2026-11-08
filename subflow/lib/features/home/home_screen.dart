import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../database/dao/project_dao.dart';
import '../../models/project.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/project_thumbnail.dart';

/// The home tab: pick a video, then the three things that make a clip
/// shareable, then the projects you already have.
///
/// Layout follows the reference sheet exactly - header row, gradient wordmark
/// with the app tile, a dashed "select video" drop zone, a 2x2 of actions, and
/// the project list. Every tile opens a screen that already exists; nothing is
/// decorative.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsControllerProvider);
    final List<Project> list = projects.valueOrNull ?? const <Project>[];

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.screenGradient),
      child: Stack(
        children: <Widget>[
          // The purple bloom behind the wordmark; purely visual, and the thing
          // that stops a flat navy page from looking unfinished.
          Positioned(
            top: -140,
            left: -80,
            right: -80,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGlow)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: <Widget>[
                _Header(onSettings: () => context.go('/settings')),
                const SizedBox(height: 18),
                const _Wordmark(),
                const SizedBox(height: 22),
                _SelectVideoCard(onTap: () => context.push('/import')),
                const SizedBox(height: 16),
                _ActionGrid(
                  onAutoSubtitles: () => _openLatest(context, ref, asr: true),
                  onStyles: () => context.push('/captions'),
                  onTranslate: () => _openLatest(context, ref, asr: true, translate: true),
                  onEdit: () => _openLatest(context, ref, asr: false),
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    const Text(
                      'پروژه‌های من',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (list.isNotEmpty)
                      TextButton(
                        onPressed: () => context.go('/projects'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          children: <Widget>[
                            Text(
                              'همه',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Icon(Icons.chevron_left_rounded,
                                size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const _EmptyProjects()
                else
                  ...list.take(4).map(
                        (Project project) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ProjectRow(project: project),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLatest(BuildContext context, WidgetRef ref, {required bool asr, bool translate = false}) {
    final List<Project>? projects = ref.read(projectsControllerProvider).valueOrNull;
    if (projects == null || projects.isEmpty) {
      context.push('/import');
      return;
    }
    final Project latest = projects.first;
    if (!asr) {
      context.push('/project/${latest.id}/subtitles');
      return;
    }
    context.push('/project/${latest.id}/asr${translate ? '?translate=1' : ''}');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => _openMenu(context),
          icon: const Icon(Icons.menu_rounded, size: 24, color: AppColors.textPrimary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          visualDensity: VisualDensity.compact,
        ),
        const Spacer(),
        const _CrownButton(),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 22, color: AppColors.textPrimary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _openMenu(BuildContext pageContext) {
    showModalBottomSheet<void>(
      context: pageContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.video_call_outlined,
              label: 'پروژهٔ تازه',
              onTap: () {
                Navigator.of(sheetContext).pop();
                pageContext.push('/import');
              },
            ),
            _MenuItem(
              icon: Icons.video_library_outlined,
              label: 'همهٔ پروژه‌ها',
              onTap: () {
                Navigator.of(sheetContext).pop();
                pageContext.go('/projects');
              },
            ),
            _MenuItem(
              icon: Icons.auto_awesome_outlined,
              label: 'گالری استایل‌ها',
              onTap: () {
                Navigator.of(sheetContext).pop();
                pageContext.push('/captions');
              },
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: 'تنظیمات',
              onTap: () {
                Navigator.of(sheetContext).pop();
                pageContext.go('/settings');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _CrownButton extends StatelessWidget {
  const _CrownButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('همهٔ امکانات این نسخه باز است؛ اشتراکی در کار نیست.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      icon: const Icon(Icons.workspace_premium_rounded, size: 24, color: AppColors.gold),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
      ),
      dense: true,
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              RichText(
                textDirection: TextDirection.ltr,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  children: <InlineSpan>[
                    TextSpan(text: 'Sub'),
                    TextSpan(
                      text: 'Flow',
                      style: TextStyle(color: AppColors.primarySoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'زیرنویس خودکار و ویرایش ویدئو',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _AppTile(),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const <Widget>[
                _Bar(height: 10),
                _Bar(height: 18),
                _Bar(height: 26),
                _Bar(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SelectVideoCard extends StatelessWidget {
  const _SelectVideoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: DashedRoundedBorder(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
          child: Column(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigher,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.movie_filter_outlined,
                    size: 30, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              const Text(
                'انتخاب ویدئو',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'یا فایل را همین‌جا رها کنید',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: const <Widget>[
                  _FormatChip('MP4'),
                  _FormatChip('MOV'),
                  _FormatChip('AVI'),
                  _FormatChip('MKV'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigher,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onAutoSubtitles,
    required this.onStyles,
    required this.onTranslate,
    required this.onEdit,
  });

  final VoidCallback onAutoSubtitles;
  final VoidCallback onStyles;
  final VoidCallback onTranslate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      _ActionTile(
        icon: Icons.mic_none_rounded,
        color: AppColors.primarySoft,
        title: 'زیرنویس خودکار',
        subtitle: 'گفتار به متن',
        onTap: onAutoSubtitles,
      ),
      _ActionTile(
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFFFF7BD5),
        title: 'استایل زیرنویس',
        subtitle: '۴۰ قالب آماده',
        onTap: onStyles,
      ),
      _ActionTile(
        icon: Icons.translate_rounded,
        color: const Color(0xFF3DDC97),
        title: 'ترجمه',
        subtitle: 'فارسی به انگلیسی',
        onTap: onTranslate,
      ),
      _ActionTile(
        icon: Icons.content_cut_rounded,
        color: const Color(0xFFFFB020),
        title: 'ویرایش ویدئو',
        subtitle: 'برش و چیدمان',
        onTap: onEdit,
      ),
    ];
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: tiles[2]),
            const SizedBox(width: 12),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outline.withOpacity(0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 26, color: color),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withOpacity(0.6)),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.video_library_outlined, size: 26, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text(
            'هنوز پروژه‌ای نیست',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'یک ویدئو انتخاب کنید تا اولین پروژه ساخته شود.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.7),
          ),
        ],
      ),
    );
  }
}

/// One row in "my projects": real frame, duration, name, last edit, menu.
class ProjectRow extends ConsumerWidget {
  const ProjectRow({required this.project, this.onTap, super.key});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => context.push('/project/${project.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: <Widget>[
              ProjectThumbnail(projectId: project.id, width: 96, height: 62, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ProjectDao.humanizeEdit(project.lastOpenedAtMs),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showProjectMenu(context, ref, project),
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                tooltip: 'گزینه‌ها',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename / duplicate / delete, shared by the home list and the projects tab.
Future<void> showProjectMenu(BuildContext context, WidgetRef ref, Project project) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 6),
          _MenuItem(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'تغییر نام',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _rename(context, ref, project);
            },
          ),
          _MenuItem(
            icon: Icons.copy_all_rounded,
            label: 'کپی پروژه',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref.read(projectsControllerProvider.notifier).duplicate(project.id);
            },
          ),
          _MenuItem(
            icon: Icons.delete_outline_rounded,
            label: 'حذف',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref.read(projectsControllerProvider.notifier).delete(project.id, permanent: false);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

Future<void> _rename(BuildContext context, WidgetRef ref, Project project) async {
  final TextEditingController controller = TextEditingController(text: project.name);
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: const Text('تغییر نام پروژه', style: TextStyle(fontSize: 15)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'نام پروژه'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return;
  await ref.read(projectsControllerProvider.notifier).rename(project.id, name);
}
