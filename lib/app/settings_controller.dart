import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/images/image_cache_store.dart';
import '../core/settings/app_settings_store.dart';
import '../core/settings/holiday_calendar.dart';
import '../core/system/platform_services.dart';

/// Owns every user preference: TMDB connection, playback defaults,
/// appearance and system integration. Split from the library state so that
/// changing a setting never rebuilds the poster walls, and library churn
/// (scans, matches, progress saves) never rebuilds MaterialApp.
class SettingsController extends ChangeNotifier {
  SettingsController({
    AppSettingsStore? store,
    HolidayCalendar? holidayCalendar,
    StartupService? startupService,
    DateTime Function()? now,
  }) : _store = store ?? AppSettingsStore(),
       _holidayCalendar = holidayCalendar ?? HolidayCalendar(),
       _startup = startupService ?? PlatformServices.instance.startup,
       _now = now ?? DateTime.now;

  final AppSettingsStore _store;
  final HolidayCalendar _holidayCalendar;
  final StartupService _startup;
  final DateTime Function() _now;

  var _loaded = false;
  var _tmdbAccessToken = '';
  var _tmdbProxy = '';
  var _backgroundImagePath = '';
  var _subtitlePreference = 'zh-hans';
  var _audioPreference = 'zh';
  var _themeMode = 'light';
  var _launchAtStartup = false;
  var _watchLimitMinutes = 45;
  var _breakMinutes = 10;
  var _screenTimePasswordHash = '';
  var _settingsUnlocked = false;
  DateTime? _breakUntil;
  var _showBreakOverlay = true;
  var _watchElapsedMilliseconds = 0;
  DateTime? _playbackActiveSince;
  DateTime? _lastProgressSavedAt;
  var _workdayDailyWatchLimit = 1;
  var _restDayDailyWatchLimit = 3;
  var _dailyViewingDate = '';
  var _dailyViewingCount = 0;
  var _temporaryDailyWatchLimitDate = '';
  int? _temporaryDailyWatchLimit;
  Map<String, String> _holidayCalendarCache = {};
  Map<String, HolidayDate> _holidayDates = {};
  int? _holidayYear;
  Timer? _screenTimeTimer;
  var _screenTimeTickInProgress = false;
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
  bool get hasManagementPassword => _screenTimePasswordHash.isNotEmpty;
  bool get settingsUnlocked => _settingsUnlocked;
  int get workdayDailyWatchLimit => _workdayDailyWatchLimit;
  int get restDayDailyWatchLimit => _restDayDailyWatchLimit;
  bool get hasTodayTemporaryWatchLimit {
    return _temporaryDailyWatchLimitDate == localDateKey(_now()) &&
        _temporaryDailyWatchLimit != null;
  }

  int? get todayTemporaryWatchLimit {
    return hasTodayTemporaryWatchLimit ? _temporaryDailyWatchLimit : null;
  }

  Duration get currentViewingElapsed => Duration(
    milliseconds: _watchElapsedMilliseconds + _activePlaybackMilliseconds,
  );
  int get todayDailyWatchLimit => _dailyLimitFor(_now());
  int get todayViewingCount {
    return _dailyViewingDate == localDateKey(_now()) ? _dailyViewingCount : 0;
  }

  int get todayRemainingViewings {
    return (todayDailyWatchLimit - todayViewingCount).clamp(
      0,
      todayDailyWatchLimit,
    );
  }

  bool get dailyViewingLimitReached => todayRemainingViewings == 0;

  String get todayDayTypeLabel {
    final now = _now();
    final holiday = _holidayDates[localDateKey(now)];
    if (holiday != null) {
      final suffix = holiday.type == HolidayDayType.transferWorkday
          ? '补班'
          : '节假日';
      return holiday.name.isEmpty ? suffix : '${holiday.name}（$suffix）';
    }
    return now.weekday == DateTime.saturday || now.weekday == DateTime.sunday
        ? '周末'
        : '工作日';
  }

  bool get breakActive {
    final breakUntil = _breakUntil;
    return breakUntil != null && _now().isBefore(breakUntil);
  }

  bool get showBreakOverlay =>
      _showBreakOverlay && (breakActive || dailyViewingLimitReached);

