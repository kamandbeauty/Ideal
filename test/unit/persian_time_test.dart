import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/core/utils/persian_number_words.dart';

void main() {
  group('PersianNumbers.toWords', () {
    test('handles units and teens', () {
      expect(PersianNumbers.toWords(0), 'صفر');
      expect(PersianNumbers.toWords(7), 'هفت');
      expect(PersianNumbers.toWords(13), 'سیزده');
      expect(PersianNumbers.toWords(19), 'نوزده');
    });

    test('handles tens and compounds', () {
      expect(PersianNumbers.toWords(20), 'بیست');
      expect(PersianNumbers.toWords(25), 'بیست و پنج');
      expect(PersianNumbers.toWords(99), 'نود و نه');
    });

    test('handles hundreds and thousands', () {
      expect(PersianNumbers.toWords(100), 'صد');
      expect(PersianNumbers.toWords(345), 'سیصد و چهل و پنج');
      expect(PersianNumbers.toWords(1000), 'هزار');
      expect(PersianNumbers.toWords(2026), 'دو هزار و بیست و شش');
    });
  });

  group('PersianNumbers.fromWord', () {
    test('parses digits and words', () {
      expect(PersianNumbers.fromWord('۹'), 9);
      expect(PersianNumbers.fromWord('نه'), 9);
      expect(PersianNumbers.fromWord('بیست'), 20);
      expect(PersianNumbers.fromWord('نامعتبر'), isNull);
    });
  });

  group('PersianTime.parseClock', () {
    test('parses a plain hour', () {
      expect(PersianTime.parseClock('۸'), (8, 0));
      expect(PersianTime.parseClock('ساعت ۹'), (9, 0));
      expect(PersianTime.parseClock('ساعت نه'), (9, 0));
    });

    test('parses «و نیم» and «و ربع»', () {
      expect(PersianTime.parseClock('۹ و نیم'), (9, 30));
      expect(PersianTime.parseClock('۱۰ و ربع'), (10, 15));
      expect(PersianTime.parseClock('۸ و چهل و پنج دقیقه'), (8, 45));
    });

    test('applies Persian meridiems', () {
      expect(PersianTime.parseClock('۸ صبح'), (8, 0));
      expect(PersianTime.parseClock('۸ شب'), (20, 0));
      expect(PersianTime.parseClock('۳ بعد از ظهر'), (15, 0));
      expect(PersianTime.parseClock('۱۲ ظهر'), (12, 0));
    });

    test('rejects nonsense instead of guessing', () {
      expect(PersianTime.parseClock('تماس بگیرم'), isNull);
    });
  });
}
