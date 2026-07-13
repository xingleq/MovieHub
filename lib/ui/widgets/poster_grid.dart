import 'package:flutter/material.dart';

import '../../core/media/media_group.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import 'entrance.dart';
import 'poster_card.dart';

/// Responsive poster wall over grouped entries. Column count adapts to the
/// available width and the selected poster density; cards enter staggered.
class PosterGrid extends StatelessWidget {
  const PosterGrid({
    super.key,
    required this.groups,
    required this.onOpenDetail,
    required this.onPlay,
    this.posterSize = PosterSize.large,
  });

  final List<MediaGroup> groups;
  final ValueChanged<MediaGroup> onOpenDetail;
  final ValueChanged<MediaGroup> onPlay;
  final PosterSize posterSize;

  /// Vertical space consumed by the two text lines under each poster. Sized
  /// with headroom — a tight value overflows the grid cell by ~1px once real
  /// font metrics land.
  static const _captionHeight = 54.0;
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
          itemCount: groups.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemBuilder: (context, index) {
            final group = groups[index];
            return Entrance(
              delayMs: (index % (columns * 2)) * 35,
              child: PosterCard(
                group: group,
                onOpenDetail: () => onOpenDetail(group),
                onPlay: () => onPlay(group),
              ),
            );
          },
        );
      },
    );
  }
}
