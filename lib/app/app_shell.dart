import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/media/media_group.dart';
import '../core/media/media_item.dart';
import '../theme/app_tokens.dart';
import '../ui/catalog/media_category.dart';
import '../ui/detail/media_detail_view.dart';
import '../ui/detail/series_detail_view.dart';
import '../ui/format/formatters.dart';
import '../ui/pages/catalog_page.dart';
import '../ui/pages/gacha_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/player/player_page.dart';
import '../ui/widgets/candy_background.dart';
import '../ui/widgets/capsule_nav.dart';
import '../ui/widgets/manual_match_dialog.dart';
import '../ui/widgets/window_control_buttons.dart';
import 'app_section.dart';
import 'library_controller.dart';
import 'library_scope.dart';
import 'settings_controller.dart';
import 'settings_scope.dart';

/// Persistent shell: candy background + capsule nav on the left, the active
/// section (or a movie/series detail overlay) on the right. Owns the
/// ephemeral navigation state; the controllers are created in [MovieHubApp].
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.library, required this.settings});

  final LibraryController library;
  final SettingsController settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final LibraryController _library;
  late final SettingsController _settings;
  var _section = AppSection.home;
  String? _detailPath;
  String? _detailSeriesKey;
  MediaItem? _playerItem;
  Duration? _playerStartAt;
  var _playerToken = 0;
  var _playerCompact = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _library = widget.library;
    _settings = widget.settings;
    unawaited(_loadControllers());
  }

  Future<void> _loadControllers() async {
    await _settings.load();
    await _library.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_settings.refreshScreenTimeState());
    }
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
        _detailSeriesKey = MediaGroup.keyOf(item);
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
    final allowed = await _settings.startViewingSession();
    if (!mounted) {
      return;
    }
    if (!allowed) {
      final message = _settings.error;
      if (!_settings.breakActive && message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    // Auto-resume without asking: partially watched items pick up where they
    // left off; finished or barely-started ones play from the beginning.
    final canResume =
        item.playbackPositionMs > 5000 &&
        item.playbackProgress > 0.01 &&
        item.playbackProgress < 0.95;
    final startAt = canResume
        ? Duration(milliseconds: item.playbackPositionMs)
        : null;

    setState(() {
      _playerItem = item;
      _playerStartAt = startAt;
      _playerCompact = false;
      _playerToken++;
    });
  }

  void _closePlayer() {
    setState(() {
      _playerItem = null;
      _playerStartAt = null;
      _playerCompact = false;
      _playerToken++;
    });
  }

  Future<void> _openManualMatch({
    required String initialQuery,
    required List<String> paths,
  }) async {
    final result = await showDialog<ManualMatchResult>(
      context: context,
      builder: (context) => ManualMatchDialog(
        initialQuery: initialQuery,
        onSearch: _library.searchTmdbCandidates,
        onFetchSeasons: _library.fetchTmdbSeasons,
        onFetchEpisodes: _library.fetchTmdbEpisodes,
        allowEpisodeSelection: paths.length == 1,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _library.applyManualMatch(
      paths,
      result.match,
      seasonNumber: result.seasonNumber,
      episodeNumber: result.episodeNumber,
    );
  }

  Future<void> _openEpisodeEditDialog(MediaItem item) async {
    final seasonController = TextEditingController(
      text: (item.seasonNumber ?? 1).toString(),
    );
    final episodeController = TextEditingController(
      text: (item.episodeNumber ?? 1).toString(),
    );
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('编辑季集'),
            content: SizedBox(
              width: 320,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: seasonController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '季',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: episodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '集',
                        prefixIcon: Icon(Icons.playlist_play),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      if (saved != true || !mounted) {
        return;
      }
      final season = int.tryParse(seasonController.text.trim());
      final episode = int.tryParse(episodeController.text.trim());
      if (season == null || episode == null || season <= 0 || episode <= 0) {
        return;
      }
      await _library.updateEpisodeInfo(
        item,
        seasonNumber: season,
        episodeNumber: episode,
      );
    } finally {
      seasonController.dispose();
      episodeController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return LibraryScope(
      controller: _library,
      child: SettingsScope(
        controller: _settings,
        child: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([_library, _settings]),
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  const CandyBackground(),
                  if (_settings.backgroundImagePath.isNotEmpty)
                    _WallpaperLayer(path: _settings.backgroundImagePath),
                  Row(
                    children: [
                      CapsuleNav(
                        selectedIndex: _section.index,
                        onSelected: (index) {
                          _goToSection(AppSection.values[index]);
                        },
                        footer: _NavFooter(controller: _library),
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
                          const CapsuleNavItem(
                            icon: Icons.style_outlined,
                            selectedIcon: Icons.style_rounded,
                            label: '抽卡',
                          ),
                          CapsuleNavItem(
                            icon: Icons.favorite_outline,
                            selectedIcon: Icons.favorite_rounded,
                            label: '收藏',
                            badgeCount: _library.favoriteCount,
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
                      Expanded(
                        child: Column(
                          children: [
                            _AppTopBar(section: _section),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: tokens.cardBorder,
                            ),
                            Expanded(child: _buildContent()),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_playerItem case final MediaItem item)
                    _PlayerOverlay(
                      key: ValueKey('player:$_playerToken:${item.path}'),
                      compact: _playerCompact,
                      child: PlayerPage(
                        item: item,
                        startAt: _playerStartAt,
                        previousEpisodeOf: _library.previousEpisodeOf,
                        nextEpisodeOf: _library.nextEpisodeOf,
                        subtitlePreference: _settings.subtitlePreference,
                        audioPreference: _settings.audioPreference,
                        settings: _settings,
                        onClose: _closePlayer,
                        onCompactChanged: (compact) {
                          if (!mounted || _playerCompact == compact) {
                            return;
                          }
                          setState(() {
                            _playerCompact = compact;
                          });
                        },
                        onProgressChanged: _library.savePlaybackProgress,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_library.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final busy = _library.scanning || _library.metadataBatchRunning;

    return Column(
      children: [
        if (busy)
          LinearProgressIndicator(
            minHeight: 2,
            value:
                _library.metadataBatchRunning && _library.metadataBatchTotal > 0
                ? _library.metadataBatchDone / _library.metadataBatchTotal
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
      final group = _findSeriesGroup(seriesKey);
      if (group != null) {
        final loading =
            _library.metadataLoadingPath != null &&
            group.paths.contains(_library.metadataLoadingPath);
        return KeyedSubtree(
          key: ValueKey('series:$seriesKey'),
          child: SeriesDetailView(
            group: group,
            loadingMetadata: loading,
            onBack: _closeDetail,
            onPlayEpisode: (episode) => unawaited(_openPlayer(episode)),
            onToggleFavorite: (group) =>
                unawaited(_library.toggleGroupFavorite(group)),
            onToggleFollowing: (group) =>
                unawaited(_library.toggleGroupFollowing(group)),
            onEditEpisode: (episode) =>
                unawaited(_openEpisodeEditDialog(episode)),
            onMatch: _library.matchGroup,
            onManualMatch: (group) {
              unawaited(
                _openManualMatch(
                  initialQuery: group.representative.seriesTitle ?? group.title,
                  paths: group.paths,
                ),
              );
            },
            onOpenLocation: _library.openItemLocation,
          ),
        );
      }
    }

    final detailPath = _detailPath;
    final detailItem = detailPath == null
        ? null
        : _library.itemByPath(detailPath);
    if (detailItem != null) {
      return KeyedSubtree(
        key: ValueKey('detail:${detailItem.path}'),
        child: MediaDetailView(
          item: detailItem,
          loadingMetadata: detailItem.path == _library.metadataLoadingPath,
          onBack: _closeDetail,
          onToggleFavorite: _library.toggleFavorite,
          onMatchTmdb: _library.matchTmdb,
          onManualMatch: (item) {
            unawaited(
              _openManualMatch(initialQuery: item.title, paths: [item.path]),
            );
          },
          onPlay: (item) => unawaited(_openPlayer(item)),
          onOpenLocation: _library.openItemLocation,
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

  /// Resolves the series group for a stored navigation key. Falls back to
  /// the title-based key so an open series page survives its group key
  /// changing mid-session (a TMDB match switches [MediaGroup.keyOf] from
  /// title to tmdb id).
  MediaGroup? _findSeriesGroup(String key) {
    for (final group in _library.groups) {
      if (group.key == key) {
        return group;
      }
    }
    for (final group in _library.groups) {
      if (group.episodes.any(
        (episode) => episode.isEpisode && MediaGroup.titleKeyOf(episode) == key,
      )) {
        return group;
      }
    }
    return null;
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
      const GachaPage(),
      CatalogPage(
        title: '我的收藏',
        groupFilter: isFavoriteGroup,
        emptyMessage: '在详情页点击收藏，影片会出现在这里。',
        onOpenEntry: _openEntry,
        onPlayEntry: _playEntry,
      ),
      // NOT const: the scopes are plain InheritedWidgets, so every rebuild
      // flows top-down from the shell's ListenableBuilder. A const child is
      // identical across builds and Flutter would skip its whole subtree —
      // the settings page would freeze until a tab switch forces a rebuild.
      SettingsPage(),
    ];
  }
}

class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({super.key, required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    if (!compact) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black),
          child: child,
        ),
      );
    }

    final windowSize = MediaQuery.sizeOf(context);
    final width = (windowSize.width - AppSpacing.xl * 2).clamp(360.0, 720.0);
    final height = (width * 9 / 16 + 72).clamp(280.0, 430.0);

    return Positioned(
      right: AppSpacing.xl,
      bottom: AppSpacing.xl,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          border: Border.all(color: tokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          child: child,
        ),
      ),
    );
  }
}

/// A dedicated title bar prevents window controls from competing with page
/// toolbars. Its center decorations are deliberately subtle and remain
/// non-interactive, leaving the whole content area available to each page.
class _AppTopBar extends StatelessWidget {
  const _AppTopBar({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.sm),
                ),
              ),
              child: Icon(section.icon, size: 18, color: tokens.accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Expanded(child: _TopBarDecorations()),
            const WindowControlButtons(),
          ],
        ),
      ),
    );
  }
}

class _TopBarDecorations extends StatelessWidget {
  const _TopBarDecorations();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 220) {
            return const SizedBox.shrink();
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: constraints.maxWidth * .24,
                child: Icon(
                  Icons.cloud_rounded,
                  size: 30,
                  color: tokens.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              Icon(
                Icons.public,
                size: 34,
                color: AppTokens.candyGradient.last.withValues(alpha: 0.18),
              ),
              Positioned(
                right: constraints.maxWidth * .19,
                top: 12,
                child: Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: tokens.accent.withValues(alpha: 0.26),
                ),
              ),
              Positioned(
                right: constraints.maxWidth * .31,
                bottom: 10,
                child: Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: AppTokens.cyanAccent.withValues(alpha: 0.22),
                ),
              ),
            ],
          );
        },
      ),
    );
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
