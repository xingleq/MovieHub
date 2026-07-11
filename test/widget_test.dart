import 'package:flutter_test/flutter_test.dart';

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
}
