import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/media/media_group.dart';
import '../core/media/media_item.dart';
import '../core/tmdb/tmdb_client.dart';
import '../theme/app_tokens.dart';
import '../ui/catalog/media_category.dart';
import '../ui/detail/media_detail_view.dart';
import '../ui/detail/series_detail_view.dart';
import '../ui/format/formatters.dart';
import '../ui/pages/catalog_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/player/player_page.dart';
import '../ui/widgets/candy_background.dart';
import '../ui/widgets/capsule_nav.dart';
import '../ui/widgets/manual_match_dialog.dart';
import 'app_section.dart';
import 'library_controller.dart';
import 'library_scope.dart';

/// Persistent shell: candy background + capsule nav on the left, the active
/// section (or a movie/series detail overlay) on the right. Owns the
/// [LibraryController] lifecycle and the ephemeral navigation state.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LibraryController _controller;
  var _section = AppSection.home;
  String? _detailPath;
  String? _detailSeriesKey;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    unawaited(_controller.loadAppState());
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _goToSection(AppSection section) {
    setState(() {
      _section = section;
      _detailPath = null;
      _detailSeriesKey = null;
    });
  }

  void _openEntry(MediaGroup group) {
    setState(() {
      if (group.isSeries) {
        _detailSeriesKey = group.key;
        _detailPath = null;
      } else {
        _detailPath = group.episodes.first.path;
        _detailSeriesKey = null;
      }
    });
  }

  /// Opens detail for a single item; episodes route to their series view.
  void _openItem(MediaItem item) {
    final seriesTitle = item.seriesTitle;
    setState(() {
      if (item.isEpisode && seriesTitle != null && seriesTitle.isNotEmpty) {
        _detailSeriesKey = MediaGroup.seriesKey(seriesTitle);
        _detailPath = null;
      } else {
        _detailPath = item.path;
        _detailSeriesKey = null;
      }
    });
  }

  void _closeDetail() {
    setState(() {
      _detailPath = null;
      _detailSeriesKey = null;
    });
  }

  void _playEntry(MediaGroup group) {
    unawaited(_openPlayer(group.playTarget));
  }

  Future<void> _openPlayer(MediaItem item) async {
    // Auto-resume without asking: partially watched items pick up where they
    // left off; finished or barely-started ones play from the beginning.
    final canResume =
        item.playbackPositionMs > 5000 &&
        item.playbackProgress > 0.01 &&
        item.playbackProgress < 0.95;
    final startAt = canResume
        ? Duration(milliseconds: item.playbackPositionMs)
        : null;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          item: item,
          startAt: startAt,
          nextEpisodeOf: _controller.nextEpisodeOf,
          subtitlePreference: _controller.subtitlePreference,
          audioPreference: _controller.audioPreference,
          onProgressChanged: _controller.savePlaybackProgress,
        ),
      ),
    );
  }

  Future<void> _openManualMatch({
    required String initialQuery,
    required List<String> paths,
  }) async {
    final match = await showDialog<TmdbMovieMatch>(
      context: context,
      builder: (context) => ManualMatchDialog(
        initialQuery: initialQuery,
        onSearch: _controller.searchTmdbCandidates,
      ),
    );
    if (match == null || !mounted) {
      return;
    }
    await _controller.applyManualMatch(paths, match);
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
                const CandyBackground(),
                if (_controller.backgroundImagePath.isNotEmpty)
                  _WallpaperLayer(path: _controller.backgroundImagePath),
                Row(
                  children: [
                    CapsuleNav(
                      selectedIndex: _section.index,
                      onSelected: (index) {
                        _goToSection(AppSection.values[index]);
                      },
                      footer: _NavFooter(controller: _controller),
                      items: [
                        const CapsuleNavItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: '首页',
                        ),
                        const CapsuleNavItem(
                          icon: Icons.auto_awesome_outlined,
                          selectedIcon: Icons.auto_awesome,
                          label: '动画',
                        ),
                        const CapsuleNavItem(
                          icon: Icons.movie_outlined,
                          selectedIcon: Icons.movie_rounded,
                          label: '电影',
                        ),
                        const CapsuleNavItem(
                          icon: Icons.tv_outlined,
                          selectedIcon: Icons.tv_rounded,
                          label: '电视剧',
                        ),
                        CapsuleNavItem(
                          icon: Icons.favorite_outline,
                          selectedIcon: Icons.favorite_rounded,
                          label: '收藏',
                          badgeCount: _controller.favoriteCount,
                        ),
                        const CapsuleNavItem(
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings_rounded,
                          label: '设置',
                        ),
                      ],
                    ),
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

  Widget _buildContent() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildDetailOrSections(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailOrSections() {
    final seriesKey = _detailSeriesKey;
    if (seriesKey != null) {
      MediaGroup? group;
      for (final candidate in groupMediaItems(_controller.items)) {
        if (candidate.key == seriesKey) {
          group = candidate;
          break;
        }
      }
      if (group != null) {
        final loading =
            _controller.metadataLoadingPath != null &&
            group.paths.contains(_controller.metadataLoadingPath);
        return KeyedSubtree(
          key: ValueKey('series:$seriesKey'),
          child: SeriesDetailView(
            group: group,
            loadingMetadata: loading,
            onBack: _closeDetail,
            onPlayEpisode: (episode) => unawaited(_openPlayer(episode)),
            onMatch: _controller.matchGroup,
            onManualMatch: (group) {
              unawaited(
                _openManualMatch(
                  initialQuery: group.representative.seriesTitle ?? group.title,
                  paths: group.paths,
                ),
              );
            },
            onOpenLocation: _controller.openItemLocation,
          ),
        );
      }
    }

    final detailPath = _detailPath;
    final detailItem = detailPath == null
        ? null
        : _controller.itemByPath(detailPath);
    if (detailItem != null) {
      return KeyedSubtree(
        key: ValueKey('detail:${detailItem.path}'),
        child: MediaDetailView(
          item: detailItem,
          loadingMetadata: detailItem.path == _controller.metadataLoadingPath,
          onBack: _closeDetail,
          onToggleFavorite: _controller.toggleFavorite,
          onMatchTmdb: _controller.matchTmdb,
          onManualMatch: (item) {
            unawaited(
              _openManualMatch(initialQuery: item.title, paths: [item.path]),
            );
          },
          onPlay: (item) => unawaited(_openPlayer(item)),
          onOpenLocation: _controller.openItemLocation,
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('sections'),
      child: IndexedStack(
        index: _section.index,
        children: [
          for (final (index, page) in _sectionPages().indexed)
            _AnimatedSection(active: _section.index == index, child: page),
        ],
      ),
    );
  }

  List<Widget> _sectionPages() {
    return [
      HomePage(
        onOpenEntry: _openEntry,
        onOpenItem: _openItem,
        onPlayEntry: _playEntry,
        onPlayItem: (item) => unawaited(_openPlayer(item)),
        onGoToSettings: () {
          _goToSection(AppSection.settings);
        },
      ),
      CatalogPage(
        title: '动画乐园',
        groupFilter: isAnimeGroup,
        emptyMessage: '匹配 TMDB 后，动画片会自动住进这里哦。',
        onOpenEntry: _openEntry,
        onPlayEntry: _playEntry,
      ),
      CatalogPage(
        title: '电影',
        groupFilter: isMovieGroup,
        emptyMessage: '扫描并匹配 TMDB 后，电影会出现在这里。',
        onOpenEntry: _openEntry,
        onPlayEntry: _playEntry,
      ),
      CatalogPage(
        title: '电视剧',
        groupFilter: isTvGroup,
        emptyMessage: '识别到季集信息或匹配为剧集的影片会出现在这里。',
        onOpenEntry: _openEntry,
        onPlayEntry: _playEntry,
      ),
      CatalogPage(
        title: '我的收藏',
        groupFilter: isFavoriteGroup,
        emptyMessage: '在详情页点击收藏，影片会出现在这里。',
        onOpenEntry: _openEntry,
        onPlayEntry: _playEntry,
      ),
      const SettingsPage(),
    ];
  }
}

/// Replays a quick fade/slide when its section becomes the active one, so
/// switching rail sections feels animated while IndexedStack keeps each
/// page's state (search, sort, scroll) alive.
class _AnimatedSection extends StatefulWidget {
  const _AnimatedSection({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.active ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_AnimatedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: widget.child,
      ),
    );
  }
}

/// Library size summary shown at the bottom of the side navigation.
class _NavFooter extends StatelessWidget {
  const _NavFooter({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final totalSize = controller.items.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes,
    );
    if (controller.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Visual progress against a 2TB reference so the bar looks like the design.
    const twoTb = 2.0 * 1024 * 1024 * 1024 * 1024;
    final progress = (totalSize / twoTb).clamp(0.02, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '存储空间',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: tokens.surfaceVariant,
                    color: tokens.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatBytes(totalSize)} / 2.00 TB',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ],
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
