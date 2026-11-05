import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/core/util/rtl_text.dart';

/// Persian correctness is a product requirement, not a cosmetic detail:
/// ZWNJ (نیم‌فاصله) must survive, digits may be displayed Persian but stored
/// ASCII, and mixed sentences must be detectable.
void main() {
  test('detects RTL and LTR paragraphs', () {
    expect(RtlText.directionOf('سلام دنیا'), TextDirection.rtl);
    expect(RtlText.directionOf('Hello world'), TextDirection.ltr);
  });

  test('first strong character wins (UAX#9 P2/P3 behaviour)', () {
    expect(RtlText.directionOf('(سلام)'), TextDirection.rtl);
    expect(RtlText.directionOf('123 سلام'), TextDirection.rtl);
    expect(RtlText.directionOf('123 Hello'), TextDirection.ltr);
  });

  test('mixed Persian/English is detected', () {
    expect(RtlText.isMixed('این یک Test است'), isTrue);
    expect(RtlText.isMixed('فقط فارسی'), isFalse);
    expect(RtlText.isMixed('only english'), isFalse);
  });

  test('ZWNJ is preserved by normalisation', () {
    const String withZwnj = 'نیم\u200Cفاصله';
    expect(RtlText.normalizePersian(withZwnj), withZwnj);
    expect(RtlText.normalizePersian('می\u200Cروم'), 'می\u200Cروم');
  });

  test('Arabic Yeh/Kaf are folded to Persian forms', () {
    expect(RtlText.normalizePersian('يك'), 'یک');
    expect(RtlText.normalizePersian('كتاب'), 'کتاب');
  });

  test('collapses repeated spaces but keeps single ones', () {
    expect(RtlText.normalizePersian('سلام   دنیا'), 'سلام دنیا');
  });

  test('Persian digits are display-only', () {
    expect(RtlText.toPersianDigits('2026'), '۲۰۲۶');
    expect(RtlText.toPersianDigits('abc 12'), 'abc ۱۲');
  });
}
