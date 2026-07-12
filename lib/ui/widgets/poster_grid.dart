import 'package:flutter/material.dart';

import '../../core/media/media_item.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import 'poster_card.dart';

/// Responsive poster wall. Column count adapts to the available width and the
/// selected poster density.
class PosterGrid extends StatelessWidget {
  const PosterGrid({
    super.key,
    required this.items,
    required this.onOpenDetail,
    required this.onPlay,
    this.posterSize = PosterSize.large,
  });

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpenDetail;
  final ValueChanged<MediaItem> onPlay;
  final PosterSize posterSize;

  /// Vertical space consumed by the two text lines under each poster.
  static const _captionHeight = 46.0;
  static const _spacing = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / posterSize.targetCardWidth)
            .floor()
            .clamp(2, 8)
            .toInt();
        final cellWidth =
            (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        final cellHeight = cellWidth * 1.5 + _captionHeight;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return PosterCard(
              item: item,
              onOpenDetail: () => onOpenDetail(item),
              onPlay: () => onPlay(item),
            );
          },
        );
      },
    );
  }
}
