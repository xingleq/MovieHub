import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Builds the dark theme. A light theme can later be added by defining
/// `AppTokens.light`, a `buildLightTheme()`, and wiring `themeMode` — the
/// widget layer reads colors via `AppTokens.of(context)` and needs no changes.
ThemeData buildDarkTheme() {
  const tokens = AppTokens.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: Brightness.dark,
  ).copyWith(surface: tokens.surface);

  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    extensions: const [tokens],
    cardTheme: CardThemeData(
      color: tokens.surface,
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: tokens.cardBorder),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: tokens.accent.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: tokens.accent),
      unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
      selectedLabelTextStyle: TextStyle(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: tokens.textSecondary),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tokens.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        borderSide: BorderSide(color: tokens.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        borderSide: BorderSide(color: tokens.cardBorder),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: tokens.textPrimary,
      displayColor: tokens.textPrimary,
    ),
  );
}
