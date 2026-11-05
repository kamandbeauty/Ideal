import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:subflow/core/time_us.dart';
import 'package:subflow/database/app_database.dart';
import 'package:subflow/database/dao/subtitle_dao.dart';
import 'package:subflow/features/effects/preset_style_mapper.dart';
import 'package:subflow/features/effects/presets_library.dart';
import 'package:subflow/features/subtitles/subtitle_document.dart';
import 'package:subflow/models/enums.dart';
import 'package:subflow/models/subtitle.dart';
import 'package:subflow/models/subtitle_style.dart';

/// Runs the *real* database code against the real SQLite engine.
///
/// 0.2.0 shipped a startup crash because nothing executed the open path in a
/// test: `PRAGMA journal_mode = WAL` went through sqflite's `execute()`, which
/// only accepts statements that return no rows, so the app died on launch. This
/// suite opens the schema, checks the pragmas, runs migrations and round-trips
/// the subtitle DAO, so the same regression fails CI instead of a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Random random = Random();
  late AppDatabase database;
  late String fileName;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    fileName = 'subflow-test-${random.nextInt(1 << 30)}.db';
    database = AppDatabase(factory: databaseFactoryFfi, fileName: fileName);
  });

  tearDown(() async {
    await database.close();
    try {
      final String dir = p.join(await databaseFactoryFfi.getDatabasesPath(), 'databases');
      final File file = File(p.join(dir, fileName));
      if (file.existsSync()) file.deleteSync();
      for (final String suffix in <String>['-wal', '-shm']) {
        final File extra = File('${file.path}$suffix');
        if (extra.existsSync()) extra.deleteSync();
      }
    } on FileSystemException {
      // A leftover file is harmless; the next run uses a fresh name.
    }
  });

  group('open path', () {
    test('opens without throwing (the 0.2.0 crash)', () async {
      final Database db = await database.database;
      expect(db.isOpen, isTrue);
    });

    test('applies every migration and records the schema version', () async {
      final Database db = await database.database;
      final int version = await db.getVersion();
      expect(version, greaterThanOrEqualTo(2));
      final List<Map<String, Object?>> rows = await db.rawQuery('PRAGMA user_version');
      expect(rows.first.values.first, version);
    });

    test('foreign keys are on and the journal mode is WAL', () async {
      final Database db = await database.database;
      final List<Map<String, Object?>> fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.first.values.first, 1);
      final List<Map<String, Object?>> journal = await db.rawQuery('PRAGMA journal_mode');
      expect('${journal.first.values.first}'.toLowerCase(), 'wal');
    });

    test('creates every table the app queries', () async {
      final Database db = await database.database;
      final List<Map<String, Object?>> rows =
          await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final Set<String> tables = rows.map((Map<String, Object?> r) => '${r['name']}').toSet();
      for (final String table in <String>[
        'projects',
        'video_assets',
        'subtitle_tracks',
        'subtitle_segments',
        'subtitle_words',
        'subtitle_styles',
        'export_jobs',
        'ai_models',
        'app_settings',
      ]) {
        expect(tables.contains(table), isTrue, reason: 'missing table $table');
      }
    });

    test('re-opening the same file does not re-run migrations', () async {
      final Database first = await database.database;
      final int version = await first.getVersion();
      await database.close();
      final AppDatabase again =
          AppDatabase(factory: databaseFactoryFfi, fileName: fileName);
      addTearDown(again.close);
      final Database second = await again.database;
      expect(await second.getVersion(), version);
    });
  });

  group('subtitle DAO against real SQLite', () {
    int counter = 0;

    // The track id matters: `subtitle_segments.track_id` is a foreign key, and a
    // wrong id here is exactly what made the first version of this suite fail.
    SubtitleSegment segment(String trackId, String id, int startMs, int endMs, String text) =>
        SubtitleSegment(
          id: id,
          trackId: trackId,
          ordinal: 0,
          startUs: TimeUs.fromMilliseconds(startMs),
          endUs: TimeUs.fromMilliseconds(endMs),
          text: text,
          source: SubtitleSource.manual,
          createdAtMs: 0,
          updatedAtMs: 0,
        );

    Future<String> insertProject() async {
      counter += 1;
      final String id = 'project-test-$counter';
      final Database db = await database.database;
      await db.insert('projects', <String, Object?>{
        'id': id,
        'name': 'پروژه تست',
        'status': ProjectStatus.draft.dbValue,
        'created_at_ms': 1,
        'updated_at_ms': 1,
      });
      return id;
    }

    test('creates exactly one original track per project', () async {
      final SubtitleDao dao = SubtitleDao(await database.database);
      final String project = await insertProject();
      final SubtitleTrack first = await dao.ensureOriginalTrack(project);
      final SubtitleTrack second = await dao.ensureOriginalTrack(project);
      expect(first.id, second.id);
      expect(first.kind, TrackKind.original);
    });

    test('round-trips segments and words, then replaces atomically', () async {
      final SubtitleDao dao = SubtitleDao(await database.database);
      final String project = await insertProject();
      final SubtitleTrack track = await dao.ensureOriginalTrack(project);

      final SubtitleDocument document = SubtitleDocument(
        trackId: track.id,
        segments: <SubtitleSegment>[
          segment(track.id, 's1', 0, 1000, ''),
          segment(track.id, 's2', 1500, 2500, ''),
        ],
      ).withText('s1', 'سلام دنیا').withText('s2', 'خداحافظ');

      await dao.replaceSegments(track.id, document.segments);
      final List<SubtitleSegment> loaded = await dao.loadSegments(track.id);
      expect(loaded.length, 2);
      expect(loaded.first.text, 'سلام دنیا');
      expect(loaded.first.words.length, 2);
      expect(loaded.first.words.first.text, 'سلام');
      expect(loaded.last.text, 'خداحافظ');
      expect(await dao.countSegments(track.id), 2);

      await dao.replaceSegments(track.id, <SubtitleSegment>[document.segments.first]);
      expect(await dao.countSegments(track.id), 1);
      final Database db = await database.database;
      final List<Map<String, Object?>> orphans = await db.rawQuery(
        'SELECT id FROM subtitle_words WHERE segment_id = ?',
        <Object?>['s2'],
      );
      expect(orphans, isEmpty, reason: 'words must not outlive their segment');
    });

    test('style rows round-trip through the DAO', () async {
      final SubtitleDao dao = SubtitleDao(await database.database);
      final String project = await insertProject();
      await dao.ensureOriginalTrack(project);
      expect(await dao.loadProjectStyle(project), isNull);

      final SubtitleStyle style = PresetStyleMapper.toStyle(
        PresetsLibrary.byId('viral-fa'),
        id: 'style-$project',
        projectId: project,
        playResX: 1080,
        playResY: 1920,
        nowMs: 5,
      );
      await dao.saveStyle(style);
      final SubtitleStyle? loaded = await dao.loadProjectStyle(project);
      expect(loaded, isNotNull);
      expect(loaded!.id, style.id);
      expect(loaded.fontFamily, style.fontFamily);
      expect(loaded.textColor, style.textColor);
      expect(loaded.direction, CaptionDirection.rtl);
    });

    test('deleting a project cascades to tracks, segments and words', () async {
      final SubtitleDao dao = SubtitleDao(await database.database);
      final String project = await insertProject();
      final SubtitleTrack track = await dao.ensureOriginalTrack(project);
      await dao.replaceSegments(
        track.id,
        SubtitleDocument(
          trackId: track.id,
          segments: <SubtitleSegment>[segment(track.id, 's1', 0, 1000, '')],
        ).withText('s1', 'یک دو سه').segments,
      );
      final Database db = await database.database;
      await db.delete('projects', where: 'id = ?', whereArgs: <Object?>[project]);
      expect(await dao.countSegments(track.id), 0);
      final List<Map<String, Object?>> words =
          await db.rawQuery('SELECT id FROM subtitle_words WHERE segment_id = ?', <Object?>['s1']);
      expect(words, isEmpty);
    });
  });
}
