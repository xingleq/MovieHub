import 'dart:convert';
import 'dart:io';

import '../system/app_paths.dart';

/// App-wide user settings: TMDB connection plus playback, appearance and
/// system-integration preferences. JSON keys keep their historical names
/// (`tmdbAccessToken`, …) so existing settings files stay readable.
class AppSettings {
  const AppSettings({
    required this.accessToken,
    required this.proxy,
    this.backgroundImagePath = '',
    this.subtitlePreference = 'zh-hans',
    this.audioPreference = 'zh',
    this.themeMode = 'dark',
    this.launchAtStartup = false,
    this.watchLimitMinutes = 45,
    this.breakMinutes = 10,
    this.screenTimePasswordHash = '',
    this.watchSessionStartedAt,
    this.breakUntil,
  });

  final String accessToken;
  final String proxy;

  /// Optional local wallpaper shown behind the whole app (personal use — the
  /// user picks their own image file).
  final String backgroundImagePath;

  /// Preferred default subtitle: 'zh-hans' | 'zh-hant' | 'en' | 'off'.
  final String subtitlePreference;

  /// Preferred default audio: 'zh' | 'ja' | 'en'.
  final String audioPreference;

  /// App theme mode: 'dark' | 'light' | 'system'.
  final String themeMode;

  /// Whether the app should be launched on Windows sign-in.
  final bool launchAtStartup;

  /// Maximum continuous playback time before a forced break.
  final int watchLimitMinutes;

  /// Forced break duration after [watchLimitMinutes] is reached.
  final int breakMinutes;

  /// Hash for the local guardian password used to change screen-time limits.
  final String screenTimePasswordHash;

  /// Start of the current viewing session. Persisted so restarts cannot reset it.
  final DateTime? watchSessionStartedAt;

  /// When non-null and in the future, the whole app is locked until this time.
  final DateTime? breakUntil;

  static const empty = AppSettings(accessToken: '', proxy: '');
}

class AppSettingsStore {
  AppSettingsStore({Directory? storageDirectory})
    : _storageDirectory = storageDirectory ?? defaultAppDataDirectory();

  final Directory _storageDirectory;

  File get _storageFile {
    return File(
      '${_storageDirectory.path}${Platform.pathSeparator}moviehub_settings.json',
    );
  }

  Future<AppSettings> load() async {
    final file = _storageFile;
    if (!await file.exists()) {
      return AppSettings.empty;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return AppSettings.empty;
    }

    final json = jsonDecode(content) as Map<String, Object?>;
    return AppSettings(
      accessToken: json['tmdbAccessToken'] as String? ?? '',
      proxy: json['tmdbProxy'] as String? ?? '',
      backgroundImagePath: json['backgroundImagePath'] as String? ?? '',
      subtitlePreference: json['subtitlePreference'] as String? ?? 'zh-hans',
      audioPreference: json['audioPreference'] as String? ?? 'zh',
      themeMode: json['themeMode'] as String? ?? 'dark',
      launchAtStartup: json['launchAtStartup'] as bool? ?? false,
      watchLimitMinutes: json['watchLimitMinutes'] as int? ?? 45,
      breakMinutes: json['breakMinutes'] as int? ?? 10,
      screenTimePasswordHash: json['screenTimePasswordHash'] as String? ?? '',
      watchSessionStartedAt: _parseDate(json['watchSessionStartedAt']),
      breakUntil: _parseDate(json['breakUntil']),
    );
  }

  Future<void> save(AppSettings settings) async {
    if (!await _storageDirectory.exists()) {
      await _storageDirectory.create(recursive: true);
    }

    final payload = {
      'tmdbAccessToken': settings.accessToken,
      'tmdbProxy': settings.proxy,
      'backgroundImagePath': settings.backgroundImagePath,
      'subtitlePreference': settings.subtitlePreference,
      'audioPreference': settings.audioPreference,
      'themeMode': settings.themeMode,
      'launchAtStartup': settings.launchAtStartup,
      'watchLimitMinutes': settings.watchLimitMinutes,
      'breakMinutes': settings.breakMinutes,
      'screenTimePasswordHash': settings.screenTimePasswordHash,
      'watchSessionStartedAt': settings.watchSessionStartedAt
          ?.toIso8601String(),
      'breakUntil': settings.breakUntil?.toIso8601String(),
    };
    await _storageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
