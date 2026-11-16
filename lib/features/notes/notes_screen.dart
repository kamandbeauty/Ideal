import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/note.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import 'note_editor_screen.dart';

/// Search/filter state for the notes tab.
final noteQueryProvider = StateProvider<String>((ref) => '');
final noteCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Notes are reloaded whenever the query, filter or a mutation bumps this.
final notesRevisionProvider = StateProvider<int>((ref) => 0);

final notesProvider = FutureProvider<List<Note>>((ref) async {
  ref.watch(notesRevisionProvider);
  final query = ref.watch(noteQueryProvider);
  final category = ref.watch(noteCategoryFilterProvider);
  return ref.watch(noteServiceProvider).list(category: category, query: query);
});

/// Tab 2 — notes with search, categories and voice dictation.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor({Note? note}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
    if (saved == true) {
      ref.read(notesRevisionProvider.notifier).state++;
    }
  }

  Future<void> _delete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف یادداشت'),
        content: Text('یادداشت «${note.displayTitle}» حذف شود؟ این کار بازگشت‌پذیر نیست.'),
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
    await ref.read(noteServiceProvider).delete(note.id);
    ref.invalidate(notesRevisionProvider);
    ref.invalidate(notesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('یادداشت حذف شد.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final category = ref.watch(noteCategoryFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'یادداشت‌ها',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton.filled(
                tooltip: 'یادداشت جدید',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                ref.read(noteQueryProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: 'جست‌وجو در یادداشت‌ها…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(noteQueryProvider.notifier).state = '';
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            children: [
              PressableChip(
                label: 'همه',
                selected: category == null,
                onTap: () => ref.read(noteCategoryFilterProvider.notifier).state = null,
              ),
              for (final key in NoteCategories.all)
                PressableChip(
                  label: NoteCategories.label(key),
                  selected: category == key,
                  onTap: () {
                    ref.read(noteCategoryFilterProvider.notifier).state =
                        category == key ? null : key;
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: notes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'خواندن یادداشت‌ها ممکن نشد',
              description: 'خطا: $error',
            ),
            data: (items) {
              if (items.isEmpty) {
                final isFiltered = category != null ||
                    ref.watch(noteQueryProvider).isNotEmpty;
                return EmptyState(
                  icon: Icons.note_add_outlined,
                  title: isFiltered ? 'چیزی پیدا نشد' : 'اولین یادداشتت را بساز',
                  description: isFiltered
                      ? 'فیلتر یا عبارت جست‌وجو را تغییر بده.'
                      : 'می‌توانی بنویسی یا با میکروفون بگویی «یادداشت جدید بساز».',
                  action: isFiltered
                      ? null
                      : FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('یادداشت جدید'),
                        ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SectionHeader(
                      title: '${items.length} یادداشت',
                      subtitle: 'روی هر یادداشت ضربه بزن تا ویرایش شود',
                      icon: Icons.sticky_note_2_outlined,
                    );
                  }
                  final note = items[index - 1];
                  return _NoteTile(
                    note: note,
                    onTap: () => _openEditor(note: note),
                    onDelete: () => _delete(note),
                    onTogglePin: () async {
                      await ref.read(noteServiceProvider).togglePinned(note);
                      ref.invalidate(notesProvider);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class PressableChip extends StatelessWidget {
  const PressableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (note.isPinned)
                const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.amber),
              PopupMenuButton<String>(
                tooltip: 'عملیات',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'pin') onTogglePin();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(note.isPinned ? 'برداشتن سنجاق' : 'سنجاق به بالا'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          if (note.preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(label: NoteCategories.label(note.category), dense: true),
              if (note.source != NoteSource.text) ...[
                const SizedBox(width: 6),
                StatusChip(
                  label: note.source == NoteSource.voice ? 'صوتی' : 'دستیار',
                  dense: true,
                  color: AppColors.indigo,
                  icon: note.source == NoteSource.voice
                      ? Icons.mic_rounded
                      : Icons.auto_awesome_rounded,
                ),
              ],
              const Spacer(),
              Text(
                PersianDate.relative(note.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
