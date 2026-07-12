import 'package:flutter/material.dart';

import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../catalog/media_category.dart';
import 'cached_tmdb_image.dart';
import 'poster_placeholder.dart';

/// Featured spotlight banner at the top of Home: full-bleed backdrop with
/// scrims, title, metadata, overview, and play/detail actions.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onOpenDetail,
    this.height = 360,
  });

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onOpenDetail;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final theme = Theme.of(context);
    final inProgress =
        item.playbackProgress > 0.01 && item.playbackProgress < 0.95;

    final metadata = [
      ?releaseYear(item),
      if (item.voteAverage != null && item.voteAverage! > 0)
        '★ ${item.voteAverage!.toStringAsFixed(1)}',
      isTv(item) ? '剧集' : '电影',
      ?item.episodeLabel,
    ].join(' · ');

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _HeroBackdrop(item: item),
            // Left scrim keeps the text legible over bright backdrops.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            // Bottom scrim melts the banner into the page background.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    tokens.background.withValues(alpha: 0.9),
                  ],
                  stops: const [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: AppSpacing.xxl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inProgress ? '▶ 继续观看' : '✨ 今日精选',
                    style: TextStyle(
                      color: tokens.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.tmdbTitle ?? item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(metadata, style: TextStyle(color: tokens.textSecondary)),
                  if ((item.overview ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        item.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                        ),
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(inProgress ? '继续播放' : '播放'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                        ),
                        onPressed: onOpenDetail,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('详情'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final backdropPath = item.backdropPath;
    if (backdropPath != null && backdropPath.isNotEmpty) {
      return CachedTmdbImage(
        url: TmdbClient.backdropUrlLarge(backdropPath),
        alignment: Alignment.topCenter,
        placeholderIconSize: 64,
      );
    }

    final posterPath = item.posterPath;
    if (posterPath != null && posterPath.isNotEmpty) {
      return CachedTmdbImage(
        url: TmdbClient.posterUrl(posterPath),
        placeholderIconSize: 64,
      );
    }

    return const PosterPlaceholder(iconSize: 64);
  }
}
