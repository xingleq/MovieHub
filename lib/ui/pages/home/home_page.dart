import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/library_scope.dart';
import '../../../core/media/media_item.dart';
import '../../../core/tmdb/tmdb_client.dart';
import '../../../theme/app_assets.dart';
import '../../../theme/app_tokens.dart';
import '../../widgets/message_banner.dart';
import 'widgets/lego_button.dart';
import 'widgets/movie_card.dart';

/// Responsive Apple-TV-like home surface. TMDB imagery stays photographic;
/// the block treatment is limited to controls, frames and focus feedback.
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
      return _EmptyHome(
        hasRoots: controller.roots.isNotEmpty,
        onGoToSettings: widget.onGoToSettings,
      );
    }

    final continueWatching = controller.continueWatchingItems;
    final candidates = continueWatching.isNotEmpty
        ? continueWatching
        : controller.spotlightItems.isNotEmpty
        ? controller.spotlightItems
        : controller.items.take(16).toList(growable: false);
    final selected = _focusedIdentity != null
        ? candidates.cast<MediaItem?>().firstWhere(
            (item) => item?.identity == _focusedIdentity,
            orElse: () => null,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = math.min(constraints.maxWidth, mediaSize.width);
        final availableHeight = math.min(
          constraints.maxHeight,
          mediaSize.height,
        );
        final compact = availableWidth < 1500;
        final short = availableHeight < 850;
        final horizontalPadding = compact ? 44.0 : 72.0;
        final shelfHeight = short ? 380.0 : 420.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _TmdbBackdrop(
                  key: ValueKey(selected?.identity),
                  item: selected ?? candidates.first,
                ),
              ),
            ),
            Positioned.fill(child: _BackdropScrim(compact: compact)),
            if (selected != null)
              Positioned(
                left: horizontalPadding,
                top: short ? 116 : 150,
                width: compact
                    ? math.min(520, constraints.maxWidth * 0.48)
                    : math.min(640, constraints.maxWidth * 0.42),
                child: _MovieInformation(
                  item: selected,
                  compact: short,
                  onPlay: () => widget.onPlayItem(selected),
                  onDetails: () => widget.onOpenItem(selected),
                ),
              ),
            if (controller.error != null)
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                top: 92,
                child: MessageBanner(
                  icon: Icons.error_outline,
                  message: controller.error!,
                  onClose: controller.clearError,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: shelfHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTokens.of(context).scrim.withValues(alpha: 0.6),
                      AppTokens.of(context).scrim.withValues(alpha: 0.92),
                    ],
                    stops: const [0, 0.3, 1],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Expanded(
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: ListView.separated(
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding - 15,
                            0,
                            horizontalPadding,
                            24,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: candidates.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final item = candidates[index];
                            return MovieCard(
                              item: item,
                              autofocus: false,
                              onFocused: () {
                                if (_focusedIdentity != item.identity) {
                                  setState(
                                    () => _focusedIdentity = item.identity,
                                  );
                                }
                              },
                              onPlay: () => widget.onPlayItem(item),
                              onOpenDetails: () => widget.onOpenItem(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TmdbBackdrop extends StatelessWidget {
  const _TmdbBackdrop({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final path = item.backdropPath;
    if (path == null || path.isEmpty) {
      return ColoredBox(color: tokens.background);
    }
    return SizedBox.expand(
      child: Image.network(
        TmdbClient.backdropUrl(path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => ColoredBox(color: tokens.background),
      ),
    );
  }
}

class _BackdropScrim extends StatelessWidget {
  const _BackdropScrim({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.46, 1],
              colors: [
                tokens.scrim.withValues(alpha: 0.10),
                tokens.scrim.withValues(alpha: 0.22),
                tokens.scrim.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: compact ? const [0, 0.55, 1] : const [0, 0.48, 0.82],
              colors: [
                tokens.scrim.withValues(alpha: 0.72),
                tokens.scrim.withValues(alpha: 0.18),
                tokens.scrim.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovieInformation extends StatelessWidget {
  const _MovieInformation({
    required this.item,
    required this.compact,
    required this.onPlay,
    required this.onDetails,
  });

  final MediaItem item;
  final bool compact;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final title = item.tmdbTitle ?? item.seriesTitle ?? item.title;
    final tags = <String>[
      if (item.releaseDate != null && item.releaseDate!.length >= 4)
        item.releaseDate!.substring(0, 4),
      if (item.tmdbMediaType == 'tv') '剧集' else '电影',
      ...?item.genres?.take(2),
      if (item.episodeLabel case final String label) label,
    ];
    final hasProgress = item.playbackProgress > 0;
    final remainingMinutes = item.playbackDurationMs > item.playbackPositionMs
        ? ((item.playbackDurationMs - item.playbackPositionMs) / 60000).ceil()
        : null;
    final progressParts = <String>[
      if (item.episodeLabel != null) item.episodeLabel!,
      if (remainingMinutes != null) '$remainingMinutes 分钟剩余',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: tokens.brickHighlight,
            fontFamily: AppFonts.pixelChinese,
            fontSize: compact ? 40 : 52,
            height: 1.1,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: tokens.scrim, blurRadius: 16),
              Shadow(color: Colors.black87, blurRadius: 8),
            ],
          ),
        ),
        if (item.tmdbTitle != null && item.title != item.tmdbTitle) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.brickHighlight.withValues(alpha: 0.82),
              fontSize: compact ? 15 : 18,
              shadows: [Shadow(color: tokens.scrim, blurRadius: 8)],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [for (final tag in tags) _InfoTag(label: tag)],
        ),
        if (item.overview case final String overview
            when overview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            overview,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.brickHighlight.withValues(alpha: 0.94),
              fontSize: compact ? 15 : 17,
              height: 1.6,
              shadows: [Shadow(color: tokens.scrim, blurRadius: 10)],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: LegoButton(
                label: hasProgress ? '继续播放' : '开始播放',
                subtitle: progressParts.isEmpty
                    ? null
                    : progressParts.join(' · '),
                iconAsset: AppAssets.play,
                onPressed: onPlay,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: LegoButton(
                label: '详情',
                iconAsset: AppAssets.details,
                onPressed: onDetails,
                primary: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: tokens.scrim.withValues(alpha: 0.45),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(
          color: tokens.brickHighlight.withValues(alpha: 0.65),
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.brickHighlight,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: tokens.scrim, blurRadius: 4)],
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.hasRoots, required this.onGoToSettings});

  final bool hasRoots;
  final VoidCallback onGoToSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ColoredBox(
      color: tokens.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_rounded,
                  size: 72,
                  color: tokens.accent,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '欢迎来到 MovieHub',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  hasRoots ? '目录已添加，请重新扫描媒体库。' : '先添加媒体文件夹，就可以建立你的影视墙。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textSecondary, height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 220,
                  child: LegoButton(
                    label: '前往设置',
                    iconAsset: AppAssets.settings,
                    onPressed: onGoToSettings,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
