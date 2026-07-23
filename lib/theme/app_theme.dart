import 'package:flutter/material.dart';

import 'app_assets.dart';
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
  final blockShape = RoundedRectangleBorder(
    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
  );
  final blockButtonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll(blockShape),
    side: WidgetStateProperty.resolveWith((states) {
      return BorderSide(
        color: states.contains(WidgetState.focused)
            ? tokens.accent
            : tokens.cardBorder,
        width: states.contains(WidgetState.focused) ? 3 : 1.5,
      );
    }),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return 1;
      }
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return 7;
      }
      return 3;
    }),
    shadowColor: WidgetStatePropertyAll(tokens.hardShadow),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return tokens.brickHighlight.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return tokens.brickHighlight.withValues(alpha: 0.1);
      }
      return tokens.surface.withValues(alpha: 0);
    }),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    splashColor: tokens.brickHighlight.withValues(alpha: 0.18),
    highlightColor: tokens.brickHighlight.withValues(alpha: 0.1),
    focusColor: tokens.brickHighlight.withValues(alpha: 0.1),
    hoverColor: tokens.brickHighlight.withValues(alpha: 0.08),
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    extensions: [tokens],
    cardTheme: CardThemeData(
      color: tokens.surface,
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: tokens.accent.withValues(alpha: 0.18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
        side: BorderSide(color: tokens.cardBorder, width: 1.5),
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
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        borderSide: BorderSide(color: tokens.cardBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        borderSide: BorderSide(color: tokens.cardBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        borderSide: BorderSide(color: tokens.accent, width: 3),
      ),
    ),
    textTheme: base.textTheme
        .apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            color: tokens.textPrimary,
            fontFamily: AppFonts.pixelChinese,
            fontSize: 48,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            color: tokens.textPrimary,
            fontFamily: AppFonts.pixelChinese,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            color: tokens.textPrimary,
            fontFamily: AppFonts.pixelChinese,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            color: tokens.textPrimary,
            fontFamily: AppFonts.pixelChinese,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: tokens.textPrimary,
            fontSize: 18,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: tokens.textPrimary,
            fontSize: 16,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(style: blockButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: blockButtonStyle),
    textButtonTheme: TextButtonThemeData(style: blockButtonStyle),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(blockShape),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: states.contains(WidgetState.focused)
                ? tokens.accent
                : tokens.cardBorder,
            width: states.contains(WidgetState.focused) ? 3 : 1.5,
          );
        }),
        iconSize: const WidgetStatePropertyAll(22),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return tokens.brickHighlight.withValues(alpha: 0.2);
          }
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered)) {
            return tokens.brickHighlight.withValues(alpha: 0.1);
          }
          return tokens.surface.withValues(alpha: 0);
        }),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      elevation: 12,
      shadowColor: tokens.hardShadow,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
        side: BorderSide(color: tokens.cardBorder, width: 2),
      ),
      titleTextStyle: TextStyle(
        color: tokens.textPrimary,
        fontFamily: AppFonts.pixelChinese,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.surfaceVariant,
      selectedColor: tokens.accent,
      side: BorderSide(color: tokens.cardBorder, width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.surfaceVariant,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: tokens.cardBorder, width: 1.5),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.surface,
      elevation: 10,
      shadowColor: tokens.hardShadow,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: tokens.cardBorder, width: 2),
      ),
      textStyle: TextStyle(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: tokens.cardBorder,
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
