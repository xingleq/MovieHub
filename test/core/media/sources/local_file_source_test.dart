import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/sources/local_file_source.dart';
import 'package:moviehub/core/media/sources/media_source.dart';

void main() {
  test('递归枚举视频文件并带上大小与修改时间', () async {
    final root = await Directory.systemTemp.createTemp('moviehub-src-');
    addTearDown(() => root.delete(recursive: true));

    final sep = Platform.pathSeparator;
    await File('${root.path}${sep}Movie One.mkv').writeAsBytes([1, 2, 3]);
    await File('${root.path}${sep}notes.txt').writeAsString('ignore');
    final deep = await Directory(
      '${root.path}${sep}Sub${sep}Deep',
    ).create(recursive: true);
    await File('${deep.path}${sep}Clip.mp4').writeAsBytes([1, 2, 3, 4]);

    final listing = await const LocalFileSource().listVideos(root.path);

    expect(listing.skippedPaths, isEmpty);
    expect(listing.entries, hasLength(2));
    final byName = {
      for (final entry in listing.entries) fileNameOf(entry.path): entry,
    };
    expect(byName.keys, containsAll(['Movie One.mkv', 'Clip.mp4']));
    expect(byName['Movie One.mkv']!.sizeBytes, 3);
    expect(byName['Clip.mp4']!.sizeBytes, 4);
    expect(byName['Clip.mp4']!.modifiedAt.isAfter(DateTime(2000)), isTrue);
  });

  test('不存在的根进入 skippedPaths 而不是抛异常', () async {
    final missing =
        '${Directory.systemTemp.path}${Platform.pathSeparator}moviehub-nope';
    final listing = await const LocalFileSource().listVideos(missing);

    expect(listing.entries, isEmpty);
    expect(listing.skippedPaths, [missing]);
  });

  test('id、播放地址与身份键契约', () {
    const source = LocalFileSource();
    expect(source.id, localMediaSourceId);
    expect(source.playbackUriOf(r'D:\a\b.mkv'), r'D:\a\b.mkv');
    expect(source.identityKeyOf(r'D:\A\B.MKV'), r'd:\a\b.mkv');
  });
}
