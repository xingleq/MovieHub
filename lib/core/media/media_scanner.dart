import 'dart:io';
import 'dart:isolate';

import 'media_filename_parser.dart';
import 'media_item.dart';

class MediaScanResult {
  const MediaScanResult({required this.items, required this.skippedPaths});

  final List<MediaItem> items;
  final List<String> skippedPaths;
}

class MediaScanner {
  static const videoExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'flv',
    'ts',
    'm2ts',
  };

  /// Walks [roots] on a background isolate (directory listing and per-file
  /// stats are blocking I/O) and returns the full new library contents.
  ///
  /// Metadata carry-over: an existing item at the same path keeps its
  /// TMDB data, favorite flag and playback state; a file that disappeared
  /// from its old path but reappears elsewhere with the same name and size
  /// is treated as moved and keeps them too.
  Future<MediaScanResult> scanRoots(
    List<String> roots, {
    List<MediaItem> existingItems = const [],
  }) {
    final rootsCopy = List<String>.of(roots);
    final existingCopy = List<MediaItem>.of(existingItems);
    return Isolate.run(() => _scanSync(rootsCopy, existingCopy));
  }

  static MediaScanResult _scanSync(
    List<String> roots,
    List<MediaItem> existingItems,
  ) {
    final previousByPath = {
      for (final item in existingItems) item.path.toLowerCase(): item,
    };
    final scannedByPath = <String, MediaItem>{};
    final skippedPaths = <String>[];

    for (final rootPath in roots) {
      final directory = Directory(rootPath);
      if (!directory.existsSync()) {
        skippedPaths.add(rootPath);
        continue;
      }

      // Group videos by folder first: episode inference needs to know how
      // many numbered siblings a file has (数码宝贝第一季/01大冒险.mkv …).
      final videosByDirectory = <String, List<File>>{};
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !isVideoPath(entity.path)) {
          continue;
        }
        videosByDirectory.putIfAbsent(entity.parent.path, () => []).add(entity);
      }

      for (final files in videosByDirectory.values) {
        final numberedSiblings = files
            .where((file) => parseEpisodeNumber(_rawTitleOf(file.path)) != null)
            .length;
        for (final file in files) {
          try {
            scannedByPath[file.path.toLowerCase()] = _itemFromFile(
              file,
              rootPath: rootPath,
              numberedSiblings: numberedSiblings,
            );
          } on FileSystemException {
            skippedPaths.add(file.path);
          }
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
          .putIfAbsent(_identityOf(entry.value), () => [])
          .add(entry.value);
    }

    final items = [
      for (final entry in scannedByPath.entries)
        entry.value.preserveAddedAt(
          previousByPath[entry.key] ??
              _uniqueMoveCandidate(moveCandidates, entry.value),
        ),
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return MediaScanResult(items: items, skippedPaths: skippedPaths);
  }

  static (String, int) _identityOf(MediaItem item) {
    return (fileNameOf(item.path).toLowerCase(), item.sizeBytes);
  }

  static MediaItem? _uniqueMoveCandidate(
    Map<(String, int), List<MediaItem>> candidates,
    MediaItem scanned,
  ) {
    final matches = candidates[_identityOf(scanned)];
    return (matches != null && matches.length == 1) ? matches.single : null;
  }

  static MediaItem _itemFromFile(
    File file, {
    required String rootPath,
    required int numberedSiblings,
  }) {
    final stat = file.statSync();
    final fileName = fileNameOf(file.path);
    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    var parsed = parseFileName(rawTitle);
    if (parsed.seasonNumber == null) {
      parsed =
          _episodeFromDirectory(
            file,
            rootPath: rootPath,
            rawTitle: rawTitle,
            numberedSiblings: numberedSiblings,
          ) ??
          parsed;
    }

    return MediaItem(
      path: file.path,
      title: parsed.title,
      extension: extension.toLowerCase(),
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
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

  static bool isVideoPath(String path) {
    final extension = extensionOf(path);
    return videoExtensions.contains(extension);
  }

  /// Derives episode info from the folder layout (剧名文件夹/01集名.mkv) when
  /// the file name itself has no S01E01-style marker. A bare leading number
  /// only counts with corroborating evidence — an explicit episode marker,
  /// a season marker on the folder, or at least two numbered siblings — so
  /// `经典电影/007.mkv` stays a movie.
  static ParsedFileName? _episodeFromDirectory(
    File file, {
    required String rootPath,
    required String rawTitle,
    required int numberedSiblings,
  }) {
    final episode = parseEpisodeNumber(rawTitle);
    if (episode == null) {
      return null;
    }

    final context = _seriesContextOf(file, rootPath);
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
  static DirectoryInfo? _seriesContextOf(File file, String rootPath) {
    final parent = file.parent;
    if (_samePath(parent.path, rootPath)) {
      final rootInfo = parseDirectoryName(fileNameOf(rootPath));
      final usable =
          rootInfo.seasonNumber != null && rootInfo.seriesTitle.isNotEmpty;
      return usable ? rootInfo : null;
    }

    final parentInfo = parseDirectoryName(fileNameOf(parent.path));
    if (parentInfo.isPureSeason) {
      final grandInfo = parseDirectoryName(fileNameOf(parent.parent.path));
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

  static bool _samePath(String a, String b) {
    String normalize(String path) {
      var normalized = path.replaceAll('\\', '/').toLowerCase();
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      return normalized;
    }

    return normalize(a) == normalize(b);
  }

  static String fileNameOf(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  static String extensionOf(String path) {
    final fileName = fileNameOf(path);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
