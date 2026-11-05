import 'package:sqflite/sqflite.dart';

import '../core/errors.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/platform/contracts.dart';
import '../database/app_database.dart';
import '../database/dao/media_dao.dart';
import '../database/dao/project_dao.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/subtitle.dart';
import '../models/video_asset.dart';
import '../models/watermark.dart';

/// Everything that mutates a project goes through here so a single place owns
/// the invariants: a project always has exactly one video asset, translations
/// never overwrite the original track, and deletion is soft until confirmed.
class ProjectRepository {
  ProjectRepository(this._database, this._fileExists);

  final AppDatabase _database;

  /// Injected so tests can run without the Android bridge. In production this
  /// is `NativeBridge.fileExists`.
  final Future<bool> Function(String uri) _fileExists;
  static const SfLog _log = SfLog('repo');

  Future<ProjectDao> _projects() async => ProjectDao(await _database.database);
  Future<MediaDao> _media() async => MediaDao(await _database.database);

  /// Creates a project for an already-probed video. The original file is never
  /// copied or modified - only its content URI and probe metadata are stored.
  Future<Project> createFromProbe(VideoProbeResult probe, {String? name}) async {
    final Database db = await _database.database;
    final int now = Ids.nowMs();
    final Project project = Project(
      id: Ids.uuid(),
      name: name ?? _defaultProjectName(probe.displayName),
      status: ProjectStatus.editing,
      createdAtMs: now,
      updatedAtMs: now,
      lastOpenedAtMs: now,
    );
    final VideoAsset asset = VideoAsset(
      id: Ids.uuid(),
      projectId: project.id,
      uri: probe.uri,
      displayName: probe.displayName,
      sizeBytes: probe.sizeBytes,
      durationUs: probe.durationUs,
      width: probe.width,
      height: probe.height,
      rotationDegrees: probe.rotationDegrees,
      fpsMilli: probe.fpsMilli,
      bitrateBps: probe.bitrateBps,
      videoCodec: probe.videoCodec,
      colorTransfer: probe.colorTransfer,
      hdr: probe.hdr,
      audioCodec: probe.audioCodec,
      audioSampleRate: probe.audioSampleRate,
      audioChannels: probe.audioChannels,
      audioBitrateBps: probe.audioBitrateBps,
      importedAtMs: now,
      probeJson: probe.rawJson,
    );
    await db.transaction((Transaction txn) async {
      await txn.insert('projects', project.toMap());
      await txn.insert('video_assets', asset.toMap());
    });
    _log.d('created project ${project.id} for ${probe.displayName}');
    return project;
  }

  Future<Project?> find(String projectId) async => (await _projects()).findById(projectId);

  Future<void> markOpened(String projectId) async => (await _projects()).touchOpened(projectId);

