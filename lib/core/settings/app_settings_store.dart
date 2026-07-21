import 'dart:convert';
import 'dart:io';

import '../system/platform_services.dart';

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
    this.workdayDailyWatchLimit = 1,
    this.restDayDailyWatchLimit = 3,
    this.dailyViewingDate = '',
    this.dailyViewingCount = 0,
    this.temporaryDailyWatchLimitDate = '',
    this.temporaryDailyWatchLimit,
    this.watchElapsedMilliseconds = 0,
    this.holidayCalendarCache = const {},
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

  /// Legacy wall-clock session marker retained only for settings compatibility.
  final DateTime? watchSessionStartedAt;

  /// When non-null and in the future, the whole app is locked until this time.
  final DateTime? breakUntil;

  /// Daily completed-viewing quota. Transfer workdays use the workday value;
  /// weekends and public holidays use the rest-day value.
  final int workdayDailyWatchLimit;
  final int restDayDailyWatchLimit;
  final String dailyViewingDate;
  final int dailyViewingCount;

  /// Optional one-day total quota override; it does not alter configured
  /// workday or rest-day defaults.
  final String temporaryDailyWatchLimitDate;
  final int? temporaryDailyWatchLimit;

  /// Actual playing time accumulated toward the next completed viewing.
  final int watchElapsedMilliseconds;

  /// Raw API responses keyed by year, retained for offline classification.
  final Map<String, String> holidayCalendarCache;

  static const empty = AppSettings(accessToken: '', proxy: '');
}

class AppSettingsStore {
  AppSettingsStore({Directory? storageDirectory})
    : _storageDirectory =
          storageDirectory ?? PlatformServices.instance.paths.appDataDirectory;

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
      workdayDailyWatchLimit: json['workdayDailyWatchLimit'] as int? ?? 1,
      restDayDailyWatchLimit: json['restDayDailyWatchLimit'] as int? ?? 3,
      dailyViewingDate: json['dailyViewingDate'] as String? ?? '',
      dailyViewingCount: json['dailyViewingCount'] as int? ?? 0,
      temporaryDailyWatchLimitDate:
          json['temporaryDailyWatchLimitDate'] as String? ?? '',
      temporaryDailyWatchLimit: json['temporaryDailyWatchLimit'] as int?,
      watchElapsedMilliseconds: json['watchElapsedMilliseconds'] as int? ?? 0,
      holidayCalendarCache: _stringMap(json['holidayCalendarCache']),
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
      'workdayDailyWatchLimit': settings.workdayDailyWatchLimit,
      'restDayDailyWatchLimit': settings.restDayDailyWatchLimit,
      'dailyViewingDate': settings.dailyViewingDate,
      'dailyViewingCount': settings.dailyViewingCount,
      'temporaryDailyWatchLimitDate': settings.temporaryDailyWatchLimitDate,
      'temporaryDailyWatchLimit': settings.temporaryDailyWatchLimit,
      'watchElapsedMilliseconds': settings.watchElapsedMilliseconds,
      'holidayCalendarCache': settings.holidayCalendarCache,
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

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map<String, Object?>) {
      return const {};
    }
    return {
      for (final entry in value.entries)
        if (entry.value is String) entry.key: entry.value! as String,
    };
  }
}
