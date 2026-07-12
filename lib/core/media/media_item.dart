import 'dart:io';

class MediaItem {
  const MediaItem({
    required this.path,
    required this.title,
    required this.extension,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.addedAt,
    required this.favorite,
    required this.seriesTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.tmdbId,
    required this.tmdbTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.tmdbMediaType,
    required this.genreIds,
    required this.genres,
    required this.directors,
    required this.cast,
    required this.runtimeMinutes,
    required this.playbackPositionMs,
    required this.playbackDurationMs,
    required this.lastPlayedAt,
  });

  final String path;
  final String title;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime addedAt;
  final bool favorite;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? tmdbId;
  final String? tmdbTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double? voteAverage;
  final String? tmdbMediaType;
  final List<int>? genreIds;
  final List<String>? genres;
  final List<String>? directors;
  final List<String>? cast;
  final int? runtimeMinutes;
  final int playbackPositionMs;
  final int playbackDurationMs;
  final DateTime? lastPlayedAt;

  bool get isEpisode {
    return seasonNumber != null && episodeNumber != null;
  }

  String? get episodeLabel {
    final season = seasonNumber;
    final episode = episodeNumber;
    if (season == null || episode == null) {
      return null;
    }
    return 'S${_twoDigits(season)}E${_twoDigits(episode)}';
  }

  double get playbackProgress {
    if (playbackDurationMs <= 0 || playbackPositionMs <= 0) {
      return 0;
    }
    return (playbackPositionMs / playbackDurationMs).clamp(0, 1).toDouble();
  }

  factory MediaItem.fromFile(File file, {DateTime? addedAt}) {
    final stat = file.statSync();
    final fileName = file.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    final episodeInfo = _parseEpisodeInfo(rawTitle);

    return MediaItem(
      path: file.path,
      title: episodeInfo == null
          ? _cleanTitle(rawTitle)
          : '${episodeInfo.seriesTitle} S${_twoDigits(episodeInfo.seasonNumber)}E${_twoDigits(episodeInfo.episodeNumber)}',
      extension: extension.toLowerCase(),
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      addedAt: addedAt ?? DateTime.now(),
      favorite: false,
      seriesTitle: episodeInfo?.seriesTitle,
      seasonNumber: episodeInfo?.seasonNumber,
      episodeNumber: episodeInfo?.episodeNumber,
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

  factory MediaItem.fromJson(Map<String, Object?> json) {
    return MediaItem(
      path: json['path'] as String,
      title: json['title'] as String,
      extension: json['extension'] as String,
      sizeBytes: json['sizeBytes'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      addedAt: DateTime.parse(json['addedAt'] as String),
      favorite: json['favorite'] as bool? ?? false,
      seriesTitle: json['seriesTitle'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      tmdbId: json['tmdbId'] as int?,
      tmdbTitle: json['tmdbTitle'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      tmdbMediaType: json['tmdbMediaType'] as String?,
      genreIds: (json['genreIds'] as List<Object?>?)
          ?.whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      genres: (json['genres'] as List<Object?>?)?.whereType<String>().toList(),
      directors: (json['directors'] as List<Object?>?)
          ?.whereType<String>()
          .toList(),
      cast: (json['cast'] as List<Object?>?)?.whereType<String>().toList(),
      runtimeMinutes: json['runtimeMinutes'] as int?,
      playbackPositionMs: json['playbackPositionMs'] as int? ?? 0,
      playbackDurationMs: json['playbackDurationMs'] as int? ?? 0,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.parse(json['lastPlayedAt'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'title': title,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'modifiedAt': modifiedAt.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'favorite': favorite,
      'seriesTitle': seriesTitle,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'tmdbId': tmdbId,
      'tmdbTitle': tmdbTitle,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
      'tmdbMediaType': tmdbMediaType,
      'genreIds': genreIds,
      'genres': genres,
      'directors': directors,
      'cast': cast,
      'runtimeMinutes': runtimeMinutes,
      'playbackPositionMs': playbackPositionMs,
      'playbackDurationMs': playbackDurationMs,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }

  MediaItem preserveAddedAt(MediaItem? previous) {
    return MediaItem(
      path: path,
      title: title,
      extension: extension,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      addedAt: previous?.addedAt ?? addedAt,
      favorite: previous?.favorite ?? favorite,
      seriesTitle: seriesTitle,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      tmdbId: previous?.tmdbId ?? tmdbId,
      tmdbTitle: previous?.tmdbTitle ?? tmdbTitle,
      overview: previous?.overview ?? overview,
      posterPath: previous?.posterPath ?? posterPath,
      backdropPath: previous?.backdropPath ?? backdropPath,
      releaseDate: previous?.releaseDate ?? releaseDate,
      voteAverage: previous?.voteAverage ?? voteAverage,
      tmdbMediaType: previous?.tmdbMediaType ?? tmdbMediaType,
      genreIds: previous?.genreIds ?? genreIds,
      genres: previous?.genres ?? genres,
      directors: previous?.directors ?? directors,
      cast: previous?.cast ?? cast,
      runtimeMinutes: previous?.runtimeMinutes ?? runtimeMinutes,
      playbackPositionMs: previous?.playbackPositionMs ?? playbackPositionMs,
      playbackDurationMs: previous?.playbackDurationMs ?? playbackDurationMs,
      lastPlayedAt: previous?.lastPlayedAt ?? lastPlayedAt,
    );
  }

  MediaItem copyWith({
    bool? favorite,
    String? seriesTitle,
    int? seasonNumber,
    int? episodeNumber,
    int? tmdbId,
    String? tmdbTitle,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
    String? tmdbMediaType,
    List<int>? genreIds,
    List<String>? genres,
    List<String>? directors,
    List<String>? cast,
    int? runtimeMinutes,
    int? playbackPositionMs,
    int? playbackDurationMs,
    DateTime? lastPlayedAt,
  }) {
    return MediaItem(
      path: path,
      title: title,
      extension: extension,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      addedAt: addedAt,
      favorite: favorite ?? this.favorite,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      tmdbId: tmdbId ?? this.tmdbId,
      tmdbTitle: tmdbTitle ?? this.tmdbTitle,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      tmdbMediaType: tmdbMediaType ?? this.tmdbMediaType,
      genreIds: genreIds ?? this.genreIds,
      genres: genres ?? this.genres,
      directors: directors ?? this.directors,
      cast: cast ?? this.cast,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      playbackDurationMs: playbackDurationMs ?? this.playbackDurationMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  static String _cleanTitle(String rawTitle) {
    final cleaned = rawTitle
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? rawTitle : cleaned;
  }

  static _EpisodeInfo? _parseEpisodeInfo(String rawTitle) {
    final normalized = rawTitle.replaceAll(RegExp(r'[._]+'), ' ');
    final patterns = [
      RegExp(r'\bS(\d{1,2})E(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match == null) {
        continue;
      }

      final season = int.tryParse(match.group(1)!);
      final episode = int.tryParse(match.group(2)!);
      if (season == null || episode == null) {
        continue;
      }

      final titlePart = normalized.substring(0, match.start);
      final seriesTitle = _cleanTitle(titlePart);
      if (seriesTitle.isEmpty) {
        continue;
      }

      return _EpisodeInfo(
        seriesTitle: seriesTitle,
        seasonNumber: season,
        episodeNumber: episode,
      );
    }

    return null;
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _EpisodeInfo {
  const _EpisodeInfo({
    required this.seriesTitle,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  final String seriesTitle;
  final int seasonNumber;
  final int episodeNumber;
}
