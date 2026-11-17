import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/note.dart';
import 'package:javid_ai/data/repositories/note_repository.dart';
import 'package:javid_ai/services/note_service.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpSqfliteFfi);

  late TestDatabase database;
  late NoteService service;

  setUp(() async {
    database = await openCleanDatabase();
    service = NoteService(NoteRepository(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a note and derives a title from the body', () async {
    final note = await service.create(body: 'خرید نان و شیر');
    expect(note.displayTitle, 'خرید نان و شیر');
    expect(note.category, NoteCategories.general);
    expect(await service.count(), 1);
  });

  test('keeps an explicit title', () async {
    final note = await service.create(body: 'جزئیات جلسه', title: 'جلسهٔ دوشنبه');
    expect(note.title, 'جلسهٔ دوشنبه');
  });

  test('truncates very long derived titles', () async {
    final note = await service.create(body: 'ا' * 120);
    expect(note.displayTitle.endsWith('…'), isTrue);
    expect(note.displayTitle.length, lessThanOrEqualTo(49));
  });

  test('searches title and body', () async {
    await service.create(body: 'صورت‌جلسهٔ تیم فنی', category: NoteCategories.work);
    await service.create(body: 'یادآوری خرید هدیه');
    final results = await service.list(query: 'جلسه');
    expect(results, hasLength(1));
    expect(results.single.body, contains('جلسه'));
  });

  test('filters by category', () async {
    await service.create(body: 'کار مهم', category: NoteCategories.work);
    await service.create(body: 'فکر جدید', category: NoteCategories.idea);
    final work = await service.list(category: NoteCategories.work);
    expect(work, hasLength(1));
    expect(work.single.category, NoteCategories.work);
  });

  test('falls back to general for unknown categories', () async {
    final note = await service.create(body: 'x', category: 'nonsense');
    expect(note.category, NoteCategories.general);
  });

  test('updates content and bumps updatedAt', () async {
    final note = await service.create(body: 'نسخهٔ اول');
    final updated = await service.update(note, body: 'نسخهٔ دوم');
    expect(updated.body, 'نسخهٔ دوم');
    expect(updated.updatedAt.isBefore(note.updatedAt), isFalse);
  });

  test('pins notes to the top of the list', () async {
    final first = await service.create(body: 'قدیمی');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.create(body: 'جدید');
    await service.togglePinned(first);
    final notes = await service.list();
    expect(notes.first.id, first.id);
    expect(notes.first.isPinned, isTrue);
  });

  test('deletes a note', () async {
    final note = await service.create(body: 'برای حذف');
    await service.delete(note.id);
    expect(await service.count(), 0);
    expect(await service.findById(note.id), isNull);
  });

  test('latest returns the most recently updated note', () async {
    await service.create(body: 'اول');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await service.create(body: 'دوم');
    final latest = await service.latest();
    expect(latest?.id, second.id);
  });

  test('data is readable after the database is closed and reopened', () async {
    // An in-memory database disappears with its last connection, so this test
    // uses a real temporary file — the same code path the app uses on device.
    final file = await openFileDatabase();
    final first = NoteService(NoteRepository(file));
    final note = await first.create(body: 'ماندگار');
    await file.close();

    final reopened = await openFileDatabase(samePath: file.fileName);
    final reloaded = await NoteRepository(reopened).findById(note.id);
    expect(reloaded?.body, 'ماندگار');
  });
}
