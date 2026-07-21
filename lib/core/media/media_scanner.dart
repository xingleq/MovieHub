import 'dart:isolate';

import 'media_filename_parser.dart';
import 'media_item.dart';
import 'sources/local_file_source.dart';
import 'sources/media_source.dart';

class MediaScanResult {
  const MediaScanResult({required this.items, required this.skippedPaths});

  final List<MediaItem> items;
  final List<String> skippedPaths;
}

/// Builds the library from a [MediaSource]: the source enumerates video
/// entries; episode inference, metadata carry-over and move detection here
/// are source-agnostic — they only look at paths, names and sizes.
class MediaScanner {
  MediaScanner({MediaSource? source})
    : source = source ?? const LocalFileSource();

  final MediaSource source;

  /// Scans [roots] within [source] and returns the full new library
  /// contents. Items in [existingItems] belonging to other sources are
  /// passed through untouched.
  ///
  /// Metadata carry-over: an existing item at the same path keeps its
  /// TMDB data, favorite flag and playback state; a file that disappeared
  /// from its old path but reappears elsewhere with the same name and size
  /// is treated as moved and keeps them too.
  Future<MediaScanResult> scanRoots(
    List<String> roots, {
    List<MediaItem> existingItems = const [],
  }) async {
    final listings = <(String, MediaSourceListing)>[];
    for (final root in List<String>.of(roots)) {
      listings.add((root, await source.listVideos(root)));
    }

    final sourceId = source.id;
    final existingCopy = List<MediaItem>.of(existingItems);
    // Identity keys are resolved here on the main isolate: the merge below
    // must not capture the source object (implementations may hold
    // non-sendable state), so only this plain map crosses over.
    final identityKeyByPath = <String, String>{
      for (final (_, listing) in listings)
        for (final entry in listing.entries)
          entry.path: source.identityKeyOf(entry.path),
      for (final item in existingCopy)
        if (item.sourceId == sourceId)
          item.path: source.identityKeyOf(item.path),
    };
    // Parsing and merging thousands of entries is pure computation; keep it
    // off the UI isolate.
    return Isolate.run(
      () => _buildResult(sourceId, listings, existingCopy, identityKeyByPath),
    );
  }

