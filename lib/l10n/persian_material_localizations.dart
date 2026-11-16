import 'package:flutter/material.dart';
import '../core/utils/jalali.dart';
import '../core/utils/persian_digits.dart';

/// Persian Material localisations.
///
/// Uses the built-in Persian `MaterialLocalizations` (for tooltips, dialogs and
/// the date picker labels) and overrides the date/time formatters so that every
/// visible date uses the Jalali calendar and Persian digits – including the
/// labels inside [showDatePicker].
class PersianMaterialLocalizations extends DefaultMaterialLocalizations {
  const PersianMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _PersianMaterialLocalizationsDelegate();

  static const _fa = 'fa_IR';

  @override
  String get localeName => _fa;

  @override
  String get datePickerHelpText => 'انتخاب تاریخ';

  @override
  String get dateRangePickerHelpText => 'انتخاب بازهٔ تاریخ';

  @override
  String get calendarModeButtonLabel => 'تقویم';

  @override
  String get inputDateModeButtonLabel => 'ورود دستی تاریخ';

  @override
  String get dateInputLabel => 'تاریخ';

  @override
  String get dateHelpText => 'مثلاً ۱۴۰۵/۰۸/۲۵';

  @override
  String get invalidDateFormatLabel => 'قالب تاریخ درست نیست';

  @override
  String get dateOutOfRangeLabel => 'تاریخ خارج از بازهٔ مجاز است';

  @override
  String get saveButtonLabel => 'ذخیره';

  @override
  String get cancelButtonLabel => 'انصراف';

  @override
  String get okButtonLabel => 'تأیید';

  @override
  String get unspecifiedDate => 'بدون تاریخ';

  @override
  String get todayLabel => 'امروز';

  @override
  String get nextMonthTooltip => 'ماه بعد';

  @override
  String get previousMonthTooltip => 'ماه قبل';

  @override
  String get unsupportedDate => 'نامعتبر';

  @override
  String formatCompactDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits(
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  String formatShortDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits('${j.day} ${jalaliMonthNames[j.month - 1]}');
  }

  @override
  String formatMediumDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits('${j.day} ${jalaliMonthNames[j.month - 1]} ${j.year}');
  }

  @override
  String formatFullDate(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits(
      '${persianWeekdayNames[date.weekday - 1]}، ${j.day} '
      '${jalaliMonthNames[j.month - 1]} ${j.year}',
    );
  }

  @override
  String formatMonthYear(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits('${jalaliMonthNames[j.month - 1]} ${j.year}');
  }

  @override
  String formatYear(DateTime date) => toPersianDigits(JalaliDate.fromDateTime(date).year);

  @override
  String formatDecimal(int number) => toPersianDigits(number);

  @override
  String formatHour(TimeOfDay timeOfDay, {bool alwaysUse24HourFormat = false}) {
    return toPersianDigits(timeOfDay.hour.toString().padLeft(2, '0'));
  }

  @override
  String formatMinute(TimeOfDay timeOfDay) =>
      toPersianDigits(timeOfDay.minute.toString().padLeft(2, '0'));

  @override
  String formatTimeOfDay(TimeOfDay timeOfDay, {bool alwaysUse24HourFormat = false}) {
    return toPersianDigits(
      '${timeOfDay.hour.toString().padLeft(2, '0')}:'
      '${timeOfDay.minute.toString().padLeft(2, '0')}',
    );
  }

  // The week in the date picker starts on Saturday in Iran.
  @override
  int get firstDayOfWeekIndex => 6; // DateTime.saturday

  /// Iranian week order, starting on Saturday: ش ی د س چ پ ج
  @override
  List<String> get narrowWeekdays =>
      const ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
}

class _PersianMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _PersianMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fa';

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      const PersianMaterialLocalizations();

  @override
  bool shouldReload(_PersianMaterialLocalizationsDelegate old) => false;
}

/// Persian (Jalali) date display helper used by widgets in place of intl's
/// Gregorian `DateFormat`.
abstract final class PersianDateFormat {
  /// e.g. «آبان ۱۴۰۵»
  static String monthYear(DateTime date) {
    final j = JalaliDate.fromDateTime(date);
    return toPersianDigits('${jalaliMonthNames[j.month - 1]} ${j.year}');
  }

  /// Formats a timestamp: «امروز ۰۹:۰۵» for today, otherwise «۲۴ آبان ۰۹:۰۵».
  static String timestamp(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final time = toPersianDigits(
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
    );
    final j = JalaliDate.fromDateTime(date);
    if (j == JalaliDate.fromDateTime(reference)) return 'امروز $time';
    return '${toPersianDigits('${j.day} ${jalaliMonthNames[j.month - 1]}')} $time';
  }
}
