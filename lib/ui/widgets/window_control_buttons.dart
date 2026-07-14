import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/system/window_controls.dart';
import '../../theme/app_tokens.dart';

class WindowControlButtons extends StatelessWidget {
  const WindowControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowButton(
            tooltip: '最小化',
            icon: Icons.remove,
            onPressed: () => unawaited(WindowControls.minimize()),
          ),
          const SizedBox(width: AppSpacing.xs),
          _WindowButton(
            tooltip: '关闭',
            icon: Icons.close,
            closeButton: true,
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
    this.closeButton = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool closeButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          foregroundColor: closeButton
              ? const Color(0xFFE84D6A)
              : tokens.textSecondary,
          backgroundColor: tokens.surface.withValues(alpha: 0.42),
          hoverColor: closeButton
              ? const Color(0xFFE84D6A).withValues(alpha: 0.16)
              : tokens.surfaceVariant.withValues(alpha: 0.36),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
