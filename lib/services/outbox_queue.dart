import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.basename,
    required this.imagePath,
    required this.mdContent,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    this.paused = false,
  });

  final int id;
  final String basename;
  final String imagePath;
  final String mdContent;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final bool paused;
}

class OutboxQueue {
  Database? _db;

  Future<void> init() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'outbox.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            basename TEXT NOT NULL,
            image_path TEXT NOT NULL,
            md_content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            paused INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> enqueue({
    required String basename,
    required String imagePath,
    required String mdContent,
  }) async {
    final db = _requireDb();
    return db.insert('outbox', {
      'basename': basename,
      'image_path': imagePath,
      'md_content': mdContent,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'paused': 0,
    });
  }

  Future<List<OutboxItem>> pending() async {
    final db = _requireDb();
    final rows = await db.query(
      'outbox',
      where: 'paused = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<OutboxItem>> all() async {
    final db = _requireDb();
    final rows = await db.query('outbox', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<int> countPending() async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM outbox WHERE paused = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSuccess(int id) async {
    final db = _requireDb();
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailure(int id, String error, {bool pause = false}) async {
    final db = _requireDb();
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ?, paused = ? WHERE id = ?',
      [error, pause ? 1 : 0, id],
    );
  }

  Future<void> resumeAll() async {
    final db = _requireDb();
    await db.update('outbox', {'paused': 0, 'last_error': null});
  }

  Future<void> delete(int id) async {
    final db = _requireDb();
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('OutboxQueue not initialized');
    }
    return db;
  }

  OutboxItem _fromRow(Map<String, dynamic> row) {
    return OutboxItem(
      id: row['id'] as int,
      basename: row['basename'] as String,
      imagePath: row['image_path'] as String,
      mdContent: row['md_content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
      paused: (row['paused'] as int) == 1,
    );
  }
}
