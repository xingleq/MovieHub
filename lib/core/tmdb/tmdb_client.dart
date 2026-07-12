import 'dart:convert';
import 'dart:async';
import 'dart:io';

class TmdbMovieMatch {
  const TmdbMovieMatch({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.mediaType,
    required this.genreIds,
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final String mediaType;
  final List<int> genreIds;

  factory TmdbMovieMatch.fromJson(Map<String, Object?> json) {
    final mediaType = json['media_type'] as String? ?? 'movie';
    return TmdbMovieMatch(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? '') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: (json['release_date'] ?? json['first_air_date']) as String?,
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
      mediaType: mediaType,
      genreIds: (json['genre_ids'] as List<Object?>? ?? [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
    );
  }
}

/// Extended metadata fetched from the details endpoint after a match:
/// localized genre names, directors, top cast, and runtime.
class TmdbDetails {
  const TmdbDetails({
    required this.genreIds,
    required this.genres,
    required this.directors,
    required this.cast,
    required this.runtimeMinutes,
  });

  final List<int> genreIds;
  final List<String> genres;
  final List<String> directors;
  final List<String> cast;
  final int? runtimeMinutes;
}

class TmdbClient {
  Future<TmdbMovieMatch?> searchMovie({
    required String accessToken,
    required String query,
    required String proxy,
  }) async {
    final candidates = _queryCandidates(query);
    if (accessToken.trim().isEmpty || candidates.isEmpty) {
      return null;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..findProxy = (uri) => _findProxy(uri, proxy);
    try {
      for (final candidate in candidates) {
        final match = await _searchMulti(
          client: client,
          accessToken: accessToken,
          query: candidate,
        );
        if (match != null) {
          return match;
        }
      }
      return null;
    } on TimeoutException {
      throw const TmdbNetworkException(
        '连接 TMDB 超时。请检查网络，或在 TMDB 设置里填写本机代理，例如 127.0.0.1:7890。',
      );
    } on SocketException catch (error) {
      throw TmdbNetworkException('无法连接 TMDB：${error.message}。请检查网络，或配置本机代理。');
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches genres, credits and runtime for a matched item. Failures return
  /// null so the basic match still succeeds without the extra metadata.
  Future<TmdbDetails?> fetchDetails({
    required String accessToken,
    required int id,
    required String mediaType,
    required String proxy,
  }) async {
    if (accessToken.trim().isEmpty) {
      return null;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..findProxy = (uri) => _findProxy(uri, proxy);
    try {
      final type = mediaType == 'tv' ? 'tv' : 'movie';
      final uri = Uri.https('api.themoviedb.org', '/3/$type/$id', {
        'language': 'zh-CN',
        'append_to_response': 'credits',
      });

      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${accessToken.trim()}',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(body) as Map<String, Object?>;

      final genreEntries = (payload['genres'] as List<Object?>? ?? [])
          .whereType<Map<String, Object?>>()
          .toList();
      final genreIds = genreEntries
          .map((entry) => (entry['id'] as num?)?.toInt())
          .whereType<int>()
          .toList(growable: false);
      final genres = genreEntries
          .map((entry) => entry['name'] as String?)
          .whereType<String>()
          .toList(growable: false);

      final credits = payload['credits'] as Map<String, Object?>? ?? {};
      final cast = (credits['cast'] as List<Object?>? ?? [])
          .whereType<Map<String, Object?>>()
          .map((entry) => entry['name'] as String?)
          .whereType<String>()
          .take(8)
          .toList(growable: false);

      var directors = <String>[];
      if (type == 'movie') {
        directors = (credits['crew'] as List<Object?>? ?? [])
            .whereType<Map<String, Object?>>()
            .where((entry) => entry['job'] == 'Director')
            .map((entry) => entry['name'] as String?)
            .whereType<String>()
            .toList(growable: false);
      } else {
        directors = (payload['created_by'] as List<Object?>? ?? [])
            .whereType<Map<String, Object?>>()
            .map((entry) => entry['name'] as String?)
            .whereType<String>()
            .toList(growable: false);
      }

      int? runtimeMinutes;
      if (type == 'movie') {
        runtimeMinutes = (payload['runtime'] as num?)?.toInt();
      } else {
        final runTimes = (payload['episode_run_time'] as List<Object?>? ?? [])
            .whereType<num>()
            .toList();
        runtimeMinutes = runTimes.isEmpty ? null : runTimes.first.toInt();
      }

      return TmdbDetails(
        genreIds: genreIds,
        genres: genres,
        directors: directors,
        cast: cast,
        runtimeMinutes: runtimeMinutes == null || runtimeMinutes <= 0
            ? null
            : runtimeMinutes,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<TmdbMovieMatch?> _searchMulti({
    required HttpClient client,
    required String accessToken,
    required String query,
  }) async {
    final uri = Uri.https('api.themoviedb.org', '/3/search/multi', {
      'query': query,
      'language': 'zh-CN',
      'include_adult': 'false',
      'page': '1',
    });

    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 10));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${accessToken.trim()}',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TmdbException(
        'TMDB 请求失败：HTTP ${response.statusCode}',
        response.statusCode,
        body,
      );
    }

    final payload = jsonDecode(body) as Map<String, Object?>;
    final results = payload['results'] as List<Object?>? ?? [];
    for (final result in results.whereType<Map<String, Object?>>()) {
      final mediaType = result['media_type'] as String?;
      if (mediaType == 'movie' || mediaType == 'tv') {
        return TmdbMovieMatch.fromJson(result);
      }
    }
    return null;
  }

  static List<String> _queryCandidates(String rawQuery) {
    final clean = rawQuery
        .replaceAll(RegExp(r'[\[\]【】()（）{}]'), ' ')
        .replaceAll(RegExp(r'\bS\d{1,2}E\d{1,3}\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}x\d{1,3}\b', caseSensitive: false), ' ')
        .replaceAll(
          RegExp(
            r'\b(720p|1080p|2160p|4k|bluray|brrip|webrip|web-dl|x264|x265|h264|h265|hevc|aac|dts|hdr)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[._,，]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final candidates = <String>[];
    final englishMatches =
        RegExp(r'[A-Za-z][A-Za-z0-9]*(?:\s+[A-Za-z][A-Za-z0-9]*)*')
            .allMatches(clean)
            .map((match) => match.group(0)!.trim())
            .where((value) => value.length >= 3)
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    if (englishMatches.isNotEmpty) {
      candidates.add(englishMatches.first);
    }
    if (clean.isNotEmpty) {
      candidates.add(clean);
    }
    final original = rawQuery.trim();
    if (original.isNotEmpty) {
      candidates.add(original);
    }

    return candidates.toSet().toList(growable: false);
  }

  /// Resolves the proxy directive for [uri]: an explicit `host:port` setting
  /// wins, otherwise the system environment proxy. Shared with the image
  /// cache downloader.
  static String findProxy(Uri uri, String proxy) {
    final normalizedProxy = proxy.trim();
    if (normalizedProxy.isNotEmpty) {
      final proxyUri = normalizedProxy.contains('://')
          ? Uri.tryParse(normalizedProxy)
          : Uri.tryParse('http://$normalizedProxy');
      final host = proxyUri?.host;
      final port = proxyUri?.port;
      if (host != null && host.isNotEmpty && port != null && port > 0) {
        return 'PROXY $host:$port';
      }
    }

    return HttpClient.findProxyFromEnvironment(
      uri,
      environment: Platform.environment,
    );
  }

  static String _findProxy(Uri uri, String proxy) => findProxy(uri, proxy);

  static String posterUrl(String posterPath) {
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  static String backdropUrl(String backdropPath) {
    return 'https://image.tmdb.org/t/p/w780$backdropPath';
  }

  static String backdropUrlLarge(String backdropPath) {
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }
}

class TmdbException implements Exception {
  const TmdbException(this.message, this.statusCode, this.body);

  final String message;
  final int statusCode;
  final String body;

  @override
  String toString() {
    return message;
  }
}

class TmdbNetworkException implements Exception {
  const TmdbNetworkException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
