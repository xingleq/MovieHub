import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/media_scanner.dart';
import 'package:moviehub/main.dart';

void main() {
  testWidgets('shows the MovieHub home screen', (tester) async {
    await tester.pumpWidget(const MovieHubApp());
    await tester.pump();

    expect(find.byType(MovieHubApp), findsOneWidget);
  });

  test('detects supported video files', () {
    expect(MediaScanner.isVideoPath(r'D:\Movies\Interstellar.2014.mkv'), true);
    expect(MediaScanner.isVideoPath(r'D:\Movies\poster.jpg'), false);
  });

  test('parses TV season and episode from filename', () async {
    final directory = await Directory.systemTemp.createTemp('moviehub_test_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File(
      '${directory.path}${Platform.pathSeparator}Yes.Minister.S01E01.mkv',
    );
    await file.writeAsBytes([0]);

    final item = MediaItem.fromFile(file);

    expect(item.seriesTitle, 'Yes Minister');
    expect(item.seasonNumber, 1);
    expect(item.episodeNumber, 1);
    expect(item.episodeLabel, 'S01E01');
  });
}
