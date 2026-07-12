import 'package:flutter/material.dart';

import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import 'cached_tmdb_image.dart';
import 'hoverable.dart';
import 'poster_placeholder.dart';

/// Portrait poster card: hover-grow, play-on-hover, favorite heart, watched
/// badge, and a progress bar for partially watched items. Tap opens detail,
/// double-tap (or the play button) starts playback. Never shows file paths.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onOpenDetail,
    required this.onPlay,
    this.width,
  });

  final MediaItem item;
  final VoidCallback onOpenDetail;
  final VoidCallback onPlay;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    final card = Hoverable(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onOpenDetail,
          onDoubleTap: onPlay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.md),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: hovered ? 1.06 : 1.0,
                        duration: AppDurations.hover,
                        curve: Curves.easeOutBack,
                        child: _PosterImage(posterPath: item.posterPath),
                      ),
                      AnimatedOpacity(
                        opacity: hovered ? 1 : 0,
                        duration: AppDurations.hover,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: IconButton.filled(
                              tooltip: '播放',
                              style: IconButton.styleFrom(
                                backgroundColor: tokens.accent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: onPlay,
                              icon: const Icon(Icons.play_arrow, size: 30),
                            ),
                          ),
                        ),
                      ),
                      if (item.favorite)
                        const Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: _CornerBadge(
                            child: Icon(
                              Icons.favorite,
                              size: 14,
                              color: Color(0xFFFF6B81),
                            ),
                          ),
                        ),
                      if (item.playbackProgress >= 0.95)
                        const Positioned(
                          top: AppSpacing.sm,
                          left: AppSpacing.sm,
                          child: _CornerBadge(
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: Color(0xFF7CE38B),
                            ),
                          ),
                        ),
                      if (item.playbackProgress > 0.01 &&
                          item.playbackProgress < 0.95)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ProgressStripe(
                            progress: item.playbackProgress,
                            accent: tokens.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.tmdbTitle ?? item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _metadataLine(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );

    if (width == null) {
      return card;
    }
    return SizedBox(width: width, child: card);
  }

  static String _metadataLine(MediaItem item) {
    final parts = [
      ?releaseYear(item),
      if (item.voteAverage != null && item.voteAverage! > 0)
        '★ ${item.voteAverage!.toStringAsFixed(1)}',
      ?item.episodeLabel,
    ];
    if (parts.isEmpty) {
      return item.extension.toUpperCase();
    }
    return parts.join(' · ');
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    final path = posterPath;
    if (path == null || path.isEmpty) {
      return const PosterPlaceholder();
    }
    return CachedTmdbImage(url: TmdbClient.posterUrl(path), cacheWidth: 400);
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _ProgressStripe extends StatelessWidget {
  const _ProgressStripe({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: Colors.white.withValues(alpha: 0.25),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0, 1),
        heightFactor: 1,
        child: ColoredBox(color: accent),
      ),
    );
  }
}
