import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/jalali.dart';

void main() {
  group('jalaliFromGregorian', () {
    test('converts the start of Nowruz 1403', () {
      final date = JalaliDate.fromDateTime(DateTime(2024, 3, 20));
      expect(date.year, 1403);
      expect(date.month, 1);
      expect(date.day, 1);
    });

    test('converts a day in Aban 1405', () {
      // 2026-11-16 is 25 Aban 1405.
      final date = JalaliDate.fromDateTime(DateTime(2026, 11, 16));
      expect(date.year, 1405);
      expect(date.month, 8);
      expect(date.day, 25);
    });

    test('handles the last day of Esfand in a leap year', () {
      // 1403 is a leap year: Esfand has 30 days (2025-03-20).
      final date = JalaliDate.fromDateTime(DateTime(2025, 3, 20));
      expect(date.year, 1403);
      expect(date.month, 12);
      expect(date.day, 30);
    });
  });

  group('gregorianFromJalali', () {
    test('round-trips 500 consecutive days', () {
      var gregorian = DateTime(2025, 1, 1);
      for (var i = 0; i < 500; i++) {
        final jalali = JalaliDate.fromDateTime(gregorian);
        final back = jalali.toDateTime();
        expect(back.year, gregorian.year, reason: 'year for ${gregorian.toIso8601String()}');
        expect(back.month, gregorian.month, reason: 'month for ${gregorian.toIso8601String()}');
        expect(back.day, gregorian.day, reason: 'day for ${gregorian.toIso8601String()}');
        gregorian = DateTime(gregorian.year, gregorian.month, gregorian.day + 1);
      }
    });

    test('Nowruz 1404 is 2025-03-21', () {
      final date = gregorianFromJalali(1404, 1, 1);
      expect(date, DateTime(2025, 3, 21));
    });
  });

  group('month lengths', () {
    test('first six months have 31 days', () {
      for (var month = 1; month <= 6; month++) {
        expect(jalaliMonthLength(1405, month), 31);
      }
    });

    test('months seven to eleven have 30 days', () {
      for (var month = 7; month <= 11; month++) {
        expect(jalaliMonthLength(1405, month), 30);
      }
    });

    test('Esfand has 29 days in a common year and 30 in a leap year', () {
      expect(jalaliIsLeapYear(1403), isTrue);
      expect(jalaliMonthLength(1403, 12), 30);
      expect(jalaliIsLeapYear(1404), isFalse);
      expect(jalaliMonthLength(1404, 12), 29);
    });
  });
}
