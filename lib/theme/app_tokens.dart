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

/// Invariant corner-radius scale. Generous curves for the cute, anime-styled
/// look.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 26;
  static const double pill = 999;
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
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color scrim;
  final Color cardBorder;

  /// Candy palette on a deep violet night sky — dark-first but soft and
  /// playful for a kids' anime wall.
  static const AppTokens dark = AppTokens(
    background: Color(0xFF141220),
    surface: Color(0xFF1E1B30),
    surfaceVariant: Color(0xFF2B2744),
    accent: Color(0xFFFF6B9D),
    textPrimary: Color(0xFFF7F5FF),
    textSecondary: Color(0xFFA8A3C7),
    scrim: Color(0xCC0A0912),
    cardBorder: Color(0x1AFFFFFF),
  );

  /// Signature candy gradient for jelly buttons and the capsule nav
  /// (粉 → 紫 → 蓝).
  static const List<Color> candyGradient = [
    Color(0xFFFF6B9D),
    Color(0xFF9D6BFF),
    Color(0xFF5BC8FF),
  ];

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
    );
  }
}