  static MediaScanResult _buildResult(
    String sourceId,
    List<(String, MediaSourceListing)> listings,
    List<MediaItem> existingItems,
    Map<String, String> identityKeyByPath,
  ) {
    String keyOf(String path) => identityKeyByPath[path] ?? path;

    final previousByPath = <String, MediaItem>{};
    final foreignItems = <MediaItem>[];
    for (final item in existingItems) {
      if (item.sourceId == sourceId) {
        previousByPath[keyOf(item.path)] = item;
      } else {
        foreignItems.add(item);
      }
    }

    final scannedByPath = <String, MediaItem>{};
    final skippedPaths = <String>[];

    for (final (rootPath, listing) in listings) {
      skippedPaths.addAll(listing.skippedPaths);

      // Group videos by folder first: episode inference needs to know how
      // many numbered siblings a file has (数码宝贝第一季/01大冒险.mkv …).
      final entriesByDirectory = <String, List<MediaSourceEntry>>{};
      for (final entry in listing.entries) {
        entriesByDirectory
            .putIfAbsent(parentPathOf(entry.path), () => [])
            .add(entry);
      }

      for (final entries in entriesByDirectory.values) {
        final numberedSiblings = entries
            .where(
              (entry) => parseEpisodeNumber(_rawTitleOf(entry.path)) != null,
            )
            .length;
        for (final entry in entries) {
          scannedByPath[keyOf(entry.path)] = _itemFromEntry(
            entry,
            sourceId: sourceId,
            rootPath: rootPath,
            numberedSiblings: numberedSiblings,
          );
        }
      }
    }

    // Items that vanished from their old location are move candidates,
    // indexed by (file name, size). Only an unambiguous single candidate is
    // safe to inherit from.
    final moveCandidates = <(String, int), List<MediaItem>>{};
    for (final entry in previousByPath.entries) {
      if (scannedByPath.containsKey(entry.key)) {
        continue;
      }
      moveCandidates
          .putIfAbsent(_identityOf(entry.key, entry.value), () => [])
          .add(entry.value);
    }

    final items = [
      for (final entry in scannedByPath.entries)
        entry.value.preserveAddedAt(
          previousByPath[entry.key] ??
              _uniqueMoveCandidate(moveCandidates, entry.key, entry.value),
        ),
      ...foreignItems,
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return MediaScanResult(items: items, skippedPaths: skippedPaths);
  }

  /// Move-detection identity, derived from the source's identity key so
  /// case handling follows the source's semantics.
  static (String, int) _identityOf(String identityKey, MediaItem item) {
    return (fileNameOf(identityKey), item.sizeBytes);
  }

  static MediaItem? _uniqueMoveCandidate(
    Map<(String, int), List<MediaItem>> candidates,
    String identityKey,
    MediaItem scanned,
  ) {
    final matches = candidates[_identityOf(identityKey, scanned)];
    return (matches != null && matches.length == 1) ? matches.single : null;
  }

  static MediaItem _itemFromEntry(
    MediaSourceEntry entry, {
    required String sourceId,
    required String rootPath,
    required int numberedSiblings,
  }) {
    final fileName = fileNameOf(entry.path);
    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    var parsed = parseFileName(rawTitle);
    if (parsed.seasonNumber == null) {
      parsed =
          _episodeFromDirectory(
            entry.path,
            rootPath: rootPath,
            rawTitle: rawTitle,
            numberedSiblings: numberedSiblings,
          ) ??
          parsed;
    }

    return MediaItem(
      path: entry.path,
      sourceId: sourceId,
      title: parsed.title,
      extension: extension.toLowerCase(),
      sizeBytes: entry.sizeBytes,
      modifiedAt: entry.modifiedAt,
      addedAt: DateTime.now(),
      favorite: false,
      following: false,
      seriesTitle: parsed.seriesTitle,
      seasonNumber: parsed.seasonNumber,
      episodeNumber: parsed.episodeNumber,
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

  /// Derives episode info from the folder layout (剧名文件夹/01集名.mkv) when
  /// the file name itself has no S01E01-style marker. A bare leading number
  /// only counts with corroborating evidence — an explicit episode marker,
  /// a season marker on the folder, or at least two numbered siblings — so
  /// `经典电影/007.mkv` stays a movie.
  static ParsedFileName? _episodeFromDirectory(
    String path, {
    required String rootPath,
    required String rawTitle,
    required int numberedSiblings,
  }) {
    final episode = parseEpisodeNumber(rawTitle);
    if (episode == null) {
      return null;
    }

    final context = _seriesContextOf(path, rootPath);
    if (context == null) {
      return null;
    }

    final trusted =
        episode.explicit ||
        context.seasonNumber != null ||
        numberedSiblings >= 2;
    if (!trusted) {
      return null;
    }

    final season = context.seasonNumber ?? 1;
    return ParsedFileName(
      title:
          '${context.seriesTitle} '
          'S${twoDigits(season)}E${twoDigits(episode.value)}',
      seriesTitle: context.seriesTitle,
      seasonNumber: season,
      episodeNumber: episode.value,
    );
  }

  /// Series title/season for a file from its parent folder — or, when the
  /// parent is a pure season folder (第一季/Season 1), from the grandparent.
  /// Files directly under a scan root only get a context when the root
  /// folder itself carries a season marker (the user added 数码宝贝第一季
  /// as a root).
  static DirectoryInfo? _seriesContextOf(String path, String rootPath) {
    final parentPath = parentPathOf(path);
    if (_samePath(parentPath, rootPath)) {
      final rootInfo = parseDirectoryName(fileNameOf(rootPath));
      final usable =
          rootInfo.seasonNumber != null && rootInfo.seriesTitle.isNotEmpty;
      return usable ? rootInfo : null;
    }

    final parentInfo = parseDirectoryName(fileNameOf(parentPath));
    if (parentInfo.isPureSeason) {
      final grandInfo = parseDirectoryName(
        fileNameOf(parentPathOf(parentPath)),
      );
      if (grandInfo.seriesTitle.isEmpty) {
        return null;
      }
      return DirectoryInfo(
        seriesTitle: grandInfo.seriesTitle,
        seasonNumber: parentInfo.seasonNumber,
      );
    }
    if (parentInfo.seriesTitle.isEmpty) {
      return null;
    }
    return parentInfo;
  }

  static String _rawTitleOf(String path) {
    final fileName = fileNameOf(path);
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /// Config-vs-listing path comparison for series-context inference only.
  /// Do not case-fold here: case-sensitive sources may contain distinct paths.
  static bool _samePath(String a, String b) {
    String normalize(String path) {
      var normalized = path.replaceAll('\\', '/');
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      return normalized;
    }

    return normalize(a) == normalize(b);
  }
}
