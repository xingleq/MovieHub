import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/media_filename_parser.dart';
import 'package:moviehub/core/media/media_scanner.dart';

void main() {
  test('cleans release metadata from a season folder title', () {
    final info = parseDirectoryName(
      '[GM-Team][国漫][那年那兔那些事儿 第五季][Year Hare Affair 5][1080P]',
    );

    expect(info.seriesTitle, '那年那兔那些事儿');
    expect(info.seasonNumber, 5);
  });

  test('recognizes a trailing episode number as directory-backed evidence', () {
    final episode = parseEpisodeNumber('迪jia.01');

    expect(episode?.value, 1);
    expect(episode?.explicit, isFalse);
  });

  test('recognizes a bracketed release episode number', () {
    final episode = parseEpisodeNumber(
      '[GM-Team][国漫][那年那兔那些事儿 第五季][01][初心涌动][1080P]',
    );

    expect(episode?.value, 1);
    expect(episode?.explicit, isFalse);
  });

  test('scans abbreviated trailing-number files as one series', () async {
    final root = await Directory.systemTemp.createTemp('moviehub_parser_');
    addTearDown(() => root.delete(recursive: true));
    final series = Directory('${root.path}${Platform.pathSeparator}迪迦奥特曼(国语蓝光)')
      ..createSync();
    File(
      '${series.path}${Platform.pathSeparator}迪jia.01.mp4',
    ).writeAsBytesSync([]);
    File(
      '${series.path}${Platform.pathSeparator}迪jia.02.mp4',
    ).writeAsBytesSync([]);

    final result = await MediaScanner().scanRoots([root.path]);
    final episodes = [...result.items]
      ..sort((a, b) => a.episodeNumber!.compareTo(b.episodeNumber!));

    expect(episodes, hasLength(2));
    expect(episodes.map((item) => item.seriesTitle), everyElement('迪迦奥特曼'));
    expect(episodes.map((item) => item.seasonNumber), everyElement(1));
    expect(episodes.map((item) => item.episodeNumber), [1, 2]);
  });
}
