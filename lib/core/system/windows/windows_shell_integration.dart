import 'dart:io';

import '../platform_services.dart';

class WindowsShellIntegration implements ShellIntegration {
  @override
  bool get canRevealInFileManager => true;

  @override
  Future<void> revealInFileManager(String path) async {
    await Process.start('explorer.exe', ['/select,', path]);
  }
}
