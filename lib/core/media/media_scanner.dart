import 'dart:io';

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

  Future<MediaScanResult> scanRoots(
    List<String> roots, {
    List<MediaItem> existingItems = const [],
  }) async {
    final previousByPath = {
      for (final item in existingItems) item.path.toLowerCase(): item,
    };
    final scannedByPath = <String, MediaItem>{};
    final skippedPaths = <String>[];

    for (final rootPath in roots) {
      final directory = Directory(rootPath);
      if (!await directory.exists()) {
        skippedPaths.add(rootPath);
        continue;
      }

      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !isVideoPath(entity.path)) {
          continue;
        }

        try {
          final item = MediaItem.fromFile(entity);
          final key = item.path.toLowerCase();
          scannedByPath[key] = item.preserveAddedAt(previousByPath[key]);
        } on FileSystemException {
          skippedPaths.add(entity.path);
        }
      }
    }

    final items = scannedByPath.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return MediaScanResult(items: items, skippedPaths: skippedPaths);
  }

  static bool isVideoPath(String path) {
    final extension = extensionOf(path);
    return videoExtensions.contains(extension);
  }

  static String extensionOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
