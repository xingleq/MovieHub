import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Gradient placeholder shown where a poster or backdrop is missing/failed.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key, this.iconSize = 40});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2E35), Color(0xFF14161A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: iconSize,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
