import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/library_controller.dart';
import 'package:moviehub/app/library_scope.dart';
import 'package:moviehub/app/settings_controller.dart';
import 'package:moviehub/app/settings_scope.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_library_store.dart';
import 'package:moviehub/theme/app_theme.dart';
import 'package:moviehub/ui/pages/settings_page.dart';

class _MemoryLibraryStore implements MediaLibraryStorage {
  @override
  Future<MediaLibrarySnapshot> load() async => MediaLibrarySnapshot.empty;

  @override
  Future<void> save(MediaLibrarySnapshot snapshot) async {}

  @override
  Future<void> saveRoots(List<String> roots) async {}

  @override
  Future<void> upsertItems(Iterable<MediaItem> items) async {}
}

void main() {
  testWidgets('设置页宽屏双列、窄屏单列，不再使用分页标签', (tester) async {
    final settings = SettingsController();
    final library = LibraryController(
      settings: settings,
      store: _MemoryLibraryStore(),
    );
    addTearDown(() {
      library.dispose();
      settings.dispose();
    });
    await library.load();

    Future<void> pumpAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: LibraryScope(
              controller: library,
              child: SettingsScope(
                controller: settings,
                child: const SettingsPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAt(const Size(1280, 900));

    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const ValueKey('settings-card-flow')), findsOneWidget);
    expect(find.text('媒体库'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-two-column-grid')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('settings-single-column')), findsNothing);
    expect(find.text('添加目录'), findsOneWidget);
    final firstAction = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加目录'),
    );
    expect(firstAction.autofocus, isTrue);

    await pumpAt(const Size(760, 900));

    expect(find.byKey(const ValueKey('settings-single-column')), findsWidgets);
    expect(
      find.byKey(const ValueKey('settings-two-column-grid')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
