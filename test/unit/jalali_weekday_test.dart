import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/jalali.dart';

void main() {
  test('Persian weekday names line up with DateTime.weekday', () {
    // persianWeekdayNames is indexed with weekday - 1.
    expect(persianWeekdayNames[DateTime.monday - 1], 'دوشنبه');
    expect(persianWeekdayNames[DateTime.tuesday - 1], 'سه‌شنبه');
    expect(persianWeekdayNames[DateTime.wednesday - 1], 'چهارشنبه');
    expect(persianWeekdayNames[DateTime.thursday - 1], 'پنجشنبه');
    expect(persianWeekdayNames[DateTime.friday - 1], 'جمعه');
    expect(persianWeekdayNames[DateTime.saturday - 1], 'شنبه');
    expect(persianWeekdayNames[DateTime.sunday - 1], 'یکشنبه');
    expect(persianWeekdayNames, hasLength(7));
  });

  test('month names are in calendar order', () {
    expect(jalaliMonthNames.first, 'فروردین');
    expect(jalaliMonthNames[7], 'آبان');
    expect(jalaliMonthNames.last, 'اسفند');
    expect(jalaliMonthNames, hasLength(12));
  });

  test('JalaliDate equality and comparison', () {
    const a = JalaliDate(1405, 8, 25);
    const b = JalaliDate(1405, 8, 25);
    const c = JalaliDate(1405, 9, 1);
    expect(a, b);
    expect(a.compareTo(b), 0);
    expect(a.compareTo(c), lessThan(0));
    expect(a.toString(), '1405-08-25');
  });
}
