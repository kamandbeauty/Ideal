import 'jalali.dart';
import 'persian_digits.dart';
import 'persian_number_words.dart';

/// Result of parsing a Persian date expression.
class ParsedDateExpression {
  const ParsedDateExpression({
    required this.date,
    required this.matchedText,
    this.hasExplicitTime = false,
  });

  /// The resolved calendar day at midnight (time is applied separately).
  final DateTime date;
  final String matchedText;

  /// Whether the expression also contained a clock time.
  final bool hasExplicitTime;

  @override
  String toString() => 'ParsedDateExpression($date, "$matchedText")';
}

/// Parses Persian date expressions such as «فردا»، «پس‌فردا»، «۲۵ آبان»،
/// «شنبه»، «سه روز دیگر» or a Jalali date like «۱۴۰۵/۰۸/۲۵».
///
/// The parser is deterministic and local: it never needs an AI round-trip, so
/// reminders keep working offline.
ParsedDateExpression? parsePersianDate(String input, DateTime now) {
  final text = normalizePersianInput(input);

  // 1) Explicit dotted date: 1405/08/25 or 1405-8-25 (also accepts a Gregorian
  //    year by falling back to DateTime when the number cannot be Jalali).
  final dotted = RegExp(r'(1[34]\d{2})[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(text);
  if (dotted != null) {
    final year = int.parse(dotted.group(1)!);
    final month = int.parse(dotted.group(2)!);
    final day = int.parse(dotted.group(3)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      final gregorian = gregorianFromJalali(year, month, day);
      return ParsedDateExpression(
        date: DateTime(gregorian.year, gregorian.month, gregorian.day),
        matchedText: dotted.group(0)!,
      );
    }
  }

  // 2) Relative day words.
  // Longest expressions first: «پس‌فردا» must not match plain «فردا».
  const relatives = <String, int>{
    'پس فردا': 2,
    'پس‌فردا': 2,
    'پریروز': -2,
    'امروز': 0,
    'فردا': 1,
    'دیروز': -1,
  };
  for (final entry in relatives.entries) {
    if (text.contains(entry.key)) {
      final start = DateTime(now.year, now.month, now.day);
      return ParsedDateExpression(
        date: DateTime(start.year, start.month, start.day + entry.value),
        matchedText: entry.key,
      );
    }
  }

  // 3) «N روز/هفته/ماه دیگر» or «بعد از N روز».
  final offset = RegExp(
    r'(\d+|یک|دو|سه|چهار|پنج|شش|هفت|هشت|نه|ده)\s*(روز|هفته|ماه)\s*(دیگر|بعد|بعدش|آینده)?',
  ).firstMatch(text);
  if (offset != null) {
    final amount = PersianNumbers.fromWord(offset.group(1)!);
    final unit = offset.group(2)!;
    if (amount != null) {
      final start = DateTime(now.year, now.month, now.day);
      final days = switch (unit) {
        'هفته' => amount * 7,
        'ماه' => amount * 30,
        _ => amount,
      };
      return ParsedDateExpression(
        date: DateTime(start.year, start.month, start.day + days),
        matchedText: offset.group(0)!,
      );
    }
  }

  // 4) Weekday names («شنبه»، «دوشنبه» …): the next occurrence, today if still
  //    upcoming later in the day is handled by the caller adding a time.
  const weekdays = <String, int>{
    'دوشنبه': DateTime.monday,
    'سه‌شنبه': DateTime.tuesday,
    'سه شنبه': DateTime.tuesday,
    'چهارشنبه': DateTime.wednesday,
    'پنجشنبه': DateTime.thursday,
    'پنج‌شنبه': DateTime.thursday,
    'جمعه': DateTime.friday,
    'شنبه': DateTime.saturday,
    'یکشنبه': DateTime.sunday,
  };
  for (final entry in weekdays.entries) {
    final pattern = RegExp('(^|\\s)${RegExp.escape(entry.key)}(?:\\s|\\u0000|\$)');
    if (pattern.hasMatch('$text\u0000')) {
      final start = DateTime(now.year, now.month, now.day);
      var candidate = start;
      do {
        candidate = DateTime(candidate.year, candidate.month, candidate.day + 1);
      } while (candidate.weekday != entry.value);
      return ParsedDateExpression(date: candidate, matchedText: entry.key);
    }
  }

  // 5) Day + Jalali month name, e.g. «۲۵ آبان» or «پانزدهم آبان».
  final dayMonth = _matchDayAndMonth(text);
  if (dayMonth != null) {
    final (day, month) = dayMonth;
    final jalaliNow = JalaliDate.fromDateTime(now);
    var year = jalaliNow.year;
    if (month < jalaliNow.month || (month == jalaliNow.month && day < jalaliNow.day)) {
      year += 1;
    }
    if (day <= jalaliMonthLength(year, month)) {
      final gregorian = gregorianFromJalali(year, month, day);
      return ParsedDateExpression(
        date: DateTime(gregorian.year, gregorian.month, gregorian.day),
        matchedText: '$day ${jalaliMonthNames[month - 1]}',
      );
    }
  }

  return null;
}

(int, int)? _matchDayAndMonth(String text) {
  // Persian ordinals: اول/یکم … سی‌ویکم
  const ordinalMap = <String, int>{
    'اول': 1, 'یکم': 1, 'دوم': 2, 'سوم': 3, 'چهارم': 4, 'پنجم': 5,
    'ششم': 6, 'هفتم': 7, 'هشتم': 8, 'نهم': 9, 'دهم': 10, 'یازدهم': 11,
    'دوازدهم': 12, 'سیزدهم': 13, 'چهاردهم': 14, 'پانزدهم': 15, 'شانزدهم': 16,
    'هفدهم': 17, 'هجدهم': 18, 'نوزدهم': 19, 'بیستم': 20, 'بیست و یکم': 21,
    'بیست و دوم': 22, 'بیست و سوم': 23, 'بیست و چهارم': 24, 'بیست و پنجم': 25,
    'بیست و ششم': 26, 'بیست و هفتم': 27, 'بیست و هشتم': 28, 'بیست و نهم': 29,
    'سی‌ام': 30, 'سی ام': 30, 'سی و یکم': 31,
  };
  for (var month = 1; month <= 12; month++) {
    final monthName = jalaliMonthNames[month - 1];
    final match = RegExp('([^\\s]+)\\s+$monthName').firstMatch(text);
    if (match == null) continue;
    final dayToken = match.group(1)!.trim();
    final day = ordinalMap[dayToken] ?? int.tryParse(dayToken);
    if (day != null && day >= 1 && day <= 31) return (day, month);
  }
  return null;
}
