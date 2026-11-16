import '../core/utils/persian_digits.dart';
import '../data/models/app_notification.dart';
import '../data/models/job.dart';

/// Builds the Persian daily briefing text from *real* local data only.
///
/// The service never invents content: every sentence is derived from rows in
/// the database, and when there is nothing to report it says so explicitly.
class BriefingService {
  const BriefingService();

  /// Notification senders or texts containing these words are flagged as
  /// potentially urgent. Kept deliberately short and documented so users know
  /// exactly why an item was highlighted.
  static const urgentKeywords = <String>[
    'فوری', 'اورژانس', 'اضطراری', 'مهم', 'جلسه', 'مهلت', 'پرداخت', 'بدهی',
    'urgent', 'asap', 'important', 'deadline',
  ];

  static bool isUrgent(CapturedNotification notification) {
    final haystack = '${notification.sender} ${notification.text}'.toLowerCase();
    return urgentKeywords.any(haystack.contains);
  }

  /// Groups [notifications] by their source application label.
  static Map<String, int> countBySource(List<CapturedNotification> notifications) {
    final counts = <String, int>{};
    for (final notification in notifications) {
      counts.update(notification.sourceLabel, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Full Persian briefing: a greeting, message counts, jobs and urgent items.
  String build({
    required DateTime now,
    required List<CapturedNotification> notifications,
    required List<Job> jobs,
    bool includeContent = false,
  }) {
    final sentences = <String>[greeting(now)];
    final sinceMidnight = DateTime(now.year, now.month, now.day);

    final todays = notifications
        .where((item) => item.postedAt.isAfter(sinceMidnight))
        .where((item) => !item.isGroupSummary)
        .toList();
    final urgent = todays.where(isUrgent).toList();

    if (todays.isEmpty) {
      sentences.add('امروز پیام تازه‌ای ثبت نشده است.');
    } else {
      final counts = countBySource(todays);
      final parts = counts.entries
          .map((entry) => '${toPersianDigits(entry.value)} پیام از ${entry.key}')
          .join('، ');
      sentences.add(
        'امروز ${toPersianDigits(todays.length)} پیام مهم داری: $parts.',
      );
    }

    final upcoming = jobs
        .where((job) => job.isActive && job.nextRunAt != null)
        .toList()
      ..sort((a, b) => a.nextRunAt!.compareTo(b.nextRunAt!));
    if (upcoming.isEmpty) {
      sentences.add('وظیفهٔ زمان‌بندی‌شده‌ای در پیش نداری.');
    } else {
      final next = upcoming.first;
      sentences.add(
        'نزدیک‌ترین وظیفه «${next.title}» برای ${_timeLabel(next.nextRunAt!)} است.',
      );
      if (upcoming.length > 1) {
        sentences.add('در کل ${toPersianDigits(upcoming.length)} وظیفهٔ فعال داری.');
      }
    }

    if (urgent.isNotEmpty) {
      final senders = urgent.map((item) => item.sender).where((s) => s.isNotEmpty).toSet();
      final senderText = senders.isEmpty ? '' : ' از ${senders.take(3).join('، ')}';
      sentences.add(
        '${toPersianDigits(urgent.length)} پیام ممکن است فوری باشد$senderText؛ '
        'لطفاً در بخش پیام‌ها بررسی کن.',
      );
    }

    if (includeContent && todays.isNotEmpty) {
      sentences.add('خلاصهٔ پیام‌ها:');
      for (final item in todays.take(5)) {
        final text = item.text.trim();
        final excerpt = text.length > 90 ? '${text.substring(0, 90)}…' : text;
        sentences.add('«${item.sourceLabel}» از ${item.sender}: $excerpt');
      }
    }

    return sentences.join(' ');
  }

  /// Short one-line version used by notifications and job outputs.
  String summarize({
    required DateTime now,
    required List<CapturedNotification> notifications,
    required List<Job> jobs,
  }) {
    final todays = notifications
        .where((item) => item.postedAt.isAfter(DateTime(now.year, now.month, now.day)))
        .toList();
    final activeJobs = jobs.where((job) => job.isActive).length;
    final counts = countBySource(todays);
    final sourceText = counts.isEmpty
        ? 'بدون پیام تازه'
        : counts.entries.map((e) => '${e.key}: ${toPersianDigits(e.value)}').join('، ');
    return '${toPersianDigits(todays.length)} پیام امروز ($sourceText) • '
        '${toPersianDigits(activeJobs)} وظیفهٔ فعال';
  }

  static String greeting(DateTime now) {
    if (now.hour < 5) return 'شب بخیر.';
    if (now.hour < 12) return 'صبح بخیر.';
    if (now.hour < 15) return 'ظهر بخیر.';
    if (now.hour < 19) return 'عصر بخیر.';
    return 'شب بخیر.';
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'ساعت ${toPersianDigits('$hour:$minute')}';
  }
}
