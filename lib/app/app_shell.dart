import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/media/media_item.dart';
import '../theme/app_tokens.dart';
import '../ui/catalog/media_category.dart';
import '../ui/detail/media_detail_view.dart';
import '../ui/format/formatters.dart';
import '../ui/pages/catalog_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/player/player_page.dart';
import 'app_section.dart';
import 'library_controller.dart';
import 'library_scope.dart';

/// Persistent shell: navigation rail on the left, the active section (or the
/// detail overlay) on the right. Owns the [LibraryController] lifecycle and
/// the ephemeral navigation state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LibraryController _controller;
  var _section = AppSection.home;
  String? _detailPath;

  @override
  void initState() {
    super.initState();
    _controller = LibraryController();
    unawaited(_controller.loadAppState());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToSection(AppSection section) {
    setState(() {
      _section = section;
      _detailPath = null;
    });
  }

  void _openDetail(MediaItem item) {
    setState(() {
      _detailPath = item.path;
    });
  }

  void _closeDetail() {
    setState(() {
      _detailPath = null;
    });
  }

  Future<void> _openPlayer(MediaItem item) async {
    Duration? startAt;
    final canResume =
        item.playbackPositionMs > 5000 &&
        item.playbackProgress > 0.01 &&
        item.playbackProgress < 0.95;

    if (canResume) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => _ResumeDialog(item: item),
      );
      if (resume == null) {
        return;
      }
      if (resume) {
        startAt = Duration(milliseconds: item.playbackPositionMs);
      }
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          item: item,
          startAt: startAt,
          nextEpisodeOf: _controller.nextEpisodeOf,
          onProgressChanged: _controller.savePlaybackProgress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return LibraryScope(
      controller: _controller,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (_controller.backgroundImagePath.isNotEmpty)
                  _WallpaperLayer(path: _controller.backgroundImagePath),
                Row(
                  children: [
                    _buildRail(tokens),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: tokens.cardBorder,
                    ),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRail(AppTokens tokens) {
    return NavigationRail(
      backgroundColor: _controller.backgroundImagePath.isEmpty
          ? null
          : Colors.transparent,
      selectedIndex: _section.index,
      onDestinationSelected: (index) {
        _goToSection(AppSection.values[index]);
      },
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: Icon(Icons.play_circle_fill, color: tokens.accent, size: 34),
      ),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('首页'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: Text('动画'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie_rounded),
          label: Text('电影'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.tv_outlined),
          selectedIcon: Icon(Icons.tv_rounded),
          label: Text('电视剧'),
        ),
        NavigationRailDestination(
          icon: Badge.count(
            count: _controller.favoriteCount,
            isLabelVisible: _controller.favoriteCount > 0,
            child: const Icon(Icons.favorite_outline),
          ),
          selectedIcon: const Icon(Icons.favorite_rounded),
          label: const Text('收藏'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('设置'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detailPath = _detailPath;
    final detailItem = detailPath == null
        ? null
        : _controller.itemByPath(detailPath);

    final busy = _controller.scanning || _controller.metadataBatchRunning;

    return Column(
      children: [
        if (busy)
          LinearProgressIndicator(
            minHeight: 2,
            value:
                _controller.metadataBatchRunning &&
                    _controller.metadataBatchTotal > 0
                ? _controller.metadataBatchDone / _controller.metadataBatchTotal
                : null,
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppDurations.fade,
            child: detailItem != null
                ? KeyedSubtree(
                    key: ValueKey('detail:${detailItem.path}'),
                    child: MediaDetailView(
                      item: detailItem,
                      loadingMetadata:
                          detailItem.path == _controller.metadataLoadingPath,
                      onBack: _closeDetail,
                      onToggleFavorite: _controller.toggleFavorite,
                      onMatchTmdb: _controller.matchTmdb,
                      onPlay: _openPlayer,
                      onOpenLocation: _controller.openItemLocation,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('sections'),
                    child: IndexedStack(
                      index: _section.index,
                      children: [
                        HomePage(
                          onOpenDetail: _openDetail,
                          onPlay: _openPlayer,
                          onGoToSettings: () {
                            _goToSection(AppSection.settings);
                          },
                        ),
                        CatalogPage(
                          title: '动画乐园',
                          predicate: isAnimeSection,
                          emptyMessage: '匹配 TMDB 后，动画片会自动住进这里哦。',
                          onOpenDetail: _openDetail,
                          onPlay: _openPlayer,
                        ),
                        CatalogPage(
                          title: '电影',
                          predicate: isMovieSection,
                          emptyMessage: '扫描并匹配 TMDB 后，电影会出现在这里。',
                          onOpenDetail: _openDetail,
                          onPlay: _openPlayer,
                        ),
                        CatalogPage(
                          title: '电视剧',
                          predicate: isTvSection,
                          emptyMessage: '识别到季集信息或匹配为剧集的影片会出现在这里。',
                          onOpenDetail: _openDetail,
                          onPlay: _openPlayer,
                        ),
                        CatalogPage(
                          title: '我的收藏',
                          predicate: (item) => item.favorite,
                          emptyMessage: '在详情页点击收藏，影片会出现在这里。',
                          onOpenDetail: _openDetail,
                          onPlay: _openPlayer,
                        ),
                        const SettingsPage(),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Full-window wallpaper picked by the user, dimmed and slightly blurred so
/// content stays readable on top.
class _WallpaperLayer extends StatelessWidget {
  const _WallpaperLayer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: tokens.background),
          ),
        ),
        ColoredBox(color: tokens.background.withValues(alpha: 0.72)),
      ],
    );
  }
}

/// todo §14: on reopening a partially watched item, ask whether to resume or
/// restart. Pops true to resume, false to restart, null when dismissed.
class _ResumeDialog extends StatelessWidget {
  const _ResumeDialog({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final position = Duration(milliseconds: item.playbackPositionMs);
    final remaining = Duration(
      milliseconds: (item.playbackDurationMs - item.playbackPositionMs)
          .clamp(0, item.playbackDurationMs)
          .toInt(),
    );

    return AlertDialog(
      title: const Text('继续观看？'),
      content: Text(
        '《${item.tmdbTitle ?? item.title}》上次看到 '
        '${formatDuration(position)}，剩余 ${formatDuration(remaining)}。',
        style: TextStyle(color: tokens.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('从头播放'),
        ),
        FilledButton.icon(
          autofocus: true,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('继续播放'),
        ),
      ],
    );
  }
}
