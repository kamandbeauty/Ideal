import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/persian_date_parse.dart';

void main() {
  // Monday, 2026-11-16 (25 Aban 1405), 10:00.
  final now = DateTime(2026, 11, 16, 10, 0);

  test('«امروز» resolves to the current day', () {
    final parsed = parsePersianDate('امروز ساعت ۹', now)!;
    expect(parsed.date, DateTime(2026, 11, 16));
  });

  test('«فردا» resolves to the next day', () {
    expect(parsePersianDate('فردا تماس بگیرم', now)!.date, DateTime(2026, 11, 17));
  });

  test('«پس‌فردا» resolves two days ahead', () {
    expect(parsePersianDate('پس‌فردا جلسه دارم', now)!.date, DateTime(2026, 11, 18));
    expect(parsePersianDate('پس فردا جلسه دارم', now)!.date, DateTime(2026, 11, 18));
  });

  test('day + month names resolve in the Jalali calendar', () {
    final parsed = parsePersianDate('۲۵ آبان یادآوری', now)!;
    // 25 Aban 1405 is today, and the parser rolls forward past today's date only
    // when the day is strictly before today.
    expect(parsed.date, DateTime(2026, 11, 16));
  });

  test('a past Jalali day/month rolls to next year', () {
    final parsed = parsePersianDate('۱۰ فروردین', now)!;
    expect(parsed.date.year, 2027);
    expect(parsed.date.month, 3);
  });

  test('Persian ordinals are understood', () {
    final parsed = parsePersianDate('اول آذر جلسه', now)!;
    expect(parsed.date, DateTime(2026, 11, 22));
  });

  test('weekday names find the next occurrence', () {
    final parsed = parsePersianDate('شنبه مهمانی', now)!;
    expect(parsed.date, DateTime(2026, 11, 21));
  });

  test('«سه روز دیگر» offsets by days', () {
    expect(parsePersianDate('سه روز دیگر', now)!.date, DateTime(2026, 11, 19));
    expect(parsePersianDate('2 هفته بعد', now)!.date, DateTime(2026, 11, 30));
  });

  test('explicit dotted Jalali dates are accepted', () {
    final parsed = parsePersianDate('۱۴۰۵/۰۹/۰۱', now)!;
    expect(parsed.date, DateTime(2026, 11, 22));
  });

  test('returns null when no date expression exists', () {
    expect(parsePersianDate('سلام، چطوری؟', now), isNull);
  });
}
