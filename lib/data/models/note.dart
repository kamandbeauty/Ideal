/// A user note, created by hand or by the voice assistant.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.source = NoteSource.text,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final NoteSource source;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Title shown in lists; falls back to the first line of the body.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first;
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 60)}…';
  }

  String get preview => body.trim().replaceAll('\n', ' ');

  Note copyWith({
    String? title,
    String? body,
    String? category,
    DateTime? updatedAt,
    bool? isPinned,
    NoteSource? source,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isPinned: isPinned ?? this.isPinned,
        source: source ?? this.source,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'is_pinned': isPinned ? 1 : 0,
        'source': source.name,
      };

  static Note fromMap(Map<String, Object?> map) => Note(
        id: map['id']! as String,
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        category: (map['category'] as String?) ?? NoteCategories.general,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
        isPinned: (map['is_pinned'] as int? ?? 0) == 1,
        source: NoteSource.values.firstWhere(
          (source) => source.name == map['source'],
          orElse: () => NoteSource.text,
        ),
      );
}

/// Where a note came from; shown as a small badge in the UI.
enum NoteSource { text, voice, assistant }

/// Category keys stay ASCII for storage; labels are Persian.
abstract final class NoteCategories {
  static const general = 'general';
  static const work = 'work';
  static const personal = 'personal';
  static const idea = 'idea';
  static const reminder = 'reminder';

  static const all = <String>[general, work, personal, idea, reminder];

  static const labels = <String, String>{
    general: 'عمومی',
    work: 'کار',
    personal: 'شخصی',
    idea: 'ایده',
    reminder: 'یادآوری',
  };

  static String label(String key) => labels[key] ?? labels[general]!;
}
