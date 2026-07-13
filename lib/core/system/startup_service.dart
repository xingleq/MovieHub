import 'dart:io';

class StartupService {
  StartupService._();

  static const _appName = 'MovieHub';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) {
      return false;
    }
    final result = await Process.run('reg', ['query', _runKey, '/v', _appName]);
    return result.exitCode == 0;
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('开机自启动当前仅支持 Windows。');
    }

    if (enabled) {
      final executable = Platform.resolvedExecutable;
      final result = await Process.run('reg', [
        'add',
        _runKey,
        '/v',
        _appName,
        '/t',
        'REG_SZ',
        '/d',
        '"$executable"',
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'reg',
          const [],
          '写入开机自启动失败：${result.stderr}',
          result.exitCode,
        );
      }
      return;
    }

    final result = await Process.run('reg', [
      'delete',
      _runKey,
      '/v',
      _appName,
      '/f',
    ]);
    if (result.exitCode != 0 && await isEnabled()) {
      throw ProcessException(
        'reg',
        const [],
        '移除开机自启动失败：${result.stderr}',
        result.exitCode,
      );
    }
  }
}
