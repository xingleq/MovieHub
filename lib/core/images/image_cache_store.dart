import 'dart:io';

import '../tmdb/tmdb_client.dart';

/// Disk cache for TMDB artwork (todo §20 海报本地缓存). Images are downloaded
/// once into `%APPDATA%/MovieHub/images` and served from disk afterwards, so
/// posters survive offline starts and never re-fetch on rebuilds.
class ImageCacheStore {
  ImageCacheStore._();

  static final ImageCacheStore instance = ImageCacheStore._();

  /// Proxy setting shared with the TMDB client; kept in sync by the
  /// library controller when settings load or change.
  String proxy = '';

  Directory? _directory;
  final _resolved = <String, File>{};
  final _inFlight = <String, Future<File?>>{};

  Directory get _cacheDirectory {
    return _directory ??= _defaultCacheDirectory();
  }

  /// Returns the cached file immediately when this URL has already been
  /// resolved this session (lets widgets render synchronously, no flicker).
  File? cachedFileSync(String url) {
    return _resolved[url];
  }

  /// Returns the local file for [url], downloading it on first use.
  /// Returns null when the download fails (caller shows a placeholder;
  /// a later session retries).
  Future<File?> resolve(String url) {
    final known = _resolved[url];
    if (known != null) {
      return Future.value(known);
    }
    return _inFlight.putIfAbsent(url, () async {
      try {
        final file = await _resolveUncached(url);
        if (file != null) {
          _resolved[url] = file;
        }
        return file;
      } finally {
        _inFlight.remove(url);
      }
    });
  }

  Future<File?> _resolveUncached(String url) async {
    final file = _fileFor(url);
    if (file == null) {
      return null;
    }
    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    try {
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..findProxy = (uri) => TmdbClient.findProxy(uri, proxy);
      try {
        final request = await client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          return null;
        }

        final tempFile = File('${file.path}.tmp');
        await response.pipe(tempFile.openWrite());
        await tempFile.rename(file.path);
        return file;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// Stable cache filename derived from the URL's size bucket and image name,
  /// e.g. `.../t/p/w500/abc123.jpg` → `w500_abc123.jpg`.
  File? _fileFor(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const [];
    if (segments.length < 2) {
      return null;
    }
    final sizeBucket = segments[segments.length - 2];
    final imageName = segments.last;
    final safeName = '${sizeBucket}_$imageName'.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return File('${_cacheDirectory.path}${Platform.pathSeparator}$safeName');
  }

  static Directory _defaultCacheDirectory() {
    final appData = Platform.environment['APPDATA'];
    final base = appData != null && appData.trim().isNotEmpty
        ? '$appData${Platform.pathSeparator}MovieHub'
        : '${Platform.environment['USERPROFILE'] ?? Directory.current.path}'
              '${Platform.pathSeparator}.moviehub';
    return Directory('$base${Platform.pathSeparator}images');
  }
}
