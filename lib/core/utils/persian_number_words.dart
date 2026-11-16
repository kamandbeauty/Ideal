import 'persian_digits.dart';

/// Persian number-to-words and time-of-day parsing helpers.
///
/// The intent parser needs this to understand «ساعت نه و نیم» or
/// «ساعت ۱۰ و ربع» in addition to plain digits.
abstract final class PersianNumbers {
  static const _ones = <String>[
    'صفر', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه',
    'ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده',
    'هفده', 'هجده', 'نوزده',
  ];
  static const _tens = <String>[
    '', '', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود',
  ];
  static const _hundreds = <String>[
    '', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد',
  ];

  /// Converts a number (0–9999) to Persian words; falls back to digits.
  static String toWords(int value) {
    if (value < 0) return toPersianDigits(value);
    if (value == 0) return _ones[0];
    if (value > 9999) return toPersianDigits(value);
    final parts = <String>[];
    final thousands = value ~/ 1000;
    if (thousands > 0) {
      parts.add(thousands == 1 ? 'هزار' : '${_toWordsBelowThousand(thousands)} هزار');
    }
    final rest = value % 1000;
    if (rest > 0) parts.add(_toWordsBelowThousand(rest));
    return parts.join(' و ');
  }

  static String _toWordsBelowThousand(int value) {
    final parts = <String>[];
    final hundreds = value ~/ 100;
    if (hundreds > 0) parts.add(_hundreds[hundreds]);
    final remainder = value % 100;
    if (remainder > 0) {
      if (remainder < 20) {
        parts.add(_ones[remainder]);
      } else {
        final tens = remainder ~/ 10;
        final ones = remainder % 10;
        parts.add(ones == 0 ? _tens[tens] : '${_tens[tens]} و ${_ones[ones]}');
      }
    }
    return parts.join(' و ');
  }

  /// Maps a Persian number word (۰–۵۹) to its value, if recognised.
  static int? fromWord(String word) {
    final normalized = word.trim();
    if (normalized.isEmpty) return null;
    final asDigits = int.tryParse(toAsciiDigits(normalized));
    if (asDigits != null) return asDigits;
    final index = _ones.indexOf(normalized);
    if (index >= 0) return index;
    final tensIndex = _tens.indexOf(normalized);
    if (tensIndex > 0) return tensIndex * 10;
    // Compound like «بیست و پنج» handled by callers splitting on « و ».
    return null;
  }
}

/// Parsing helpers for Persian clock expressions.
abstract final class PersianTime {
  /// «نه و نیم» → 9:30, «نه و ربع» → 9:15, «نه و بیست دقیقه» → 9:20.
  static (int hour, int minute)? parseClock(String value) {
    var text = toAsciiDigits(value).trim();
    if (text.isEmpty) return null;

    // Remove common prefixes: ساعت، حدوداً، حوالی...
    text = text.replaceAll(RegExp(r'^(ساعت|حدود|حدوداً|حوالی|ساعتِ)\s*'), '').trim();

    var minute = 0;
    final halfMatch = RegExp(r'(.+?)\s*و\s*(نیم|ربع|سی دقیقه|چهل و پنج دقیقه|(.+?)\s*دقیقه)$')
        .firstMatch(text);
    String hourPart = text;
    if (halfMatch != null) {
      hourPart = halfMatch.group(1)!.trim();
      final suffix = halfMatch.group(2)!.trim();
      if (suffix == 'نیم') {
        minute = 30;
      } else if (suffix == 'ربع') {
        minute = 15;
      } else if (suffix == 'سی دقیقه') {
        minute = 30;
      } else if (suffix == 'چهل و پنج دقیقه') {
        minute = 45;
      } else {
        final minutesWord = halfMatch.group(3)!.trim();
        final parsed = PersianNumbers.fromWord(minutesWord);
        if (parsed == null || parsed < 0 || parsed > 59) return null;
        minute = parsed;
      }
    }

    // «۸ صبح» / «۸ شب» / «۸ بعدازظهر»
    var meridiem = '';
    final meridiemMatch =
        RegExp(r'(.+?)\s*(صبح|ظهر|بعد از ظهر|بعدازظهر|عصر|شب|بامداد)$').firstMatch(hourPart);
    if (meridiemMatch != null) {
      hourPart = meridiemMatch.group(1)!.trim();
      meridiem = meridiemMatch.group(2)!.trim();
    }

    final hour = _parseHour(hourPart);
    if (hour == null) return null;
    return (_applyMeridiem(hour, meridiem), minute);
  }

  static int? _parseHour(String text) {
    final normalized = text.trim();
    final asDigits = int.tryParse(toAsciiDigits(normalized).replaceAll(RegExp(r'[^\d]'), ''));
    if (asDigits != null) return asDigits;
    final word = PersianNumbers.fromWord(normalized);
    if (word != null) return word;
    // Compound words like «بیست و یک»
    if (normalized.contains(' و ')) {
      final parts = normalized.split(' و ');
      final base = PersianNumbers.fromWord(parts.first.trim());
      final extra = PersianNumbers.fromWord(parts.last.trim());
      if (base != null && extra != null && extra < 10) return base + extra;
    }
    return null;
  }

  static int _applyMeridiem(int hour, String meridiem) {
    switch (meridiem) {
      case 'صبح':
      case 'بامداد':
        return hour == 12 ? 0 : hour;
      case 'بعد از ظهر':
      case 'بعدازظهر':
      case 'عصر':
        return hour == 12 ? 12 : (hour < 12 ? hour + 12 : hour);
      case 'شب':
        // «۸ شب» means 20:00; «۱۱ شب» means 23:00.
        return hour >= 5 && hour < 12 ? hour + 12 : hour;
      case 'ظهر':
        return hour == 12 ? 12 : hour;
      default:
        return hour;
    }
  }
}
