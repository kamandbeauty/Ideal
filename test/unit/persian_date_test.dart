import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/persian_date.dart';

void main() {
  final sample = DateTime(2026, 11, 16, 9, 5);

  test('shortDate formats a Jalali date with Persian digits', () {
    expect(PersianDate.shortDate(sample), '۱۴۰۵/۰۸/۲۵');
  });

  test('longDate uses Persian month names', () {
    expect(PersianDate.longDate(sample), '۲۵ آبان ۱۴۰۵');
  });

  test('weekdayDate knows Persian weekday names', () {
    // 2026-11-16 is a Monday.
    expect(PersianDate.weekdayDate(sample), contains('دوشنبه'));
  });

  test('clock pads hours and minutes', () {
    expect(PersianDate.clock(sample), '۰۹:۰۵');
  });

  test('relative describes recent times', () {
    final now = DateTime(2026, 11, 16, 12, 0);
    expect(PersianDate.relative(now.subtract(const Duration(seconds: 20)), now: now),
        'همین حالا');
    expect(PersianDate.relative(now.subtract(const Duration(minutes: 12)), now: now),
        '۱۲ دقیقه پیش');
    expect(PersianDate.relative(now.subtract(const Duration(hours: 3)), now: now),
        '۳ ساعت پیش');
    expect(PersianDate.relative(DateTime(2026, 11, 15, 20), now: now), 'دیروز');
  });

  test('scheduleLabel distinguishes today and tomorrow', () {
    final now = DateTime(2026, 11, 16, 12, 0);
    expect(PersianDate.scheduleLabel(DateTime(2026, 11, 16, 18, 30), now: now),
        'امروز ۱۸:۳۰');
    expect(PersianDate.scheduleLabel(DateTime(2026, 11, 17, 9, 0), now: now),
        'فردا ۰۹:۰۰');
  });

  test('greeting follows the hour of day', () {
    expect(PersianDate.greeting(DateTime(2026, 11, 16, 7)), 'صبح بخیر');
    expect(PersianDate.greeting(DateTime(2026, 11, 16, 13)), 'ظهر بخیر');
    expect(PersianDate.greeting(DateTime(2026, 11, 16, 17)), 'عصر بخیر');
    expect(PersianDate.greeting(DateTime(2026, 11, 16, 22)), 'شب بخیر');
  });

  test('addDays keeps the wall-clock time across month boundaries', () {
    final result = PersianDate.addDays(DateTime(2026, 11, 30, 8, 15), 2);
    expect(result, DateTime(2026, 12, 2, 8, 15));
  });
}
