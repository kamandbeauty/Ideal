import 'jalali.dart';
import 'persian_digits.dart';

/// Persian (Jalali) date and clock formatting used across the UI.
abstract final class PersianDate {
  /// e.g. `۱۴۰۵/۰۸/۲۵`
  static String shortDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits(
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
    );
  }

  /// e.g. `۲۵ آبان ۱۴۰۵`
  static String longDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    final month = jalaliMonthNames[j.month - 1];
    return toPersianDigits('${j.day} $month ${j.year}');
  }

  /// e.g. `دوشنبه، ۲۵ آبان`
  static String weekdayDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    final month = jalaliMonthNames[j.month - 1];
    // DateTime.weekday: Monday == 1 ... Sunday == 7.
    final weekday = persianWeekdayNames[date.weekday - 1];
    return toPersianDigits('$weekday، ${j.day} $month');
  }

  /// e.g. `۰۹:۰۵`
  static String clock(DateTime time, {bool withSeconds = false}) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (!withSeconds) return toPersianDigits('$hour:$minute');
    final second = time.second.toString().padLeft(2, '0');
    return toPersianDigits('$hour:$minute:$second');
  }

  /// Relative phrasing used in lists: «همین حالا»، «۱۲ دقیقه پیش»، «دیروز»، …
  static String relative(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final difference = reference.difference(date);
    if (difference.isNegative) {
      final future = date.difference(reference);
      if (future.inMinutes < 1) return 'همین لحظه';
      if (future.inMinutes < 60) return '${toPersianDigits(future.inMinutes)} دقیقهٔ دیگر';
      if (future.inHours < 24) return '${toPersianDigits(future.inHours)} ساعت دیگر';
      return '${toPersianDigits(future.inDays)} روز دیگر';
    }
    if (difference.inSeconds < 60) return 'همین حالا';
    if (difference.inMinutes < 60) return '${toPersianDigits(difference.inMinutes)} دقیقه پیش';
    if (difference.inHours < 24) return '${toPersianDigits(difference.inHours)} ساعت پیش';
    final startOfToday = DateTime(reference.year, reference.month, reference.day);
    final startOfDate = DateTime(date.year, date.month, date.day);
    final dayGap = startOfToday.difference(startOfDate).inDays;
    if (dayGap == 1) return 'دیروز';
    if (dayGap < 7) return '${toPersianDigits(dayGap)} روز پیش';
    return longDate(date);
  }

  /// Friendly label used in the jobs list: «امروز ۰۸:۰۰» / «فردا ۱۰:۰۰».
  static String scheduleLabel(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final startOfToday = DateTime(reference.year, reference.month, reference.day);
    final startOfDate = DateTime(date.year, date.month, date.day);
    final dayGap = startOfDate.difference(startOfToday).inDays;
    final time = clock(date);
    if (dayGap == 0) return 'امروز $time';
    if (dayGap == 1) return 'فردا $time';
    if (dayGap == -1) return 'دیروز $time';
    if (dayGap > 1 && dayGap < 7) {
      return '${persianWeekdayNames[date.weekday - 1]} $time';
    }
    return '${longDate(date)}، $time';
  }

  /// Time-of-day greeting: «صبح بخیر» / «ظهر بخیر» / «عصر بخیر» / «شب بخیر».
  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 5) return 'شب بخیر';
    if (hour < 12) return 'صبح بخیر';
    if (hour < 15) return 'ظهر بخیر';
    if (hour < 19) return 'عصر بخیر';
    return 'شب بخیر';
  }

  /// Start of the calendar day containing [date].
  static DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Adds [days] calendar days, keeping the local wall clock time.
  static DateTime addDays(DateTime date, int days) => DateTime(
        date.year,
        date.month,
        date.day + days,
        date.hour,
        date.minute,
        date.second,
      );
}
