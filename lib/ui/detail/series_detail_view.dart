import 'package:flutter/material.dart';

import '../../core/media/media_group.dart';
import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../format/formatters.dart';
import '../widgets/cached_tmdb_image.dart';
import '../widgets/jelly_button.dart';
import '../widgets/poster_placeholder.dart';

/// Cinematic series detail: backdrop header shared with the movie detail,
/// then a season-grouped episode list with watched marks (todo §15) —
/// tapping an episode plays it.
class SeriesDetailView extends StatelessWidget {
  const SeriesDetailView({
    super.key,
    required this.group,
    required this.loadingMetadata,
    required this.onBack,
    required this.onPlayEpisode,
    required this.onMatch,
    required this.onManualMatch,
    required this.onOpenLocation,
  });

  final MediaGroup group;
  final bool loadingMetadata;
  final VoidCallback onBack;
  final ValueChanged<MediaItem> onPlayEpisode;
  final ValueChanged<MediaGroup> onMatch;
  final ValueChanged<MediaGroup> onManualMatch;
  final ValueChanged<MediaItem> onOpenLocation;

  static const _backdropHeight = 340.0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final rep = group.representative;
    final next = group.nextUnwatched;

    final seasons = <int, List<MediaItem>>{};
    for (final episode in group.episodes) {
      seasons.putIfAbsent(episode.seasonNumber ?? 0, () => []).add(episode);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: _backdropHeight,
                    width: double.infinity,
                    child: _Backdrop(item: rep),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  200,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Poster(item: rep),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                group.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 12,
                                          color: Colors.black87,
                                        ),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  for (final chip in _chips())
                                    _MetadataChip(label: chip),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Wrap(
                                spacing: AppSpacing.md,
                                runSpacing: AppSpacing.md,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  JellyButton(
                                    icon: Icons.play_arrow,
                                    label: next == null
                                        ? '再看一遍'
                                        : group.watchedCount == 0
                                        ? '开始观看'
                                        : '继续看 ${next.episodeLabel ?? ''}',
                                    onPressed: () =>
                                        onPlayEpisode(group.playTarget),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: loadingMetadata
                                        ? null
                                        : () => onMatch(group),
                                    icon: loadingMetadata
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.cloud_sync_outlined),
                                    label: Text(
                                      rep.tmdbId == null ? '匹配剧集' : '重新匹配',
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: loadingMetadata
                                        ? null
                                        : () => onManualMatch(group),
                                    icon: const Icon(Icons.search),
                                    label: const Text('手动匹配'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        onOpenLocation(group.episodes.first),
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('打开位置'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((rep.overview ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '简介',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          rep.overview!,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    for (final season in seasons.keys.toList()..sort()) ...[
                      Text(
                        season == 0 ? '剧集' : '第 $season 季',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final episode in seasons[season]!)
                        _EpisodeRow(
                          episode: episode,
                          onPlay: () => onPlayEpisode(episode),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          child: IconButton.filledTonal(
            tooltip: '返回',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ],
    );
  }

  List<String> _chips() {
    final rep = group.representative;
    return [
      ?releaseYear(rep),
      if (rep.voteAverage != null && rep.voteAverage! > 0)
        '★ ${rep.voteAverage!.toStringAsFixed(1)}',
      '剧集',
      ...?rep.genres,
      '共 ${group.episodes.length} 集',
      if (group.watchedCount > 0) '已看 ${group.watchedCount} 集',
      if (rep.runtimeMinutes != null) '单集 ${rep.runtimeMinutes} 分钟',
    ];
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onPlay});

  final MediaItem episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final progress = episode.playbackProgress;
    final watched = progress >= 0.95;
    final inProgress = progress > 0.01 && !watched;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: tokens.surface.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  watched ? Icons.check_circle : Icons.play_circle_outline,
                  size: 20,
                  color: watched ? const Color(0xFF7CE38B) : tokens.accent,
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 72,
                  child: Text(
                    episode.episodeLabel ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: inProgress
                      ? Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(2),
                                ),
                                child: SizedBox(
                                  height: 4,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.15,
                                    ),
                                    color: tokens.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          watched ? '已看完' : '未观看',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  formatBytes(episode.sizeBytes),
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: SizedBox(
          width: 220,
          height: 330,
          child: item.posterPath != null && item.posterPath!.isNotEmpty
              ? CachedTmdbImage(
                  url: TmdbClient.posterUrl(item.posterPath!),
                  cacheWidth: 500,
                  placeholderIconSize: 56,
                )
              : const PosterPlaceholder(iconSize: 56),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final backdropPath = item.backdropPath;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropPath != null && backdropPath.isNotEmpty)
          CachedTmdbImage(
            url: TmdbClient.backdropUrlLarge(backdropPath),
            alignment: Alignment.topCenter,
          )
        else
          ColoredBox(color: tokens.surfaceVariant),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              stops: const [0, 0.7],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                tokens.background.withValues(alpha: 0.55),
                tokens.background,
              ],
              stops: const [0.3, 0.75, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
