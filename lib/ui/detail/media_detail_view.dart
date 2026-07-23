import 'package:flutter/material.dart';

import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../catalog/media_category.dart';
import '../format/formatters.dart';
import '../widgets/cached_tmdb_image.dart';
import '../widgets/block_asset.dart';
import '../widgets/jelly_button.dart';
import '../widgets/poster_placeholder.dart';

/// Cinematic detail view: full-width backdrop with gradient scrims, poster,
/// metadata chips, actions, overview, and this file's own information.
class MediaDetailView extends StatelessWidget {
  const MediaDetailView({
    super.key,
    required this.item,
    required this.loadingMetadata,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onMatchTmdb,
    required this.onManualMatch,
    required this.onPlay,
    required this.onOpenLocation,
  });

  final MediaItem item;
  final bool loadingMetadata;
  final VoidCallback onBack;
  final ValueChanged<MediaItem> onToggleFavorite;
  final ValueChanged<MediaItem> onMatchTmdb;
  final ValueChanged<MediaItem> onManualMatch;
  final ValueChanged<MediaItem> onPlay;

  /// Null when the platform has no file manager to reveal in — the
  /// "打开位置" action hides itself.
  final ValueChanged<MediaItem>? onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final inProgress =
        item.playbackProgress > 0.01 && item.playbackProgress < 0.95;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: DetailBackdropLayer(item: item)),
        SingleChildScrollView(
          child: Padding(
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
                    _DetailPoster(item: item),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            item.tmdbTitle ?? item.title,
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
                          if (item.tmdbTitle != null &&
                              item.tmdbTitle != item.title) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tokens.textSecondary),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          if (item.voteAverage != null &&
                              item.voteAverage! > 0) ...[
                            DetailScoreBlock(score: item.voteAverage!),
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
                                label: inProgress ? '继续播放' : '播放',
                                tone: JellyTone.sunny,
                                onPressed: () => onPlay(item),
                              ),
                              DetailActionButton(
                                icon: item.favorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                label: item.favorite ? '已收藏' : '收藏',
                                onPressed: () => onToggleFavorite(item),
                              ),
                              if (onOpenLocation case final onOpenLocation?)
                                DetailActionButton(
                                  icon: Icons.folder_open,
                                  label: '打开位置',
                                  onPressed: () => onOpenLocation(item),
                                ),
                              DetailActionButton(
                                icon: loadingMetadata
                                    ? Icons.hourglass_empty
                                    : Icons.cloud_sync_outlined,
                                label: item.tmdbId == null ? '匹配 TMDB' : '重新匹配',
                                onPressed: loadingMetadata
                                    ? null
                                    : () => onMatchTmdb(item),
                              ),
                              DetailActionButton(
                                icon: Icons.search,
                                label: '手动匹配',
                                onPressed: loadingMetadata
                                    ? null
                                    : () => onManualMatch(item),
                              ),
                            ],
                          ),
                          if (inProgress) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _ProgressSummary(item: item, tokens: tokens),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if ((item.overview ?? '').trim().isNotEmpty) ...[
                  Text(
                    '简介',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      item.overview!,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  '详细信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._infoRows(context),
                const SizedBox(height: AppSpacing.sm),
                Text('文件路径', style: TextStyle(color: tokens.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(item.path, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 88 + AppSpacing.lg,
          left: AppSpacing.lg,
          child: IconButton.filledTonal(
            tooltip: '返回',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
            ),
            onPressed: onBack,
            icon: const BlockIcon(AppAssets.back, size: 30),
          ),
        ),
      ],
    );
  }

  List<String> _chips() {
    return [
      ?releaseYear(item),
      if (item.voteAverage != null && item.voteAverage! > 0)
        '★ ${item.voteAverage!.toStringAsFixed(1)}',
      if (item.tmdbId != null) (isTv(item) ? '剧集' : '电影'),
      ...?item.genres,
      ?item.episodeLabel,
      if (item.runtimeMinutes != null) '${item.runtimeMinutes} 分钟',
      item.extension.toUpperCase(),
      formatBytes(item.sizeBytes),
    ];
  }

  List<Widget> _infoRows(BuildContext context) {
    final rows = <(String, String)>[
      if (item.tmdbId != null) ('TMDB', '#${item.tmdbId}'),
      if (item.releaseDate != null) ('上映', item.releaseDate!),
      if (item.directors != null && item.directors!.isNotEmpty)
        ('导演', item.directors!.join(' / ')),
      if (item.cast != null && item.cast!.isNotEmpty)
        ('主演', item.cast!.join(' / ')),
      if (item.seriesTitle != null) ('剧名', item.seriesTitle!),
      ('添加时间', formatDate(item.addedAt)),
      ('修改时间', formatDate(item.modifiedAt)),
      if (item.playbackDurationMs > 0)
        (
          '播放进度',
          '${(item.playbackProgress * 100).round()}%  '
              '${formatDuration(Duration(milliseconds: item.playbackPositionMs))}'
              ' / '
              '${formatDuration(Duration(milliseconds: item.playbackDurationMs))}',
        ),
    ];

    final tokens = AppTokens.of(context);
    return [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
              Expanded(child: Text(value)),
            ],
          ),
        ),
    ];
  }
}

class DetailActionButton extends StatelessWidget {
  const DetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: BlockIcon.fromMaterial(icon, size: 26),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: tokens.surface.withValues(alpha: 0.7),
        foregroundColor: tokens.textPrimary,
      ),
    );
  }
}

class _DetailPoster extends StatelessWidget {
  const _DetailPoster({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        border: Border.all(color: tokens.brickYellow, width: 3),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
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
      ),
    );
  }
}

class DetailBackdropLayer extends StatelessWidget {
  const DetailBackdropLayer({super.key, required this.item});

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
                Colors.black.withValues(alpha: 0.08),
                tokens.background.withValues(alpha: 0.38),
                tokens.background.withValues(alpha: 0.82),
                tokens.background.withValues(alpha: 0.94),
              ],
              stops: const [0, 0.38, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class DetailMetadataChip extends StatelessWidget {
  const DetailMetadataChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.all(color: tokens.cardBorder, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(fontFamily: AppFonts.pixelLabel, fontSize: 12),
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.item, required this.tokens});

  final MediaItem item;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final remaining = Duration(
      milliseconds: (item.playbackDurationMs - item.playbackPositionMs)
          .clamp(0, item.playbackDurationMs)
          .toInt(),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: item.playbackProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                color: tokens.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '已观看 ${(item.playbackProgress * 100).round()}% · 剩余 '
            '${formatDuration(remaining)}',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DetailScoreBlock extends StatelessWidget {
  const DetailScoreBlock({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppTokens.candyGradient,
          ).createShader(bounds),
          child: Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontFamily: AppFonts.pixelLatin,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'TMDB 评分',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
