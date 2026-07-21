import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/library_controller.dart';
import 'package:moviehub/app/library_scope.dart';
import 'package:moviehub/app/settings_controller.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_library_store.dart';
import 'package:moviehub/core/media/sources/media_source.dart';
import 'package:moviehub/theme/app_theme.dart';
import 'package:moviehub/ui/pages/home_page.dart';

class _MemoryLibraryStore implements MediaLibraryStorage {
  _MemoryLibraryStore(this.snapshot);

  MediaLibrarySnapshot snapshot;

  @override
  Future<MediaLibrarySnapshot> load() async => snapshot;

  @override
  Future<void> save(MediaLibrarySnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> saveRoots(List<String> roots) async {}

  @override
  Future<void> upsertItems(Iterable<MediaItem> items) async {}
}

void main() {
  testWidgets('首页卡片点击进详情，悬停播放按钮单独触发播放', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final item = _mediaItem();
    final settings = SettingsController();
    final library = LibraryController(
      settings: settings,
      store: _MemoryLibraryStore(
        MediaLibrarySnapshot(roots: const ['D:/Movies'], items: [item]),
      ),
    );
    addTearDown(() {
      library.dispose();
      settings.dispose();
    });
    await library.load();
    var detailOpens = 0;
    var plays = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: LibraryScope(
          controller: library,
          child: HomePage(
            onOpenItem: (_) => detailOpens++,
            onPlayItem: (_) => plays++,
            onGoToSettings: () {},
          ),
        ),
      ),
    );

    final poster = find.byKey(
      ValueKey('home-poster:${item.sourceId}:${item.path}'),
    );
    final playButton = find.byKey(
      ValueKey('home-play:${item.sourceId}:${item.path}'),
    );
    expect(poster, findsOneWidget);
    expect(tester.getSize(poster).width, 168);

    await tester.tap(poster);
    expect(detailOpens, 1);
    expect(plays, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(poster));
    await tester.pump(const Duration(milliseconds: 250));
    expect(playButton, findsOneWidget);

    await tester.tap(playButton);
    expect(detailOpens, 1);
    expect(plays, 1);
  });
}

MediaItem _mediaItem() {
  final now = DateTime(2026, 7, 20);
  return MediaItem(
    path: 'D:/Movies/test.mp4',
    sourceId: localMediaSourceId,
    title: '测试电影',
    extension: 'mp4',
    sizeBytes: 1024,
    modifiedAt: now,
    addedAt: now,
    favorite: false,
    following: false,
    seriesTitle: null,
    seasonNumber: null,
    episodeNumber: null,
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
