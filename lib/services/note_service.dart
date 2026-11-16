import '../core/utils/id_gen.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';

/// Business rules for notes: creation, editing, searching, pinning, deletion.
class NoteService {
  NoteService(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final NoteRepository _repository;
  final DateTime Function() _clock;

  Future<List<Note>> list({String? category, String? query}) =>
      _repository.list(category: category, query: query);

  Future<Note?> findById(String id) => _repository.findById(id);

  /// Creates a note. The title is derived from the first line when not given.
  Future<Note> create({
    required String body,
    String? title,
    String category = NoteCategories.general,
    NoteSource source = NoteSource.text,
  }) async {
    final now = _clock();
    final derivedTitle = (title ?? '').trim().isEmpty ? _deriveTitle(body) : title!.trim();
    final note = Note(
      id: newId(),
      title: derivedTitle,
      body: body.trim(),
      category: NoteCategories.all.contains(category) ? category : NoteCategories.general,
      createdAt: now,
      updatedAt: now,
      source: source,
    );
    await _repository.upsert(note);
    return note;
  }

  Future<Note> update(
    Note note, {
    String? title,
    String? body,
    String? category,
    bool? isPinned,
  }) async {
    final updated = note.copyWith(
      title: title,
      body: body,
      category: category,
      isPinned: isPinned,
      updatedAt: _clock(),
    );
    await _repository.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) => _repository.delete(id);

  Future<void> togglePinned(Note note) =>
      update(note, isPinned: !note.isPinned);

  Future<int> count() => _repository.count();

  /// The most recent note, used for «آخرین یادداشت را بخوان».
  Future<Note?> latest() async {
    final notes = await _repository.list();
    return notes.isEmpty ? null : notes.first;
  }

  static String _deriveTitle(String body) {
    final firstLine = body.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'یادداشت بدون عنوان';
    if (firstLine.length <= 48) return firstLine;
    return '${firstLine.substring(0, 48).trimRight()}…';
  }
}
