import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_scanner.dart';
import 'package:moviehub/core/media/sources/media_source.dart';

/// In-memory source: listings are handed in per root; identity semantics
/// switchable to exercise both case-folding behaviors.
class _FakeSource implements MediaSource {
  _FakeSource({required this.listings, this.caseSensitive = false});

  final Map<String, MediaSourceListing> listings;
  final bool caseSensitive;

  @override
  String get id => 'fake';

  @override
  Future<MediaSourceListing> listVideos(String rootPath) async {
    return listings[rootPath] ??
        MediaSourceListing(entries: const [], skippedPaths: [rootPath]);
  }

  @override
  String playbackUriOf(String path) => 'fake://$path';

  @override
  String identityKeyOf(String path) =>
      caseSensitive ? path : path.toLowerCase();
}

MediaSourceEntry _entry(String path, {int size = 100}) {
  return MediaSourceEntry(
    path: path,
    sizeBytes: size,
    modifiedAt: DateTime(2026, 1, 1),
  );
}

MediaItem _item(
  String path, {
  String sourceId = 'fake',
  int sizeBytes = 100,
  DateTime? addedAt,
  int? tmdbId,
  bool favorite = false,
}) {
  final stamp = DateTime(2026, 1, 1);
  return MediaItem(
    path: path,
    sourceId: sourceId,
    title: '旧标题',
    extension: 'mkv',
    sizeBytes: sizeBytes,
    modifiedAt: stamp,
    addedAt: addedAt ?? stamp,
    favorite: favorite,
    following: false,
    seriesTitle: null,
    seasonNumber: null,
    episodeNumber: null,
    tmdbId: tmdbId,
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
  test('扫描条目带上 sourceId，扩展名折叠小写', () async {
    final scanner = MediaScanner(
      source: _FakeSource(
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('R/Alpha.mkv'), _entry('R/Beta.MKV')],
            skippedPaths: const [],
          ),
        },
      ),
    );

    final result = await scanner.scanRoots(['R']);

    expect(result.items, hasLength(2));
    expect(result.items.every((item) => item.sourceId == 'fake'), isTrue);
    expect(result.items.map((item) => item.extension).toSet(), {'mkv'});
    expect(result.skippedPaths, isEmpty);
  });

  test('同路径（大小写不同）继承元数据、收藏与入库时间', () async {
    final oldAddedAt = DateTime(2025, 6, 1);
    final previous = _item(
      'R/Movie.mkv',
      tmdbId: 42,
      favorite: true,
      addedAt: oldAddedAt,
    );
    final scanner = MediaScanner(
      source: _FakeSource(
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('r/movie.mkv')],
            skippedPaths: const [],
          ),
        },
      ),
    );

    final result = await scanner.scanRoots(['R'], existingItems: [previous]);

    final item = result.items.single;
    expect(item.path, 'r/movie.mkv');
    expect(item.tmdbId, 42);
    expect(item.favorite, isTrue);
    expect(item.addedAt, oldAddedAt);
  });

  test('大小写敏感源中 Movie.mkv 与 movie.mkv 是两个条目', () async {
    final scanner = MediaScanner(
      source: _FakeSource(
        caseSensitive: true,
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('R/Movie.mkv'), _entry('R/movie.mkv')],
            skippedPaths: const [],
          ),
        },
      ),
    );

    final result = await scanner.scanRoots(
      ['R'],
      existingItems: [_item('R/MOVIE.mkv', tmdbId: 9)],
    );

    expect(result.items, hasLength(2));
    // 大小写敏感语义下，MOVIE.mkv 与两个新条目互不相同，不继承。
    expect(result.items.every((item) => item.tmdbId == null), isTrue);
  });

  test('唯一同名同大小候选按移动继承，歧义候选不继承', () async {
    final moved = _item('R/old/Film.mkv', sizeBytes: 500, tmdbId: 7);
    final scanner = MediaScanner(
      source: _FakeSource(
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('R/new/Film.mkv', size: 500)],
            skippedPaths: const [],
          ),
        },
      ),
    );

    final unique = await scanner.scanRoots(['R'], existingItems: [moved]);
    expect(unique.items.single.tmdbId, 7);

    final ambiguous = await scanner.scanRoots(
      ['R'],
      existingItems: [
        _item('R/a/Film.mkv', sizeBytes: 500, tmdbId: 7),
        _item('R/b/Film.mkv', sizeBytes: 500, tmdbId: 8),
      ],
    );
    expect(ambiguous.items.single.tmdbId, isNull);
  });

  test('其它来源的条目原样透传', () async {
    final foreign = _item('remote/x.mkv', sourceId: 'webdav', tmdbId: 3);
    final scanner = MediaScanner(
      source: _FakeSource(
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('R/local.mkv')],
            skippedPaths: const [],
          ),
        },
      ),
    );

    final result = await scanner.scanRoots(['R'], existingItems: [foreign]);

    expect(result.items, hasLength(2));
    final kept = result.items.singleWhere((item) => item.sourceId == 'webdav');
    expect(kept.path, 'remote/x.mkv');
    expect(kept.tmdbId, 3);
  });

  test('源报告的 skippedPaths 与缺失根一起透传', () async {
    final scanner = MediaScanner(
      source: _FakeSource(
        listings: {
          'R': MediaSourceListing(
            entries: [_entry('R/a.mkv')],
            skippedPaths: ['R/denied'],
          ),
        },
      ),
    );

    final result = await scanner.scanRoots(['R', 'MISSING']);

    expect(result.skippedPaths, containsAll(['R/denied', 'MISSING']));
  });
}
