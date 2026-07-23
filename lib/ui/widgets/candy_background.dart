import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Slowly breathing pixel-brick backdrop. The grid stays subtle so posters
/// remain the visual focus while the shell still feels constructed from blocks.
class CandyBackground extends StatefulWidget {
  const CandyBackground({super.key});

  @override
  State<CandyBackground> createState() => _CandyBackgroundState();
}

class _CandyBackgroundState extends State<CandyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final tokens = AppTokens.of(context);
          final t = _controller.value;
          final wave = (math.sin(t * 2 * math.pi) + 1) / 2;
          final colors = [
            Color.lerp(tokens.background, tokens.surface, wave * 0.45)!,
            Color.lerp(tokens.surface, tokens.surfaceVariant, wave * 0.28)!,
            tokens.background,
          ];
          return CustomPaint(
            foregroundPainter: _PixelFieldPainter(t, tokens: tokens),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _PixelFieldPainter extends CustomPainter {
  _PixelFieldPainter(this.time, {required this.tokens});

  final double time;
  final AppTokens tokens;

  static const _blockCount = 22;
  static const _gridSize = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = tokens.pixelGrid.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += _gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final palette = [
      tokens.accent,
      tokens.brickYellow,
      tokens.brickGreen,
      tokens.brickPurple,
    ];
    final paint = Paint();
    for (var i = 0; i < _blockCount; i++) {
      final fx = _fraction(i * 7 + 3);
      final fy = _fraction(i * 13 + 5);
      final phase = _fraction(i * 29 + 11);
      final speed = 0.5 + _fraction(i * 17 + 2);
      final pulse = (math.sin((time * speed + phase) * 2 * math.pi) + 1) / 2;
      final blockSize = 3.0 + _fraction(i * 31 + 7) * 5;
      paint.color = palette[i % palette.length].withValues(
        alpha: 0.07 + pulse * 0.16,
      );
      canvas.drawRect(
        Rect.fromLTWH(fx * size.width, fy * size.height, blockSize, blockSize),
        paint,
      );
    }
  }

  /// Pseudo-random but stable fraction in [0, 1).
  static double _fraction(int seed) {
    return (seed * 2654435761 % 1000) / 1000;
  }

  @override
  bool shouldRepaint(_PixelFieldPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.tokens != tokens;
  }
}
