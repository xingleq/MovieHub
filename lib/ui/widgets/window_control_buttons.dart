import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/system/window_controls.dart';
import '../../theme/app_tokens.dart';

class WindowControlButtons extends StatelessWidget {
  const WindowControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.64),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowButton(
            tooltip: '最小化',
            icon: Icons.remove,
            onPressed: () => unawaited(WindowControls.minimize()),
          ),
          _WindowButton(
            tooltip: '关闭',
            icon: Icons.close,
            foreground: Colors.white,
            background: const Color(0xFFE84D6A),
            onPressed: () => unawaited(WindowControls.close()),
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.foreground,
    this.background,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          fixedSize: const Size(34, 34),
          foregroundColor: foreground ?? tokens.textSecondary,
          backgroundColor: background,
          hoverColor: background == null
              ? Colors.white.withValues(alpha: 0.08)
              : background!.withValues(alpha: 0.82),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
