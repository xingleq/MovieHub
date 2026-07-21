import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../widgets/cached_tmdb_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/hoverable.dart';
import '../widgets/message_banner.dart';

/// A non-scrolling, console-style media desktop. The focused poster controls
/// the full-window artwork; metadata and playback actions live on detail pages.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenItem,
    required this.onPlayItem,
    required this.onGoToSettings,
  });

  final ValueChanged<MediaItem> onOpenItem;
  final ValueChanged<MediaItem> onPlayItem;
  final VoidCallback onGoToSettings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MediaIdentity? _focusedIdentity;

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    if (controller.items.isEmpty) {
      return EmptyState(
        icon: Icons.auto_awesome,
        title: '欢迎来到你的小影院 ✨',
        message: controller.roots.isEmpty
            ? '先在设置里添加媒体文件夹，沉浸式桌面马上就出现。'
            : '目录已添加，进入设置重新扫描即可。',
        action: FilledButton.icon(
          onPressed: widget.onGoToSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('前往设置'),
        ),
      );
    }

    final continueWatching = controller.continueWatchingItems;
    final candidates = continueWatching.isNotEmpty
        ? continueWatching
        : controller.spotlightItems.isNotEmpty
        ? controller.spotlightItems
        : controller.items.take(16).toList(growable: false);
    final selected = candidates.cast<MediaItem?>().firstWhere(
      (item) => item?.identity == _focusedIdentity,
      orElse: () => candidates.first,
    )!;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.025, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _ImmersiveBackdrop(
            key: ValueKey(selected.identity),
            item: selected,
          ),
        ),
        if (controller.error != null)
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: 96,
            child: MessageBanner(
              icon: Icons.error_outline,
              message: controller.error!,
              onClose: controller.clearError,
            ),
          ),
        if (controller.skippedPaths.isNotEmpty)
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: controller.error == null ? 96 : 154,
            child: MessageBanner(
              icon: Icons.warning_amber,
              message: '有 ${controller.skippedPaths.length} 个路径无法读取或不存在。',
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.lg,
          height: 304,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = candidates[index];
              return _FocusPoster(
                item: item,
                onFocused: () {
                  if (_focusedIdentity != item.identity) {
                    setState(() => _focusedIdentity = item.identity);
                  }
                },
                onOpen: () => widget.onOpenItem(item),
                onPlay: () => widget.onPlayItem(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ImmersiveBackdrop extends StatelessWidget {
  const _ImmersiveBackdrop({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final backdropPath = item.backdropPath;
    final posterPath = item.posterPath;
    Widget artwork;
    if (backdropPath != null && backdropPath.isNotEmpty) {
      artwork = CachedTmdbImage(
        url: TmdbClient.backdropUrl(backdropPath),
        cacheWidth: 1920,
      );
    } else if (posterPath != null && posterPath.isNotEmpty) {
      artwork = Transform.scale(
        scale: 1.22,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CachedTmdbImage(
            url: TmdbClient.posterUrl(posterPath),
            cacheWidth: 900,
          ),
        ),
      );
    } else {
      artwork = const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF251B46), Color(0xFF101526)],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        artwork,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x58000000), Color(0x08000000), Color(0xD9000000)],
              stops: [0, 0.48, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x30000000), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusPoster extends StatelessWidget {
  const _FocusPoster({
    required this.item,
    required this.onFocused,
    required this.onOpen,
    required this.onPlay,
  });

  final MediaItem item;
  final VoidCallback onFocused;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final posterPath = item.posterPath;
    return SizedBox(
      width: 168,
      child: Hoverable(
        onActivate: onOpen,
        onHighlightChanged: (highlighted) {
          if (highlighted) {
            onFocused();
          }
        },
        builder: (context, highlighted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  key: ValueKey('home-poster:${item.sourceId}:${item.path}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedTmdbImage(
                          url: posterPath == null || posterPath.isEmpty
                              ? null
                              : TmdbClient.posterUrl(posterPath),
                          cacheWidth: 320,
                        ),
                        AnimatedOpacity(
                          opacity: highlighted ? 1 : 0,
                          duration: AppDurations.hover,
                          child: ExcludeFocus(
                            excluding: !highlighted,
                            child: IgnorePointer(
                              ignoring: !highlighted,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.32),
                                child: Center(
                                  child: IconButton.filled(
                                    key: ValueKey(
                                      'home-play:${item.sourceId}:${item.path}',
                                    ),
                                    tooltip: '播放',
                                    onPressed: onPlay,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      minimumSize: const Size.square(52),
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedOpacity(
                opacity: highlighted ? 1 : 0,
                duration: AppDurations.hover,
                child: Text(
                  item.tmdbTitle ?? item.seriesTitle ?? item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
