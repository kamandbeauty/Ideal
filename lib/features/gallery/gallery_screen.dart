/// Photo selection: pick, review, reorder, remove, continue.
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
import '../../core/errors/app_failure.dart';
import '../../core/models/motion_profile.dart';
import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../../core/services/media_picker_service.dart';
import '../project/project_editor_controller.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final List<PickedPhoto> _picked = <PickedPhoto>[];
  final Map<String, String> _thumbPaths = <String, String>{};
  bool _busy = false;

  Future<void> _addPhotos() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bootstrap = ref.read(bootstrapProvider);
    try {
      final photos = await bootstrap.mediaPicker.pickPhotos();
      if (photos.isEmpty) return;
      for (final p in photos) {
        _picked.add(p);
        // Thumbnail generation is best-effort: failure just means the tile
        // falls back to the full file.
        try {
          final thumb = await bootstrap.thumbs.generate(p.id, p.bytes);
          _thumbPaths[p.id] = thumb.path;
        } catch (_) {
          // ignored on purpose — see comment above
        }
      }
      if (mounted) setState(() {});
    } on AppFailure catch (e) {
      if (mounted) context.snack(context.l10n.t(e.messageKey), isError: true);
    } catch (e) {
      if (mounted) {
        context.snack(context.l10n.t('error_unknown'), isError: true);
        debugPrint('pick failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(String id) {
    setState(() {
      _picked.removeWhere((p) => p.id == id);
      _thumbPaths.remove(id);
    });
  }

  void _clear() {
    setState(() {
      _picked.clear();
      _thumbPaths.clear();
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _picked.removeAt(oldIndex);
      _picked.insert(newIndex, item);
    });
  }

  void _continue() {
    if (_picked.isEmpty) return;
    final bootstrap = ref.read(bootstrapProvider);
    final settings = ref.read(settingsProvider);

    final photos = <PhotoItem>[
      for (var i = 0; i < _picked.length; i++)
        PhotoItem(
          id: _picked[i].id,
          sourceUri: _picked[i].path,
          width: _picked[i].width,
          height: _picked[i].height,
          duration: settings.defaultPhotoDuration,
          order: i,
          displayName: _picked[i].originalName,
          thumbnailPath: _thumbPaths[_picked[i].id],
        ),
    ];

    final project = Project(
      id: 'proj-${DateTime.now().millisecondsSinceEpoch}',
      name: 'MotionShot ${DateTime.now().day}/${DateTime.now().month}',
      photos: photos,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      exportSettings: settings.defaultExport,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      thumbnailPath: photos.first.thumbnailPath,
    );

    final ctrl = ref.read(projectEditorProvider.notifier);
    ctrl.attach(project: project, repo: bootstrap.repository);
    // Auto Motion on entry: one tap from picking photos to a moving preview.
    ctrl.autoMotion(intensity: settings.defaultIntensity);
    ctrl.selectPhoto(photos.first.id);
    context.go(AppRoutes.editor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = _picked.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('gallery_title')),
        actions: <Widget>[
          if (_picked.isNotEmpty)
            IconButton(
              tooltip: l10n.t('gallery_clear'),
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Pill(
                    label: l10n.plural('gallery_selected', count),
                    icon: Icons.photo_outlined,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _busy ? null : _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 18),
                    label: Text(l10n.t('gallery_add')),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                l10n.t('gallery_supported'),
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              Expanded(
                child: _picked.isEmpty
                    ? EmptyState(
                        icon: Icons.photo_library_outlined,
                        title: l10n.t('gallery_empty'),
                        hint: l10n.t('gallery_empty_hint'),
                        action: FilledButton.icon(
                          onPressed: _busy ? null : _addPhotos,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(l10n.t('gallery_add')),
                        ),
                      )
                    : ReorderableGridView.count(
                        crossAxisCount: _columns(context),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        footer: <Widget>[
                          _AddTile(onTap: _busy ? null : _addPhotos),
                        ],
                        onReorder: _reorder,
                        children: <Widget>[
                          for (var i = 0; i < _picked.length; i++)
                            _PickedTile(
                              key: ValueKey<String>(_picked[i].id),
                              photo: _picked[i],
                              thumbPath: _thumbPaths[_picked[i].id],
                              index: i,
                              onRemove: () => _remove(_picked[i].id),
                            ),
                        ],
                      ),
              ),
              if (_picked.isNotEmpty) ...<Widget>[
                Text(
                  l10n.t('gallery_reorder_hint'),
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.s8),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: l10n.t('gallery_continue'),
                    icon: Icons.arrow_forward_rounded,
                    onPressed: count == 0 ? null : _continue,
                  ),
                ),
                const SizedBox(height: AppTheme.s12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _columns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 3;
  }
}

class _PickedTile extends StatelessWidget {
  const _PickedTile({
    required this.photo,
    required this.thumbPath,
    required this.index,
    required this.onRemove,
    super.key,
  });

  final PickedPhoto photo;
  final String? thumbPath;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final file = thumbPath != null && File(thumbPath!).existsSync()
        ? File(thumbPath!)
        : File(photo.path);
    return PhotoTile(
      image: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover, cacheWidth: 512)
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
              fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      overlay: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.theme.colorScheme.outline,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Icon(Icons.add_rounded,
              size: 28, color: context.theme.colorScheme.primary),
        ),
      ),
    );
  }
}

/// A reorderable grid with an optional trailing "add" tile.
///
/// Flutter has no built-in reorderable grid, and pulling in a package for this
/// single screen would be a heavy dependency for a small feature. This widget
/// implements long-press drag with the same feel as `ReorderableListView`.
class ReorderableGridView extends StatefulWidget {
  const ReorderableGridView.count({
    required this.crossAxisCount,
    required this.children,
    required this.onReorder,
    this.footer = const <Widget>[],
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    super.key,
  });

  final int crossAxisCount;
  final List<Widget> children;
  final List<Widget> footer;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<ReorderableGridView> createState() => _ReorderableGridViewState();
}

class _ReorderableGridViewState extends State<ReorderableGridView> {
  int? _dragging;
  int? _hovering;

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length + widget.footer.length;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: 1,
      ),
      itemCount: total,
      itemBuilder: (BuildContext ctx, int i) {
        if (i >= widget.children.length) {
          return widget.footer[i - widget.children.length];
        }
        final isDragging = _dragging == i;
        final isHover = _hovering == i;
        return LongPressDraggable<int>(
          data: i,
          onDragStarted: () => setState(() => _dragging = i),
          onDragEnd: (_) => setState(() {
            _dragging = null;
            _hovering = null;
          }),
          onDraggableCanceled: (_, __) => setState(() {
            _dragging = null;
            _hovering = null;
          }),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 110,
              height: 110,
              child: Opacity(opacity: 0.9, child: widget.children[i]),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: widget.children[i],
          ),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (DragTargetDetails<int> d) {
              if (d.data == i) return false;
              setState(() => _hovering = i);
              return true;
            },
            onLeave: (_) => setState(() => _hovering = null),
            onAcceptWithDetails: (DragTargetDetails<int> d) {
              widget.onReorder(d.data, i);
              setState(() {
                _dragging = null;
                _hovering = null;
              });
            },
            builder: (BuildContext c, List<int?> candidate, List<dynamic> r) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: isHover
                      ? Border.all(
                          color: context.theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Opacity(
                  opacity: isDragging ? 0.4 : 1,
                  child: widget.children[i],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