  Duration get breakRemaining {
    final breakUntil = _breakUntil;
    if (breakUntil == null) {
      return Duration.zero;
    }
    final remaining = breakUntil.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String? get error => _error;

  void dismissBreakOverlay() {
    if (!_showBreakOverlay) {
      return;
    }
    _showBreakOverlay = false;
    notifyListeners();
  }

  void requestBreakOverlay() {
    if ((!breakActive && !dailyViewingLimitReached) || _showBreakOverlay) {
      return;
    }
    _showBreakOverlay = true;
    notifyListeners();
  }

  int get _activePlaybackMilliseconds {
    final activeSince = _playbackActiveSince;
    if (activeSince == null) {
      return 0;
    }
    return _now().difference(activeSince).inMilliseconds.clamp(0, 1 << 31);
  }

  @override
  void dispose() {
    _disposed = true;
    _screenTimeTimer?.cancel();
    _holidayCalendar.close();
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

  bool unlockSettings(String password) {
    if (_screenTimePasswordHash.isEmpty ||
        _screenTimePasswordHash != _hashPassword(password.trim())) {
      _error = _screenTimePasswordHash.isEmpty ? '请先设置管理密码。' : '管理密码不正确。';
      notifyListeners();
      return false;
    }
    _settingsUnlocked = true;
    _error = null;
    notifyListeners();
    return true;
  }

  void lockSettings() {
    if (!_settingsUnlocked) {
      return;
    }
    _settingsUnlocked = false;
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
      _breakUntil = settings.breakUntil;
      _watchElapsedMilliseconds = settings.watchElapsedMilliseconds.clamp(
        0,
        600 * 60 * 1000,
      );
      _workdayDailyWatchLimit = settings.workdayDailyWatchLimit.clamp(1, 99);
      _restDayDailyWatchLimit = settings.restDayDailyWatchLimit.clamp(1, 99);
      _dailyViewingDate = settings.dailyViewingDate;
      _dailyViewingCount = settings.dailyViewingCount.clamp(0, 99);
      _temporaryDailyWatchLimitDate = settings.temporaryDailyWatchLimitDate;
      _temporaryDailyWatchLimit = settings.temporaryDailyWatchLimit?.clamp(
        0,
        99,
      );
      _holidayCalendarCache = Map.of(settings.holidayCalendarCache);
      try {
        _launchAtStartup = await _startup.isEnabled();
      } catch (_) {
        // Keep the persisted preference when registry probing is unavailable.
      }
      ImageCacheStore.instance.proxy = settings.proxy;
      await _ensureHolidayCalendar(_now().year);
      final dailyStateChanged = _normalizeDailyViewingDate(_now());
      await _normalizeBreakState();
      if (dailyStateChanged) {
        await _store.save(_current);
      }
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
      watchSessionStartedAt: null,
      breakUntil: _breakUntil,
      workdayDailyWatchLimit: _workdayDailyWatchLimit,
      restDayDailyWatchLimit: _restDayDailyWatchLimit,
      dailyViewingDate: _dailyViewingDate,
      dailyViewingCount: _dailyViewingCount,
      temporaryDailyWatchLimitDate: _temporaryDailyWatchLimitDate,
      temporaryDailyWatchLimit: _temporaryDailyWatchLimit,
      watchElapsedMilliseconds: _watchElapsedMilliseconds,
      holidayCalendarCache: _holidayCalendarCache,
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
      await _startup.setEnabled(enabled);
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
    required int workdayDailyWatchLimit,
    required int restDayDailyWatchLimit,
    required String password,
  }) async {
    final trimmedPassword = password.trim();
    if (_screenTimePasswordHash.isEmpty) {
      _error = '请先设置管理密码。';
      notifyListeners();
      return false;
    }
    if (!_settingsUnlocked &&
        _screenTimePasswordHash != _hashPassword(trimmedPassword)) {
      _error = '管理密码不正确，无法修改观看时长。';
      notifyListeners();
      return false;
    }

    _watchLimitMinutes = watchLimitMinutes.clamp(1, 600);
    _breakMinutes = breakMinutes.clamp(1, 600);
    _workdayDailyWatchLimit = workdayDailyWatchLimit.clamp(1, 99);
    _restDayDailyWatchLimit = restDayDailyWatchLimit.clamp(1, 99);
    await _updateViewingProgress();
    await _completeViewingIfNeeded();
    await _store.save(_current);
    _error = null;
    _startScreenTimeTimer();
    notifyListeners();
    return true;
  }

  Future<bool> saveTodayTemporaryWatchLimit({
    required int? watchLimit,
    required String password,
  }) async {
    if (_screenTimePasswordHash.isEmpty) {
      _error = '请先设置管理密码。';
      notifyListeners();
      return false;
    }
    if (!_settingsUnlocked &&
        _screenTimePasswordHash != _hashPassword(password.trim())) {
      _error = '管理密码不正确，无法修改今日临时次数。';
      notifyListeners();
      return false;
    }

    if (watchLimit == null) {
      _temporaryDailyWatchLimitDate = '';
      _temporaryDailyWatchLimit = null;
    } else {
      _temporaryDailyWatchLimitDate = localDateKey(_now());
      _temporaryDailyWatchLimit = watchLimit.clamp(0, 99);
    }
    await _store.save(_current);
    _error = null;
    notifyListeners();
    return true;
  }

  bool verifyManagementPassword(String password) {
    if (_settingsUnlocked) {
      _error = null;
      return true;
    }
    if (_screenTimePasswordHash.isEmpty) {
      _error = '请先设置管理密码。';
      notifyListeners();
      return false;
    }
    if (_screenTimePasswordHash != _hashPassword(password.trim())) {
      _error = '管理密码不正确。';
      notifyListeners();
      return false;
    }
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> saveManagementPassword({
    required String password,
    required String newPassword,
  }) async {
    final trimmedPassword = password.trim();
    final trimmedNewPassword = newPassword.trim();
    if (trimmedNewPassword.length < 4) {
      _error = '管理密码至少需要 4 位。';
      notifyListeners();
      return false;
    }
    if (_screenTimePasswordHash.isNotEmpty &&
        !_settingsUnlocked &&
        _screenTimePasswordHash != _hashPassword(trimmedPassword)) {
      _error = '当前管理密码不正确。';
      notifyListeners();
      return false;
    }
    _screenTimePasswordHash = _hashPassword(trimmedNewPassword);
    await _store.save(_current);
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> startViewingSession() async {
    final now = _now();
    final dayChanged = _normalizeDailyViewingDate(now);
    await _normalizeBreakState();
    if (breakActive) {
      requestBreakOverlay();
      return false;
    }

    final dailyLimit = _dailyLimitFor(now);
    if (_dailyViewingCount >= dailyLimit) {
      _error = '今日观看次数已用完（$todayDayTypeLabel每天 $dailyLimit 次）。';
      requestBreakOverlay();
      notifyListeners();
      return false;
    }

    if (dayChanged) {
      await _store.save(_current);
    }
    _error = null;
    _startScreenTimeTimer();
    notifyListeners();
    return true;
  }

  /// Starts or pauses accumulation of actual playback time. Opening the
  /// player does not consume a daily viewing; a viewing is consumed only when
  /// the accumulated playing time reaches [watchLimitMinutes].
  Future<bool> setPlaybackActive(bool active) async {
    await _updateViewingProgress();
    await _normalizeBreakState();

    final wasActive = _playbackActiveSince != null;
    if (active && !wasActive) {
      final now = _now();
      _normalizeDailyViewingDate(now);
      if (!breakActive && _dailyViewingCount < _dailyLimitFor(now)) {
        _playbackActiveSince = now;
        _error = null;
      } else if (!breakActive) {
        final dailyLimit = _dailyLimitFor(now);
        _error = '今日观看次数已用完（$todayDayTypeLabel每天 $dailyLimit 次）。';
        requestBreakOverlay();
      } else {
        requestBreakOverlay();
      }
    } else if (!active && wasActive) {
      _playbackActiveSince = null;
    }

    if (wasActive != (_playbackActiveSince != null)) {
      _lastProgressSavedAt = _now();
      await _store.save(_current);
      notifyListeners();
    }
    return !active || _playbackActiveSince != null;
  }

  Future<void> refreshScreenTimeState() async {
    await _ensureHolidayCalendar(_now().year);
    final beforeBreakUntil = _breakUntil;
    final beforeElapsed = _watchElapsedMilliseconds;
    await _normalizeBreakState();
    await _updateViewingProgress();
    if (beforeBreakUntil != _breakUntil ||
        beforeElapsed != _watchElapsedMilliseconds) {
      notifyListeners();
    }
  }

  int _dailyLimitFor(DateTime date) {
    final temporaryLimit = _temporaryDailyWatchLimit;
    if (_temporaryDailyWatchLimitDate == localDateKey(date) &&
        temporaryLimit != null) {
      return temporaryLimit;
    }
    if (isRestDay(date, _holidayDates)) {
      return _restDayDailyWatchLimit;
    }
    return _workdayDailyWatchLimit;
  }

  Future<void> _ensureHolidayCalendar(int year) async {
    if (_holidayYear == year) {
      return;
    }

    final cached = _holidayCalendarCache['$year'];
    if (cached != null) {
      try {
        _holidayDates = HolidayCalendar.parse(cached, year: year);
        _holidayYear = year;
      } catch (_) {
        _holidayCalendarCache.remove('$year');
      }
    }

    try {
      final payload = await _holidayCalendar.fetchYear(year);
      final dates = HolidayCalendar.parse(payload, year: year);
      _holidayDates = dates;
      _holidayYear = year;
      _holidayCalendarCache['$year'] = payload;
      await _store.save(_current);
    } catch (_) {
      // Cached data remains authoritative while offline. Without a cache,
      // normal Saturdays and Sundays are still treated as rest days.
      _holidayYear = year;
    }
  }

  bool _normalizeDailyViewingDate(DateTime now) {
    final today = localDateKey(now);
    var changed = false;
    if (_dailyViewingDate != today) {
      _dailyViewingDate = today;
      _dailyViewingCount = 0;
      changed = true;
    }
    if (_temporaryDailyWatchLimitDate.isNotEmpty &&
        _temporaryDailyWatchLimitDate != today) {
      _temporaryDailyWatchLimitDate = '';
      _temporaryDailyWatchLimit = null;
      changed = true;
    }
    return changed;
  }

  Future<bool> _normalizeBreakState() async {
    final now = _now();
    final breakUntil = _breakUntil;
    if (breakUntil == null || now.isBefore(breakUntil)) {
      return false;
    }
    _breakUntil = null;
    // A visible final-quota message stays visible until explicitly closed;
    // an ordinary break countdown disappears when the break finishes.
    _showBreakOverlay = _showBreakOverlay && dailyViewingLimitReached;
    await _store.save(_current);
    return true;
  }

  Future<bool> _updateViewingProgress() async {
    final activeSince = _playbackActiveSince;
    if (activeSince == null) {
      return false;
    }

    final now = _now();
    final elapsed = now.difference(activeSince).inMilliseconds;
    _playbackActiveSince = now;
    if (elapsed > 0) {
      _watchElapsedMilliseconds += elapsed;
    }

    if (await _completeViewingIfNeeded()) {
      return true;
    }

    final lastSavedAt = _lastProgressSavedAt;
    if (lastSavedAt == null ||
        now.difference(lastSavedAt) >= const Duration(seconds: 10)) {
      _lastProgressSavedAt = now;
      await _store.save(_current);
    }
    return elapsed > 0;
  }

  Future<bool> _completeViewingIfNeeded() async {
    if (_watchElapsedMilliseconds < _watchLimitMinutes * 60 * 1000) {
      return false;
    }

    final now = _now();
    _normalizeDailyViewingDate(now);
    _watchElapsedMilliseconds = 0;
    _playbackActiveSince = null;
    _dailyViewingCount++;
    _breakUntil = now.add(Duration(minutes: _breakMinutes));
    _showBreakOverlay = true;
    _lastProgressSavedAt = now;
    await _store.save(_current);
    return true;
  }

  void _startScreenTimeTimer() {
    _screenTimeTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickScreenTime());
    });
  }

  Future<void> _tickScreenTime() async {
    if (_screenTimeTickInProgress) {
      return;
    }
    _screenTimeTickInProgress = true;
    final beforeBreakUntil = _breakUntil;
    final beforeElapsed = _watchElapsedMilliseconds;
    try {
      await _normalizeBreakState();
      await _updateViewingProgress();
      if (beforeBreakUntil != _breakUntil ||
          beforeElapsed != _watchElapsedMilliseconds ||
          breakActive) {
        notifyListeners();
      }
    } finally {
      _screenTimeTickInProgress = false;
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
