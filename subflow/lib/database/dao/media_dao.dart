import 'package:sqflite/sqflite.dart';

import '../../models/subtitle.dart';
import '../../models/video_asset.dart';
import '../../models/watermark.dart';

/// Video asset, subtitle track/segment, and watermark persistence.
class MediaDao {
  const MediaDao(this._db);

  final Database _db;

  // ------------------------------------------------------------- video assets
  Future<void> upsertAsset(VideoAsset asset) async {
    await _db.insert('video_assets', asset.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<VideoAsset?> assetOfProject(String projectId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'video_assets',
      where: 'project_id = ?',
      whereArgs: <Object?>[projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VideoAsset.fromMap(rows.first);
  }

  Future<void> markAssetMissing(String assetId, bool missing) async {
    await _db.update(
      'video_assets',
      <String, Object?>{'is_missing': missing ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[assetId],
    );
  }

  // ---------------------------------------------------------- subtitle tracks
  Future<List<SubtitleTrack>> tracksOfProject(String projectId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_tracks',
      where: 'project_id = ?',
      whereArgs: <Object?>[projectId],
      orderBy: 'is_default DESC, created_at_ms ASC',
    );
    return rows.map(SubtitleTrack.fromMap).toList(growable: false);
  }

  Future<void> insertTrack(SubtitleTrack track) async {
    await _db.insert('subtitle_tracks', track.toMap());
  }

  Future<void> deleteTrack(String trackId) async {
    await _db.delete('subtitle_tracks', where: 'id = ?', whereArgs: <Object?>[trackId]);
  }

  // -------------------------------------------------------- subtitle segments
  Future<List<SubtitleSegment>> segmentsOfTrack(String trackId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_segments',
      where: 'track_id = ?',
      whereArgs: <Object?>[trackId],
      orderBy: 'ordinal ASC',
    );
    return rows.map(SubtitleSegment.fromMap).toList(growable: false);
  }

  Future<List<SubtitleWord>> wordsOfSegment(String segmentId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subtitle_words',
      where: 'segment_id = ?',
      whereArgs: <Object?>[segmentId],
      orderBy: 'ordinal ASC',
    );
    return rows.map(SubtitleWord.fromMap).toList(growable: false);
  }

  /// Replaces every segment of a track atomically. Used after transcription and
  /// after silence removal, where the whole timeline changes at once.
  Future<void> replaceSegments(String trackId, List<SubtitleSegment> segments) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete('subtitle_segments', where: 'track_id = ?', whereArgs: <Object?>[trackId]);
      final Batch batch = txn.batch();
      for (final SubtitleSegment segment in segments) {
        batch.insert('subtitle_segments', segment.toMap());
        for (final SubtitleWord word in segment.words) {
          batch.insert('subtitle_words', word.toMap());
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateSegment(SubtitleSegment segment) async {
    await _db.update(
      'subtitle_segments',
      segment.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[segment.id],
    );
  }

  // -------------------------------------------------------------- watermarks
  Future<List<Watermark>> watermarksOfProject(String projectId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'watermarks',
      where: 'project_id = ?',
      whereArgs: <Object?>[projectId],
      orderBy: 'z_index ASC',
    );
    return rows.map(Watermark.fromMap).toList(growable: false);
  }

  Future<void> insertWatermark(Watermark watermark) async {
    await _db.insert('watermarks', watermark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWatermark(String id) async {
    await _db.delete('watermarks', where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
