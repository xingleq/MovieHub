import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/settings/holiday_calendar.dart';

void main() {
  const payload = '''
  {
    "year": 2026,
    "region": "CN",
    "dates": [
      {
        "date": "2026-01-02",
        "name_cn": "元旦",
        "type": "public_holiday"
      },
      {
        "date": "2026-01-04",
        "name_cn": "元旦补班",
        "type": "transfer_workday"
      }
    ]
  }
  ''';

  test('解析法定节假日和补班日期', () {
    final dates = HolidayCalendar.parse(payload, year: 2026);

    expect(dates['2026-01-02']?.name, '元旦');
    expect(dates['2026-01-02']?.type, HolidayDayType.publicHoliday);
    expect(dates['2026-01-04']?.type, HolidayDayType.transferWorkday);
  });

  test('节假日优先于星期，周末补班按工作日处理', () {
    final dates = HolidayCalendar.parse(payload, year: 2026);

    expect(isRestDay(DateTime(2026, 1, 2), dates), isTrue);
    expect(isRestDay(DateTime(2026, 1, 3), dates), isTrue);
    expect(isRestDay(DateTime(2026, 1, 4), dates), isFalse);
    expect(isRestDay(DateTime(2026, 1, 5), dates), isFalse);
  });

  test('拒绝年份不匹配的数据', () {
    expect(
      () => HolidayCalendar.parse(payload, year: 2027),
      throwsFormatException,
    );
  });
}
