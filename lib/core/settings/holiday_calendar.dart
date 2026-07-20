import 'dart:convert';
import 'dart:io';

enum HolidayDayType { publicHoliday, transferWorkday }

class HolidayDate {
  const HolidayDate({required this.name, required this.type});

  final String name;
  final HolidayDayType type;
}

class HolidayCalendar {
  HolidayCalendar({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  static const _baseUrl = 'https://unpkg.com/holiday-calendar@1.3.3/data/CN';

  Future<String> fetchYear(int year) async {
    final request = await _client
        .getUrl(Uri.parse('$_baseUrl/$year.json'))
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('节假日接口返回 ${response.statusCode}');
    }
    return response.transform(utf8.decoder).join();
  }

  static Map<String, HolidayDate> parse(String payload, {required int year}) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, Object?> || decoded['year'] != year) {
      throw const FormatException('节假日数据年份不匹配');
    }
    final dates = decoded['dates'];
    if (dates is! List<Object?>) {
      throw const FormatException('节假日数据缺少 dates');
    }

    final result = <String, HolidayDate>{};
    for (final value in dates) {
      if (value is! Map<String, Object?>) {
        continue;
      }
      final date = value['date'];
      final type = switch (value['type']) {
        'public_holiday' => HolidayDayType.publicHoliday,
        'transfer_workday' => HolidayDayType.transferWorkday,
        _ => null,
      };
      if (date is! String || type == null || !date.startsWith('$year-')) {
        continue;
      }
      result[date] = HolidayDate(
        name: value['name_cn'] as String? ?? value['name'] as String? ?? '',
        type: type,
      );
    }
    return result;
  }

  void close() => _client.close(force: true);
}

String localDateKey(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}

bool isRestDay(DateTime date, Map<String, HolidayDate> holidayDates) {
  final holiday = holidayDates[localDateKey(date)];
  if (holiday?.type == HolidayDayType.transferWorkday) {
    return false;
  }
  return holiday?.type == HolidayDayType.publicHoliday ||
      date.weekday == DateTime.saturday ||
      date.weekday == DateTime.sunday;
}
