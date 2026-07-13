import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/images/image_cache_store.dart';
import '../core/settings/app_settings_store.dart';
import '../core/system/startup_service.dart';

/// Owns every user preference: TMDB connection, playback defaults,
/// appearance and system integration. Split from the library state so that
/// changing a setting never rebuilds the poster walls, and library churn
/// (scans, matches, progress saves) never rebuilds MaterialApp.
class SettingsController extends ChangeNotifier {
  SettingsController({AppSettingsStore? store})
    : _store = store ?? AppSettingsStore();

  final AppSettingsStore _store;

  var _loaded = false;
  var _tmdbAccessToken = '';
  var _tmdbProxy = '';
  var _backgroundImagePath = '';
  var _subtitlePreference = 'zh-hans';
  var _audioPreference = 'zh';
  var _themeMode = 'dark';
  var _launchAtStartup = false;
  var _watchLimitMinutes = 45;
  var _breakMinutes = 10;
  var _screenTimePasswordHash = '';
  DateTime? _watchSessionStartedAt;
  DateTime? _breakUntil;
  Timer? _screenTimeTimer;
  String? _error;
  var _disposed = false;

  bool get loaded => _loaded;
  String get tmdbAccessToken => _tmdbAccessToken;
  String get tmdbProxy => _tmdbProxy;
  bool get hasTmdbToken => _tmdbAccessToken.isNotEmpty;
  String get backgroundImagePath => _backgroundImagePath;
  String get subtitlePreference => _subtitlePreference;
  String get audioPreference => _audioPreference;
  String get themeMode => _themeMode;
  bool get launchAtStartup => _launchAtStartup;
  int get watchLimitMinutes => _watchLimitMinutes;
  int get breakMinutes => _breakMinutes;
  bool get hasScreenTimePassword => _screenTimePasswordHash.isNotEmpty;
  bool get breakActive {
    final breakUntil = _breakUntil;
    return breakUntil != null && DateTime.now().isBefore(breakUntil);
  }

