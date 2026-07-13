import 'dart:io';

/// Per-user data root shared by every store: `%APPDATA%\MovieHub` on Windows,
/// `~/.moviehub` elsewhere. Single source of truth — do not copy this logic.
Directory defaultAppDataDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.trim().isNotEmpty) {
    return Directory('$appData${Platform.pathSeparator}MovieHub');
  }

  final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
  return Directory('$home${Platform.pathSeparator}.moviehub');
}
