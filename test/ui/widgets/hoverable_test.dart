import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/ui/widgets/hoverable.dart';

void main() {
  testWidgets('键盘焦点放大到 1.06 并可用 Enter 激活', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Hoverable(
              onActivate: () => activated = true,
              builder: (context, highlighted) => SizedBox(
                width: 120,
                height: 60,
                child: ColoredBox(
                  color: highlighted ? Colors.purple : Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.06);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, isTrue);
  });
}
