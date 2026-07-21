import 'dart:io';

import '../platform_services.dart';

/// Launch-on-login via the per-user Run registry key.
class WindowsStartupService implements StartupService {
  static const _appName = 'MovieHub';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled() async {
    final result = await Process.run('reg', ['query', _runKey, '/v', _appName]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
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
