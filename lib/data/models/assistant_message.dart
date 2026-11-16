/// A single turn in the assistant activity log.
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
    this.source = AssistantTurnSource.text,
    this.meta,
  });

  final String id;
  final String text;
  final AssistantRole role;
  final DateTime createdAt;
  final AssistantTurnSource source;

  /// Optional structured payload (intent name, tool id, ...) for debugging and
  /// for the "activity" timeline. JSON-encoded when persisted.
  final Map<String, Object?>? meta;

  Map<String, Object?> toMap() => {
        'id': id,
        'text': text,
        'role': role.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'source': source.name,
        'meta': _encodeMeta(meta),
      };

  static AssistantMessage fromMap(Map<String, Object?> map) => AssistantMessage(
        id: map['id']! as String,
        text: (map['text'] as String?) ?? '',
        role: AssistantRole.values.firstWhere(
          (role) => role.name == map['role'],
          orElse: () => AssistantRole.assistant,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
        source: AssistantTurnSource.values.firstWhere(
          (source) => source.name == map['source'],
          orElse: () => AssistantTurnSource.text,
        ),
        meta: _decodeMeta(map['meta'] as String?),
      );

  static String? _encodeMeta(Map<String, Object?>? meta) {
    if (meta == null || meta.isEmpty) return null;
    final entries = meta.entries
        .map((entry) => '"${entry.key}":"${entry.value.toString().replaceAll('"', r'\"')}"')
        .join(',');
    return '{$entries}';
  }

  static Map<String, Object?>? _decodeMeta(String? raw) {
    if (raw == null || raw.length < 3) return null;
    final body = raw.substring(1, raw.length - 1);
    if (body.isEmpty) return null;
    final result = <String, Object?>{};
    for (final part in body.split('","')) {
      final separator = part.indexOf('":"');
      if (separator <= 0) continue;
      result[part.substring(1, separator)] = part.substring(separator + 3);
    }
    return result;
  }
}

enum AssistantRole { user, assistant, system }

enum AssistantTurnSource { text, voice, job, notification }
