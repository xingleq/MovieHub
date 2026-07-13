import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_group.dart';
import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../format/formatters.dart';
import '../widgets/cached_tmdb_image.dart';
import '../widgets/jelly_button.dart';
import '../widgets/poster_placeholder.dart';
import 'media_detail_view.dart'
    show
        DetailActionButton,
        DetailMetadataChip,
        DetailScoreBlock,
        RelatedDetailShelf;

/// Cinematic series detail: backdrop header, season-grouped episode list,
/// and related recommendations.
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
    final related = _relatedItems(context);

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
                              if (rep.voteAverage != null &&
                                  rep.voteAverage! > 0) ...[
                                DetailScoreBlock(score: rep.voteAverage!),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  for (final chip in _chips())
                                    DetailMetadataChip(label: chip),
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
                                  DetailActionButton(
                                    icon: group.anyFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    label: group.anyFavorite ? '已收藏' : '收藏',
                                    onPressed: null,
                                  ),
                                  DetailActionButton(
                                    icon: Icons.add,
                                    label: '追番',
                                    onPressed: null,
                                  ),
                                  DetailActionButton(
                                    icon: loadingMetadata
                                        ? Icons.hourglass_empty
                                        : Icons.cloud_sync_outlined,
                                    label: rep.tmdbId == null ? '匹配剧集' : '重新匹配',
                                    onPressed: loadingMetadata
                                        ? null
                                        : () => onMatch(group),
                                  ),
                                  DetailActionButton(
                                    icon: Icons.search,
                                    label: '手动匹配',
                                    onPressed: loadingMetadata
                                        ? null
                                        : () => onManualMatch(group),
                                  ),
                                  DetailActionButton(
                                    icon: Icons.folder_open,
                                    label: '打开位置',
                                    onPressed: () =>
                                        onOpenLocation(group.episodes.first),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '剧集列表',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _EpisodePagination(total: group.episodes.length),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final season in seasons.keys.toList()..sort()) ...[
                      if (season != 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            '第 $season 季',
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                        ),
                      for (final episode in seasons[season]!)
                        _EpisodeRow(
                          episode: episode,
                          onPlay: () => onPlayEpisode(episode),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (related.isNotEmpty) ...[
                      RelatedDetailShelf(
                        title: '相关推荐',
                        items: related,
                        onTap: (_) {},
                      ),
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

  List<MediaItem> _relatedItems(BuildContext context) {
    final controller = LibraryScope.of(context);
    final rep = group.representative;
    final all = controller.items
        .where((i) => !group.paths.contains(i.path))
        .toList();
    final genres = rep.genres?.toSet() ?? {};

    all.sort((a, b) {
      final aScore = _genreScore(a, genres) + _recencyScore(a);
      final bScore = _genreScore(b, genres) + _recencyScore(b);
      return bScore.compareTo(aScore);
    });
    return all.take(10).toList();
  }

  int _genreScore(MediaItem other, Set<String> genres) {
    if (genres.isEmpty || other.genres == null) return 0;
    return other.genres!.where(genres.contains).length * 100;
  }

  int _recencyScore(MediaItem other) {
    return other.addedAt.difference(DateTime(2000)).inDays;
  }

  List<String> _chips() {
    final rep = group.representative;
    return [
      ?releaseYear(rep),
      '剧集',
      ...?rep.genres,
      '全 ${group.episodes.length} 话',
      if (group.watchedCount > 0) '已看 ${group.watchedCount} 话',
      if (rep.runtimeMinutes != null) '单集 ${rep.runtimeMinutes} 分钟',
    ];
  }
}

class _EpisodePagination extends StatelessWidget {
  const _EpisodePagination({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    // Visual pagination matching the design: first few pages + ellipsis + last.
    final pages = <int>{
      for (var i = 1; i <= total.clamp(1, 7); i++) i,
      if (total > 7) total,
    }.toList()..sort();

    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < pages.length; i++) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pages[i] == 1
                  ? tokens.accent
                  : tokens.surface.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.sm),
              ),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Text(
              '${pages[i]}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: pages[i] == 1 ? FontWeight.w700 : FontWeight.w500,
                color: pages[i] == 1 ? Colors.white : tokens.textSecondary,
              ),
            ),
          ),
          if (i == pages.length - 2 && pages.last > pages[i] + 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text('...', style: TextStyle(color: tokens.textSecondary)),
            ),
        ],
      ],
    );
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
