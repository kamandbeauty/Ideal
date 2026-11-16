import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/note.dart';
import 'base_repository.dart';

/// Persistence for notes. All queries are local; nothing leaves the device.
class NoteRepository extends BaseRepository {
  NoteRepository(super.database);

  Future<List<Note>> list({String? category, String? query}) async {
    final database = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null && category != NoteCategories.general) {
      where.add('category = ?');
      args.add(category);
    }
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      where.add('(title LIKE ? OR body LIKE ?)');
      args
        ..add('%$trimmed%')
        ..add('%$trimmed%');
    }
    final rows = await database.query(
      AppDatabase.notesTable,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(Note.fromMap).toList(growable: false);
  }

  Future<Note?> findById(String id) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  Future<void> upsert(Note note) => insertRow(AppDatabase.notesTable, note.toMap());

  Future<void> delete(String id) async {
    final database = await db;
    await database.delete(AppDatabase.notesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final database = await db;
    final result =
        await database.rawQuery('SELECT COUNT(*) AS c FROM ${AppDatabase.notesTable}');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
