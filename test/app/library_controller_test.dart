import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/library_controller.dart';
import 'package:moviehub/app/settings_controller.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_library_store.dart';
import 'package:moviehub/core/media/media_scanner.dart';
import 'package:moviehub/core/media/sources/media_source.dart';
import 'package:moviehub/core/system/platform_services.dart';

class _MemoryLibraryStore implements MediaLibraryStorage {
  _MemoryLibraryStore(this.snapshot);

  MediaLibrarySnapshot snapshot;

  @override
  Future<MediaLibrarySnapshot> load() async => snapshot;

  @override
  Future<void> save(MediaLibrarySnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> saveRoots(List<String> roots) async {}

  @override
  Future<void> upsertItems(Iterable<MediaItem> items) async {}
}

class _StreamSource implements MediaSource {
  const _StreamSource({this.sourceId = 'stream', this.scheme = 'stream'});

  final String sourceId;
  final String scheme;

  @override
  String get id => sourceId;

  @override
  Future<MediaSourceListing> listVideos(String rootPath) async {
    return const MediaSourceListing(entries: [], skippedPaths: []);
  }

  @override
  String playbackUriOf(String path) => '$scheme://$path';

  @override
  String identityKeyOf(String path) => path;
}

class _RecordingShell implements ShellIntegration {
  final revealed = <String>[];
  Object? throwOnReveal;

  @override
  bool get canRevealInFileManager => true;

  @override
  Future<void> revealInFileManager(String path) async {
    final error = throwOnReveal;
    if (error != null) {
      throw error;
    }
    revealed.add(path);
  }
}

MediaItem _item(String path, {String sourceId = 'stream'}) {
  final stamp = DateTime(2026, 1, 1);
  return MediaItem(
    path: path,
    sourceId: sourceId,
    title: 'a',
    extension: 'mkv',
    sizeBytes: 1,
    modifiedAt: stamp,
    addedAt: stamp,
    favorite: false,
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
  late SettingsController settings;
  late LibraryController library;
  late _RecordingShell shell;
  late PlatformServices originalServices;

  setUp(() {
    originalServices = PlatformServices.instance;
    shell = _RecordingShell();
    PlatformServices.instance = PlatformServices(
      windowControls: const NoopWindowControls(),
      sessionEvents: const NoSessionEvents(),
      startup: const UnsupportedStartupService(),
      paths: GenericAppPaths(),
      shell: shell,
    );
    settings = SettingsController();
    library = LibraryController(
      settings: settings,
      store: _MemoryLibraryStore(MediaLibrarySnapshot.empty),
      scanner: MediaScanner(source: _StreamSource()),
    );
  });

  tearDown(() {
    library.dispose();
    settings.dispose();
    PlatformServices.instance = originalServices;
  });

  test('playbackUriOf 委托给条目所属的源', () {
    expect(
      library.playbackUriOf(_item('folder/a.mkv')),
      'stream://folder/a.mkv',
    );
  });

  test('playbackUriOf 按 sourceId 分派，不固定使用扫描源', () {
    library.dispose();
    library = LibraryController(
      settings: settings,
      store: _MemoryLibraryStore(MediaLibrarySnapshot.empty),
      scanner: MediaScanner(source: const _StreamSource()),
      mediaSources: const [_StreamSource(sourceId: 'nas', scheme: 'https')],
    );

    expect(
      library.playbackUriOf(_item('folder/a.mkv', sourceId: 'nas')),
      'https://folder/a.mkv',
    );
  });

  test('相同 path 的不同源条目按复合身份独立更新', () async {
    library.dispose();
    final local = _item('folder/a.mkv', sourceId: 'local');
    final nas = _item('folder/a.mkv', sourceId: 'nas');
    library = LibraryController(
      settings: settings,
      store: _MemoryLibraryStore(
        MediaLibrarySnapshot(roots: const [], items: [local, nas]),
      ),
      scanner: MediaScanner(source: const _StreamSource()),
    );
    await library.load();

    await library.toggleFavorite(nas);

    expect(library.itemByIdentity(local.identity)!.favorite, isFalse);
    expect(library.itemByIdentity(nas.identity)!.favorite, isTrue);
  });

  test('打开文件位置经由注入的 ShellIntegration', () async {
    await library.openItemLocation(_item('folder/a.mkv', sourceId: 'local'));

    expect(shell.revealed, ['folder/a.mkv']);
    expect(library.error, isNull);
  });

  test('ShellIntegration 失败时转换为错误提示', () async {
    shell.throwOnReveal = UnsupportedError('nope');

    await library.openItemLocation(_item('folder/a.mkv', sourceId: 'local'));

    expect(shell.revealed, isEmpty);
    expect(library.error, contains('打开文件位置失败'));
  });

  test('非本地媒体源不调用文件管理器', () async {
    await library.openItemLocation(_item('folder/a.mkv', sourceId: 'nas'));

    expect(shell.revealed, isEmpty);
    expect(library.error, contains('当前媒体源不支持'));
  });
}
