import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/media/media_group.dart';
import '../core/media/media_item.dart';
import '../core/media/media_library_sqlite_store.dart';
import '../core/media/media_library_store.dart';
import '../core/media/media_scanner.dart';
import '../core/tmdb/tmdb_client.dart';
import 'settings_controller.dart';

/// Owns the media library data: items, roots, scanning, TMDB matching and
/// playback progress. UI-agnostic: never holds a BuildContext; navigation
/// stays in the widget layer. User preferences live in [SettingsController];
/// this class only reads the TMDB token/proxy from it.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required this._settings,
    MediaLibraryStorage? store,
    MediaScanner? scanner,
    TmdbClient? tmdbClient,
  }) : _store =
           store ?? MediaLibrarySqliteStore(legacyStore: MediaLibraryStore()),
       _scanner = scanner ?? MediaScanner(),
       _tmdbClient = tmdbClient ?? TmdbClient();

  final SettingsController _settings;
  final MediaLibraryStorage _store;
  final MediaScanner _scanner;
  final TmdbClient _tmdbClient;

  /// Pause between TMDB matches during a batch run, to stay far away from
  /// the API rate limit.
  static const _batchMatchInterval = Duration(milliseconds: 250);

  var _roots = <String>[];
  var _items = <MediaItem>[];
  List<MediaGroup>? _groupsCache;
  var _skippedPaths = <String>[];
  var _loading = true;
  var _scanning = false;
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
  String? get metadataLoadingPath => _metadataLoadingPath;
  bool get metadataBatchRunning => _metadataBatchRunning;
  int get metadataBatchDone => _metadataBatchDone;
  int get metadataBatchTotal => _metadataBatchTotal;
  String? get error => _error;

  /// Wall entries derived from [items]. Cached — grouping is O(n log n) and
  /// every page reads this on rebuild, so it must not recompute per caller.
  List<MediaGroup> get groups => _groupsCache ??= groupMediaItems(_items);

  int get favoriteCount {
    return _items.where((item) => item.favorite).length;
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

    // Episodes of a series share one home-shelf card, even when the user has
    // progress in different seasons. Items are already newest-first, so the
    // first one retained is always the most recently watched episode and
    // remains the resume target for that series.
    final uniqueItems = <String, MediaItem>{};
    for (final item in items) {
      final key = item.isEpisode
          ? MediaGroup.keyOf(item)
          : 'movie:${item.path}';
      uniqueItems.putIfAbsent(key, () => item);
    }

    return uniqueItems.values.take(12).toList(growable: false);
  }

  List<MediaItem> get recentlyAddedItems {
    final sorted = [..._items]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted.take(16).toList(growable: false);
  }

  /// The item featured in the home hero banner: prefer something in progress
  /// with a backdrop, then the newest item with a backdrop, then anything.
  MediaItem? get spotlightItem {
    final items = spotlightItems;
    return items.isEmpty ? null : items.first;
  }

  List<MediaItem> get spotlightItems {
    final continueItems = continueWatchingItems;
    final candidates = <MediaItem>[
      ...continueItems,
      ...recentlyAddedItems,
      ..._items,
    ];
    final seen = <String>{};
    final withBackdrop = <MediaItem>[];
    final fallback = <MediaItem>[];
    for (final item in candidates) {
      if (!seen.add(item.path)) {
        continue;
      }
      if ((item.backdropPath ?? '').isNotEmpty) {
        withBackdrop.add(item);
      } else {
        fallback.add(item);
      }
    }
    return [...withBackdrop, ...fallback].take(3).toList(growable: false);
  }

  MediaItem? itemByPath(String path) {
    for (final item in _items) {
      if (item.path == path) {
        return item;
      }
    }
    return null;
  }

  /// The episode that follows [item] in its series' season/episode order.
  /// Located by path containment (group keys can differ from the item's own
  /// key for partially matched series); order-based rather than
  /// `episode + 1`, so a missing episode doesn't break auto-play-next.
  MediaItem? nextEpisodeOf(MediaItem item) {
    if (!item.isEpisode) {
      return null;
    }
    for (final group in groups) {
      final index = group.episodes.indexWhere(
        (episode) => episode.path == item.path,
      );
      if (index < 0) {
        continue;
      }
      if (index + 1 >= group.episodes.length) {
        return null;
      }
      return group.episodes[index + 1];
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    final store = _store;
    if (store is MediaLibrarySqliteStore) {
      store.dispose();
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  /// Replaces the item list and invalidates every derived cache.
  void _setItems(List<MediaItem> items) {
    _items = items;
    _groupsCache = null;
  }

  /// Merges [updated] into the item list (matched by path) and persists
  /// exactly those rows.
  Future<void> _applyItemUpdates(List<MediaItem> updated) async {
    if (updated.isEmpty) {
      return;
    }
    final updatedByPath = {for (final item in updated) item.path: item};
    await _store.upsertItems(updated);
    _setItems([for (final item in _items) updatedByPath[item.path] ?? item]);
  }

  Future<void> load() async {
    try {
      final snapshot = await _store.load();
      _roots = snapshot.roots;
      _setItems(snapshot.items);
      _loading = false;
      notifyListeners();
    } catch (error) {
      _error = '读取媒体库失败：$error';
      _loading = false;
      notifyListeners();
    }
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
    await _store.saveRoots(updatedRoots);

    _roots = updatedRoots;
    notifyListeners();
  }

  Future<void> removeRoot(String path) async {
    final updatedRoots = _roots.where((root) => root != path).toList();
    await _store.saveRoots(updatedRoots);

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

      _setItems(result.items);
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
    final current = itemByPath(item.path);
    if (current == null) {
      return;
    }
    await _applyItemUpdates([current.copyWith(favorite: !current.favorite)]);
    notifyListeners();
  }

  Future<void> toggleGroupFavorite(MediaGroup group) async {
    final favorite = !group.anyFavorite;
    await _applyItemUpdates([
      for (final episode in group.episodes)
        if (itemByPath(episode.path) case final current?)
          current.copyWith(favorite: favorite),
    ]);
    notifyListeners();
  }

  Future<void> toggleGroupFollowing(MediaGroup group) async {
    final following = !group.anyFollowing;
    await _applyItemUpdates([
      for (final episode in group.episodes)
        if (itemByPath(episode.path) case final current?)
          current.copyWith(following: following),
    ]);
    notifyListeners();
  }

  Future<void> updateEpisodeInfo(
    MediaItem item, {
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final current = itemByPath(item.path);
    if (current == null || seasonNumber <= 0 || episodeNumber <= 0) {
      return;
    }
    await _applyItemUpdates([
      current.copyWith(
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
    ]);
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
    final current = itemByPath(item.path);
    if (current == null) {
      return;
    }

    await _applyItemUpdates([
      current.copyWith(
        playbackPositionMs: position.inMilliseconds,
        playbackDurationMs: duration.inMilliseconds,
        lastPlayedAt: DateTime.now(),
      ),
    ]);
    notifyListeners();
  }

  Future<void> matchTmdb(MediaItem item) async {
    await _matchPaths(
      paths: {item.path},
      query: item.title,
      preferTv: false,
      loadingPath: item.path,
    );
  }

  /// Matches one wall entry: a whole series gets a single TMDB lookup whose
  /// result is applied to every episode; a movie matches itself.
  Future<void> matchGroup(MediaGroup group) async {
    final rep = group.representative;
    await _matchPaths(
      paths: group.paths.toSet(),
      query: group.isSeries ? (rep.seriesTitle ?? group.title) : rep.title,
      preferTv: group.isSeries,
      loadingPath: rep.path,
    );
  }

  Future<void> _matchPaths({
    required Set<String> paths,
    required String query,
    required bool preferTv,
    required String loadingPath,
  }) async {
    if (!_settings.hasTmdbToken) {
      _error = '请先在设置中填写 TMDB 令牌。';
      notifyListeners();
      return;
    }

    _metadataLoadingPath = loadingPath;
    _error = null;
    notifyListeners();

    try {
      final match = await _tmdbClient.searchMovie(
        accessToken: _settings.tmdbAccessToken,
        query: query,
        proxy: _settings.tmdbProxy,
        preferTv: preferTv,
      );

      if (match == null) {
        _metadataLoadingPath = null;
        _error = 'TMDB 未找到匹配结果：$query';
        notifyListeners();
        return;
      }

      final details = await _tmdbClient.fetchDetails(
        accessToken: _settings.tmdbAccessToken,
        id: match.id,
        mediaType: match.mediaType,
        proxy: _settings.tmdbProxy,
      );

      await _applyItemUpdates(_matchedItems(_items, paths, match, details));
      _metadataLoadingPath = null;
      notifyListeners();
    } catch (error) {
      _metadataLoadingPath = null;
      _error = 'TMDB 匹配失败：$error';
      notifyListeners();
    }
  }

  /// Manual match chosen from the search dialog — applied to all [paths]
  /// (one movie, or every episode of a series).
  Future<void> applyManualMatch(
    List<String> paths,
    TmdbMovieMatch match, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    if (paths.isEmpty) {
      return;
    }
    _metadataLoadingPath = paths.first;
    _error = null;
    notifyListeners();

    try {
      final details = await _tmdbClient.fetchDetails(
        accessToken: _settings.tmdbAccessToken,
        id: match.id,
        mediaType: match.mediaType,
        proxy: _settings.tmdbProxy,
      );

      await _applyItemUpdates(
        _matchedItems(
          _items,
          paths.toSet(),
          match,
          details,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        ),
      );
    } catch (error) {
      _error = 'TMDB 匹配失败：$error';
    }
    _metadataLoadingPath = null;
    notifyListeners();
  }

  /// Candidate list for the manual match dialog. Network errors surface as
  /// the shared error banner and return an empty list.
  Future<List<TmdbMovieMatch>> searchTmdbCandidates(String query) async {
    if (!_settings.hasTmdbToken) {
      _error = '请先在设置中填写 TMDB 令牌。';
      notifyListeners();
      return const [];
    }
    try {
      return await _tmdbClient.searchCandidates(
        accessToken: _settings.tmdbAccessToken,
        query: query,
        proxy: _settings.tmdbProxy,
      );
    } catch (error) {
      _error = 'TMDB 搜索失败：$error';
      notifyListeners();
      return const [];
    }
  }

  Future<List<TmdbSeasonInfo>> fetchTmdbSeasons(TmdbMovieMatch match) async {
    if (!_settings.hasTmdbToken || match.mediaType != 'tv') {
      return const [];
    }
    try {
      return await _tmdbClient.fetchTvSeasons(
        accessToken: _settings.tmdbAccessToken,
        tvId: match.id,
        proxy: _settings.tmdbProxy,
      );
    } catch (error) {
      _error = 'TMDB 读取季信息失败：$error';
      notifyListeners();
      return const [];
    }
  }

  Future<List<TmdbEpisodeInfo>> fetchTmdbEpisodes(
    TmdbMovieMatch match,
    int seasonNumber,
  ) async {
    if (!_settings.hasTmdbToken || match.mediaType != 'tv') {
      return const [];
    }
    try {
      return await _tmdbClient.fetchTvSeasonEpisodes(
        accessToken: _settings.tmdbAccessToken,
        tvId: match.id,
        seasonNumber: seasonNumber,
        proxy: _settings.tmdbProxy,
      );
    } catch (error) {
      _error = 'TMDB 读取分集失败：$error';
      notifyListeners();
      return const [];
    }
  }

  Future<void> matchAllTmdb() async {
    if (_metadataBatchRunning) {
      return;
    }

    if (!_settings.hasTmdbToken) {
      _error = '请先在设置中填写 TMDB 令牌。';
      notifyListeners();
      return;
    }

    final pendingGroups = groups
        .where((group) => group.episodes.any((item) => item.tmdbId == null))
        .toList();
    if (pendingGroups.isEmpty) {
      _error = '没有需要匹配的影片。';
      notifyListeners();
      return;
    }

    _metadataBatchRunning = true;
    _metadataBatchDone = 0;
    _metadataBatchTotal = pendingGroups.length;
    _metadataLoadingPath = null;
    _error = null;
    notifyListeners();

    var failedCount = 0;

    for (final group in pendingGroups) {
      if (_disposed) {
        return;
      }

      final rep = group.representative;
      _metadataLoadingPath = rep.path;
      notifyListeners();

      try {
        final match = await _tmdbClient.searchMovie(
          accessToken: _settings.tmdbAccessToken,
          query: group.isSeries ? (rep.seriesTitle ?? group.title) : rep.title,
          proxy: _settings.tmdbProxy,
          preferTv: group.isSeries,
        );

        if (match == null) {
          failedCount++;
        } else {
          final details = await _tmdbClient.fetchDetails(
            accessToken: _settings.tmdbAccessToken,
            id: match.id,
            mediaType: match.mediaType,
            proxy: _settings.tmdbProxy,
          );
          await _applyItemUpdates(
            _matchedItems(_items, group.paths.toSet(), match, details),
          );
        }
      } catch (_) {
        failedCount++;
      }

      if (_disposed) {
        return;
      }
      _metadataBatchDone++;
      notifyListeners();

      if (_metadataBatchDone < _metadataBatchTotal) {
        await Future<void>.delayed(_batchMatchInterval);
      }
    }

    _metadataBatchRunning = false;
    _metadataLoadingPath = null;
    _error = failedCount == 0 ? null : '批量匹配完成，$failedCount 个条目未匹配。';
    notifyListeners();
  }

  /// The items in [paths] with the TMDB match applied — only the changed
  /// rows, ready for an upsert.
  static List<MediaItem> _matchedItems(
    List<MediaItem> items,
    Set<String> paths,
    TmdbMovieMatch match,
    TmdbDetails? details, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return [
      for (final item in items)
        if (paths.contains(item.path))
          item.copyWith(
            tmdbId: match.id,
            tmdbTitle: match.title,
            overview: match.overview,
            posterPath: match.posterPath,
            backdropPath: match.backdropPath,
            releaseDate: match.releaseDate,
            voteAverage: match.voteAverage,
            tmdbMediaType: match.mediaType,
            seriesTitle: match.mediaType == 'tv'
                ? (item.seriesTitle ?? match.title)
                : item.seriesTitle,
            seasonNumber: seasonNumber ?? item.seasonNumber,
            episodeNumber: episodeNumber ?? item.episodeNumber,
            genreIds: details?.genreIds ?? match.genreIds,
            genres: details?.genres,
            directors: details?.directors,
            cast: details?.cast,
            runtimeMinutes: details?.runtimeMinutes,
          ),
    ];
  }
}