  Future<void> rename(String projectId, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppFailure(AppErrorCode.validation, 'نام پروژه نمی‌تواند خالی باشد.');
    }
    await (await _projects()).rename(projectId, trimmed);
  }

  Future<int> softDelete(String projectId) async => (await _projects()).softDelete(projectId);

  Future<void> restore(String projectId) async => (await _projects()).restore(projectId);

  /// Permanent delete. Cascades remove assets, tracks, segments, words,
  /// watermarks, effects and export history. The caller must confirm first.
  Future<void> deletePermanently(String projectId) async {
    await (await _projects()).hardDelete(projectId);
    _log.d('permanently deleted project $projectId');
  }

  /// Deep copy: project, asset, styles, tracks (+ provenance), segments, words,
  /// watermarks and effects. Independent from the original afterwards.
  Future<Project> duplicate(String projectId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: <Object?>[projectId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppFailure(AppErrorCode.validation, 'پروژه برای کپی پیدا نشد.');
    }
    final int now = Ids.nowMs();
    final String newProjectId = Ids.uuid();
    final String newName = await ProjectDao(db).suggestCopyName(projectId);

    await db.transaction((Transaction txn) async {
      await txn.insert(
        'projects',
        Map<String, Object?>.from(rows.first)
          ..['id'] = newProjectId
          ..['name'] = newName
          ..['created_at_ms'] = now
          ..['updated_at_ms'] = now
          ..['last_opened_at_ms'] = now
          ..['deleted_at_ms'] = null,
      );

      for (final Map<String, Object?> asset in await txn.query(
        'video_assets',
        where: 'project_id = ?',
        whereArgs: <Object?>[projectId],
      )) {
        await txn.insert(
          'video_assets',
          Map<String, Object?>.from(asset)
            ..['id'] = Ids.uuid()
            ..['project_id'] = newProjectId,
        );
      }

      final Map<String, String> styleIds = <String, String>{};
      for (final Map<String, Object?> style in await txn.query(
        'subtitle_styles',
        where: 'project_id = ?',
        whereArgs: <Object?>[projectId],
      )) {
        final String newId = Ids.uuid();
        styleIds[style['id']! as String] = newId;
        await txn.insert(
          'subtitle_styles',
          Map<String, Object?>.from(style)
            ..['id'] = newId
            ..['project_id'] = newProjectId,
        );
      }

      final List<Map<String, Object?>> tracks = await txn.query(
        'subtitle_tracks',
        where: 'project_id = ?',
        whereArgs: <Object?>[projectId],
        orderBy: 'created_at_ms ASC',
      );
      final Map<String, String> trackIds = <String, String>{};
      for (final Map<String, Object?> track in tracks) {
        final String newTrackId = Ids.uuid();
        trackIds[track['id']! as String] = newTrackId;
        await txn.insert(
          'subtitle_tracks',
          Map<String, Object?>.from(track)
            ..['id'] = newTrackId
            ..['project_id'] = newProjectId
            ..['original_track_id'] = null,
        );
      }
      for (final Map<String, Object?> track in tracks) {
        final String? original = track['original_track_id'] as String?;
        if (original != null && trackIds.containsKey(original)) {
          await txn.update(
            'subtitle_tracks',
            <String, Object?>{'original_track_id': trackIds[original]},
            where: 'id = ?',
            whereArgs: <Object?>[trackIds[track['id']]],
          );
        }
      }

      for (final Map<String, Object?> track in tracks) {
        final String oldTrackId = track['id']! as String;
        final String newTrackId = trackIds[oldTrackId]!;
        for (final Map<String, Object?> segment in await txn.query(
          'subtitle_segments',
          where: 'track_id = ?',
          whereArgs: <Object?>[oldTrackId],
        )) {
          final String newSegmentId = Ids.uuid();
          final String? styleId = segment['style_id'] as String?;
          await txn.insert(
            'subtitle_segments',
            Map<String, Object?>.from(segment)
              ..['id'] = newSegmentId
              ..['track_id'] = newTrackId
              ..['style_id'] = styleId == null ? null : styleIds[styleId],
          );
          for (final Map<String, Object?> word in await txn.query(
            'subtitle_words',
            where: 'segment_id = ?',
            whereArgs: <Object?>[segment['id']],
          )) {
            await txn.insert(
              'subtitle_words',
              Map<String, Object?>.from(word)
                ..['id'] = Ids.uuid()
                ..['segment_id'] = newSegmentId,
            );
          }
        }
      }

      for (final Map<String, Object?> watermark in await txn.query(
        'watermarks',
        where: 'project_id = ?',
        whereArgs: <Object?>[projectId],
      )) {
        await txn.insert(
          'watermarks',
          Map<String, Object?>.from(watermark)
            ..['id'] = Ids.uuid()
            ..['project_id'] = newProjectId,
        );
      }

      for (final Map<String, Object?> effect in await txn.query(
        'subtitle_effects',
        where: 'project_id = ?',
        whereArgs: <Object?>[projectId],
      )) {
        await txn.insert(
          'subtitle_effects',
          Map<String, Object?>.from(effect)
            ..['id'] = Ids.uuid()
            ..['project_id'] = newProjectId,
        );
      }
    });

    _log.d('duplicated $projectId -> $newProjectId');
    final Project? copy = await ProjectDao(db).findById(newProjectId);
    if (copy == null) {
      throw const AppFailure(AppErrorCode.database, 'کپی پروژه ساخته نشد.');
    }
    return copy;
  }

  /// Checks that the referenced media still exists (file moved, SD card pulled,
  /// URI permission revoked) and records the result on the asset row.
  Future<bool> verifyMedia(String projectId) async {
    final MediaDao media = await _media();
    final VideoAsset? asset = await media.assetOfProject(projectId);
    if (asset == null) return false;
    final bool exists = await _fileExists(asset.uri);
    // Persist only when the stored flag disagrees with reality.
    if (asset.isMissing == exists) {
      await media.markAssetMissing(asset.id, !exists);
    }
    return exists;
  }

  static String _defaultProjectName(String displayName) {
    final int dot = displayName.lastIndexOf('.');
    final String base = dot > 0 ? displayName.substring(0, dot) : displayName;
    return base.isEmpty ? 'پروژه بدون نام' : base;
  }
}

/// Aggregate loaded by the editor screen.
class ProjectDetail {
  const ProjectDetail({
    required this.project,
    required this.asset,
    required this.tracks,
    required this.watermarks,
    required this.mediaAvailable,
  });

  final Project project;
  final VideoAsset? asset;
  final List<SubtitleTrack> tracks;
  final List<Watermark> watermarks;
  final bool mediaAvailable;

  bool get hasSubtitles => tracks.any((SubtitleTrack t) => t.kind == TrackKind.original);
}
