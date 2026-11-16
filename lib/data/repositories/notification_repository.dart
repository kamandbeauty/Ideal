import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/app_notification.dart';
import 'base_repository.dart';

/// Persistence for captured notifications with deduplication.
class NotificationRepository extends BaseRepository {
  NotificationRepository(super.database);

  Future<List<CapturedNotification>> list({int limit = 100}) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.notificationsTable,
      where: 'is_group_summary = 0',
      orderBy: 'posted_at DESC',
      limit: limit,
    );
    return rows.map(CapturedNotification.fromMap).toList(growable: false);
  }

  /// Notifications posted since [since], newest first.
  Future<List<CapturedNotification>> since(DateTime since, {int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.notificationsTable,
      where: 'posted_at >= ? AND is_group_summary = 0',
      whereArgs: [since.millisecondsSinceEpoch],
      orderBy: 'posted_at DESC',
      limit: limit,
    );
    return rows.map(CapturedNotification.fromMap).toList(growable: false);
  }

  Future<int> unreadCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.notificationsTable} '
      'WHERE is_read = 0 AND is_group_summary = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Inserts [notification], silently ignoring duplicates by dedupe key.
  ///
  /// Returns true when a new row was written.
  Future<bool> insertIfNew(CapturedNotification notification) async {
    final database = await db;
    final id = await database.insert(
      AppDatabase.notificationsTable,
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id != 0;
  }

  Future<void> markRead(String id) async {
    final database = await db;
    await database.update(
      AppDatabase.notificationsTable,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final database = await db;
    await database.update(AppDatabase.notificationsTable, {'is_read': 1});
  }

  Future<void> deleteAll() async {
    final database = await db;
    await database.delete(AppDatabase.notificationsTable);
  }

  /// Removes notifications posted before [cutoff]; returns the deleted count.
  Future<int> deleteBefore(DateTime cutoff) async {
    final database = await db;
    return database.delete(
      AppDatabase.notificationsTable,
      where: 'posted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
