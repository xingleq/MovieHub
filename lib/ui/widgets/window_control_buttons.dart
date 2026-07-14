import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/system/window_controls.dart';
import '../../theme/app_tokens.dart';

class WindowControlButtons extends StatelessWidget {
  const WindowControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(color: tokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
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
            const _ControlDivider(),
            _WindowButton(
              tooltip: '最大化 / 还原',
              icon: Icons.crop_square,
              onPressed: () => unawaited(WindowControls.toggleMaximize()),
            ),
            const _ControlDivider(),
            _WindowButton(
              tooltip: '关闭',
              icon: Icons.close,
              closeButton: true,
              onPressed: () => unawaited(WindowControls.close()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlDivider extends StatelessWidget {
  const _ControlDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: AppTokens.of(context).cardBorder,
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
          fixedSize: const Size(38, 30),
          foregroundColor: closeButton
              ? const Color(0xFFE84D6A)
              : tokens.textSecondary,
          backgroundColor: Colors.transparent,
          hoverColor: closeButton
              ? const Color(0xFFE84D6A).withValues(alpha: 0.16)
              : tokens.surfaceVariant.withValues(alpha: 0.72),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
