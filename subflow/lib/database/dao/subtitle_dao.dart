import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';
import '../../models/enums.dart';
import '../../models/subtitle.dart';
import '../../models/subtitle_style.dart';

/// Persistence for subtitle tracks, segments, words and styles.
///
/// Writes replace the whole segment list of a track inside one transaction:
/// partial saves are impossible, so a crash mid-autosave can never leave a
/// half-updated document behind. Ordinals are re-derived on write, which means
/// the store always matches the in-memory order the user sees.
class SubtitleDao {
  const SubtitleDao(this._db);

  final Database _db;

  Future<SubtitleTrack?> findOriginalTrack(String projectId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_tracks',
      where: 'project_id = ? AND kind = ?',
      whereArgs: <Object?>[projectId, TrackKind.original.dbValue],
      orderBy: 'is_default DESC, created_at_ms ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SubtitleTrack.fromMap(rows.first);
  }

  /// Returns the project's original track, creating it on first use.
  Future<SubtitleTrack> ensureOriginalTrack(
    String projectId, {
    SubtitleLanguage language = SubtitleLanguage.auto,
  }) async {
    final SubtitleTrack? existing = await findOriginalTrack(projectId);
    if (existing != null) return existing;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final SubtitleTrack track = SubtitleTrack(
      id: Ids.uuid(),
      projectId: projectId,
      kind: TrackKind.original,
      language: language,
      label: language == SubtitleLanguage.en ? 'English' : 'فارسی',
      isDefault: true,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.insert('subtitle_tracks', track.toMap());
    return track;
  }

  Future<List<SubtitleSegment>> loadSegments(String trackId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_segments',
      where: 'track_id = ?',
      whereArgs: <Object?>[trackId],
      orderBy: 'ordinal ASC',
    );
    if (rows.isEmpty) return const <SubtitleSegment>[];
    final List<Map<String, Object?>> wordRows = await _db.rawQuery(
      'SELECT w.* FROM subtitle_words w '
      'JOIN subtitle_segments s ON s.id = w.segment_id '
      'WHERE s.track_id = ? ORDER BY w.segment_id ASC, w.ordinal ASC',
      <Object?>[trackId],
    );
    final Map<String, List<SubtitleWord>> wordsBySegment = <String, List<SubtitleWord>>{};
    for (final Map<String, Object?> row in wordRows) {
      final SubtitleWord word = SubtitleWord.fromMap(row);
      wordsBySegment.putIfAbsent(word.segmentId, () => <SubtitleWord>[]).add(word);
    }
    return rows.map((Map<String, Object?> row) {
      final SubtitleSegment segment = SubtitleSegment.fromMap(row);
      final List<SubtitleWord> words =
          wordsBySegment[segment.id] ?? const <SubtitleWord>[];
      return segment.copyWith(words: words);
    }).toList(growable: false);
  }

  /// Replaces every segment (and its words) of [trackId] atomically.
  Future<void> replaceSegments(
    String trackId,
    List<SubtitleSegment> segments, {
    int? updatedAtMs,
  }) async {
    final int now = updatedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((Transaction txn) async {
      // Cascades remove the words of the deleted segments.
      await txn.delete('subtitle_segments', where: 'track_id = ?', whereArgs: <Object?>[trackId]);
      for (int index = 0; index < segments.length; index++) {
        final SubtitleSegment segment = segments[index];
        // `copyWith` deliberately has no `ordinal`: order is a database concern,
        // so it is re-derived here rather than carried around in the model.
        final Map<String, Object?> row = segment.toMap()..['ordinal'] = index;
        await txn.insert(
          'subtitle_segments',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (int wordIndex = 0; wordIndex < segment.words.length; wordIndex++) {
          final SubtitleWord word = segment.words[wordIndex];
          await txn.insert(
            'subtitle_words',
            SubtitleWord(
              id: word.id,
              segmentId: segment.id,
              ordinal: wordIndex,
              startUs: word.startUs,
              endUs: word.endUs,
              text: word.text,
              confidence: word.confidence,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await txn.update(
        'subtitle_tracks',
        <String, Object?>{'updated_at_ms': now},
        where: 'id = ?',
        whereArgs: <Object?>[trackId],
      );
    });
  }

  Future<int> countSegments(String trackId) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM subtitle_segments WHERE track_id = ?',
      <Object?>[trackId],
    );
    final Object? value = rows.isEmpty ? 0 : rows.first['n'];
    return value is int ? value : 0;
  }

  Future<SubtitleStyle?> loadProjectStyle(String projectId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_styles',
      where: 'project_id = ?',
      whereArgs: <Object?>[projectId],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SubtitleStyle.fromMap(rows.first);
  }

  Future<void> saveStyle(SubtitleStyle style) async {
    await _db.insert(
      'subtitle_styles',
      style.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes every caption of a track without touching the track row itself.
  Future<void> clearSegments(String trackId) async {
    await _db.delete('subtitle_segments', where: 'track_id = ?', whereArgs: <Object?>[trackId]);
  }
}
