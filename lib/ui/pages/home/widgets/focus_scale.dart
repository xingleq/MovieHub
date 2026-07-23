import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_tokens.dart';

@immutable
class FocusScaleStatus {
  const FocusScaleStatus({
    required this.hovered,
    required this.focused,
    required this.pressed,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;

  bool get highlighted => hovered || focused;
}

/// Mouse and D-pad interaction wrapper shared by home-page controls.
class FocusScale extends StatefulWidget {
  const FocusScale({
    super.key,
    required this.builder,
    this.onActivate,
    this.onHighlightChanged,
    this.focusNode,
    this.focusScale = 1.08,
    this.hoverScale = 1.03,
    this.autofocus = false,
  });

  final Widget Function(BuildContext context, FocusScaleStatus status) builder;
  final VoidCallback? onActivate;
  final ValueChanged<bool>? onHighlightChanged;
  final FocusNode? focusNode;
  final double focusScale;
  final double hoverScale;
  final bool autofocus;

  @override
  State<FocusScale> createState() => _FocusScaleState();
}

class _FocusScaleState extends State<FocusScale> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  var _hovered = false;
  var _focused = false;
  var _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    final focused = _focusNode.hasFocus;
    if (_focused == focused) {
      return;
    }
    final wasHighlighted = _hovered || _focused;
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    _notifyHighlight(wasHighlighted);
  }

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    final wasHighlighted = _hovered || _focused;
    setState(() => _hovered = value);
    _notifyHighlight(wasHighlighted);
  }

  void _notifyHighlight(bool wasHighlighted) {
    final highlighted = _hovered || _focused;
    if (wasHighlighted != highlighted) {
      widget.onHighlightChanged?.call(highlighted);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = FocusScaleStatus(
      hovered: _hovered,
      focused: _focused,
      pressed: _pressed,
    );
    final scale = _pressed
        ? 0.97
        : _focused
        ? widget.focusScale
        : _hovered
        ? widget.hoverScale
        : 1.0;

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      mouseCursor: widget.onActivate == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
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
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          if (_pressed) {
            setState(() => _pressed = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onActivate == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapCancel: widget.onActivate == null
              ? null
              : () => setState(() => _pressed = false),
          onTapUp: widget.onActivate == null
              ? null
              : (_) {
                  setState(() => _pressed = false);
                  widget.onActivate?.call();
                },
          child: AnimatedScale(
            scale: scale,
            duration: AppDurations.hover,
            curve: Curves.easeOutBack,
            child: widget.builder(context, status),
          ),
        ),
      ),
    );
  }
}
