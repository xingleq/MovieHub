import 'dart:convert';
import 'dart:io';

import '../system/platform_services.dart';
import 'media_item.dart';

class MediaLibrarySnapshot {
  const MediaLibrarySnapshot({required this.roots, required this.items});

  final List<String> roots;
  final List<MediaItem> items;

  static const empty = MediaLibrarySnapshot(roots: [], items: []);
}

/// Persistence contract for the media library.
///
/// [save] replaces the whole library (scan results, migration). Everyday
/// single-item mutations — favorite, playback progress, metadata match —
/// must go through [upsertItems] so implementations can write just the
/// touched rows instead of rewriting the library.
abstract interface class MediaLibraryStorage {
  Future<MediaLibrarySnapshot> load();

  /// Full replace: persists exactly [snapshot], removing absent items.
  Future<void> save(MediaLibrarySnapshot snapshot);

  /// Writes only [items] (keyed by source id + path), leaving every other row
  /// untouched.
  Future<void> upsertItems(Iterable<MediaItem> items);

  /// Replaces the media root list without touching items.
  Future<void> saveRoots(List<String> roots);
}

/// Read-only view of the pre-SQLite JSON library file. Kept solely as the
/// migration source for [MediaLibrarySqliteStore]; new writes never land here.
class MediaLibraryStore {
  MediaLibraryStore({Directory? storageDirectory})
    : _storageDirectory =
          storageDirectory ?? PlatformServices.instance.paths.appDataDirectory;

  final Directory _storageDirectory;

  /// Public so the SQLite store can migrate and archive the legacy file.
  File get storageFile {
    return File(
      '${_storageDirectory.path}${Platform.pathSeparator}moviehub_library.json',
    );
  }

  Future<MediaLibrarySnapshot> load() async {
    final file = storageFile;
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
}
