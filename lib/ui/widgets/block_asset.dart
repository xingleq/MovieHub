import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';

class BlockIcon extends StatelessWidget {
  const BlockIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.semanticLabel,
    this.color,
  }) : fallbackIcon = null;

  BlockIcon.fromMaterial(
    IconData icon, {
    super.key,
    this.size = 24,
    this.semanticLabel,
    this.color,
  }) : asset = _assetFor(icon),
       fallbackIcon = icon;

  final String? asset;
  final IconData? fallbackIcon;
  final double size;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    if (asset == null) {
      return Icon(
        fallbackIcon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      );
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }

  static String? _assetFor(IconData icon) {
    if (icon == Icons.search || icon == Icons.search_rounded) {
      return AppAssets.search;
    }
    if (icon == Icons.home || icon == Icons.home_rounded) {
      return AppAssets.home;
    }
    if (icon == Icons.movie || icon == Icons.movie_rounded) {
      return AppAssets.movie;
    }
    if (icon == Icons.tv || icon == Icons.tv_rounded) {
      return AppAssets.tv;
    }
    if (icon == Icons.favorite || icon == Icons.favorite_rounded) {
      return AppAssets.favorite;
    }
    if (icon == Icons.settings || icon == Icons.settings_rounded) {
      return AppAssets.settings;
    }
    if (icon == Icons.play_arrow || icon == Icons.play_arrow_rounded) {
      return AppAssets.play;
    }
    if (icon == Icons.pause || icon == Icons.pause_rounded) {
      return AppAssets.pause;
    }
    if (icon == Icons.arrow_back || icon == Icons.arrow_back_rounded) {
      return AppAssets.back;
    }
    if (icon == Icons.close || icon == Icons.close_rounded) {
      return AppAssets.close;
    }
    if (icon == Icons.folder ||
        icon == Icons.folder_outlined ||
        icon == Icons.folder_open_outlined) {
      return AppAssets.folder;
    }
    if (icon == Icons.sync || icon == Icons.refresh) {
      return AppAssets.refresh;
    }
    if (icon == Icons.history || icon == Icons.history_rounded) {
      return AppAssets.history;
    }
    if (icon == Icons.timer_outlined || icon == Icons.schedule) {
      return AppAssets.clock;
    }
    if (icon == Icons.lock || icon == Icons.lock_outline) {
      return AppAssets.lock;
    }
    if (icon == Icons.sort) {
      return AppAssets.sort;
    }
    if (icon == Icons.grid_view || icon == Icons.apps) {
      return AppAssets.grid;
    }
    return null;
  }
}

class BlockIllustration extends StatelessWidget {
  const BlockIllustration({
    super.key,
    required this.asset,
    this.size = 160,
    this.semanticLabel,
  });

  const BlockIllustration.mascot({
    super.key,
    this.size = 160,
    this.semanticLabel = '积木风提示图标',
  }) : asset = AppAssets.mascot;

  final String asset;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.brickHighlight,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          semanticsLabel: semanticLabel,
        ),
      ),
    );
  }
}
