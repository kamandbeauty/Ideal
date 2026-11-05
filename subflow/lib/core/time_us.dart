/// Timestamp helpers.
///
/// Rule for the whole product: a timestamp is an `int` count of **microseconds**
/// from timeline start. No `double` seconds, no `Duration` in the database.
/// 29.97 fps sources therefore cannot drift, and SQLite stores an exact integer.
class TimeUs {
  const TimeUs._();

  static const int perMillisecond = 1000;
  static const int perSecond = 1000000;
  static const int perMinute = 60 * perSecond;

  static int fromMilliseconds(num ms) => (ms * perMillisecond).round();
  static int fromSeconds(num seconds) => (seconds * perSecond).round();
  static double toSeconds(int us) => us / perSecond;
  static int fromFrames(int frames, double fps) {
    if (fps <= 0) return 0;
    return (frames * perSecond / fps).round();
  }

  static int clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// `01:02:03,456` - the separator SRT expects.
  static String srt(int us) {
    final int safe = us < 0 ? 0 : us;
    final int ms = (safe ~/ perMillisecond) % 1000;
    final int totalSeconds = safe ~/ perSecond;
    final int s = totalSeconds % 60;
    final int m = (totalSeconds ~/ 60) % 60;
    final int h = totalSeconds ~/ 3600;
    return '${_two(h)}:${_two(m)}:${_two(s)},${_three(ms)}';
  }

  /// `mm:ss` for compact UI (timeline ruler, player badge).
  static String clock(int us) {
    final int safe = us < 0 ? 0 : us;
    final int totalSeconds = safe ~/ perSecond;
    final int s = totalSeconds % 60;
    final int m = totalSeconds ~/ 60;
    return '${_two(m)}:${_two(s)}';
  }

  /// `mm:ss.mmm` for the editor where frame-accurate scrubbing matters.
  static String precise(int us) {
    final int safe = us < 0 ? 0 : us;
    final int ms = (safe ~/ perMillisecond) % 1000;
    final int totalSeconds = safe ~/ perSecond;
    return '${_two(totalSeconds ~/ 60)}:${_two(totalSeconds % 60)}.${_three(ms)}';
  }

  /// Human readable estimate used in the export screen: `۲ دقیقه و ۱۰ ثانیه`.
  static String humanDuration(int us) {
    final int totalSeconds = (us < 0 ? 0 : us) ~/ perSecond;
    final int h = totalSeconds ~/ 3600;
    final int m = (totalSeconds ~/ 60) % 60;
    final int s = totalSeconds % 60;
    if (h > 0) return '$h ساعت و $m دقیقه';
    if (m > 0) return '$m دقیقه و $s ثانیه';
    return '$s ثانیه';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _three(int value) => value.toString().padLeft(3, '0');
}
