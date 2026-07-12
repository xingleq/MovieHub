import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/images/image_cache_store.dart';
import '../core/media/media_item.dart';
import '../core/media/media_library_store.dart';
import '../core/media/media_scanner.dart';
import '../core/tmdb/tmdb_client.dart';
import '../core/tmdb/tmdb_settings_store.dart';

/// Owns the media library data and every persisted operation. UI-agnostic:
/// never holds a BuildContext; navigation stays in the widget layer.
class LibraryController extends ChangeNotifier {
  LibraryController({
    MediaLibraryStore? store,
    MediaScanner? scanner,
    TmdbClient? tmdbClient,
    TmdbSettingsStore? settingsStore,
  }) : _store = store ?? MediaLibraryStore(),
       _scanner = scanner ?? MediaScanner(),
       _tmdbClient = tmdbClient ?? TmdbClient(),
       _settingsStore = settingsStore ?? TmdbSettingsStore();

  final MediaLibraryStore _store;
  final MediaScanner _scanner;
  final TmdbClient _tmdbClient;
  final TmdbSettingsStore _settingsStore;

  var _roots = <String>[];
  var _items = <MediaItem>[];
  var _skippedPaths = <String>[];
  var _loading = true;
  var _scanning = false;
  var _tmdbAccessToken = '';
  var _tmdbProxy = '';
  var _backgroundImagePath = '';
  String? _metadataLoadingPath;
  var _metadataBatchRunning = false;
  var _metadataBatchDone = 0;
  var _metadataBatchTotal = 0;
  String? _error;
  var _disposed = false;

  List<String> get roots => List.unmodifiable(_roots);
  List<MediaItem> get items => List.unmodifiable(_items);
  List<String> get skippedPaths => List.unmodifiable(_skippedPaths);
  bool get loading => _loading;
  bool get scanning => _scanning;
  String get tmdbAccessToken => _tmdbAccessToken;
  String get tmdbProxy => _tmdbProxy;
  String get backgroundImagePath => _backgroundImagePath;
  bool get hasTmdbToken => _tmdbAccessToken.isNotEmpty;
  String? get metadataLoadingPath => _metadataLoadingPath;
  bool get metadataBatchRunning => _metadataBatchRunning;
  int get metadataBatchDone => _metadataBatchDone;
  int get metadataBatchTotal => _metadataBatchTotal;
  String? get error => _error;

  int get favoriteCount {
    return _items.where((item) => item.favorite).length;
  }

  List<MediaItem> get favoriteItems {
    return _items.where((item) => item.favorite).toList(growable: false);
  }

