import 'dart:convert';
import 'dart:io';

class TmdbSettings {
  const TmdbSettings({
    required this.accessToken,
    required this.proxy,
    this.backgroundImagePath = '',
    this.subtitlePreference = 'zh-hans',
    this.audioPreference = 'zh',
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

  static const empty = TmdbSettings(accessToken: '', proxy: '');
}

class TmdbSettingsStore {
  TmdbSettingsStore({Directory? storageDirectory})
    : _storageDirectory = storageDirectory ?? _defaultStorageDirectory();

  final Directory _storageDirectory;

  File get _storageFile {
    return File(
      '${_storageDirectory.path}${Platform.pathSeparator}moviehub_settings.json',
    );
  }

  Future<TmdbSettings> load() async {
    final file = _storageFile;
    if (!await file.exists()) {
      return TmdbSettings.empty;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return TmdbSettings.empty;
    }

    final json = jsonDecode(content) as Map<String, Object?>;
    return TmdbSettings(
      accessToken: json['tmdbAccessToken'] as String? ?? '',
      proxy: json['tmdbProxy'] as String? ?? '',
      backgroundImagePath: json['backgroundImagePath'] as String? ?? '',
      subtitlePreference: json['subtitlePreference'] as String? ?? 'zh-hans',
      audioPreference: json['audioPreference'] as String? ?? 'zh',
    );
  }

  Future<void> save(TmdbSettings settings) async {
    if (!await _storageDirectory.exists()) {
      await _storageDirectory.create(recursive: true);
    }

    final payload = {
      'tmdbAccessToken': settings.accessToken,
      'tmdbProxy': settings.proxy,
      'backgroundImagePath': settings.backgroundImagePath,
      'subtitlePreference': settings.subtitlePreference,
      'audioPreference': settings.audioPreference,
    };
    await _storageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  static Directory _defaultStorageDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}MovieHub');
    }

    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory('$home${Platform.pathSeparator}.moviehub');
  }
}
