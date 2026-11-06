/// Home: brand, new project, recent projects, short how-to.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/models/project.dart';
import '../../core/storage/project_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<ProjectSummary>> _recent;

  @override
  void initState() {
    super.initState();
    _recent = _load();
  }

  Future<List<ProjectSummary>> _load() async =>
      ref.read(bootstrapProvider).repository.recent(limit: 12);

  void _reload() => setState(() => _recent = _load());

  Future<void> _openProject(ProjectSummary summary) async {
    final repo = ref.read(bootstrapProvider).repository;
    final Project? project = await repo.load(summary.id);
    if (project == null) {
      if (mounted) context.snack(context.l10n.t('error_unknown'), isError: true);
      return;
    }
    final ctrl = ref.read(projectEditorProvider.notifier);
    ctrl.attach(project: project, repo: repo);
    if (mounted) context.go(AppRoutes.editor);
  }

  Future<void> _delete(ProjectSummary summary) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.t('home_delete'),
      message: l10n.t('home_delete_confirm'),
      confirmLabel: l10n.t('action_delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(bootstrapProvider).repository.delete(summary.id);
    } catch (e) {
      debugPrint('delete failed: $e');
      if (mounted) context.snack(context.l10n.t('error_unknown'), isError: true);
      return;
    }
    if (mounted) _reload();
  }

  void _newProject() {
    ref.read(projectEditorProvider.notifier).detach();
    context.go(AppRoutes.gallery);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _header(context, l10n)),
              SliverToBoxAdapter(child: const SizedBox(height: AppTheme.s24)),
              SliverToBoxAdapter(child: _hero(context, l10n)),
              SliverToBoxAdapter(child: const SizedBox(height: AppTheme.s24)),
              SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.history_rounded,
                        size: 18, color: context.theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.t('home_recent'),
                        style: context.theme.textTheme.titleMedium?
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s12)),
              FutureBuilder<List<ProjectSummary>>(
                future: _recent,
                builder: (BuildContext ctx,
                    AsyncSnapshot<List<ProjectSummary>> snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final items = snap.data ?? const <ProjectSummary>[];
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.s20),
                          child: EmptyState(
                            icon: Icons.movie_creation_outlined,
                            title: l10n.t('home_no_recent'),
                            hint: l10n.t('home_no_recent_hint'),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.s8),
                    itemBuilder: (BuildContext c, int i) {
                      final s = items[i];
                      return _RecentTile(
                        summary: s,
                        onOpen: () => _openProject(s),
                        onDelete: () => _delete(s),
                      );
                    },
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s24)),
              SliverToBoxAdapter(child: _howTo(context, l10n)),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, L10n l10n) {
    return Row(
      children: <Widget>[
        const MotionShotLogo(size: 42, showWordmark: true),
        const Spacer(),
        IconButton(
          tooltip: l10n.t('nav_settings'),
          onPressed: () => context.push(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, L10n l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.s20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.violet.withValues(alpha: 0.28),
            AppColors.blue.withValues(alpha: 0.12),
            context.theme.colorScheme.surface,
          ],
        ),
        border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.t('app_tagline'),
            style: context.theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppTheme.s12),
          Row(
            children: <Widget>[
              const Pill(
                label: '100% offline',
                icon: Icons.wifi_off_rounded,
                color: AppColors.mint,
              ),
              const SizedBox(width: 8),
              Pill(
                label: l10n.t('home_offline_badge'),
                icon: Icons.lock_outline_rounded,
                color: context.theme.colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: l10n.t('home_new_project'),
              icon: Icons.add_photo_alternate_outlined,
              onPressed: _newProject,
            ),
          ),
        ],
      ),
    );
  }

  Widget _howTo(BuildContext context, L10n l10n) {
    final steps = <String>[
      l10n.t('home_howto_1'),
      l10n.t('home_howto_2'),
      l10n.t('home_howto_3'),
      l10n.t('home_howto_4'),
    ];
    final icons = <IconData>[
      Icons.photo_library_outlined,
      Icons.auto_awesome_rounded,
      Icons.tune_rounded,
      Icons.movie_outlined,
    ];
    return SectionCard(
      title: l10n.t('home_howto'),
      icon: Icons.lightbulb_outline_rounded,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.s8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.primary
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icons[i],
                        size: 16, color: context.theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(steps[i],
                        style: context.theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.summary,
    required this.onOpen,
    required this.onDelete,
  });

  final ProjectSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thumb = summary.thumbnailPath;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.s12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: thumb != null && File(thumb).existsSync()
                      ? Image.file(File(thumb), fit: BoxFit.cover)
                      : ColoredBox(
                          color: context.theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.movie_outlined,
                              color: context.theme.colorScheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: AppTheme.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n
                          .plural('home_photos_count', summary.photoCount),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.t('home_delete'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
