import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/persian_digits.dart';

void main() {
  group('toPersianDigits', () {
    test('converts ASCII digits', () {
      expect(toPersianDigits('1405/08/25'), '۱۴۰۵/۰۸/۲۵');
    });

    test('keeps letters and punctuation', () {
      expect(toPersianDigits('ساعت 9:05'), 'ساعت ۹:۰۵');
    });

    test('accepts non-string input', () {
      expect(toPersianDigits(42), '۴۲');
      expect(toPersianDigits(null), '');
    });
  });

  group('toAsciiDigits', () {
    test('converts Persian digits', () {
      expect(toAsciiDigits('۱۴۰۵'), '1405');
    });

    test('converts Arabic-Indic digits', () {
      expect(toAsciiDigits('٣٠'), '30');
    });
  });

  group('normalizePersianInput', () {
    test('unifies Arabic yeh and kaf', () {
      expect(normalizePersianInput('يك كلمه'), 'یک کلمه');
    });

    test('removes diacritics and tatweel', () {
      expect(normalizePersianInput('سَلامـــ'), 'سلام');
    });

    test('converts digits and collapses whitespace', () {
      expect(normalizePersianInput('  ساعت   ۹ صبح '), 'ساعت 9 صبح');
    });

    test('replaces zero-width non-joiners with spaces', () {
      expect(normalizePersianInput('می‌خواهم'), 'می خواهم');
    });
  });
}
