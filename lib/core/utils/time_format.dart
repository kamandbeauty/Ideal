import 'persian_digits.dart';
import 'jalali.dart';

/// Formatting helpers that are shared by services and widgets.
abstract final class TimeFormat {
  /// «۸ دقیقه» / «۲ ساعت» — a compact human duration in Persian.
  static String humanDuration(Duration duration) {
    if (duration.inMinutes < 1) return 'کمتر از یک دقیقه';
    if (duration.inMinutes < 60) return '${toPersianDigits(duration.inMinutes)} دقیقه';
    if (duration.inHours < 24) {
      final minutes = duration.inMinutes % 60;
      final hours = '${toPersianDigits(duration.inHours)} ساعت';
      return minutes == 0 ? hours : '$hours و ${toPersianDigits(minutes)} دقیقه';
    }
    return '${toPersianDigits(duration.inDays)} روز';
  }

  /// 24h clock with Persian digits, e.g. «۰۹:۰۵».
  static String clock(DateTime time) =>
      toPersianDigits('${_two(time.hour)}:${_two(time.minute)}');

  /// Full Jalali date, e.g. «۲۵ آبان ۱۴۰۵».
  static String jalaliDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits('${j.day} ${jalaliMonthNames[j.month - 1]} ${j.year}');
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
