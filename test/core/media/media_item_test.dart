import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/media_item.dart';
import 'package:moviehub/core/media/sources/media_source.dart';

Map<String, Object?> _minimalJson() {
  return {
    'path': r'D:\Movies\a.mkv',
    'title': 'a',
    'extension': 'mkv',
    'sizeBytes': 10,
    'modifiedAt': '2026-01-01T00:00:00.000',
    'addedAt': '2026-01-02T00:00:00.000',
  };
}

void main() {
  test('旧数据缺少 sourceId 时回填 local', () {
    final item = MediaItem.fromJson(_minimalJson());
    expect(item.sourceId, localMediaSourceId);
  });

  test('sourceId 随 JSON 往返保留', () {
    final json = _minimalJson()..['sourceId'] = 'nas1';
    final item = MediaItem.fromJson(json);
    expect(item.sourceId, 'nas1');
    expect(MediaItem.fromJson(item.toJson()).sourceId, 'nas1');
  });

  test('copyWith 与 preserveAddedAt 保留 sourceId', () {
    final item = MediaItem.fromJson(_minimalJson()..['sourceId'] = 'nas1');
    expect(item.copyWith(favorite: true).sourceId, 'nas1');
    expect(item.preserveAddedAt(null).sourceId, 'nas1');
  });
}
