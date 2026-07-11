import 'dart:io';

class MediaItem {
  const MediaItem({
    required this.path,
    required this.title,
    required this.extension,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.addedAt,
  });

  final String path;
  final String title;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime addedAt;

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
