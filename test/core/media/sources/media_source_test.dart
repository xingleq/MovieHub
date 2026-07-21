import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/media/sources/media_source.dart';

void main() {
  group('fileNameOf', () {
    test('两种分隔符都取最后一段', () {
      expect(fileNameOf(r'D:\Movies\奇迹.mkv'), '奇迹.mkv');
      expect(fileNameOf('/home/user/movie.mp4'), 'movie.mp4');
      expect(fileNameOf(r'\\nas\share\clip.ts'), 'clip.ts');
      expect(fileNameOf('plain.mkv'), 'plain.mkv');
    });
  });

  group('fileExtensionOf', () {
    test('折叠大小写', () {
      expect(fileExtensionOf(r'D:\a\b.MKV'), 'mkv');
    });

    test('无扩展名或以点结尾返回空', () {
      expect(fileExtensionOf('noext'), '');
      expect(fileExtensionOf('trailing.'), '');
    });
  });

  group('isVideoFilePath', () {
    test('按扩展名过滤且不区分大小写', () {
      expect(isVideoFilePath(r'D:\x\a.mkv'), isTrue);
      expect(isVideoFilePath(r'D:\x\a.MP4'), isTrue);
      expect(isVideoFilePath(r'D:\x\a.txt'), isFalse);
      expect(isVideoFilePath(r'D:\x\noext'), isFalse);
    });
  });

  group('parentPathOf', () {
    test('保留原始分隔符', () {
      expect(parentPathOf(r'D:\Movies\Sub\a.mkv'), r'D:\Movies\Sub');
      expect(parentPathOf('/home/user/a.mkv'), '/home/user');
      expect(parentPathOf(r'\\nas\share\a.mkv'), r'\\nas\share');
    });

    test('文件系统根保留结尾分隔符，名字为空', () {
      expect(parentPathOf(r'D:\a.mkv'), r'D:\');
      expect(fileNameOf(parentPathOf(r'D:\a.mkv')), '');
      expect(parentPathOf('/a.mkv'), '/');
    });

    test('无分隔符原样返回', () {
      expect(parentPathOf('a.mkv'), 'a.mkv');
    });
  });
}
