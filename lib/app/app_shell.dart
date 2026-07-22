import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/media/media_group.dart';
import '../core/media/media_item.dart';
import '../core/system/platform_services.dart';
import '../theme/app_tokens.dart';
import '../ui/catalog/media_category.dart';
import '../ui/detail/media_detail_view.dart';
import '../ui/detail/series_detail_view.dart';
import '../ui/pages/catalog_page.dart';
import '../ui/pages/gacha_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/player/player_page.dart';
import '../ui/widgets/candy_background.dart';
import '../ui/widgets/immersive_top_nav.dart';
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
  MediaIdentity? _detailIdentity;
  String? _detailSeriesKey;
  MediaItem? _playerItem;
  Duration? _playerStartAt;
  var _playerToken = 0;
  var _searchQuery = '';

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
    if (_section == AppSection.settings && section != AppSection.settings) {
      _settings.lockSettings();
    }
    setState(() {
      _section = section;
      _detailIdentity = null;
      _detailSeriesKey = null;
    });
  }

  Future<void> _requestSection(AppSection section) async {
    if (section != AppSection.settings) {
      _goToSection(section);
      return;
    }
    if (_settings.settingsUnlocked) {
      _goToSection(section);
      return;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _settings.hasManagementPassword
          ? _UnlockSettingsDialog(settings: _settings)
          : _CreateSettingsPasswordDialog(settings: _settings),
    );
    if (granted != true || !mounted) {
      return;
    }
    _goToSection(AppSection.settings);
  }

  List<MediaGroup> get _searchResults {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return _library.groups
        .where((group) {
          if (group.title.toLowerCase().contains(query)) {
            return true;
          }
          return group.episodes.any((item) {
            return item.title.toLowerCase().contains(query) ||
                (item.tmdbTitle?.toLowerCase().contains(query) ?? false) ||
                (item.seriesTitle?.toLowerCase().contains(query) ?? false) ||
                item.path.toLowerCase().contains(query);
          });
        })
        .toList(growable: false);
  }

  void _openEntry(MediaGroup group) {
    setState(() {
      if (group.isSeries) {
        _detailSeriesKey = group.key;
        _detailIdentity = null;
      } else {
        _detailIdentity = group.episodes.first.identity;
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
        _detailIdentity = null;
      } else {
        _detailIdentity = item.identity;
        _detailSeriesKey = null;
      }
    });
  }

  void _closeDetail() {
    setState(() {
      _detailIdentity = null;
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
      if (!_settings.showBreakOverlay && message != null) {
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
      _playerToken++;
    });
  }

  void _closePlayer() {
    setState(() {
      _playerItem = null;
      _playerStartAt = null;
      _playerToken++;
    });
  }

  Future<void> _openManualMatch({
    required String initialQuery,
    required List<MediaIdentity> identities,
  }) async {
    final result = await showDialog<ManualMatchResult>(
      context: context,
      builder: (context) => ManualMatchDialog(
        initialQuery: initialQuery,
        onSearch: _library.searchTmdbCandidates,
        onFetchSeasons: _library.fetchTmdbSeasons,
        onFetchEpisodes: _library.fetchTmdbEpisodes,
        allowEpisodeSelection: identities.length == 1,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _library.applyManualMatch(
      identities,
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
    final windowControlsSupported =
        PlatformServices.instance.windowControls.isSupported;
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
                  Padding(
                    padding:
                        _section == AppSection.home ||
                            _detailIdentity != null ||
                            _detailSeriesKey != null
                        ? EdgeInsets.zero
                        : const EdgeInsets.only(top: 88),
                    child: _buildContent(),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.xl,
                    // Keeps clear of the window buttons where they exist.
                    right: windowControlsSupported ? 150 : AppSpacing.xl,
                    child: ImmersiveTopNav(
                      selected: _section,
                      onSelected: (section) {
                        unawaited(_requestSection(section));
                      },
                      searchResults: _searchResults,
                      onSearch: (query) {
                        setState(() => _searchQuery = query);
                      },
                      onOpenResult: _openEntry,
                    ),
                  ),
                  if (windowControlsSupported)
                    const Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.sm,
                      height: 58,
                      child: WindowControlButtons(),
                    ),
                  if (_playerItem case final MediaItem item)
                    _PlayerOverlay(
                      key: ValueKey(
                        'player:$_playerToken:${item.sourceId}:${item.path}',
                      ),
                      child: PlayerPage(
                        item: item,
                        startAt: _playerStartAt,
                        previousEpisodeOf: _library.previousEpisodeOf,
                        nextEpisodeOf: _library.nextEpisodeOf,
                        playbackUriOf: _library.playbackUriOf,
                        subtitlePreference: _settings.subtitlePreference,
                        audioPreference: _settings.audioPreference,
                        settings: _settings,
                        onClose: _closePlayer,
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
            duration: const Duration(milliseconds: 320),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
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
            _library.metadataLoadingIdentity != null &&
            group.identities.contains(_library.metadataLoadingIdentity);
        return KeyedSubtree(
          key: ValueKey('series:$seriesKey'),
          child: SeriesDetailView(
            group: group,
            loadingMetadata: loading,
            onBack: _closeDetail,
            onPlayEpisode: (episode) => unawaited(_openPlayer(episode)),
            onToggleFavorite: (group) =>
                unawaited(_library.toggleGroupFavorite(group)),
            onEditEpisode: (episode) =>
                unawaited(_openEpisodeEditDialog(episode)),
            onMatch: _library.matchGroup,
            onManualMatch: (group) {
              unawaited(
                _openManualMatch(
                  initialQuery: group.representative.seriesTitle ?? group.title,
                  identities: group.identities,
                ),
              );
            },
            onOpenLocation: _library.canOpenItemLocation(group.episodes.first)
                ? _library.openItemLocation
                : null,
          ),
        );
      }
    }

    final detailIdentity = _detailIdentity;
    final detailItem = detailIdentity == null
        ? null
        : _library.itemByIdentity(detailIdentity);
    if (detailItem != null) {
      return KeyedSubtree(
        key: ValueKey('detail:${detailItem.sourceId}:${detailItem.path}'),
        child: MediaDetailView(
          item: detailItem,
          loadingMetadata:
              detailItem.identity == _library.metadataLoadingIdentity,
          onBack: _closeDetail,
          onToggleFavorite: _library.toggleFavorite,
          onMatchTmdb: _library.matchTmdb,
          onManualMatch: (item) {
            unawaited(
              _openManualMatch(
                initialQuery: item.title,
                identities: [item.identity],
              ),
            );
          },
          onPlay: (item) => unawaited(_openPlayer(item)),
          onOpenLocation: _library.canOpenItemLocation(detailItem)
              ? _library.openItemLocation
              : null,
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('sections'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final (index, page) in _sectionPages().indexed)
            _AnimatedSection(
              key: ValueKey('section:$index'),
              active: _section.index == index,
              child: page,
            ),
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
        onOpenItem: _openItem,
        onPlayItem: (item) => unawaited(_openPlayer(item)),
        onGoToSettings: () {
          unawaited(_requestSection(AppSection.settings));
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

class _CreateSettingsPasswordDialog extends StatefulWidget {
  const _CreateSettingsPasswordDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_CreateSettingsPasswordDialog> createState() =>
      _CreateSettingsPasswordDialogState();
}

class _CreateSettingsPasswordDialogState
    extends State<_CreateSettingsPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.length < 4) {
      setState(() => _error = '密码至少需要 4 位。');
      return;
    }
    if (password != _confirmController.text.trim()) {
      setState(() => _error = '两次输入的密码不一致。');
      return;
    }
    final saved = await widget.settings.saveManagementPassword(
      password: '',
      newPassword: password,
    );
    if (!saved || !mounted) {
      setState(() => _error = widget.settings.error);
      return;
    }
    widget.settings.unlockSettings(password);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建家长密码'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('首次进入设置前，请创建家长密码。以后每次进入设置都需要验证。'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '家长密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _confirmController,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '确认密码',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('创建并进入')),
      ],
    );
  }
}

class _UnlockSettingsDialog extends StatefulWidget {
  const _UnlockSettingsDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_UnlockSettingsDialog> createState() => _UnlockSettingsDialogState();
}

class _UnlockSettingsDialogState extends State<_UnlockSettingsDialog> {
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.settings.unlockSettings(_passwordController.text)) {
      setState(() => _error = widget.settings.error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('进入设置'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _passwordController,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '家长密码',
            prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('验证并进入')),
      ],
    );
  }
}

class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: child,
      ),
    );
  }
}

/// Replays a quick fade/slide when its section becomes the active one, so
/// switching rail sections feels animated while IndexedStack keeps each
/// page's state (search, sort, scroll) alive.
class _AnimatedSection extends StatefulWidget {
  const _AnimatedSection({
    super.key,
    required this.active,
    required this.child,
  });

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
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.active ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_AnimatedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.reverse();
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
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: ExcludeFocus(
          excluding: !widget.active,
          child: ExcludeSemantics(
            excluding: !widget.active,
            child: IgnorePointer(ignoring: !widget.active, child: widget.child),
          ),
        ),
      ),
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
