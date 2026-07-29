import 'package:flutter/material.dart';

import '../../theme/app_assets.dart';

/// Shared fallback shown when a title has no recognized poster or while its
/// remote poster is loading.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key, this.iconSize = 40});

  // Kept for source compatibility with existing call sites. The fallback is
  // now a complete illustration rather than a scalable icon.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.defaultPoster,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      semanticLabel: '未识别影视默认封面',
    );
  }
}

/// Shared fallback for full-width artwork such as Home and detail backdrops.
class BackdropPlaceholder extends StatelessWidget {
  const BackdropPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.defaultBackdrop,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      semanticLabel: '影视默认背景',
    );
  }
}
