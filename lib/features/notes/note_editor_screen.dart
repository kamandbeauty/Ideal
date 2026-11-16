import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../data/models/note.dart';
import '../../ui/widgets/voice_dictation_field.dart';

/// Create/edit screen for a single note.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.note?.body ?? '');
  late String _category = widget.note?.category ?? NoteCategories.general;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _body.text.trim();
    final title = _title.text.trim();
    if (body.isEmpty && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('یادداشت خالی است.')),
      );
      return;
    }
    setState(() => _saving = true);
    final service = ref.read(noteServiceProvider);
    if (widget.note == null) {
      await service.create(body: body, title: title, category: _category);
    } else {
      await service.update(
        widget.note!,
        title: title,
        body: body,
        category: _category,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'یادداشت جدید' : 'ویرایش یادداشت'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('ذخیره'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'عنوان (اختیاری)'),
            ),
            const SizedBox(height: 12),
            VoiceDictationField(controller: _body),
            const SizedBox(height: 20),
            Text('دسته', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in NoteCategories.all)
                  ChoiceChip(
                    label: Text(NoteCategories.label(key)),
                    selected: _category == key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('ذخیرهٔ یادداشت'),
            ),
            const SizedBox(height: 8),
            Text(
              'یادداشت‌ها فقط روی همین دستگاه ذخیره می‌شوند و بدون اجازهٔ تو ارسال نمی‌شوند.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
