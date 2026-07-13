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

      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !isVideoPath(entity.path)) {
          continue;
        }

        try {
          scannedByPath[entity.path.toLowerCase()] = _itemFromFile(entity);
        } on FileSystemException {
          skippedPaths.add(entity.path);
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

  static MediaItem _itemFromFile(File file) {
    final stat = file.statSync();
    final fileName = fileNameOf(file.path);
    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    final parsed = parseFileName(rawTitle);

    return MediaItem(
      path: file.path,
      title: parsed.title,
      extension: extension.toLowerCase(),
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      addedAt: DateTime.now(),
      favorite: false,
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
