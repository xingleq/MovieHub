import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../system/platform_services.dart';
import 'media_item.dart';
import 'media_library_store.dart';

/// SQLite-backed media library in `%APPDATA%/MovieHub/moviehub.db`.
///
/// Write granularity matches [MediaLibraryStorage]: [upsertItems] touches
/// only the given rows on the UI isolate (sub-millisecond for the everyday
/// one-item case), while the full-replace [save] — thousands of rows after
/// a scan — runs on a background isolate over its own connection so the UI
/// never blocks. WAL journaling plus a busy timeout make the two
/// connections safe together.
///
/// Each item row stores the item's JSON document, so the schema never needs
/// migrations when [MediaItem] gains fields.
class MediaLibrarySqliteStore implements MediaLibraryStorage {
  MediaLibrarySqliteStore({Directory? storageDirectory, this.legacyStore})
    : _storageDirectory =
          storageDirectory ?? PlatformServices.instance.paths.appDataDirectory;

  final Directory _storageDirectory;

  /// Legacy JSON store; a non-empty legacy file is imported once and then
  /// archived as `.bak`.
  final MediaLibraryStore? legacyStore;

  Database? _database;

  Database get _db => _database ??= _open(_storageDirectory.path);

  /// Opens (and if needed creates) the database under [directoryPath].
  /// Static so the background-isolate writer can open its own connection.
  static Database _open(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final database = sqlite3.open(
      '$directoryPath${Platform.pathSeparator}moviehub.db',
    );
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA busy_timeout = 5000;');
    database.execute('''
      CREATE TABLE IF NOT EXISTS roots (
        path TEXT PRIMARY KEY
      );
    ''');
    _ensureItemsTable(database);
    return database;
  }

  static void _ensureItemsTable(Database database) {
    final columns = database.select('PRAGMA table_info(items)');
    if (columns.isEmpty) {
      _createItemsTable(database);
      return;
    }
    if (columns.any((row) => row['name'] == 'source_id')) {
      return;
    }

    // v1.1.x keyed rows by path only. Preserve every document and backfill
    // its source id while changing the primary key to (source_id, path).
    final legacyRows = [
      for (final row in database.select('SELECT path, json FROM items'))
        (row['path'] as String, row['json'] as String),
    ];
    _inTransaction(database, () {
      database.execute('ALTER TABLE items RENAME TO items_v1');
      _createItemsTable(database);
      _insertItemRows(database, [
        for (final (path, json) in legacyRows)
          (
            (jsonDecode(json) as Map<String, Object?>)['sourceId'] as String? ??
                'local',
            path,
            json,
          ),
      ]);
      database.execute('DROP TABLE items_v1');
    });
  }

  static void _createItemsTable(Database database) {
    database.execute('''
      CREATE TABLE items (
        source_id TEXT NOT NULL,
        path TEXT NOT NULL,
        json TEXT NOT NULL,
        PRIMARY KEY (source_id, path)
      );
    ''');
  }

  @override
  Future<MediaLibrarySnapshot> load() async {
    await _migrateFromLegacyIfNeeded();

    final roots = [
      for (final row in _db.select('SELECT path FROM roots'))
        row['path'] as String,
    ];
    final items = [
      for (final row in _db.select('SELECT json FROM items'))
        MediaItem.fromJson(
          jsonDecode(row['json'] as String) as Map<String, Object?>,
        ),
    ];
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return MediaLibrarySnapshot(roots: roots, items: items);
  }

  @override
  Future<void> upsertItems(Iterable<MediaItem> items) async {
    final rows = [
      for (final item in items)
        (item.sourceId, item.path, jsonEncode(item.toJson())),
    ];
    if (rows.isEmpty) {
      return;
    }
    _inTransaction(_db, () {
      _insertItemRows(_db, rows);
    });
  }

  @override
  Future<void> saveRoots(List<String> roots) async {
    _inTransaction(_db, () {
      _db.execute('DELETE FROM roots');
      _insertRootRows(_db, roots);
    });
  }

  @override
  Future<void> save(MediaLibrarySnapshot snapshot) async {
    final directoryPath = _storageDirectory.path;
    final roots = List<String>.of(snapshot.roots);
    final items = List<MediaItem>.of(snapshot.items);

    await Isolate.run(() {
      final database = _open(directoryPath);
      try {
        _inTransaction(database, () {
          database.execute('DELETE FROM roots');
          database.execute('DELETE FROM items');
          _insertRootRows(database, roots);
          _insertItemRows(database, [
            for (final item in items)
              (item.sourceId, item.path, jsonEncode(item.toJson())),
          ]);
        });
      } finally {
        database.dispose();
      }
    });
  }

  static void _inTransaction(Database database, void Function() body) {
    database.execute('BEGIN');
    try {
      body();
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _insertRootRows(Database database, List<String> roots) {
    final statement = database.prepare(
      'INSERT OR REPLACE INTO roots (path) VALUES (?)',
    );
    try {
      for (final root in roots) {
        statement.execute([root]);
      }
    } finally {
      statement.dispose();
    }
  }

  static void _insertItemRows(
    Database database,
    List<(String, String, String)> rows,
  ) {
    final statement = database.prepare(
      'INSERT OR REPLACE INTO items (source_id, path, json) VALUES (?, ?, ?)',
    );
    try {
      for (final (sourceId, path, json) in rows) {
        statement.execute([sourceId, path, json]);
      }
    } finally {
      statement.dispose();
    }
  }

  Future<void> _migrateFromLegacyIfNeeded() async {
    final legacy = legacyStore;
    if (legacy == null) {
      return;
    }

    final itemCount =
        _db.select('SELECT COUNT(*) AS c FROM items').first['c'] as int;
    final rootCount =
        _db.select('SELECT COUNT(*) AS c FROM roots').first['c'] as int;
    if (itemCount > 0 || rootCount > 0) {
      return;
    }

    final legacyFile = legacy.storageFile;
    if (!await legacyFile.exists()) {
      return;
    }

    final snapshot = await legacy.load();
    if (snapshot.roots.isEmpty && snapshot.items.isEmpty) {
      return;
    }

    await save(snapshot);
    try {
      await legacyFile.rename('${legacyFile.path}.bak');
    } on FileSystemException {
      // Archiving is best-effort; the database is already populated and an
      // empty db never re-triggers migration once rows exist.
    }
  }

  void dispose() {
    _database?.dispose();
    _database = null;
  }
}
