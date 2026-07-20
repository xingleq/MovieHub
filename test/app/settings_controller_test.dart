import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/app/settings_controller.dart';
import 'package:moviehub/core/settings/app_settings_store.dart';
import 'package:moviehub/core/settings/holiday_calendar.dart';

class _FakeHolidayCalendar extends HolidayCalendar {
  _FakeHolidayCalendar(this.payload);

  final String payload;

  @override
  Future<String> fetchYear(int year) async => payload;

  @override
  void close() {}
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
}
