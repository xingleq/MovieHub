import 'package:flutter/material.dart';

import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import '../format/formatters.dart';
import 'block_asset.dart';
import 'cached_tmdb_image.dart';
import 'hoverable.dart';
import 'poster_placeholder.dart';

/// Landscape card for the 继续观看 shelf: backdrop image, remaining time and a
/// progress bar. Tap opens detail, double-tap or the hover play button resumes.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.onOpenDetail,
    required this.onPlay,
    this.width = 300,
  });

  final MediaItem item;
  final VoidCallback onOpenDetail;
  final VoidCallback onPlay;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final remaining = Duration(
      milliseconds: (item.playbackDurationMs - item.playbackPositionMs)
          .clamp(0, item.playbackDurationMs)
          .toInt(),
    );

    return SizedBox(
      width: width,
      child: Hoverable(
        onActivate: onOpenDetail,
        builder: (context, hovered) {
          return GestureDetector(
            onTap: onOpenDetail,
            onDoubleTap: onPlay,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BackdropImage(item: item),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: hovered ? 1 : 0,
                    duration: AppDurations.hover,
                    child: Center(
                      child: IconButton.filled(
                        tooltip: '继续播放',
                        style: IconButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onPlay,
                        icon: const BlockIcon(AppAssets.play, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md + 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.tmdbTitle ?? item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (item.episodeNumber != null)
                              '第 ${item.episodeNumber} 话'
                            else
                              ?item.episodeLabel,
                            '观看至 ${(item.playbackProgress * 100).round()}%',
                            '剩余 ${formatDuration(remaining)}',
                          ].join(' · '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      color: Colors.white.withValues(alpha: 0.25),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: item.playbackProgress.clamp(0, 1),
                        heightFactor: 1,
                        child: ColoredBox(color: tokens.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final backdropPath = item.backdropPath;
    if (backdropPath != null && backdropPath.isNotEmpty) {
      return CachedTmdbImage(
        url: TmdbClient.backdropUrl(backdropPath),
        cacheWidth: 640,
        placeholderIconSize: 32,
      );
    }

    final posterPath = item.posterPath;
    if (posterPath != null && posterPath.isNotEmpty) {
      return CachedTmdbImage(
        url: TmdbClient.posterUrl(posterPath),
        cacheWidth: 400,
        placeholderIconSize: 32,
      );
    }

    return const PosterPlaceholder(iconSize: 32);
  }
}
