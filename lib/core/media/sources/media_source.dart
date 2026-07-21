/// Where media files come from. `LocalFileSource` covers folders on this
/// machine (including mounted NAS drives and UNC shares); NAS/WebDAV/网盘
/// sources implement the same contract later.
///
/// Everything downstream — filename parsing, episode inference, TMDB
/// matching, playback progress — only ever sees source paths and the data
/// in [MediaSourceEntry], so it works unchanged for any source.
abstract interface class MediaSource {
  /// Stable identifier persisted with every item ([MediaItem.sourceId]).
  String get id;

  /// Enumerates every video file under [rootPath]. Never throws for an
  /// unreadable root or file — those land in [MediaSourceListing.skippedPaths].
  Future<MediaSourceListing> listVideos(String rootPath);

  /// What the player actually opens for [path]: local files play by path;
  /// remote sources return a streamable URL. Must stay cheap and
  /// synchronous — auth handshakes belong in the implementation's own
  /// lifecycle, not here.
  String playbackUriOf(String path);

  /// Canonical form of [path] for identity comparisons — scan carry-over
  /// and move detection key on it. Case-insensitive sources (Windows
  /// filesystems) fold case; case-sensitive sources return [path]
  /// unchanged. Must be a pure function that preserves path structure
  /// ([fileNameOf] etc. still work on the result).
  String identityKeyOf(String path);
}

/// Identifier of the built-in local-folders source. Also the backfill value
/// for items persisted before `MediaItem.sourceId` existed.
const String localMediaSourceId = 'local';

/// One video file enumerated from a source. Plain sendable data — listings
/// cross isolate boundaries.
class MediaSourceEntry {
  const MediaSourceEntry({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// Source-native path (local: absolute OS path; remote: path within the
  /// source). Separators may be `/` or `\` — the helpers below accept both.
  final String path;

  final int sizeBytes;
  final DateTime modifiedAt;
}

/// Result of enumerating one root.
class MediaSourceListing {
  const MediaSourceListing({required this.entries, required this.skippedPaths});

  final List<MediaSourceEntry> entries;

  /// Roots or files that could not be read.
  final List<String> skippedPaths;
}

/// File extensions treated as video, shared by every source implementation.
const Set<String> videoFileExtensions = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'flv',
  'ts',
  'm2ts',
};

bool isVideoFilePath(String path) {
  return videoFileExtensions.contains(fileExtensionOf(path));
}

String fileNameOf(String path) {
  return path.replaceAll('\\', '/').split('/').last;
}

String fileExtensionOf(String path) {
  final fileName = fileNameOf(path);
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) {
    return '';
  }
  return fileName.substring(dotIndex + 1).toLowerCase();
}

/// Parent of a source path, keeping the original separators. Filesystem
/// roots keep their trailing separator (`D:\`, `/`) so their "name" stays
/// empty, matching dart:io `Directory.parent` semantics.
String parentPathOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return path;
  }
  final isRootCut = index == 0 || (index == 2 && normalized[1] == ':');
  return path.substring(0, isRootCut ? index + 1 : index);
}
