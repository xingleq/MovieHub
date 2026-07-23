import 'package:flutter/material.dart';

/// Invariant spacing scale — identical in dark and light, so it lives as plain
/// consts rather than behind [Theme.of].
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Blocky corner-radius scale. Small radii keep controls friendly without
/// losing the hard-edged pixel-brick silhouette.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 26;
  static const double pill = 12;
}

/// Invariant animation durations.
abstract final class AppDurations {
  static const Duration hover = Duration(milliseconds: 140);
  static const Duration fade = Duration(milliseconds: 220);
}

/// Semantic colors that vary between dark and light themes. Exposed as a
/// [ThemeExtension] so a future light theme is a drop-in second instance with
/// no widget changes.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.scrim,
    required this.cardBorder,
    required this.brickRed,
    required this.brickYellow,
    required this.brickGreen,
    required this.brickPurple,
    required this.brickHighlight,
    required this.hardShadow,
    required this.pixelGrid,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color scrim;
  final Color cardBorder;
  final Color brickRed;
  final Color brickYellow;
  final Color brickGreen;
  final Color brickPurple;
  final Color brickHighlight;
  final Color hardShadow;
  final Color pixelGrid;

  /// Night variant of the same toy-brick system.
  static const AppTokens dark = AppTokens(
    background: Color(0xFF14243A),
    surface: Color(0xFF1E2F48),
    surfaceVariant: Color(0xFF2A4261),
    accent: Color(0xFF2D78FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC8CFD8),
    scrim: Color(0xD914243A),
    cardBorder: Color(0xFF54749A),
    brickRed: Color(0xFFFF5A4F),
    brickYellow: Color(0xFFFFC629),
    brickGreen: Color(0xFF2DBE60),
    brickPurple: Color(0xFF8454E8),
    brickHighlight: Color(0xFFFFFFFF),
    hardShadow: Color(0xFF0C315F),
    pixelGrid: Color(0xFF294665),
  );

  static const AppTokens light = AppTokens(
    background: Color(0xFFEFF7FF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF4F9FF),
    accent: Color(0xFF2D78FF),
    textPrimary: Color(0xFF1E2A3A),
    textSecondary: Color(0xFF6B7280),
    scrim: Color(0x991E2A3A),
    cardBorder: Color(0xFFD8E8F8),
    brickRed: Color(0xFFFF5A4F),
    brickYellow: Color(0xFFFFC629),
    brickGreen: Color(0xFF2DBE60),
    brickPurple: Color(0xFF8454E8),
    brickHighlight: Color(0xFFFFFFFF),
    hardShadow: Color(0xFF174A8B),
    pixelGrid: Color(0xFFDDEBFA),
  );

  /// Signature blue brick gradient for primary actions.
  static const List<Color> candyGradient = [
    Color(0xFF2D78FF),
    Color(0xFF28BFD6),
  ];

  /// Warm yellow highlight for ratings, stars and small achievements.
  static const Color cyanAccent = Color(0xFF28BFD6);

  /// Reads the tokens from [context], falling back to [dark] so a missing
  /// extension can never null-crash.
  static AppTokens of(BuildContext context) {
    return Theme.of(context).extension<AppTokens>() ?? dark;
  }

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? scrim,
    Color? cardBorder,
    Color? brickRed,
    Color? brickYellow,
    Color? brickGreen,
    Color? brickPurple,
    Color? brickHighlight,
    Color? hardShadow,
    Color? pixelGrid,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      scrim: scrim ?? this.scrim,
      cardBorder: cardBorder ?? this.cardBorder,
      brickRed: brickRed ?? this.brickRed,
      brickYellow: brickYellow ?? this.brickYellow,
      brickGreen: brickGreen ?? this.brickGreen,
      brickPurple: brickPurple ?? this.brickPurple,
      brickHighlight: brickHighlight ?? this.brickHighlight,
      hardShadow: hardShadow ?? this.hardShadow,
      pixelGrid: pixelGrid ?? this.pixelGrid,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      brickRed: Color.lerp(brickRed, other.brickRed, t)!,
      brickYellow: Color.lerp(brickYellow, other.brickYellow, t)!,
      brickGreen: Color.lerp(brickGreen, other.brickGreen, t)!,
      brickPurple: Color.lerp(brickPurple, other.brickPurple, t)!,
      brickHighlight: Color.lerp(brickHighlight, other.brickHighlight, t)!,
      hardShadow: Color.lerp(hardShadow, other.hardShadow, t)!,
      pixelGrid: Color.lerp(pixelGrid, other.pixelGrid, t)!,
    );
  }
}
