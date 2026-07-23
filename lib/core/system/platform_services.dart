import 'dart:io';

import 'windows/windows_app_paths.dart';
import 'windows/windows_cursor_service.dart';
import 'windows/windows_session_events.dart';
import 'windows/windows_shell_integration.dart';
import 'windows/windows_startup_service.dart';
import 'windows/windows_window_controls.dart';

/// Native window chrome actions (custom title bar buttons).
///
/// Capability flags ([isSupported] here and on the other services) exist so
/// the UI can hide entry points entirely — never render a control that does
/// nothing or errors when tapped.
abstract interface class WindowControls {
  /// False on platforms without app-managed window chrome (TV, mobile).
  bool get isSupported;

  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
}

/// OS session events: emits 'lock' when the screen locks and 'unlock' when
/// it unlocks. Platforms without the concept emit nothing.
abstract interface class SessionEvents {
  Stream<String> get stream;
}

/// Launch-on-login integration.
abstract interface class StartupService {
  /// False where the app cannot register itself for launch on login; the
  /// settings entry hides itself accordingly.
  bool get isSupported;

  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
}

/// Per-user directories. Single source of truth — do not copy this logic.
///
/// Getters are synchronous by design: a platform whose path lookup is async
/// (Android via path_provider) resolves once at bootstrap and constructs
/// its implementation with the resolved paths.
abstract interface class AppPaths {
  /// Data root shared by every store (`%APPDATA%\MovieHub` on Windows).
  Directory get appDataDirectory;

  /// Whether [screenshotsDirectory] points somewhere the user can actually
  /// find (a real Pictures folder). The player hides its screenshot button
  /// when false.
  bool get supportsScreenshots;

  /// Where player screenshots land.
  Directory get screenshotsDirectory;
}

/// Desktop file-manager integration.
abstract interface class ShellIntegration {
  /// False where no file manager exists (TV, mobile); "打开文件位置"
  /// actions hide themselves accordingly.
  bool get canRevealInFileManager;

  /// Opens the system file manager with [path] selected (or its folder).
  Future<void> revealInFileManager(String path);
}

/// Application-local mouse cursor styling.
///
/// Windows uses an application-local pixel pickaxe inside MovieHub. The player
/// and non-client window edges remain native. TV/mobile implementations are
/// intentionally no-op.
abstract interface class CursorService {
  bool get isSupported;

  Future<void> setPixelStyleEnabled(bool enabled);
}

/// The platform seam: one bundle of per-OS service implementations, picked
/// once per process. New platforms (Android/TV) add a branch in
/// [forCurrentPlatform] with their own implementations — call sites never
/// branch on the OS themselves.
class PlatformServices {
  PlatformServices({
    required this.windowControls,
    required this.sessionEvents,
    required this.startup,
    required this.paths,
    required this.shell,
    CursorService? cursor,
  }) : cursor = cursor ?? const NoopCursorService();

  final WindowControls windowControls;
  final SessionEvents sessionEvents;
  final StartupService startup;
  final AppPaths paths;
  final ShellIntegration shell;
  final CursorService cursor;

  /// Process-wide bundle, lazily created for the running OS. Tests may
  /// replace it wholesale.
  static PlatformServices instance = forCurrentPlatform();

  static PlatformServices forCurrentPlatform() {
    if (Platform.isWindows) {
      return PlatformServices(
        windowControls: WindowsWindowControls(),
        sessionEvents: WindowsSessionEvents(),
        startup: WindowsStartupService(),
        paths: WindowsAppPaths(),
        shell: WindowsShellIntegration(),
        cursor: WindowsCursorService(),
      );
    }
    if (Platform.isMacOS) {
      return _genericDesktop(
        paths: GenericAppPaths(supportsScreenshots: true),
        shell: const GenericShellIntegration.macOs(),
      );
    }
    if (Platform.isLinux) {
      return _genericDesktop(
        paths: GenericAppPaths(supportsScreenshots: true),
        shell: const GenericShellIntegration.xdg(),
      );
    }
    return _genericDesktop(
      paths: GenericAppPaths(),
      shell: const GenericShellIntegration.unsupported(),
    );
  }

  static PlatformServices _genericDesktop({
    required AppPaths paths,
    required ShellIntegration shell,
  }) {
    return PlatformServices(
      windowControls: const NoopWindowControls(),
      sessionEvents: const NoSessionEvents(),
      startup: const UnsupportedStartupService(),
      paths: paths,
      shell: shell,
    );
  }
}

class NoopCursorService implements CursorService {
  const NoopCursorService();

  @override
  bool get isSupported => false;

  @override
  Future<void> setPixelStyleEnabled(bool enabled) async {}
}

/// Fallbacks for platforms without a dedicated implementation — the minimum
/// contract every port must be able to satisfy.
class NoopWindowControls implements WindowControls {
  const NoopWindowControls();

  @override
  bool get isSupported => false;

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}
}

class NoSessionEvents implements SessionEvents {
  const NoSessionEvents();

  @override
  Stream<String> get stream => const Stream.empty();
}

class UnsupportedStartupService implements StartupService {
  const UnsupportedStartupService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {
    throw UnsupportedError('开机自启动当前仅支持 Windows。');
  }
}

class GenericAppPaths implements AppPaths {
  GenericAppPaths({this.supportsScreenshots = false});

  String get _home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;

  @override
  Directory get appDataDirectory {
    return Directory('$_home${Platform.pathSeparator}.moviehub');
  }

  @override
  final bool supportsScreenshots;

  @override
  Directory get screenshotsDirectory {
    final separator = Platform.pathSeparator;
    return Directory('$_home${separator}Pictures${separator}MovieHub');
  }
}

class GenericShellIntegration implements ShellIntegration {
  const GenericShellIntegration.unsupported() : _style = null;
  const GenericShellIntegration.macOs() : _style = _ShellStyle.macOs;
  const GenericShellIntegration.xdg() : _style = _ShellStyle.xdg;

  final _ShellStyle? _style;

  @override
  bool get canRevealInFileManager => _style != null;

  @override
  Future<void> revealInFileManager(String path) async {
    if (_style == _ShellStyle.macOs) {
      await Process.start('open', ['-R', path]);
      return;
    }
    if (_style == _ShellStyle.xdg) {
      await Process.start('xdg-open', [File(path).parent.path]);
      return;
    }
    throw UnsupportedError('当前平台不支持在文件管理器中显示文件。');
  }
}

enum _ShellStyle { macOs, xdg }
