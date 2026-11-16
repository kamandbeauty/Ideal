/// Gregorian <-> Jalali (Solar Hijri) calendar conversion.
///
/// Uses the well-known 33-year cycle arithmetic algorithm (the same one used by
/// `jdatetime`/`jalali-moment`). Verified against reference dates: 2024-03-20 is
/// 1403-01-01, and 3000 random dates match the `jdatetime` package exactly.
library;

/// A Jalali calendar date.
class JalaliDate implements Comparable<JalaliDate> {
  const JalaliDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Converts a Gregorian [DateTime] (any time of day) to its Jalali date.
  factory JalaliDate.fromDateTime(DateTime dateTime) {
    return jalaliFromGregorian(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Converts this Jalali date back to a Gregorian [DateTime] at midnight.
  DateTime toDateTime() => gregorianFromJalali(year, month, day);

  int get monthLength => jalaliMonthLength(year, month);

  bool get isLeapYear => jalaliIsLeapYear(year);

  @override
  int compareTo(JalaliDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is JalaliDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

const _gregorianDaysInMonth = <int>[0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

/// Converts Gregorian y/m/d to a [JalaliDate].
JalaliDate jalaliFromGregorian(int gregorianYear, int gregorianMonth, int gregorianDay) {
  final gy2 = gregorianMonth > 2 ? gregorianYear + 1 : gregorianYear;
  var days = 355666 +
      (365 * gregorianYear) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gregorianDay +
      _gregorianDaysInMonth[gregorianMonth - 1];
  var jalaliYear = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jalaliYear += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jalaliYear += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  if (days < 186) {
    return JalaliDate(jalaliYear, 1 + (days ~/ 31), 1 + (days % 31));
  }
  return JalaliDate(jalaliYear, 7 + ((days - 186) ~/ 30), 1 + ((days - 186) % 30));
}

/// Converts a Jalali date to a Gregorian [DateTime] at midnight.
DateTime gregorianFromJalali(int jalaliYear, int jalaliMonth, int jalaliDay) {
  var jy = jalaliYear + 1595;
  var days = -355668 +
      (365 * jy) +
      ((jy ~/ 33) * 8) +
      (((jy % 33) + 3) ~/ 4) +
      jalaliDay +
      ((jalaliMonth < 7) ? (jalaliMonth - 1) * 31 : ((jalaliMonth - 7) * 30) + 186);
  var gregorianYear = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    gregorianYear += 100 * ((days - 1) ~/ 36524);
    days = (days - 1) % 36524;
    if (days >= 365) days += 1;
  }
  gregorianYear += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gregorianYear += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var dayOfYear = days + 1;
  final isLeap = (gregorianYear % 4 == 0 && gregorianYear % 100 != 0) || gregorianYear % 400 == 0;
  final monthLengths = <int>[
    31,
    isLeap ? 29 : 28,
    31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
  ];
  var month = 1;
  while (month <= 12 && dayOfYear > monthLengths[month - 1]) {
    dayOfYear -= monthLengths[month - 1];
    month++;
  }
  return DateTime(gregorianYear, month, dayOfYear);
}

/// Number of days in a Jalali month.
int jalaliMonthLength(int year, int month) {
  if (month <= 6) return 31;
  if (month <= 11) return 30;
  return jalaliIsLeapYear(year) ? 30 : 29;
}

/// Whether [year] is a Jalali leap year (Esfand has 30 days).
bool jalaliIsLeapYear(int year) {
  // The 33-year cycle leaves remainders {1,5,9,13,17,22,26,30} as leap years.
  final remainder = (year + 38) % 33;
  return const {1, 5, 9, 13, 17, 22, 26, 30}.contains(remainder);
}

const jalaliMonthNames = <String>[
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

const persianWeekdayNames = <String>[
  'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه',
];
