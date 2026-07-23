import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';

/// Rebuilds [builder] with the current hover state. Keeps hover-tracking local
/// so hovering one card never rebuilds its siblings.
class Hoverable extends StatefulWidget {
  const Hoverable({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
    this.onActivate,
    this.onHighlightChanged,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  final VoidCallback? onActivate;
  final ValueChanged<bool>? onHighlightChanged;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool hovered) {
    final wasHighlighted = _hovered || _focused;
    setState(() => _hovered = hovered);
    final highlighted = _hovered || _focused;
    if (wasHighlighted != highlighted) {
      widget.onHighlightChanged?.call(highlighted);
    }
  }

  void _setFocused(bool focused) {
    final wasHighlighted = _hovered || _focused;
    setState(() => _focused = focused);
    final highlighted = _hovered || _focused;
    if (wasHighlighted != highlighted) {
      widget.onHighlightChanged?.call(highlighted);
    }
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return FocusableActionDetector(
      mouseCursor: widget.cursor,
      onShowFocusHighlight: _setFocused,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedScale(
          scale: _focused ? 1.06 : 1,
          duration: AppDurations.hover,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            decoration: BoxDecoration(
              color: _focused
                  ? tokens.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: _focused
                  ? Border.all(color: tokens.accent, width: 3)
                  : null,
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.24),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: widget.builder(context, _hovered || _focused),
          ),
        ),
      ),
    );
  }
}
