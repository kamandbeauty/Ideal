/// Persian/Arabic-Indic digit handling.
///
/// JavidAI always *displays* Persian digits, but stores and parses ASCII
/// digits internally so that comparisons, sorting and JSON stay predictable.
const _persianDigits = <String>['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _arabicDigits = <String>['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts every ASCII digit in [input] to its Persian counterpart.
String toPersianDigits(Object? input) {
  if (input == null) return '';
  final text = input.toString();
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.write(_persianDigits[rune - 0x30]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Converts Persian and Arabic-Indic digits in [input] back to ASCII.
String toAsciiDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final persianIndex = _persianDigits.indexOf(String.fromCharCode(rune));
    if (persianIndex >= 0) {
      buffer.write(persianIndex);
      continue;
    }
    final arabicIndex = _arabicDigits.indexOf(String.fromCharCode(rune));
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

/// Normalises text typed or dictated in Persian: unifies Arabic Yeh/Kaf,
/// removes tatweel, collapses whitespace and converts digits to ASCII.
String normalizePersianInput(String input) {
  var text = toAsciiDigits(input);
  text = text
      .replaceAll('\u064A', '\u06CC') // Arabic yeh -> Persian yeh
      .replaceAll('\u0643', '\u06A9') // Arabic kaf -> Persian kaf
      .replaceAll('\u0640', '') // tatweel
      .replaceAll('\u200F', '') // RLM
      .replaceAll('\u200E', '') // LRM
      .replaceAll('\u200C', ' '); // ZWNJ -> space (for keyword matching only)
  text = text.replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // harakat
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
