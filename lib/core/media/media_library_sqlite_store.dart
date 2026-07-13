import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'media_item.dart';
import 'media_library_store.dart';

/// SQLite-backed media library (todo §10): per-row storage in
/// `%APPDATA%/MovieHub/moviehub.db` with transactional writes — much cheaper
/// than rewriting one big pretty-printed JSON file as the library grows.
///
/// Each item row stores the item's JSON document, so the schema never needs
/// migrations when [MediaItem] gains fields.
class MediaLibrarySqliteStore implements MediaLibraryStorage {
  MediaLibrarySqliteStore({Directory? storageDirectory, this.legacyStore})
    : _storageDirectory = storageDirectory ?? _defaultStorageDirectory();

  final Directory _storageDirectory;

  /// Legacy JSON store; a non-empty legacy file is imported once and then
  /// archived as `.bak`.
  final MediaLibraryStore? legacyStore;

  Database? _database;

  Database get _db {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    if (!_storageDirectory.existsSync()) {
      _storageDirectory.createSync(recursive: true);
    }
    final database = sqlite3.open(
      '${_storageDirectory.path}${Platform.pathSeparator}moviehub.db',
    );
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('''
      CREATE TABLE IF NOT EXISTS roots (
        path TEXT PRIMARY KEY
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS items (
        path TEXT PRIMARY KEY,
        json TEXT NOT NULL
      );
    ''');
    return _database = database;
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
  Future<void> save(MediaLibrarySnapshot snapshot) async {
    final database = _db;
    database.execute('BEGIN');
    try {
      database.execute('DELETE FROM roots');
      database.execute('DELETE FROM items');

      final insertRoot = database.prepare(
        'INSERT OR REPLACE INTO roots (path) VALUES (?)',
      );
      final insertItem = database.prepare(
        'INSERT OR REPLACE INTO items (path, json) VALUES (?, ?)',
      );
      try {
        for (final root in snapshot.roots) {
          insertRoot.execute([root]);
        }
        for (final item in snapshot.items) {
          insertItem.execute([item.path, jsonEncode(item.toJson())]);
        }
      } finally {
        insertRoot.dispose();
        insertItem.dispose();
      }

      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
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

  static Directory _defaultStorageDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}MovieHub');
    }

    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory('$home${Platform.pathSeparator}.moviehub');
  }
}
