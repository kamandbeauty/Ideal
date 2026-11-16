import '../../core/utils/persian_date_parse.dart';
import '../../core/utils/persian_digits.dart';
import '../../core/utils/persian_number_words.dart';
import '../../data/models/job.dart';
import '../../data/models/note.dart';
import 'intent.dart';

/// Deterministic, offline Persian intent parser.
///
/// JavidAI always tries this parser first: it is instant, private (no text
/// leaves the device) and covers the everyday commands — notes, reminders,
/// briefings. A cloud model is only consulted when this returns
/// [IntentType.unknown] *and* the user enabled cloud AI.
class IntentParser {
  IntentParser({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  AgentIntent parse(String rawText) {
    final text = normalizePersianInput(rawText);
    if (text.isEmpty) {
      return AgentIntent(type: IntentType.unknown, rawText: rawText);
    }

    final lowered = text.toLowerCase();

    if (_isGreeting(lowered)) {
      return AgentIntent(type: IntentType.greeting, rawText: rawText, confidence: 0.95);
    }
    if (_isHelp(lowered)) {
      return AgentIntent(type: IntentType.help, rawText: rawText, confidence: 0.9);
    }
    // Scheduling wins over the generic "summarise something" shortcuts: a
    // phrase like «هر روز ساعت ۸ خلاصهٔ پیام‌ها را بگو» is a *job*, not a
    // one-off briefing request.
    final jobIntent = _parseJobCreation(text, lowered, rawText);
    if (jobIntent != null) return jobIntent;

    if (_isBriefingRequest(lowered)) {
      return AgentIntent(
        type: IntentType.dailyBriefing,
        rawText: rawText,
        confidence: 0.92,
        slots: {
          'includeContent': lowered.contains('متن') || lowered.contains('بخوان') ||
              lowered.contains('جزئیات'),
        },
      );
    }
    if (_isMessageSummaryRequest(lowered)) {
      return AgentIntent(type: IntentType.messageSummary, rawText: rawText, confidence: 0.9);
    }

    final jobManagement = _parseJobManagement(lowered, rawText);
    if (jobManagement != null) return jobManagement;

    final noteIntent = _parseNoteIntent(text, lowered, rawText);
    if (noteIntent != null) return noteIntent;

    return AgentIntent(type: IntentType.unknown, rawText: rawText);
  }

  // ---------------------------------------------------------------- greetings
  bool _isGreeting(String text) {
    const greetings = [
      'سلام', 'درود', 'صبح بخیر', 'عصر بخیر', 'شب بخیر', 'چطوری', 'خوبی',
      'hi', 'hello', 'hey',
    ];
    return greetings.any((greeting) => text.startsWith(greeting)) && text.length < 30;
  }

  bool _isHelp(String text) =>
      text.contains('چه کار') ||
      text.contains('چیکار') ||
      text.contains('کمک') ||
      text.contains('راهنما') ||
      text.contains('دستور') && text.contains('ها');

  bool _isBriefingRequest(String text) {
    final hasBriefing =
        text.contains('خلاصه') || text.contains('گزارش') || text.contains('برنامه');
    final targetsDay =
        text.contains('امروز') || text.contains('روز') || text.contains('صبح') ||
        text.contains('بخوان') || text.contains('بگو');
    final mentionsMessages =
        text.contains('پیام') || text.contains('اعلان') || text.contains('نوتیف');
    return hasBriefing && (targetsDay || mentionsMessages);
  }

  bool _isMessageSummaryRequest(String text) =>
      (text.contains('پیام') || text.contains('اعلان') || text.contains('نوتیفیکیشن')) &&
      !text.contains('بساز') &&
      !text.contains('ذخیره');

  // ----------------------------------------------------------- job management
  AgentIntent? _parseJobManagement(String lowered, String raw) {
    final mentionsJobs =
        lowered.contains('وظیفه') || lowered.contains('کار') && lowered.contains('ها');
    final wantsList = lowered.contains('نشان') ||
        lowered.contains('چی') ||
        lowered.contains('لیست') ||
        lowered.contains('چه');

    final wantsPause = lowered.contains('توقف') ||
        lowered.contains('غیرفعال') ||
        lowered.contains('متوقف') ||
        lowered.contains('معلق');
    final wantsDelete = lowered.contains('حذف') || lowered.contains('پاک');

    if ((wantsPause || wantsDelete) && (mentionsJobs || lowered.contains('یادآور'))) {
      final title = _extractQuoted(lowered) ?? _extractAfterDeleteKeyword(lowered);
      return AgentIntent(
        type: wantsPause ? IntentType.pauseJob : IntentType.deleteJob,
        rawText: raw,
        confidence: 0.7,
        slots: {'title': title},
      );
    }
    if (mentionsJobs && wantsList) {
      return AgentIntent(type: IntentType.listJobs, rawText: raw, confidence: 0.85);
    }
    return null;
  }

  static String? _extractQuoted(String text) {
    final guillemet = RegExp('«([^»]+)»').firstMatch(text);
    if (guillemet != null) return guillemet.group(1)!.trim();
    return null;
  }

  static String? _extractAfterDeleteKeyword(String text) {
    final match = RegExp(r'(?:حذف|پاک|توقف|غیرفعال)\s*(?:کن)?\s*(?:وظیفه|یادآور)?\s*(.*)$')
        .firstMatch(text);
    final tail = match?.group(1)?.trim();
    return (tail == null || tail.isEmpty) ? null : tail;
  }

  // ------------------------------------------------------------ job creation
  AgentIntent? _parseJobCreation(String text, String lowered, String raw) {
    final recovered = toAsciiDigits(text).replaceAll('\u200c', ' ');
    final schedule = _parseSchedule(text, lowered);

    // A command is only a *scheduled job* when it carries a real temporal
    // marker. «یادآوری» alone is not enough: «یادآوری کن» without a time is
    // still a job (defaults to one hour from now), but a bare note/command must
    // never turn into one.
    final hasTemporalMarker = RegExp(
      r'(ساعت|هر\s*روز|هر\s*شب|همه\s*روزه|هر\s*هفته|هر\s*(شنبه|یکشنبه|دوشنبه|سه‌? ?شنبه|چهارشنبه|پنج‌? ?شنبه|جمعه)|هر\s*\d+\s*(دقیقه|ساعت)|فردا|پس\s*فردا|امروز|دیروز|\d{1,2}\s*(روز|هفته|ماه))',
    ).hasMatch(recovered);
    final jobVerb = lowered.contains('یادآوری') ||
        lowered.contains('یادم') ||
        lowered.contains('به یاد') ||
        recovered.contains('وظیفه') ||
        recovered.contains('هر روز') ||
        recovered.contains('هر شب') ||
        // «فردا ساعت ۹ تماس بگیرم» — a dated phrase is a scheduling request.
        (recovered.contains('فردا') && recovered.contains('ساعت')) ||
        (recovered.contains('ساعت') && recovered.contains('تماس'));

    if (schedule == null) return null;
    if (!hasTemporalMarker || !jobVerb) return null;
    final title = _extractJobTitle(text, lowered, schedule);
    final action = _inferJobAction(lowered);
    final kind = switch (action) {
      JobAction.dailyBriefing => JobKind.briefing,
      JobAction.messageSummary => JobKind.summary,
      JobAction.reminder => JobKind.reminder,
      JobAction.assistantPrompt => JobKind.custom,
    };

    return AgentIntent(
      type: IntentType.createJob,
      rawText: raw,
      confidence: 0.88,
      slots: {
        'schedule': schedule,
        'title': title,
        'prompt': title,
        'action': action,
        'kind': kind,
      },
    );
  }

  JobAction _inferJobAction(String lowered) {
    if (lowered.contains('خلاصه') && (lowered.contains('پیام') || lowered.contains('اعلان'))) {
      return JobAction.messageSummary;
    }
    if (lowered.contains('خلاصه') ||
        lowered.contains('گزارش') ||
        lowered.contains('اخبار') ||
        lowered.contains('برنامه')) {
      return JobAction.dailyBriefing;
    }
    return JobAction.reminder;
  }

  String _extractJobTitle(String text, String lowered, ScheduleRequest schedule) {
    var cleaned = text;
    // Time/date expressions
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(هر روز|هر شب|همه روزه|هر هفته|هر \d+ دقیقه|هر \d+ ساعت|'
        r'فردا|پس فردا|پس\u200cفردا|امروز|دیروز|'
        r'ساعت\s*[\d\p{N}]+(\s*(و\s*(نیم|ربع|[\d]+\s*دقیقه)))?|'
        r'(صبح|عصر|شب|ظهر|بعد از ظهر|بعدازظهر)\b|'
        r'\d+\s*(دقیقه|ساعت)\s*(دیگر|بعد)؟)',
        unicode: true,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'(یادآوری کن|یادآوری|یادم باشه|یادم بیار|یادم بینداز|به یادم بیار|'
          r'تنظیم کن|زمان‌بندی کن|بساز|برای|که|را)'),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[،,.؛;\-]+|[،,.؛;\-]+$'), '').trim();

    if (cleaned.isEmpty) {
      if (schedule.kind == JobScheduleKind.daily) return 'یادآوری روزانه';
      if (schedule.kind == JobScheduleKind.weekly) return 'یادآوری هفتگی';
      if (schedule.kind == JobScheduleKind.interval) return 'اجرای دوره‌ای';
      return 'یادآوری';
    }
    if (cleaned.length > 80) return '${cleaned.substring(0, 80).trimRight()}…';
    return cleaned;
  }

  ScheduleRequest? _parseSchedule(String text, String lowered) {
    final now = _clock();

    // Recurring daily
    final daily = RegExp(r'هر\s*(روز|شب|صبح|عصر)').hasMatch(lowered);
    // Interval: «هر ۲ ساعت» / «هر ۳۰ دقیقه»
    final intervalMatch = RegExp(
      r'هر\s*(\d+|یک|دو|سه|چهار|پنج|شش|هفت|هشت|نه|ده|دوازده)\s*(ساعت|دقیقه)',
    ).firstMatch(toAsciiDigits(lowered));
    if (intervalMatch != null) {
      final amount = PersianNumbers.fromWord(intervalMatch.group(1)!) ?? 1;
      final unit = intervalMatch.group(2)!;
      final minutes = unit == 'ساعت' ? amount * 60 : amount;
      return ScheduleRequest(
        kind: JobScheduleKind.interval,
        intervalMinutes: minutes < 15 ? 15 : minutes,
      );
    }

    // Weekly: «هر شنبه ساعت ۱۰»
    const weekdays = <String, int>{
      'دوشنبه': DateTime.monday,
      'سه‌شنبه': DateTime.tuesday,
      'سه شنبه': DateTime.tuesday,
      'چهارشنبه': DateTime.wednesday,
      'پنجشنبه': DateTime.thursday,
      'پنج شنبه': DateTime.thursday,
      'جمعه': DateTime.friday,
      'شنبه': DateTime.saturday,
      'یکشنبه': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (RegExp('هر\\s*${RegExp.escape(entry.key)}').hasMatch(lowered)) {
        final clock = _parseClockIn(text, now);
        return ScheduleRequest(
          kind: JobScheduleKind.weekly,
          weekday: entry.value,
          hour: clock?.$1 ?? 9,
          minute: clock?.$2 ?? 0,
        );
      }
    }

    // Explicit clock gives a concrete time; pair it with a date if present.
    final clock = _parseClockIn(text, now);
    final date = parsePersianDate(text, now);

    if (daily) {
      final hour = clock?.$1 ?? (lowered.contains('صبح') ? 8 : (lowered.contains('شب') ? 21 : 9));
      final minute = clock?.$2 ?? 0;
      return ScheduleRequest(kind: JobScheduleKind.daily, hour: hour, minute: minute);
    }

    if (date != null) {
      final hour = clock?.$1 ?? 9;
      final minute = clock?.$2 ?? 0;
      var fireAt = DateTime(date.date.year, date.date.month, date.date.day, hour, minute);
      if (!fireAt.isAfter(now)) {
        // «فردا ساعت ۹» parsed when the date rolled over, or a bare time in the
        // past: schedule for tomorrow rather than silently dropping the job.
        fireAt = DateTime(
          date.date.year,
          date.date.month,
          date.date.day + 1,
          hour,
          minute,
        );
      }
      return ScheduleRequest(kind: JobScheduleKind.once, onceAt: fireAt);
    }

    if (clock != null) {
      var fireAt = DateTime(now.year, now.month, now.day, clock.$1, clock.$2);
      if (!fireAt.isAfter(now)) {
        fireAt = DateTime(now.year, now.month, now.day + 1, clock.$1, clock.$2);
      }
      return ScheduleRequest(kind: JobScheduleKind.once, onceAt: fireAt);
    }

    if (lowered.contains('یادآوری') && !lowered.contains('وظیفه')) {
      // «یادآوری کن» with no time: one hour from now, clearly stated in the reply.
      return ScheduleRequest(
        kind: JobScheduleKind.once,
        onceAt: now.add(const Duration(hours: 1)),
      );
    }
    return null;
  }

  (int, int)? _parseClockIn(String text, DateTime now) {
    final match = RegExp(r'ساعت\s*(.+)$').firstMatch(text);
    if (match == null) return null;
    final tail = toAsciiDigits(match.group(1)!)
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'[،,.؛;]'), ' ')
        .trim();
    final words = tail.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return null;

    // Collect the leading tokens that can belong to a time expression, stopping
    // at the first token that starts the thing being reminded about.
    const clockWords = <String>{
      'و', 'نیم', 'ربع', 'دقیقه', 'صبح', 'ظهر', 'عصر', 'شب', 'بامداد',
      'بعد', 'از', 'بعدازظهر', 'ساعت',
    };
    final tokens = <String>[];
    for (final word in words) {
      final isNumber = RegExp(r'^\d{1,2}$').hasMatch(word) ||
          PersianNumbers.fromWord(word) != null;
      if (isNumber || clockWords.contains(word)) {
        tokens.add(word);
      } else {
        break;
      }
      // A time expression never needs more than 4 tokens (e.g. «۹ و نیم»).
      if (tokens.length == 4) break;
    }

    for (var count = tokens.length; count >= 1; count--) {
      final candidate = tokens.take(count).join(' ');
      final parsed = PersianTime.parseClock(candidate);
      if (parsed != null && parsed.$1 >= 0 && parsed.$1 <= 23 && parsed.$2 >= 0 && parsed.$2 <= 59) {
        return parsed;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------- notes
  AgentIntent? _parseNoteIntent(String text, String lowered, String raw) {
    final saveVerb = lowered.contains('ذخیره') ||
        lowered.contains('سیو') ||
        lowered.contains('ثبت کن') ||
        lowered.contains('نگه دار');
    final noteVerb = lowered.contains('یادداشت') || lowered.contains('نوت');
    final newVerb = lowered.contains('جدید') || lowered.contains('بساز');
    final listVerb = lowered.contains('نشان') ||
        lowered.contains('لیست') ||
        (lowered.contains('چند') && lowered.contains('یادداشت'));
    final deleteVerb = lowered.contains('حذف') || lowered.contains('پاک');

    if (deleteVerb && noteVerb) {
      return AgentIntent(
        type: IntentType.deleteNote,
        rawText: raw,
        confidence: 0.8,
        slots: {'title': _extractQuoted(lowered) ?? _extractAfterDeleteKeyword(lowered)},
      );
    }

    // Creating a note takes precedence over listing/reading it: the phrases
    // «یادداشت جدید بساز» and «یادداشت‌هایم را نشان بده» differ only in verbs.
    if (saveVerb || (noteVerb && newVerb)) {
      final body = _extractNoteBody(text);
      if (body.isEmpty) {
        return AgentIntent(
          type: IntentType.createNote,
          rawText: raw,
          confidence: 0.5,
          slots: {'body': '', 'needsBody': true},
        );
      }
      final category = _inferCategory(lowered);
      return AgentIntent(
        type: IntentType.createNote,
        rawText: raw,
        confidence: 0.9,
        slots: {'body': body, 'category': category},
      );
    }

    if (noteVerb && listVerb) {
      return AgentIntent(type: IntentType.listNotes, rawText: raw, confidence: 0.85);
    }

    if (lowered.contains('آخرین') || (noteVerb && lowered.contains('بخوان'))) {
      return AgentIntent(type: IntentType.readLatestNote, rawText: raw, confidence: 0.8);
    }

    return null;
  }

  static String _extractNoteBody(String text) {
    final quoted = RegExp('«([^»]+)»').firstMatch(text) ??
        RegExp('"([^"]+)"').firstMatch(text);
    if (quoted != null && quoted.group(1)!.trim().isNotEmpty) {
      return quoted.group(1)!.trim();
    }
    final commandEnd = RegExp(
      r'(این متن را|این را|متن زیر را|متن را|یادداشت جدید(?:ی)?(?: بساز)?|یادداشت|'
      r'نوت جدید(?: بساز)?|نوت|ذخیره کن|ذخیره|ثبت کن|ثبت|بساز|برای من|لطفاً|لطفا)',
    ).allMatches(text).lastOrNull;
    var body = commandEnd == null
        ? text
        : text.substring(commandEnd.end).trimLeft();
    body = body.replaceFirst(RegExp(r'^[:\-–—]+\s*'), '');
    body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return body.replaceAll(RegExp(r'^[،,.؛;\-]+|[،,.؛;\-]+$'), '').trim();
  }

  static String _inferCategory(String lowered) {
    if (lowered.contains('کار') || lowered.contains('جلسه') || lowered.contains('پروژه')) {
      return NoteCategories.work;
    }
    if (lowered.contains('شخصی') || lowered.contains('خانواده') || lowered.contains('خرید')) {
      return NoteCategories.personal;
    }
    if (lowered.contains('ایده') || lowered.contains('فکر')) return NoteCategories.idea;
    if (lowered.contains('یادآوری')) return NoteCategories.reminder;
    return NoteCategories.general;
  }
}
