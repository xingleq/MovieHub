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
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
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
      try {
        _launchAtStartup = await StartupService.isEnabled();
      } catch (_) {
        // Keep the persisted preference when registry probing is unavailable.
      }
      ImageCacheStore.instance.proxy = settings.proxy;
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
