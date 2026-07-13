import 'package:flutter/material.dart';

import 'app_tokens.dart';

ThemeData buildDarkTheme() {
  return _buildTheme(AppTokens.dark, Brightness.dark);
}

ThemeData buildLightTheme() {
  return _buildTheme(AppTokens.light, Brightness.light);
}

ThemeData _buildTheme(AppTokens tokens, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(surface: tokens.surface);

  final base = ThemeData(useMaterial3: true, brightness: brightness);

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    extensions: [tokens],
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent;
        }
        return tokens.textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.withValues(alpha: 0.35);
        }
        return tokens.surfaceVariant;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
