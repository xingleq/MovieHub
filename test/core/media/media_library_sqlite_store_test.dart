import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_library_sqlite_store.dart';
import 'package:moviehub/core/media/media_library_store.dart';
import 'package:sqlite3/sqlite3.dart';

MediaItem _item(String sourceId, String path, {bool favorite = false}) {
  final stamp = DateTime(2026, 1, 1);
  return MediaItem(
    sourceId: sourceId,
    path: path,
    title: '$sourceId-$path',
    extension: 'mkv',
    sizeBytes: 1,
    modifiedAt: stamp,
    addedAt: stamp,
    favorite: favorite,
    following: false,
    seriesTitle: null,
    seasonNumber: null,
    episodeNumber: null,
    tmdbId: null,
    tmdbTitle: null,
    overview: null,
    posterPath: null,
    backdropPath: null,
    releaseDate: null,
    voteAverage: null,
    tmdbMediaType: null,
    genreIds: null,
    genres: null,
    directors: null,
    cast: null,
    runtimeMinutes: null,
    playbackPositionMs: 0,
    playbackDurationMs: 0,
    lastPlayedAt: null,
  );
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('moviehub-sqlite-test-');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('相同 path 的不同媒体源可同时保存并独立更新', () async {
    final store = MediaLibrarySqliteStore(storageDirectory: directory);
    final local = _item('local', 'folder/movie.mkv');
    final nas = _item('nas', 'folder/movie.mkv');

    await store.save(
      MediaLibrarySnapshot(roots: const [], items: [local, nas]),
    );
    await store.upsertItems([nas.copyWith(favorite: true)]);

    final loaded = await store.load();
    expect(loaded.items, hasLength(2));
    expect(
      loaded.items.singleWhere((item) => item.sourceId == 'local').favorite,
      isFalse,
    );
    expect(
      loaded.items.singleWhere((item) => item.sourceId == 'nas').favorite,
      isTrue,
    );
    store.dispose();
  });

  test('旧 path 主键表迁移为复合主键并回填 local', () async {
    final database = sqlite3.open(
      '${directory.path}${Platform.pathSeparator}moviehub.db',
    );
    database.execute('CREATE TABLE roots (path TEXT PRIMARY KEY)');
    database.execute(
      'CREATE TABLE items (path TEXT PRIMARY KEY, json TEXT NOT NULL)',
    );
    final legacy = _item('local', 'legacy/movie.mkv').toJson()
      ..remove('sourceId');
    database.execute('INSERT INTO items (path, json) VALUES (?, ?)', [
      'legacy/movie.mkv',
      jsonEncode(legacy),
    ]);
    database.dispose();

    final store = MediaLibrarySqliteStore(storageDirectory: directory);
    final loaded = await store.load();

    expect(loaded.items.single.sourceId, 'local');
    await store.upsertItems([_item('nas', 'legacy/movie.mkv')]);
    expect((await store.load()).items, hasLength(2));
    store.dispose();
  });
}
