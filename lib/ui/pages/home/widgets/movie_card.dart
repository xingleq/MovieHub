import 'package:flutter/material.dart';

import '../../../../core/media/media_item.dart';
import '../../../../core/tmdb/tmdb_client.dart';
import '../../../../theme/app_tokens.dart';
import '../../../widgets/cached_tmdb_image.dart';
import 'focus_scale.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.item,
    required this.onFocused,
    required this.onPlay,
    required this.onOpenDetails,
    required this.onToggleFavorite,
    this.autofocus = false,
  });

  static const double posterWidth = 180;
  static const double posterHeight = 270;

  final MediaItem item;
  final VoidCallback onFocused;
  final VoidCallback onPlay;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleFavorite;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      width: 200,
      height: 300,
      child: FocusScale(
        autofocus: autofocus,
        onActivate: onOpenDetails,
        onHighlightChanged: (highlighted) {
          if (highlighted) {
            onFocused();
          }
        },
        builder: (context, status) {
          final highlighted = status.highlighted;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: Container(
                  key: ValueKey('home-poster:${item.sourceId}:${item.path}'),
                  width: posterWidth,
                  height: posterHeight,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.lg),
                    ),
                    border: Border.all(
                      color: highlighted
                          ? tokens.accent
                          : tokens.accent.withValues(alpha: 0.3),
                      width: highlighted ? 6 : 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: highlighted
                            ? tokens.accent.withValues(alpha: 0.9)
                            : tokens.accent.withValues(alpha: 0.2),
                        blurRadius: highlighted ? 40 : 20,
                        spreadRadius: highlighted ? 4 : 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedTmdbImage(
                          url:
                              item.posterPath == null ||
                                  item.posterPath!.isEmpty
                              ? null
                              : TmdbClient.posterUrl(item.posterPath!),
                          cacheWidth: 360,
                        ),
                        if (item.playbackProgress > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(AppRadius.sm),
                                ),
                                child: LinearProgressIndicator(
                                  value: item.playbackProgress,
                                  minHeight: 6,
                                  color: tokens.accent,
                                  backgroundColor: tokens.brickHighlight
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 276,
                left: 6,
                right: 6,
                child: AnimatedOpacity(
                  opacity: highlighted ? 1 : 0.88,
                  duration: AppDurations.hover,
                  child: Text(
                    item.tmdbTitle ?? item.seriesTitle ?? item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.brickHighlight,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: tokens.scrim, blurRadius: 10)],
                    ),
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
