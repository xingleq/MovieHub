import 'dart:io';

import '../platform_services.dart';

class WindowsAppPaths implements AppPaths {
  @override
  Directory get appDataDirectory {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}MovieHub');
    }

    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory('$home${Platform.pathSeparator}.moviehub');
  }

  @override
  bool get supportsScreenshots => true;

  @override
  Directory get screenshotsDirectory {
    final home = Platform.environment['USERPROFILE'] ?? '';
    final separator = Platform.pathSeparator;
    return Directory('$home${separator}Pictures${separator}MovieHub');
  }
}
