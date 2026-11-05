/// Project persistence.
///
/// SQLite holds the project index (fast list, sort, thumbnails) and the full
/// project JSON document. Storing one JSON document per project keeps the
/// model layer the single source of truth (no column/field divergence), while
/// the indexed columns make "recent projects" a single cheap query.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/project.dart';

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.photoCount,
    required this.updatedAt,
    this.thumbnailPath,
  });

  final String id;
  final String name;
  final int photoCount;
  final DateTime updatedAt;
  final String? thumbnailPath;
}

class ProjectRepository {
  ProjectRepository(this._db, this._dir);

  final Database _db;
  final Directory _dir;

  static const String _table = 'projects';

  /// Opens (and migrates) the project database.
  static Future<ProjectRepository> open({required Directory appDir}) async {
    final dbDir = Directory(p.join(appDir.path, 'db'));
    await dbDir.create(recursive: true);
    final db = await openDatabase(
      p.join(dbDir.path, 'motionshot.db'),
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            photo_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            thumbnail_path TEXT,
            document TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_projects_updated ON $_table(updated_at DESC)');
      },
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    final dir = Directory(p.join(appDir.path, 'projects'));
    await dir.create(recursive: true);
    return ProjectRepository(db, dir);
  }

  Future<void> save(Project project) async {
    final doc = jsonEncode(project.toJson());
    await _db.insert(
      _table,
      <String, Object?>{
        'id': project.id,
        'name': project.name,
        'photo_count': project.photos.length,
        'created_at': project.createdAt.millisecondsSinceEpoch,
        'updated_at': project.updatedAt.millisecondsSinceEpoch,
        'thumbnail_path': project.thumbnailPath,
        'document': doc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Mirror to disk so a project survives DB corruption and can be shared.
    final file = File(p.join(_dir.path, '${project.id}.json'));
    await file.writeAsString(doc, flush: true);
  }

  Future<Project?> load(String id) async {
    final rows = await _db.query(_table,
        columns: <String>['document'], where: 'id = ?', whereArgs: <Object?>[id]);
    if (rows.isEmpty) return null;
    final doc = rows.first['document'] as String;
    return Project.fromJson(jsonDecode(doc) as Map<String, dynamic>);
  }

  Future<List<ProjectSummary>> recent({int limit = 20}) async {
    final rows = await _db.query(
      _table,
      columns: <String>[
        'id', 'name', 'photo_count', 'updated_at', 'thumbnail_path'
      ],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows
        .map((r) => ProjectSummary(
              id: r['id'] as String,
              name: r['name'] as String,
              photoCount: (r['photo_count'] as num).toInt(),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  (r['updated_at'] as num).toInt()),
              thumbnailPath: r['thumbnail_path'] as String?,
            ))
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
    final file = File(p.join(_dir.path, '$id.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> rename(String id, String name) async {
    final project = await load(id);
    if (project == null) return;
    await save(project.copyWith(
        name: name, updatedAt: DateTime.now().toUtc()));
  }

  Future<void> close() => _db.close();
}