  Duration get breakRemaining {
    final breakUntil = _breakUntil;
    if (breakUntil == null) {
      return Duration.zero;
    }
    final remaining = breakUntil.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    _screenTimeTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final settings = await _store.load();
      _tmdbAccessToken = settings.accessToken;
      _tmdbProxy = settings.proxy;
      _backgroundImagePath = settings.backgroundImagePath;
      _subtitlePreference = settings.subtitlePreference;
      _audioPreference = settings.audioPreference;
      _themeMode = settings.themeMode;
      _launchAtStartup = settings.launchAtStartup;
      _watchLimitMinutes = settings.watchLimitMinutes;
      _breakMinutes = settings.breakMinutes;
      _screenTimePasswordHash = settings.screenTimePasswordHash;
      _watchSessionStartedAt = settings.watchSessionStartedAt;
      _breakUntil = settings.breakUntil;
      try {
        _launchAtStartup = await StartupService.isEnabled();
      } catch (_) {
        // Keep the persisted preference when registry probing is unavailable.
      }
      ImageCacheStore.instance.proxy = settings.proxy;
      await _normalizeScreenTimeState();
      _startScreenTimeTimer();
    } catch (error) {
      _error = '读取设置失败：$error';
    }
    _loaded = true;
    notifyListeners();
  }

  AppSettings get _current {
    return AppSettings(
      accessToken: _tmdbAccessToken,
      proxy: _tmdbProxy,
      backgroundImagePath: _backgroundImagePath,
      subtitlePreference: _subtitlePreference,
      audioPreference: _audioPreference,
      themeMode: _themeMode,
      launchAtStartup: _launchAtStartup,
      watchLimitMinutes: _watchLimitMinutes,
      breakMinutes: _breakMinutes,
      screenTimePasswordHash: _screenTimePasswordHash,
      watchSessionStartedAt: _watchSessionStartedAt,
      breakUntil: _breakUntil,
    );
  }

  Future<void> saveTmdbConnection({
    required String accessToken,
    required String proxy,
  }) async {
    _tmdbAccessToken = accessToken.trim();
    _tmdbProxy = proxy.trim();
    await _store.save(_current);

    ImageCacheStore.instance.proxy = _tmdbProxy;
    _error = null;
    notifyListeners();
  }

  /// Persists the default subtitle/audio preferences used by the player
  /// (todo §12/§13 默认中文，可配置).
  Future<void> savePlaybackPreferences({
    String? subtitlePreference,
    String? audioPreference,
  }) async {
    _subtitlePreference = subtitlePreference ?? _subtitlePreference;
    _audioPreference = audioPreference ?? _audioPreference;
    await _store.save(_current);
    notifyListeners();
  }

  Future<void> saveThemeMode(String themeMode) async {
    if (!{'dark', 'light', 'system'}.contains(themeMode)) {
      return;
    }
    _themeMode = themeMode;
    await _store.save(_current);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    try {
      await StartupService.setEnabled(enabled);
      _launchAtStartup = enabled;
      _error = null;
      await _store.save(_current);
      notifyListeners();
    } catch (error) {
      _error = '设置开机自启动失败：$error';
      notifyListeners();
    }
  }

  Future<bool> saveScreenTimeLimits({
    required int watchLimitMinutes,
    required int breakMinutes,
    required String password,
    String? newPassword,
  }) async {
    final trimmedPassword = password.trim();
    final trimmedNewPassword = newPassword?.trim() ?? '';
    if (_screenTimePasswordHash.isEmpty) {
      if (trimmedNewPassword.length < 4) {
        _error = '请设置至少 4 位的管理密码。';
        notifyListeners();
        return false;
      }
      _screenTimePasswordHash = _hashPassword(trimmedNewPassword);
    } else if (_screenTimePasswordHash != _hashPassword(trimmedPassword)) {
      _error = '管理密码不正确，无法修改观看时长。';
      notifyListeners();
      return false;
    }

    _watchLimitMinutes = watchLimitMinutes.clamp(1, 600);
    _breakMinutes = breakMinutes.clamp(1, 600);
    if (trimmedNewPassword.isNotEmpty) {
      if (trimmedNewPassword.length < 4) {
        _error = '新管理密码至少需要 4 位。';
        notifyListeners();
        return false;
      }
      _screenTimePasswordHash = _hashPassword(trimmedNewPassword);
    }
    await _normalizeScreenTimeState();
    await _store.save(_current);
    _error = null;
    _startScreenTimeTimer();
    notifyListeners();
    return true;
  }

  Future<void> startViewingSession() async {
    await _normalizeScreenTimeState();
    if (breakActive || _watchSessionStartedAt != null) {
      return;
    }
    _watchSessionStartedAt = DateTime.now();
    await _store.save(_current);
    _startScreenTimeTimer();
    notifyListeners();
  }

  Future<void> _normalizeScreenTimeState() async {
    final now = DateTime.now();
    final breakUntil = _breakUntil;
    if (breakUntil != null) {
      if (now.isBefore(breakUntil)) {
        return;
      }
      _breakUntil = null;
      _watchSessionStartedAt = null;
      await _store.save(_current);
      return;
    }

    final startedAt = _watchSessionStartedAt;
    if (startedAt == null) {
      return;
    }

    final watchEndsAt = startedAt.add(Duration(minutes: _watchLimitMinutes));
    if (now.isBefore(watchEndsAt)) {
      return;
    }

    final lockUntil = watchEndsAt.add(Duration(minutes: _breakMinutes));
    if (now.isBefore(lockUntil)) {
      _breakUntil = lockUntil;
    } else {
      _watchSessionStartedAt = null;
      _breakUntil = null;
    }
    await _store.save(_current);
  }

  void _startScreenTimeTimer() {
    _screenTimeTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickScreenTime());
    });
  }

  Future<void> _tickScreenTime() async {
    final beforeBreakUntil = _breakUntil;
    final beforeStartedAt = _watchSessionStartedAt;
    await _normalizeScreenTimeState();
    if (beforeBreakUntil != _breakUntil ||
        beforeStartedAt != _watchSessionStartedAt ||
        breakActive) {
      notifyListeners();
    }
  }

  static String _hashPassword(String password) {
    var hash = 0x811c9dc5;
    for (final unit in password.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Lets the user pick a local wallpaper image shown behind the whole app.
  Future<void> pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择背景图片',
      type: FileType.image,
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    await _saveBackgroundImage(path);
  }

  Future<void> clearBackgroundImage() async {
    await _saveBackgroundImage('');
  }

  Future<void> _saveBackgroundImage(String path) async {
    _backgroundImagePath = path;
    await _store.save(_current);
    notifyListeners();
  }
}
