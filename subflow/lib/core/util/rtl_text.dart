import 'package:flutter/widgets.dart';

/// Persian/English text helpers.
///
/// Important: SubFlow does **not** reorder or reshape text by hand. Dart's text
/// stack runs the Unicode BiDi algorithm and HarfBuzz shaping, and so does
/// libass for the ASS export. These helpers only answer questions the UI needs
/// (which way to align a block, whether to show a "RTL" hint) so both renderers
/// receive the same *logical* string.
class RtlText {
  const RtlText._();

  static final RegExp _rtlRange = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final RegExp _arabicLetter = RegExp(r'[\u0620-\u064A\u066E-\u06D3]');
  static final RegExp _latinLetter = RegExp(r'[A-Za-z]');

  static bool containsRtl(String text) => _rtlRange.hasMatch(text);

  /// The paragraph direction of the *first strong character*, matching the P2/P3
  /// rules of UAX#9 closely enough for alignment decisions.
  static TextDirection directionOf(String text) {
    for (final int rune in text.runes) {
      final String char = String.fromCharCode(rune);
      if (_arabicLetter.hasMatch(char)) return TextDirection.rtl;
      if (_latinLetter.hasMatch(char)) return TextDirection.ltr;
    }
    return TextDirection.rtl; // Persian-first product default
  }

  /// True for mixed Persian/English captions ("این یک Test است") where the UI
  /// should offer an explicit direction override instead of guessing.
  static bool isMixed(String text) => containsRtl(text) && _latinLetter.hasMatch(text);

  /// Persian digits for display only. Stored text keeps ASCII digits so SRT/ASS
  /// exports and search stay predictable.
  static String toPersianDigits(String input) {
    const List<String> persian = <String>['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(persian[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Collapses repeated spaces and normalises Arabic Yeh/Kaf to Persian so two
  /// visually identical captions cannot produce different search results.
  /// ZWNJ (U+200C) is preserved - removing it would break Persian words.
  static String normalizePersian(String input) {
    return input
        .replaceAll('\u064A', '\u06CC') // Arabic Yeh -> Persian Yeh
        .replaceAll('\u0643', '\u06A9') // Arabic Kaf -> Persian Kaf
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll('\u200B', '')
        .trim();
  }
}
