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
    final recovered = toAsciiDigits(text).replaceAll('\u200c', ' ');

    if (_isGreeting(lowered)) {
      return AgentIntent(type: IntentType.greeting, rawText: rawText, confidence: 0.95);
    }
    if (_isHelp(lowered)) {
      return AgentIntent(type: IntentType.help, rawText: rawText, confidence: 0.9);
    }

    // 1) Explicit note verbs are the strongest signal: they describe what to do
    //    with the *content*, which may itself mention dates or times.
    final explicitNote = _parseExplicitNoteVerb(text, lowered, rawText);
    if (explicitNote != null) return explicitNote;

    // 2) Scheduling. A recurring expression always wins; otherwise a scheduling
    //    verb («یادآوری کن») must accompany the time.
    final recurring = _hasRecurringExpression(recovered);
    final scheduleVerb = lowered.contains('یادآوری') ||
        lowered.contains('یادم') ||
        lowered.contains('به یاد') ||
        recovered.contains('وظیفه') ||
        recovered.contains('زمان بندی') ||
        recovered.contains('زمان‌بندی') ||
        recovered.contains('تنظیم کن');
    if (recurring || scheduleVerb || _hasTomorrowClock(recovered)) {
      final jobIntent = _parseJobCreation(text, lowered, rawText);
      if (jobIntent != null) return jobIntent;
    }

    // 3) Job management («وظیفه‌هایم را نشان بده»، «وظیفهٔ ورزش را حذف کن»).
    final jobManagement = _parseJobManagement(lowered, rawText);
    if (jobManagement != null) return jobManagement;

    // 4) One-off summaries. A phrase that asks about *today* in general terms
    //    («پیام‌های امروز را خلاصه کن») is the daily briefing; the narrower
    //    message-summary action is for phrasing about the messages themselves.
    if (_isBriefingRequest(lowered)) {
      return AgentIntent(
        type: IntentType.dailyBriefing,
        rawText: rawText,
        confidence: 0.92,
        slots: {
          'includeContent': lowered.contains('متن') ||
              lowered.contains('بخوان') ||
              lowered.contains('جزئیات'),
        },
      );
    }
    if (_isMessageSummaryRequest(lowered)) {
      return AgentIntent(
        type: IntentType.messageSummary,
        rawText: rawText,
        confidence: 0.9,
      );
    }

    // 5) Everything else: notes phrased without the word «یادداشت».
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
    final schedule = _parseSchedule(text, lowered);
    if (schedule == null) return null;
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
      r'هر\s*(\d{1,3}|یک|دو|سه|چهار|پنج|شش|هفت|هشت|نه|ده|دوازده|بیست|سی)\s*(ساعت|دقیقه)',
    ).firstMatch(toAsciiDigits(lowered));
    if (intervalMatch != null) {
      final amount = PersianNumbers.fromWord(intervalMatch.group(1)!) ?? 1;
      if (amount <= 0) return null;
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
      // «یادآوری کن» with no time: one hour from now. This checks *why* it was
      // called (a scheduling verb) rather than inventing a time for notes.
      return ScheduleRequest(
        kind: JobScheduleKind.once,
        onceAt: now.add(const Duration(hours: 1)),
      );
    }
    return null;
  }

  /// «فردا ساعت ۱۰ و ربع» is a one-off reminder even without the word «یادآوری».
  /// A bare «ساعت» is not enough: «یادداشت بساز: جلسه ساعت ۱۰» is still a note.
  bool _hasTomorrowClock(String recovered) =>
      RegExp(r'(فردا|پس\s*فردا|امروز)').hasMatch(recovered) &&
      recovered.contains('ساعت');

  /// True when the text contains a *recurring* scheduling expression. Notes and
  /// notes-like commands that merely mention a date («جلسهٔ فردا») are not
  /// turned into jobs.
  bool _hasRecurringExpression(String recovered) => RegExp(
        r'(هر\s*(روز|شب|صبح|عصر|هفته|شنبه|یکشنبه|دوشنبه|سه‌? ?شنبه|چهارشنبه|پنج‌? ?شنبه|جمعه)|'
        r'همه\s*روزه|هر\s*\d+\s*(دقیقه|ساعت)|روزانه|هفتگی)',
      ).hasMatch(recovered);

  (int, int)? _parseClockIn(String text, DateTime now) {
    final match = RegExp(r'ساعت\s*(.+)$').firstMatch(text);
    if (match == null) return null;
    final tail = toAsciiDigits(match.group(1)!)
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'[،,.؛;]'), ' ')
        .trim();
    var words = tail.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return null;

    // «هر شب ساعت ۸» — the period word may precede «ساعت», so it is not part of
    // the tail. Remember it as a fallback for when the tail has none of its own.
    const periodWords = {'صبح', 'ظهر', 'عصر', 'شب', 'بامداد', 'بعدازظهر', 'بعد از ظهر'};
    final prefix = text.substring(0, match.start).trim();
    final prefixWords = toAsciiDigits(prefix).split(RegExp(r'\s+'));
    final inheritedPeriod = prefixWords.isNotEmpty &&
            periodWords.contains(prefixWords.last.trim())
        ? prefixWords.last.trim()
        : null;

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
      // The connector «و» is only valid once a number has been read and only if
      // a real time word follows («۹ و نیم»، «۹ و بیست دقیقه»).
      final isConnector = word == 'و' && tokens.isNotEmpty;
      if (isNumber || clockWords.contains(word) || isConnector) {
        tokens.add(word);
      } else {
        break;
      }
      if (tokens.length >= 6) break;
    }
    while (tokens.isNotEmpty && tokens.last == 'و') {
      tokens.removeLast();
    }

    for (var count = tokens.length; count >= 1; count--) {
      var candidate = tokens.take(count).join(' ');
      if (inheritedPeriod != null &&
          !tokens.take(count).any(periodWords.contains)) {
        candidate = '$candidate $inheritedPeriod';
      }
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
      final body = _extractNoteBody(raw);
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

  /// Handles commands that *unambiguously* create/list/read notes.
  AgentIntent? _parseExplicitNoteVerb(String text, String lowered, String raw) {
    final hasNoteWord = lowered.contains('یادداشت') || lowered.contains('نوت');
    final save = lowered.contains('ذخیره') ||
        lowered.contains('سیو') ||
        lowered.contains('ثبت کن') ||
        lowered.contains('نگه دار');
    final create = hasNoteWord &&
        (lowered.contains('جدید') || lowered.contains('بساز') || lowered.contains('بنویس'));
    final remove = hasNoteWord && (lowered.contains('حذف') || lowered.contains('پاک'));

    if (remove) {
      return AgentIntent(
        type: IntentType.deleteNote,
        rawText: raw,
        confidence: 0.85,
        slots: {'title': _extractQuoted(lowered) ?? _extractAfterDeleteKeyword(lowered)},
      );
    }

    if (save || create) {
      final body = _extractNoteBody(raw);
      if (body.isEmpty) {
        return AgentIntent(
          type: IntentType.createNote,
          rawText: raw,
          confidence: 0.6,
          slots: {'body': '', 'needsBody': true},
        );
      }
      return AgentIntent(
        type: IntentType.createNote,
        rawText: raw,
        confidence: 0.92,
        slots: {'body': body, 'category': _inferCategory(lowered)},
      );
    }

    if (hasNoteWord && (lowered.contains('نشان') || lowered.contains('لیست'))) {
      return AgentIntent(type: IntentType.listNotes, rawText: raw, confidence: 0.85);
    }
    if ((hasNoteWord && lowered.contains('بخوان')) || lowered.contains('آخرین یادداشت')) {
      return AgentIntent(type: IntentType.readLatestNote, rawText: raw, confidence: 0.85);
    }
    return null;
  }

  /// Extracts the dictated body from [raw], the text exactly as the user wrote
  /// or spoke it. Normalising first would strip ZWNJ/harakat and rewrite digits,
  /// which changes what the user asked us to store.
  static String _extractNoteBody(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final quoted = RegExp('«([^»]+)»').firstMatch(text) ??
        RegExp('"([^"]+)"').firstMatch(text);
    if (quoted != null && quoted.group(1)!.trim().isNotEmpty) {
      return quoted.group(1)!.trim();
    }
    // The command is a *prefix* («این متن را ذخیره کن: …») and may chain several
    // phrases, so keep stripping leading command words until real content starts.
    // Matching the last occurrence anywhere would eat words that belong to the note.
    final commandWord = RegExp(
      r'(?:(?:لطفاً|لطفا|برای من)[\s،]*)?'
      r'(?:این متن را|این را|متن زیر را|متن را|یادداشت جدیدی?(?: بساز)?|'
      r'یادداشت|نوت جدید(?: بساز)?|نوت|ذخیره کن|ذخیره|ثبت کن|ثبت|بساز)'
      r'[\s:،\-]*',
    );
    var body = text;
    for (var i = 0; i < 4; i++) {
      final match = commandWord.matchAsPrefix(body);
      if (match == null) break;
      body = body.substring(match.end);
    }
    body = body.replaceFirst(RegExp(r'^[:\-–—\s]+'), '');
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
