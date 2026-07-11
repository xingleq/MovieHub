import 'dart:convert';
import 'dart:io';

import 'media_item.dart';

class MediaLibrarySnapshot {
  const MediaLibrarySnapshot({required this.roots, required this.items});

  final List<String> roots;
  final List<MediaItem> items;

  static const empty = MediaLibrarySnapshot(roots: [], items: []);
}

class MediaLibraryStore {
  MediaLibraryStore({Directory? storageDirectory})
    : _storageDirectory = storageDirectory ?? _defaultStorageDirectory();

  final Directory _storageDirectory;

  File get _storageFile {
    return File(
      '${_storageDirectory.path}${Platform.pathSeparator}moviehub_library.json',
    );
  }

  Future<MediaLibrarySnapshot> load() async {
    final file = _storageFile;
    if (!await file.exists()) {
      return MediaLibrarySnapshot.empty;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return MediaLibrarySnapshot.empty;
    }

    final json = jsonDecode(content) as Map<String, Object?>;
    final roots = (json['roots'] as List<Object?>? ?? [])
        .whereType<String>()
        .toList(growable: false);
    final items = (json['items'] as List<Object?>? ?? [])
        .whereType<Map<String, Object?>>()
        .map(MediaItem.fromJson)
        .toList(growable: false);

    return MediaLibrarySnapshot(roots: roots, items: items);
  }

  Future<void> save(MediaLibrarySnapshot snapshot) async {
    if (!await _storageDirectory.exists()) {
      await _storageDirectory.create(recursive: true);
    }

    final payload = {
      'roots': snapshot.roots,
      'items': snapshot.items.map((item) => item.toJson()).toList(),
    };

    await _storageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  static Directory _defaultStorageDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}MovieHub');
    }

    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory('$home${Platform.pathSeparator}.moviehub');
  }
}
