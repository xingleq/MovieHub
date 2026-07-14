import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slowly breathing sky-gradient backdrop with twinkling star particles —
/// the ambient layer of the anime-styled UI. Cheap: one repaint boundary,
/// one animation controller.
class CandyBackground extends StatefulWidget {
  const CandyBackground({super.key});

  @override
  State<CandyBackground> createState() => _CandyBackgroundState();
}

class _CandyBackgroundState extends State<CandyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _paletteA = [
    Color(0xFF0C1B31),
    Color(0xFF102847),
    Color(0xFF0C203A),
  ];
  static const _paletteB = [
    Color(0xFF102442),
    Color(0xFF15345A),
    Color(0xFF0E294A),
  ];
  static const _lightPaletteA = [
    Color(0xFFF4FAFF),
    Color(0xFFEAF6FF),
    Color(0xFFF7FBFF),
  ];
  static const _lightPaletteB = [
    Color(0xFFF9FCFF),
    Color(0xFFE5F3FF),
    Color(0xFFF0F8FF),
  ];

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
          final isLight = Theme.of(context).brightness == Brightness.light;
          final t = _controller.value;
          final wave = (math.sin(t * 2 * math.pi) + 1) / 2;
          final from = isLight ? _lightPaletteA : _paletteA;
          final to = isLight ? _lightPaletteB : _paletteB;
          final colors = [
            for (var i = 0; i < from.length; i++)
              Color.lerp(from[i], to[i], wave)!,
          ];
          return CustomPaint(
            foregroundPainter: _StarPainter(t, light: isLight),
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

/// Deterministic star field: positions derive from the star index, so no
/// randomness is needed and every frame is pure a function of time.
class _StarPainter extends CustomPainter {
  _StarPainter(this.time, {required this.light});

  final double time;
  final bool light;

  static const _starCount = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < _starCount; i++) {
      final fx = _fraction(i * 7 + 3);
      final fy = _fraction(i * 13 + 5);
      final phase = _fraction(i * 29 + 11);
      final speed = 0.5 + _fraction(i * 17 + 2);

      final twinkle = (math.sin((time * speed + phase) * 2 * math.pi) + 1) / 2;
      final opacity = light ? 0.05 + twinkle * 0.1 : 0.04 + twinkle * 0.22;
      final radius = 0.8 + _fraction(i * 31 + 7) * 1.6;

      paint.color = (light ? const Color(0xFF5AB4F6) : Colors.white).withValues(
        alpha: opacity,
      );
      canvas.drawCircle(
        Offset(fx * size.width, fy * size.height),
        radius,
        paint,
      );
    }
  }

  /// Pseudo-random but stable fraction in [0, 1).
  static double _fraction(int seed) {
    return (seed * 2654435761 % 1000) / 1000;
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.light != light;
  }
}