  List<MediaItem> get continueWatchingItems {
    final items =
        _items.where((item) {
          return item.playbackProgress > 0.01 && item.playbackProgress < 0.95;
        }).toList()..sort((a, b) {
          final aDate =
              a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

    return items.take(12).toList(growable: false);
  }

  List<MediaItem> get recentlyAddedItems {
    final sorted = [..._items]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted.take(16).toList(growable: false);
  }

  /// The item featured in the home hero banner: prefer something in progress
  /// with a backdrop, then the newest item with a backdrop, then anything.
  MediaItem? get spotlightItem {
    final continueItems = continueWatchingItems;
    for (final item in continueItems) {
      if ((item.backdropPath ?? '').isNotEmpty) {
        return item;
      }
    }
    for (final item in recentlyAddedItems) {
      if ((item.backdropPath ?? '').isNotEmpty) {
        return item;
      }
    }
    if (continueItems.isNotEmpty) {
      return continueItems.first;
    }
    return _items.isEmpty ? null : _items.first;
  }

  MediaItem? itemByPath(String path) {
    for (final item in _items) {
      if (item.path == path) {
        return item;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  Future<void> loadAppState() async {
    try {
      final snapshot = await _store.load();
      final settings = await _settingsStore.load();
      _roots = snapshot.roots;
      _items = snapshot.items;
      _tmdbAccessToken = settings.accessToken;
      _tmdbProxy = settings.proxy;
      _backgroundImagePath = settings.backgroundImagePath;
      ImageCacheStore.instance.proxy = settings.proxy;
      _loading = false;
      notifyListeners();
    } catch (error) {
      _error = '读取媒体库失败：$error';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveTmdbSettings({
    required String accessToken,
    required String proxy,
  }) async {
    final token = accessToken.trim();
    final normalizedProxy = proxy.trim();
    await _settingsStore.save(
      TmdbSettings(
        accessToken: token,
        proxy: normalizedProxy,
        backgroundImagePath: _backgroundImagePath,
      ),
    );

    _tmdbAccessToken = token;
    _tmdbProxy = normalizedProxy;
    ImageCacheStore.instance.proxy = normalizedProxy;
    _error = null;
    notifyListeners();
  }

  /// Lets the user pick a local wallpaper image shown behind the whole app.
  Future<void> pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择背景图片',
      type: FileType.image,
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    await _saveBackgroundImage(path);
  }

  Future<void> clearBackgroundImage() async {
    await _saveBackgroundImage('');
  }

  Future<void> _saveBackgroundImage(String path) async {
    await _settingsStore.save(
      TmdbSettings(
        accessToken: _tmdbAccessToken,
        proxy: _tmdbProxy,
        backgroundImagePath: path,
      ),
    );
    _backgroundImagePath = path;
    notifyListeners();
  }

  Future<void> selectRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择影视文件夹',
      lockParentWindow: true,
    );
    if (path == null || path.trim().isEmpty || _roots.contains(path)) {
      return;
    }

    final updatedRoots = [..._roots, path];
    await _store.save(MediaLibrarySnapshot(roots: updatedRoots, items: _items));

    _roots = updatedRoots;
    notifyListeners();
  }

  Future<void> removeRoot(String path) async {
    final updatedRoots = _roots.where((root) => root != path).toList();
    await _store.save(MediaLibrarySnapshot(roots: updatedRoots, items: _items));

    _roots = updatedRoots;
    notifyListeners();
  }

  Future<void> scan() async {
    if (_roots.isEmpty || _scanning) {
      return;
    }

    _scanning = true;
    _error = null;
    _skippedPaths = [];
    notifyListeners();

    try {
      final result = await _scanner.scanRoots(_roots, existingItems: _items);
      await _store.save(
        MediaLibrarySnapshot(roots: _roots, items: result.items),
      );

      _items = result.items;
      _skippedPaths = result.skippedPaths;
      _scanning = false;
      notifyListeners();
    } catch (error) {
      _error = '扫描失败：$error';
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> openItemLocation(MediaItem item) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', item.path]);
        return;
      }

      if (Platform.isMacOS) {
        await Process.start('open', ['-R', item.path]);
        return;
      }

      await Process.start('xdg-open', [File(item.path).parent.path]);
    } catch (error) {
      _error = '打开文件位置失败：$error';
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final updatedItems = _items.map((current) {
      if (current.path != item.path) {
        return current;
      }
      return current.copyWith(favorite: !current.favorite);
    }).toList();

    await _store.save(MediaLibrarySnapshot(roots: _roots, items: updatedItems));

    _items = updatedItems;
    notifyListeners();
  }

  Future<void> matchTmdb(MediaItem item) async {
    if (_tmdbAccessToken.isEmpty) {
      _error = '请先在设置中填写 TMDB 令牌。';
      notifyListeners();
      return;
    }

    _metadataLoadingPath = item.path;
    _error = null;
    notifyListeners();

    try {
      final match = await _tmdbClient.searchMovie(
        accessToken: _tmdbAccessToken,
        query: item.title,
        proxy: _tmdbProxy,
      );

      if (match == null) {
        _metadataLoadingPath = null;
        _error = 'TMDB 未找到匹配结果：${item.title}';
        notifyListeners();
        return;
      }

      final details = await _tmdbClient.fetchDetails(
        accessToken: _tmdbAccessToken,
        id: match.id,
        mediaType: match.mediaType,
        proxy: _tmdbProxy,
      );

      final updatedItems = _applyMatch(_items, item.path, match, details);
      await _store.save(
        MediaLibrarySnapshot(roots: _roots, items: updatedItems),
      );

      _items = updatedItems;
      _metadataLoadingPath = null;
      notifyListeners();
    } catch (error) {
      _metadataLoadingPath = null;
      _error = 'TMDB 匹配失败：$error';
      notifyListeners();
    }
  }

  Future<void> matchAllTmdb() async {
    if (_metadataBatchRunning) {
      return;
    }

    if (_tmdbAccessToken.isEmpty) {
      _error = '请先在设置中填写 TMDB 令牌。';
      notifyListeners();
      return;
    }

    final pendingItems = _items.where((item) => item.tmdbId == null).toList();
    if (pendingItems.isEmpty) {
      _error = '没有需要匹配的影片。';
      notifyListeners();
      return;
    }

    _metadataBatchRunning = true;
    _metadataBatchDone = 0;
    _metadataBatchTotal = pendingItems.length;
    _metadataLoadingPath = null;
    _error = null;
    notifyListeners();

    var updatedItems = List<MediaItem>.of(_items);
    var failedCount = 0;

    for (final item in pendingItems) {
      if (_disposed) {
        return;
      }

      _metadataLoadingPath = item.path;
      notifyListeners();

      try {
        final match = await _tmdbClient.searchMovie(
          accessToken: _tmdbAccessToken,
          query: item.title,
          proxy: _tmdbProxy,
        );

        if (match == null) {
          failedCount++;
        } else {
          final details = await _tmdbClient.fetchDetails(
            accessToken: _tmdbAccessToken,
            id: match.id,
            mediaType: match.mediaType,
            proxy: _tmdbProxy,
          );
          updatedItems = _applyMatch(updatedItems, item.path, match, details);
          await _store.save(
            MediaLibrarySnapshot(roots: _roots, items: updatedItems),
          );
        }
      } catch (_) {
        failedCount++;
      }

      if (_disposed) {
        return;
      }
      _items = updatedItems;
      _metadataBatchDone++;
      notifyListeners();
    }

    _metadataBatchRunning = false;
    _metadataLoadingPath = null;
    _error = failedCount == 0 ? null : '批量匹配完成，$failedCount 个条目未匹配。';
    notifyListeners();
  }

  Future<void> savePlaybackProgress(
    MediaItem item,
    Duration position,
    Duration duration,
  ) async {
    if (duration.inMilliseconds <= 0) {
      return;
    }

    final updatedItems = _items.map((current) {
      if (current.path != item.path) {
        return current;
      }
      return current.copyWith(
        playbackPositionMs: position.inMilliseconds,
        playbackDurationMs: duration.inMilliseconds,
        lastPlayedAt: DateTime.now(),
      );
    }).toList();

    await _store.save(MediaLibrarySnapshot(roots: _roots, items: updatedItems));

    _items = updatedItems;
    notifyListeners();
  }

  static List<MediaItem> _applyMatch(
    List<MediaItem> items,
    String path,
    TmdbMovieMatch match,
    TmdbDetails? details,
  ) {
    return items.map((current) {
      if (current.path != path) {
        return current;
      }
      return current.copyWith(
        tmdbId: match.id,
        tmdbTitle: match.title,
        overview: match.overview,
        posterPath: match.posterPath,
        backdropPath: match.backdropPath,
        releaseDate: match.releaseDate,
        voteAverage: match.voteAverage,
        tmdbMediaType: match.mediaType,
        genreIds: details?.genreIds ?? match.genreIds,
        genres: details?.genres,
        directors: details?.directors,
        cast: details?.cast,
        runtimeMinutes: details?.runtimeMinutes,
      );
    }).toList();
  }

  /// Finds the next episode of the same series: same season next episode,
  /// otherwise the first episode of the next season.
  MediaItem? nextEpisodeOf(MediaItem item) {
    final seriesTitle = item.seriesTitle;
    final season = item.seasonNumber;
    final episode = item.episodeNumber;
    if (seriesTitle == null || season == null || episode == null) {
      return null;
    }

    final episodes = _items.where((candidate) {
      return candidate.isEpisode &&
          candidate.seriesTitle?.toLowerCase() == seriesTitle.toLowerCase();
    });

    MediaItem? sameSeasonNext;
    MediaItem? nextSeasonFirst;
    for (final candidate in episodes) {
      if (candidate.seasonNumber == season &&
          candidate.episodeNumber == episode + 1) {
        sameSeasonNext = candidate;
      }
      if (candidate.seasonNumber == season + 1 &&
          candidate.episodeNumber == 1) {
        nextSeasonFirst = candidate;
      }
    }
    return sameSeasonNext ?? nextSeasonFirst;
  }
}
