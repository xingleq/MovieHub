import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/theme/app_assets.dart';
import 'package:moviehub/theme/app_theme.dart';
import 'package:moviehub/theme/app_tokens.dart';

void main() {
  testWidgets('全局主题使用像素积木造型与颜色令牌', (tester) async {
    late ThemeData theme;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final tokens = theme.extension<AppTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.background, const Color(0xFFEFF7FF));
    expect(tokens.accent, const Color(0xFF2D78FF));
    expect(tokens.brickYellow, const Color(0xFFFFC629));
    expect(AppRadius.md, 12);
    expect(theme.cardTheme.elevation, 3);
    expect(theme.textTheme.headlineLarge?.fontFamily, AppFonts.pixelChinese);
    expect(theme.focusColor, tokens.brickHighlight.withValues(alpha: 0.1));
    expect(theme.highlightColor, tokens.brickHighlight.withValues(alpha: 0.1));

    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.side.width, 1.5);
    expect(cardShape.borderRadius, BorderRadius.circular(AppRadius.xl));

    final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
    expect(dialogShape.side.width, 2);
    expect(dialogShape.borderRadius, BorderRadius.circular(AppRadius.xl));

    final focusedOverlay = theme.textButtonTheme.style!.overlayColor!.resolve({
      WidgetState.focused,
    });
    final hoveredOverlay = theme.iconButtonTheme.style!.overlayColor!.resolve({
      WidgetState.hovered,
    });
    expect(focusedOverlay, tokens.brickHighlight.withValues(alpha: 0.1));
    expect(hoveredOverlay, tokens.brickHighlight.withValues(alpha: 0.1));
  });
}
