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
    required this.tmdbId,
    required this.tmdbTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
  });

  final String path;
  final String title;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime addedAt;
  final bool favorite;
  final int? tmdbId;
  final String? tmdbTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double? voteAverage;

  factory MediaItem.fromFile(File file, {DateTime? addedAt}) {
    final stat = file.statSync();
    final fileName = file.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    return MediaItem(
      path: file.path,
      title: _cleanTitle(rawTitle),
      extension: extension.toLowerCase(),
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      addedAt: addedAt ?? DateTime.now(),
      favorite: false,
      tmdbId: null,
      tmdbTitle: null,
      overview: null,
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      voteAverage: null,
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
      tmdbId: json['tmdbId'] as int?,
      tmdbTitle: json['tmdbTitle'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
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
      'tmdbId': tmdbId,
      'tmdbTitle': tmdbTitle,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
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
      tmdbId: previous?.tmdbId ?? tmdbId,
      tmdbTitle: previous?.tmdbTitle ?? tmdbTitle,
      overview: previous?.overview ?? overview,
      posterPath: previous?.posterPath ?? posterPath,
      backdropPath: previous?.backdropPath ?? backdropPath,
      releaseDate: previous?.releaseDate ?? releaseDate,
      voteAverage: previous?.voteAverage ?? voteAverage,
    );
  }

  MediaItem copyWith({
    bool? favorite,
    int? tmdbId,
    String? tmdbTitle,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
  }) {
    return MediaItem(
      path: path,
      title: title,
      extension: extension,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      addedAt: addedAt,
      favorite: favorite ?? this.favorite,
      tmdbId: tmdbId ?? this.tmdbId,
      tmdbTitle: tmdbTitle ?? this.tmdbTitle,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
    );
  }

  static String _cleanTitle(String rawTitle) {
    final cleaned = rawTitle
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? rawTitle : cleaned;
  }
}
