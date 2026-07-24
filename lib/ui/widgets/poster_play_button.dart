import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Shared hover play action used by the home shelf and catalog poster cards.
class PosterPlayButton extends StatelessWidget {
  const PosterPlayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return IconButton(
      tooltip: '播放',
      onPressed: onPressed,
      iconSize: 48,
      icon: Icon(
        Icons.play_circle_outline,
        size: 48,
        color: tokens.brickHighlight,
      ),
    );
  }
}
