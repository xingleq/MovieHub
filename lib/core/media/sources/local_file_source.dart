import 'dart:io';
import 'dart:isolate';

import 'media_source.dart';

/// The built-in source: folders on this machine's filesystem, including
/// mapped network drives and UNC shares (`\\nas\share`). Paths are OS-native
/// and playable directly.
class LocalFileSource implements MediaSource {
  const LocalFileSource({this.caseSensitive = false});

  /// Windows local folders use false. A future case-sensitive local-filesystem
  /// port can opt in without changing scanner behavior.
  final bool caseSensitive;

  @override
  String get id => localMediaSourceId;

  /// Directory walking and per-file stats are blocking I/O, so the listing
  /// runs on a background isolate.
  @override
  Future<MediaSourceListing> listVideos(String rootPath) {
    return Isolate.run(() => listVideosSync(rootPath));
  }

  /// Synchronous walk, exposed for callers already off the UI isolate.
  ///
  /// Traverses with an explicit stack instead of `listSync(recursive:)`:
  /// the recursive form throws on the first unreadable subdirectory
  /// (permissions, dropped UNC share), which would abort the whole scan.
  /// Here an unreadable directory lands in [MediaSourceListing.skippedPaths]
  /// and the rest of the tree still gets scanned.
  static MediaSourceListing listVideosSync(String rootPath) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      return MediaSourceListing(entries: const [], skippedPaths: [rootPath]);
    }

    final entries = <MediaSourceEntry>[];
    final skippedPaths = <String>[];
    final pending = <Directory>[root];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      final List<FileSystemEntity> children;
      try {
        children = directory.listSync(followLinks: false);
      } on FileSystemException {
        skippedPaths.add(directory.path);
        continue;
      }
      for (final entity in children) {
        if (entity is Directory) {
          pending.add(entity);
          continue;
        }
        if (entity is! File || !isVideoFilePath(entity.path)) {
          continue;
        }
        try {
          final stat = entity.statSync();
          entries.add(
            MediaSourceEntry(
              path: entity.path,
              sizeBytes: stat.size,
              modifiedAt: stat.modified,
            ),
          );
        } on FileSystemException {
          skippedPaths.add(entity.path);
        }
      }
    }
    return MediaSourceListing(entries: entries, skippedPaths: skippedPaths);
  }

  @override
  String playbackUriOf(String path) => path;

  @override
  String identityKeyOf(String path) =>
      caseSensitive ? path : path.toLowerCase();
}
