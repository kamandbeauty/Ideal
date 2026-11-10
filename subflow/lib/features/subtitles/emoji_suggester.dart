/// Adds a matching emoji to a caption line, offline.
///
/// The "AI emoji" feature of cloud editors is a keyword model behind an API.
/// SubFlow has no network by design, so this is a curated Persian keyword table
/// instead: deterministic, instant, reviewable, and it never overwrites text the
/// user wrote - it only appends one emoji per line, and only once per emoji.
class EmojiSuggester {
  const EmojiSuggester._();

  /// Longest phrases first so «دوستت دارم» wins over «دوست».
  static const Map<String, String> _dictionary = <String, String>{
    'دوستت دارم': '❤️',
    'عاشق': '😍',
    'عشق': '❤️',
    'قلب': '❤️',
    'خنده': '😂',
    'میخندم': '😂',
    'بامزه': '😄',
    'شوخی': '😜',
    'گریه': '😢',
    'غمگین': '😔',
    'ناراحت': '😞',
    'عصبانی': '😡',
    'خسته': '😴',
    'خواب': '😴',
    'ترسناک': '😱',
    'عجیب': '😳',
    'تعجب': '😲',
    'فکر': '🤔',
    'نمیفهمم': '🤔',
    'سوال': '❓',
    'جواب': '✅',
    'درست': '✅',
    'غلط': '❌',
    'عالی': '👌',
    'بهترین': '🏆',
    'موفق': '🏆',
    'برنده': '🥇',
    'قهرمان': '🏆',
    'تبریک': '🎉',
    'تولد': '🎂',
    'هدیه': '🎁',
    'جشن': '🎊',
    'سلام': '👋',
    'خداحافظ': '👋',
    'ممنون': '🙏',
    'متشکر': '🙏',
    'لطفا': '🙏',
    'ببخشید': '🙇',
    'پول': '💰',
    'درآمد': '💸',
    'فروش': '📈',
    'گران': '💸',
    'ارزان': '🏷️',
    'خرید': '🛍️',
    'آتش': '🔥',
    'داغ': '🔥',
    'سریع': '⚡',
    'قدرت': '💪',
    'ورزش': '💪',
    'بدنسازی': '🏋️',
    'فوتبال': '⚽',
    'بازی': '🎮',
    'گیم': '🎮',
    'موسیقی': '🎵',
    'آهنگ': '🎧',
    'رقص': '💃',
    'فیلم': '🎬',
    'دوربین': '📸',
    'عکس': '📷',
    'ویدئو': '🎥',
    'گوشی': '📱',
    'موبایل': '📱',
    'لپتاپ': '💻',
    'کامپیوتر': '🖥️',
    'اینترنت': '🌐',
    'کتاب': '📚',
    'درس': '📚',
    'امتحان': '📝',
    'مدرسه': '🏫',
    'دانشگاه': '🎓',
    'کار': '💼',
    'شغل': '💼',
    'جلسه': '📅',
    'وقت': '⏰',
    'زمان': '⏳',
    'صبح': '🌅',
    'شب': '🌙',
    'آفتاب': '☀️',
    'باران': '🌧️',
    'برف': '❄️',
    'هوا': '🌤️',
    'سفر': '✈️',
    'جاده': '🛣️',
    'ماشین': '🚗',
    'پرواز': '🛫',
    'دریا': '🌊',
    'کوه': '⛰️',
    'شهر': '🏙️',
    'خانه': '🏠',
    'خانواده': '👨‍👩‍👧',
    'بچه': '👶',
    'مادر': '👩',
    'پدر': '👨',
    'دوست': '🤝',
    'غذا': '🍽️',
    'خوشمزه': '😋',
    'پیتزا': '🍕',
    'قهوه': '☕',
    'چای': '🍵',
    'آب': '💧',
    'نوشیدنی': '🥤',
    'گربه': '🐱',
    'سگ': '🐶',
    'حیوان': '🐾',
    'گل': '🌸',
    'درخت': '🌳',
    'ستاره': '⭐',
    'ماه': '🌙',
    'خطر': '⚠️',
    'کمک': '🆘',
    'مهم': '📌',
    'سری': '🔒',
    'رمز': '🔑',
    'قانون': '⚖️',
    'بیمار': '🤒',
    'دکتر': '🩺',
    'دارو': '💊',
    'سلامتی': '🍏',
    'زیبا': '✨',
    'شگفت': '🤩',
    'هیجان': '🤩',
    'آرام': '😌',
    'لبخند': '🙂',
    'بوسه': '😘',
  };

  static final List<MapEntry<String, String>> _entries =
      _dictionary.entries.toList(growable: false)
        ..sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
            b.key.length.compareTo(a.key.length));

  /// True when the line already ends with an emoji, so a second pass (or a run
  /// after the user added one by hand) never stacks them up.
  static bool _endsWithEmoji(String text) {
    final String trimmed = text.trimRight();
    if (trimmed.isEmpty) return false;
    final int last = trimmed.runes.last;
    return (last >= 0x1F300 && last <= 0x1FAFF) ||
        (last >= 0x2600 && last <= 0x27BF) ||
        last == 0x2764 ||
        last == 0xFE0F;
  }

  /// Returns [text] with one matching emoji appended, or [text] unchanged.
  static String decorate(String text) {
    if (text.trim().isEmpty) return text;
    if (_endsWithEmoji(text)) return text;
    for (final MapEntry<String, String> entry in _entries) {
      if (text.contains(entry.key)) {
        return '${text.trimRight()} ${entry.value}';
      }
    }
    return text;
  }

  /// Which keyword fired, for the "why did it add that?" tooltip.
  static String? keywordFor(String text) {
    for (final MapEntry<String, String> entry in _entries) {
      if (text.contains(entry.key)) return entry.key;
    }
    return null;
  }
}
