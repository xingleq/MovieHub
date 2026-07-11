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
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;

  factory TmdbMovieMatch.fromJson(Map<String, Object?> json) {
    return TmdbMovieMatch(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? '') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
    );
  }
}

class TmdbClient {
  Future<TmdbMovieMatch?> searchMovie({
    required String accessToken,
    required String query,
    required String proxy,
  }) async {
    final normalizedQuery = query.trim();
    if (accessToken.trim().isEmpty || normalizedQuery.isEmpty) {
      return null;
    }

    final uri = Uri.https('api.themoviedb.org', '/3/search/movie', {
      'query': normalizedQuery,
      'language': 'zh-CN',
      'include_adult': 'false',
      'page': '1',
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..findProxy = (uri) => _findProxy(uri, proxy);
    try {
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
        throw TmdbException(
          'TMDB 请求失败：HTTP ${response.statusCode}',
          response.statusCode,
          body,
        );
      }

      final payload = jsonDecode(body) as Map<String, Object?>;
      final results = payload['results'] as List<Object?>? ?? [];
      if (results.isEmpty) {
        return null;
      }

      return TmdbMovieMatch.fromJson(results.first as Map<String, Object?>);
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

  static String _findProxy(Uri uri, String proxy) {
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

  static String posterUrl(String posterPath) {
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  static String backdropUrl(String backdropPath) {
    return 'https://image.tmdb.org/t/p/w780$backdropPath';
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
