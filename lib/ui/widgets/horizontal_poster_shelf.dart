import 'package:flutter/material.dart';

import '../../core/media/media_group.dart';
import '../../core/media/media_item.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import 'cached_tmdb_image.dart';
import 'poster_placeholder.dart';

/// 横向滚动的海报架，带乐高风格边框
class HorizontalPosterShelf extends StatelessWidget {
  const HorizontalPosterShelf({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.icon,
  });

  final String title;
  final List<dynamic> items; // MediaItem 或 MediaGroup
  final ValueChanged<dynamic> onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24, color: tokens.accent),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return _PosterCard(
                item: item,
                onTap: () => onTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatefulWidget {
  const _PosterCard({
    required this.item,
    required this.onTap,
  });

  final dynamic item; // MediaItem 或 MediaGroup
  final VoidCallback onTap;

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  var _focused = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final highlighted = _focused || _hovered;

    // 获取海报路径和标题
    String? posterPath;
    String title;

    if (widget.item is MediaItem) {
      final mediaItem = widget.item as MediaItem;
      posterPath = mediaItem.posterPath;
      title = mediaItem.tmdbTitle ?? mediaItem.seriesTitle ?? mediaItem.title;
    } else if (widget.item is MediaGroup) {
      final group = widget.item as MediaGroup;
      posterPath = group.representative.posterPath;
      title = group.title;
    } else {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedScale(
          scale: highlighted ? 1.08 : 1.0,
          duration: AppDurations.hover,
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
                border: Border.all(
                  color: highlighted ? tokens.accent : tokens.cardBorder,
                  width: highlighted ? 3 : 2,
                ),
                boxShadow: [
                  if (highlighted)
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.42),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  else
                    BoxShadow(
                      color: tokens.scrim.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.sm),
                        ),
                        child: posterPath != null && posterPath.isNotEmpty
                            ? CachedTmdbImage(
                                url: TmdbClient.posterUrl(posterPath),
                                cacheWidth: 300,
                                placeholderIconSize: 32,
                              )
                            : const PosterPlaceholder(iconSize: 32),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      0,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
