import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/settings_controller.dart';
import 'package:moviehub/core/settings/app_settings_store.dart';
import 'package:moviehub/core/settings/holiday_calendar.dart';
import 'package:moviehub/core/system/platform_services.dart';
import 'package:moviehub/theme/app_theme.dart';
import 'package:moviehub/ui/widgets/screen_time_overlay.dart';

class _FakeHolidayCalendar extends HolidayCalendar {
  _FakeHolidayCalendar(this.payload);

  final String payload;

  @override
  Future<String> fetchYear(int year) async => payload;

  @override
  void close() {}
}

class _MemorySettingsStore extends AppSettingsStore {
  AppSettings settings = AppSettings.empty;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

class _FakeStartupService implements StartupService {
  _FakeStartupService({this.failOnSet = false});

  final bool failOnSet;
  var enabled = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    if (failOnSet) {
      throw UnsupportedError('nope');
    }
    enabled = value;
  }
}

void main() {
  const payload = '''
  {
    "year": 2026,
    "region": "CN",
    "dates": [
      {
        "date": "2026-01-04",
        "name_cn": "元旦补班",
        "type": "transfer_workday"
      }
    ]
  }
  ''';

  test('只累计实际播放时长，暂停不计时且完成后才扣次数', () async {
    final directory = await Directory.systemTemp.createTemp(
      'moviehub-settings-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = AppSettingsStore(storageDirectory: directory);
    var now = DateTime(2026, 1, 4, 10);

    final controller = SettingsController(
      store: store,
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => now,
    );
    await controller.load();
    await controller.saveManagementPassword(password: '', newPassword: '1234');
    await controller.saveScreenTimeLimits(
      watchLimitMinutes: 30,
      breakMinutes: 30,
      workdayDailyWatchLimit: 1,
      restDayDailyWatchLimit: 3,
      password: '1234',
    );

    expect(controller.todayDayTypeLabel, '元旦补班（补班）');
    expect(await controller.startViewingSession(), isTrue);
    expect(controller.todayViewingCount, 0);

    await controller.setPlaybackActive(true);
    now = now.add(const Duration(minutes: 20));
    await controller.setPlaybackActive(false);

    expect(controller.currentViewingElapsed, const Duration(minutes: 20));
    expect(controller.todayViewingCount, 0);
    expect(controller.breakActive, isFalse);
    controller.dispose();

    now = now.add(const Duration(hours: 1));

    var restored = SettingsController(
      store: store,
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => now,
    );
    await restored.load();

    expect(restored.currentViewingElapsed, const Duration(minutes: 20));
    expect(restored.todayViewingCount, 0);
    expect(await restored.startViewingSession(), isTrue);

    await restored.setPlaybackActive(true);
    now = now.add(const Duration(minutes: 10));
    await restored.setPlaybackActive(false);

    expect(restored.currentViewingElapsed, Duration.zero);
    expect(restored.todayViewingCount, 1);
    expect(restored.breakActive, isTrue);
    expect(restored.showBreakOverlay, isTrue);

    restored.dismissBreakOverlay();
    expect(restored.breakActive, isTrue);
    expect(restored.showBreakOverlay, isFalse);
    expect(await restored.startViewingSession(), isFalse);
    expect(restored.showBreakOverlay, isTrue);
    restored.dismissBreakOverlay();

    now = now.add(const Duration(minutes: 30));
    await restored.refreshScreenTimeState();

    expect(restored.breakActive, isFalse);
    expect(await restored.startViewingSession(), isFalse);
    expect(await restored.setPlaybackActive(true), isFalse);

    expect(restored.workdayDailyWatchLimit, 1);
    expect(
      await restored.saveTodayTemporaryWatchLimit(
        watchLimit: 2,
        password: '1234',
      ),
      isTrue,
    );
    expect(restored.todayDailyWatchLimit, 2);
    expect(restored.workdayDailyWatchLimit, 1);
    expect(restored.hasTodayTemporaryWatchLimit, isTrue);
    expect(await restored.startViewingSession(), isTrue);

    restored.dispose();
    restored = SettingsController(
      store: store,
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => now,
    );
    await restored.load();
    expect(restored.todayDailyWatchLimit, 2);
    expect(restored.workdayDailyWatchLimit, 1);
    expect(restored.hasTodayTemporaryWatchLimit, isTrue);

    now = now.add(const Duration(days: 1));
    expect(restored.todayDailyWatchLimit, 1);
    expect(restored.hasTodayTemporaryWatchLimit, isFalse);
    expect(await restored.startViewingSession(), isTrue);
    restored.dispose();
  });

  test('休息日完成一轮并休息后仍保留另外两次机会', () async {
    final directory = await Directory.systemTemp.createTemp(
      'moviehub-rest-day-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    var now = DateTime(2026, 1, 3, 10);
    final controller = SettingsController(
      store: AppSettingsStore(storageDirectory: directory),
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => now,
    );
    await controller.load();
    await controller.saveManagementPassword(password: '', newPassword: '1234');
    await controller.saveScreenTimeLimits(
      watchLimitMinutes: 1,
      breakMinutes: 1,
      workdayDailyWatchLimit: 1,
      restDayDailyWatchLimit: 3,
      password: '1234',
    );

    expect(await controller.startViewingSession(), isTrue);
    expect(await controller.setPlaybackActive(true), isTrue);
    now = now.add(const Duration(minutes: 1));
    await controller.setPlaybackActive(false);

    expect(controller.todayViewingCount, 1);
    expect(controller.todayRemainingViewings, 2);
    expect(controller.breakActive, isTrue);

    now = now.add(const Duration(minutes: 1));
    await controller.refreshScreenTimeState();

    expect(await controller.startViewingSession(), isTrue);
    expect(await controller.setPlaybackActive(true), isTrue);
    controller.dispose();
  });

  test('设置解锁后免二次验证，离开设置后立即恢复锁定', () async {
    final directory = await Directory.systemTemp.createTemp(
      'moviehub-settings-gate-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final controller = SettingsController(
      store: AppSettingsStore(storageDirectory: directory),
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => DateTime(2026, 7, 20, 10),
    );
    await controller.load();
    await controller.saveManagementPassword(password: '', newPassword: '1234');

    expect(controller.settingsUnlocked, isFalse);
    expect(controller.unlockSettings('0000'), isFalse);
    expect(controller.unlockSettings('1234'), isTrue);
    expect(controller.settingsUnlocked, isTrue);
    expect(
      await controller.saveScreenTimeLimits(
        watchLimitMinutes: 30,
        breakMinutes: 20,
        workdayDailyWatchLimit: 2,
        restDayDailyWatchLimit: 4,
        password: '',
      ),
      isTrue,
    );

    controller.lockSettings();
    expect(controller.settingsUnlocked, isFalse);
    expect(
      await controller.saveScreenTimeLimits(
        watchLimitMinutes: 25,
        breakMinutes: 15,
        workdayDailyWatchLimit: 1,
        restDayDailyWatchLimit: 3,
        password: '',
      ),
      isFalse,
    );
    controller.dispose();
  });

  testWidgets('最后一次用完显示大弹窗但不倒计，增加次数后恢复休息倒计时', (tester) async {
    var now = DateTime(2026, 7, 20, 10);
    final controller = SettingsController(
      store: _MemorySettingsStore(),
      holidayCalendar: _FakeHolidayCalendar(payload),
      now: () => now,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      await controller.load();
      await controller.saveManagementPassword(
        password: '',
        newPassword: '1234',
      );
      await controller.saveScreenTimeLimits(
        watchLimitMinutes: 1,
        breakMinutes: 30,
        workdayDailyWatchLimit: 1,
        restDayDailyWatchLimit: 3,
        password: '1234',
      );
      await controller.startViewingSession();
      await controller.setPlaybackActive(true);
      now = now.add(const Duration(minutes: 1));
      await controller.setPlaybackActive(false);
    });

    expect(controller.dailyViewingLimitReached, isTrue);
    expect(controller.breakActive, isTrue);
    await tester.pumpWidget(_overlayApp(controller));
    expect(find.text('今天的观看时间到啦！'), findsOneWidget);
    expect(find.text('今日 1 次观看机会已全部使用完。'), findsOneWidget);
    expect(find.text('小时'), findsNothing);
    expect(find.text('分钟'), findsNothing);
    expect(find.text('秒'), findsNothing);
    expect(find.textContaining('设置'), findsNothing);
    expect(find.textContaining('增加'), findsNothing);
    expect(find.textContaining('临时'), findsNothing);
    expect(find.textContaining('再次播放'), findsNothing);

    await tester.runAsync(
      () => controller.saveTodayTemporaryWatchLimit(
        watchLimit: 2,
        password: '1234',
      ),
    );
    await tester.pumpWidget(_overlayApp(controller));
    expect(controller.dailyViewingLimitReached, isFalse);
    expect(find.text('时间到啦，休息一下吧！'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);
    expect(find.text('秒'), findsOneWidget);
  });

  test('开机自启动读写走注入的 StartupService', () async {
    final startup = _FakeStartupService()..enabled = true;
    final controller = SettingsController(
      store: _MemorySettingsStore(),
      holidayCalendar: _FakeHolidayCalendar(payload),
      startupService: startup,
      now: () => DateTime(2026, 1, 5, 10),
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.launchAtStartup, isTrue);

    await controller.setLaunchAtStartup(false);
    expect(startup.enabled, isFalse);
    expect(controller.launchAtStartup, isFalse);
    expect(controller.error, isNull);
  });

  test('设置开机自启动失败时保留原值并给出错误', () async {
    final controller = SettingsController(
      store: _MemorySettingsStore(),
      holidayCalendar: _FakeHolidayCalendar(payload),
      startupService: _FakeStartupService(failOnSet: true),
      now: () => DateTime(2026, 1, 5, 10),
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setLaunchAtStartup(true);

    expect(controller.launchAtStartup, isFalse);
    expect(controller.error, contains('设置开机自启动失败'));
  });
}

Widget _overlayApp(SettingsController controller) {
  return MaterialApp(
    theme: buildDarkTheme(),
    home: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SizedBox()),
          ScreenTimeOverlay(settings: controller),
        ],
      ),
    ),
  );
}
