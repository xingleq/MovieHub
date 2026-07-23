import 'package:flutter/material.dart';

import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import 'block_asset.dart';

/// Gradient placeholder shown where a poster or backdrop is missing or still
/// downloading — the icon pulses gently as a lightweight skeleton.
class PosterPlaceholder extends StatefulWidget {
  const PosterPlaceholder({super.key, this.iconSize = 40});

  final double iconSize;

  @override
  State<PosterPlaceholder> createState() => _PosterPlaceholderState();
}

class _PosterPlaceholderState extends State<PosterPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceVariant,
            tokens.accent.withValues(alpha: 0.16),
          ],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 0.35,
            end: 0.85,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: BlockIcon(
            AppAssets.movie,
            size: widget.iconSize,
            semanticLabel: '影视封面占位',
          ),
        ),
      ),
    );
  }
}
