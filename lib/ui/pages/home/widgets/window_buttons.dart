import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/system/platform_services.dart';
import '../../../../theme/app_tokens.dart';

class WindowControlButtons extends StatelessWidget {
  const WindowControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final controls = PlatformServices.instance.windowControls;
    if (!controls.isSupported) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowBrickButton(
          tooltip: '最小化',
          icon: Icons.remove_rounded,
          color: tokens.accent,
          foreground: tokens.brickHighlight,
          onPressed: () => unawaited(controls.minimize()),
        ),
        const SizedBox(width: AppSpacing.sm),
        _WindowBrickButton(
          tooltip: '最大化 / 还原',
          icon: Icons.crop_square_rounded,
          color: tokens.brickYellow,
          foreground: tokens.hardShadow,
          onPressed: () => unawaited(controls.toggleMaximize()),
        ),
        const SizedBox(width: AppSpacing.sm),
        _WindowBrickButton(
          tooltip: '关闭',
          icon: Icons.close_rounded,
          color: tokens.brickRed,
          foreground: tokens.brickHighlight,
          onPressed: () => unawaited(controls.close()),
        ),
      ],
    );
  }
}

class _WindowBrickButton extends StatefulWidget {
  const _WindowBrickButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  State<_WindowBrickButton> createState() => _WindowBrickButtonState();
}

class _WindowBrickButtonState extends State<_WindowBrickButton> {
  var _pressed = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed
                ? 0.95
                : _focused
                ? 1.06
                : 1,
            duration: AppDurations.hover,
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: 46,
              height: 50,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.hardShadow,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.sm),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.sm),
                        ),
                        border: Border.all(
                          color: _focused
                              ? tokens.brickHighlight
                              : widget.color,
                          width: _focused ? 3 : 2,
                        ),
                        boxShadow: _focused
                            ? [
                                BoxShadow(
                                  color: tokens.accent.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                ),
                              ]
                            : const [],
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.foreground,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
