import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/app_section.dart';
import 'package:moviehub/theme/app_theme.dart';
import 'package:moviehub/ui/widgets/immersive_top_nav.dart';

void main() {
  testWidgets('搜索会将导航展开为输入框，确认后展示结果浮层', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? query;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ImmersiveTopNav(
              selected: AppSection.home,
              onSelected: (_) {},
              searchResults: const [],
              onSearch: (value) => query = value,
              onOpenResult: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
    expect(find.text('首页'), findsNothing);

    await tester.enterText(find.byType(TextField), '哈利波特');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(query, '哈利波特');
    expect(find.text('没有找到匹配内容'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(query, '');
  });
}
