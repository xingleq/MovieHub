import 'package:flutter/material.dart';

import '../../core/media/media_group.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import 'cached_tmdb_image.dart';
import 'hoverable.dart';
import 'poster_placeholder.dart';

/// Portrait poster card for a wall entry (movie or aggregated series):
/// hover-grow with candy glow, play-on-hover, favorite heart, watched badge,
/// episode-count chip and progress stripes. Never shows file paths.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.group,
    required this.onOpenDetail,
    required this.onPlay,
    this.width,
  });

  final MediaGroup group;
  final VoidCallback onOpenDetail;
  final VoidCallback onPlay;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final rep = group.representative;

    final watched = group.isSeries
        ? group.allWatched
        : rep.playbackProgress >= 0.95;

    double? stripeValue;
    if (group.isSeries) {
      if (group.watchedCount > 0 && !group.allWatched) {
        stripeValue = group.watchedCount / group.episodes.length;
      }
    } else if (rep.playbackProgress > 0.01 && rep.playbackProgress < 0.95) {
      stripeValue = rep.playbackProgress;
    }

    final card = Hoverable(
      onActivate: onOpenDetail,
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
                child: AnimatedContainer(
                  duration: AppDurations.hover,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                    boxShadow: hovered
                        ? [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
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
                          child: _PosterImage(posterPath: rep.posterPath),
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
                        if (rep.voteAverage != null && rep.voteAverage! > 0)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: _RatingChip(score: rep.voteAverage!),
                          ),
                        Positioned(
                          top: AppSpacing.sm,
                          left: AppSpacing.sm,
                          child: Column(
                            children: [
                              if (watched)
                                const _CornerBadge(
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Color(0xFF7CE38B),
                                  ),
                                ),
                              if (group.anyFavorite) ...[
                                if (watched) const SizedBox(height: 4),
                                const _CornerBadge(
                                  child: Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: Color(0xFFFF6B81),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (group.isSeries)
                          Positioned(
                            right: AppSpacing.sm,
                            bottom: AppSpacing.sm + 6,
                            child: _EpisodeCountChip(group: group),
                          ),
                        if (stripeValue != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _ProgressStripe(
                              progress: stripeValue,
                              accent: tokens.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                group.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _metadataLine(group),
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

  static String _metadataLine(MediaGroup group) {
    final rep = group.representative;
    final parts = [
      ?releaseYear(rep),
      if (group.isSeries) '全 ${group.episodes.length} 话' else ?rep.episodeLabel,
    ];
    if (parts.isEmpty) {
      return rep.extension.toUpperCase();
    }
    return parts.join(' · ');
  }
}

/// Pink score badge in the poster's top-right corner, per the design spec.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppTokens.candyGradient),
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EpisodeCountChip extends StatelessWidget {
  const _EpisodeCountChip({required this.group});

  final MediaGroup group;

  @override
  Widget build(BuildContext context) {
    final label = group.watchedCount > 0
        ? '${group.watchedCount}/${group.episodes.length}'
        : '${group.episodes.length} 集';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
