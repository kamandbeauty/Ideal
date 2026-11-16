import '../local/app_database.dart';
import '../models/assistant_message.dart';
import 'base_repository.dart';

/// Persistence for the assistant conversation/activity log.
class AssistantRepository extends BaseRepository {
  AssistantRepository(super.database);

  Future<List<AssistantMessage>> recent({int limit = 50}) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.assistantMessagesTable,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AssistantMessage.fromMap).toList(growable: false);
  }

  Future<void> insert(AssistantMessage message) =>
      insertRow(AppDatabase.assistantMessagesTable, message.toMap());

  Future<void> clear() async {
    final database = await db;
    await database.delete(AppDatabase.assistantMessagesTable);
  }
}
