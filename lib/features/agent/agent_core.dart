import '../../core/utils/persian_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/job.dart';
import '../../data/models/note.dart';
import '../../services/briefing_service.dart';
import '../../services/job_service.dart';
import '../../services/note_service.dart';
import 'intent.dart';
import 'intent_parser.dart';
import 'tool.dart';

/// One step of an agent turn as shown in the activity timeline.
class AgentTurn {
  const AgentTurn({
    required this.reply,
    this.toolCall,
    this.requiresConfirmation = false,
  });

  final String reply;

  /// Tool that was executed (or will be, after confirmation).
  final AgentToolCall? toolCall;
  final bool requiresConfirmation;
}

/// Describes a tool execution to run (possibly after user confirmation).
class AgentToolCall {
  const AgentToolCall({
    required this.title,
    required this.preview,
    required this.execute,
    this.isDestructive = false,
  });

  final String title;

  /// Exact, human readable description of what will happen.
  final String preview;
  final Future<ToolResult<Object?>> Function() execute;
  final bool isDestructive;
}

/// The brain of the MVP: parses Persian text into an intent and runs it against
/// local services. Fully offline, deterministic and testable.
///
/// A cloud planner can be layered on top later for open-ended conversation, but
/// every *action* must come back through this class so the confirmation policy
/// always applies.
class AgentCore {
  AgentCore({
    required IntentParser parser,
    required NoteService notes,
    required JobService jobs,
    required BriefingService briefing,
    List<CapturedNotification> notifications = const [],
    DateTime Function()? clock,
  })  : _parser = parser,
        _notes = notes,
        _jobs = jobs,
        _briefing = briefing,
        _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final IntentParser _parser;
  final NoteService _notes;
  final JobService _jobs;
  final BriefingService _briefing;
  final List<CapturedNotification> _notifications;
  final DateTime Function() _clock;

  /// Local notification snapshot used by briefing requests.
  List<CapturedNotification> get notifications => _notifications;

  /// Handles [text] and returns the reply. Notifications are injected through
  /// the constructor so the core stays free of database access and is trivially
  /// testable.
  Future<AgentTurn> handle(String text) async {
    final intent = _parser.parse(text);
    final notifications = _notifications;
    final now = _clock();

    switch (intent.type) {
      case IntentType.greeting:
        return AgentTurn(
          reply: '${PersianDate.greeting(now)}! من جویده‌ام — یادداشت، وظیفه و '
              'خلاصهٔ پیام‌ها. چه کاری برایت انجام بدهم؟',
        );

      case IntentType.help:
        return AgentTurn(reply: _helpText);

      case IntentType.dailyBriefing:
        final jobs = await _jobs.list();
        final reply = _briefing.build(
          now: now,
          notifications: notifications,
          jobs: jobs,
          includeContent: intent.slot<bool>('includeContent') ?? false,
        );
        return AgentTurn(reply: reply);

      case IntentType.messageSummary:
        final jobs = await _jobs.list();
        return AgentTurn(
          reply: _briefing.summarize(now: now, notifications: notifications, jobs: jobs),
        );

      case IntentType.createNote:
        final body = intent.slot<String>('body') ?? '';
        if (body.isEmpty) {
          return const AgentTurn(
            reply: 'متن یادداشت را بگو یا بنویس تا ذخیره کنم.',
          );
        }
        final category = intent.slot<String>('category') ?? NoteCategories.general;
        return AgentTurn(
          reply: 'یادداشت «${_preview(body)}» با دستهٔ '
              '«${NoteCategories.label(category)}» آمادهٔ ذخیره است.',
          requiresConfirmation: true,
          toolCall: AgentToolCall(
            title: 'ذخیرهٔ یادداشت',
            preview: 'متن: $body\nدسته: ${NoteCategories.label(category)}\n'
                'فقط روی همین دستگاه ذخیره می‌شود.',
            execute: () async {
              final note = await _notes.create(
                body: body,
                category: category,
                source: NoteSource.voice,
              );
              return ToolResult<Object?>.ok(
                'یادداشت «${note.displayTitle}» ذخیره شد.',
                data: note,
              );
            },
          ),
        );

      case IntentType.listNotes:
        final notes = await _notes.list();
        if (notes.isEmpty) {
          return const AgentTurn(reply: 'هنوز یادداشتی نداری.');
        }
        final list = notes
            .take(5)
            .map((note) => '• ${note.displayTitle}')
            .join('\n');
        return AgentTurn(reply: '${toPersianDigits(notes.length)} یادداشت داری:\n$list');

      case IntentType.readLatestNote:
        final note = await _notes.latest();
        if (note == null) {
          return const AgentTurn(reply: 'هنوز یادداشتی نداری.');
        }
        return AgentTurn(reply: 'آخرین یادداشت: «${note.displayTitle}»\n${note.body}');

      case IntentType.deleteNote:
        final title = intent.slot<String>('title');
        final notes = await _notes.list();
        if (notes.isEmpty) return const AgentTurn(reply: 'یادداشتی برای حذف پیدا نشد.');
        Note? target;
        if (title != null && title.trim().isNotEmpty) {
          target = notes.cast<Note?>().firstWhere(
                (note) => note!.displayTitle.contains(title) || note.body.contains(title),
                orElse: () => null,
              );
        }
        target ??= notes.first;
        final noteToDelete = target;
        return AgentTurn(
          reply: 'می‌خواهی یادداشت «${noteToDelete.displayTitle}» حذف شود؟ '
              'این کار بازگشت‌پذیر نیست.',
          requiresConfirmation: true,
          toolCall: AgentToolCall(
            title: 'حذف یادداشت',
            preview: 'یادداشت «${noteToDelete.displayTitle}» برای همیشه حذف می‌شود.',
            isDestructive: true,
            execute: () async {
              await _notes.delete(noteToDelete.id);
              return const ToolResult<Object?>.ok('یادداشت حذف شد.');
            },
          ),
        );

      case IntentType.createJob:
        final schedule = intent.slot<ScheduleRequest>('schedule');
        if (schedule == null) {
          return const AgentTurn(reply: 'زمان اجرای وظیفه را متوجه نشدم؛ دوباره بگو.');
        }
        final title = intent.slot<String>('title') ?? 'یادآوری';
        final action = intent.slot<JobAction>('action') ?? JobAction.reminder;
        final kind = intent.slot<JobKind>('kind') ?? JobKind.custom;
        final prompt = intent.slot<String>('prompt') ?? title;
        final jobSchedule = schedule.toSchedule();
        final nextRun = jobSchedule.nextRun(now);
        final whenText = nextRun == null
            ? 'زمان نامعتبر'
            : PersianDate.scheduleLabel(nextRun, now: now);
        return AgentTurn(
          reply: 'وظیفهٔ «$title» تنظیم می‌شود؛ اولین اجرا: $whenText.',
          requiresConfirmation: true,
          toolCall: AgentToolCall(
            title: 'ساخت وظیفه',
            preview: 'عنوان: $title\nزمان‌بندی: ${jobSchedule.label}\n'
                'اولین اجرا: $whenText\nنوع: ${_actionLabel(action)}',
            execute: () async {
              final job = await _jobs.create(
                title: title,
                prompt: prompt,
                schedule: jobSchedule,
                action: action,
                kind: kind,
              );
              return ToolResult<Object?>.ok(
                'وظیفهٔ «${job.title}» ثبت شد.',
                data: job,
              );
            },
          ),
        );

      case IntentType.listJobs:
        final jobs = await _jobs.list();
        if (jobs.isEmpty) return const AgentTurn(reply: 'هنوز وظیفه‌ای تنظیم نکرده‌ای.');
        final active = jobs.where((job) => job.isActive).toList();
        final lines = active
            .take(5)
            .map((job) {
              final next = job.nextRunAt;
              final when = next == null
                  ? 'بدون زمان'
                  : PersianDate.scheduleLabel(next, now: now);
              return '• ${job.title} — $when';
            })
            .join('\n');
        return AgentTurn(
          reply: '${toPersianDigits(active.length)} وظیفهٔ فعال:\n$lines',
        );

      case IntentType.pauseJob:
      case IntentType.deleteJob:
        final title = intent.slot<String>('title');
        final jobs = await _jobs.list();
        if (jobs.isEmpty) return const AgentTurn(reply: 'وظیفه‌ای پیدا نشد.');
        final matches = jobs.where((job) {
          if (title == null || title.trim().isEmpty) return true;
          return job.title.contains(title) || title.contains(job.title);
        }).toList();
        if (matches.isEmpty) {
          return AgentTurn(reply: 'وظیفه‌ای با عنوان «${title ?? ''}» پیدا نشد.');
        }
        final job = matches.first;
        if (intent.type == IntentType.pauseJob) {
          return AgentTurn(
            reply: 'وظیفهٔ «${job.title}» غیرفعال شود؟',
            requiresConfirmation: true,
            toolCall: AgentToolCall(
              title: 'غیرفعال‌کردن وظیفه',
              preview: 'وظیفهٔ «${job.title}» تا زمانی که دوباره فعالش کنی اجرا نمی‌شود.',
              execute: () async {
                await _jobs.setEnabled(job, false);
                return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
              },
            ),
          );
        }
        return AgentTurn(
          reply: 'وظیفهٔ «${job.title}» حذف شود؟ این کار بازگشت‌پذیر نیست.',
          requiresConfirmation: true,
          toolCall: AgentToolCall(
            title: 'حذف وظیفه',
            preview: 'وظیفهٔ «${job.title}» و تاریخچهٔ اجرای آن حذف می‌شود.',
            isDestructive: true,
            execute: () async {
              await _jobs.delete(job.id);
              return const ToolResult<Object?>.ok('وظیفه حذف شد.');
            },
          ),
        );

      case IntentType.unknown:
        return const AgentTurn(
          reply: 'این درخواست را متوجه نشدم. می‌توانم یادداشت ذخیره کنم، '
              'وظیفه بسازم یا خلاصهٔ پیام‌ها را بگویم. مثلاً بگو: '
              '«یادداشت جدید بساز: خرید نان» یا «یادآوری کن فردا ساعت ۹ تماس بگیرم».',
        );
    }
  }

  String _preview(String body) {
    const limit = 40;
    final trimmed = body.trim();
    if (trimmed.length <= limit) return trimmed;
    return '${trimmed.substring(0, limit).trimRight()}…';
  }

  static String _actionLabel(JobAction action) => switch (action) {
        JobAction.reminder => 'یادآوری',
        JobAction.dailyBriefing => 'خلاصهٔ روزانه',
        JobAction.messageSummary => 'خلاصهٔ پیام‌ها',
        JobAction.assistantPrompt => 'دستور به دستیار',
      };

  static const _helpText = 'کارهایی که الان می‌توانم انجام دهم:\n'
      '• «یادداشت جدید بساز: جلسهٔ فردا ساعت ۱۰»\n'
      '• «یادآوری کن فردا ساعت ۹ تماس بگیرم»\n'
      '• «هر روز ساعت ۸ خلاصهٔ پیام‌ها را بگو»\n'
      '• «خلاصهٔ امروز را بگو»\n'
      '• «وظیفه‌هایم را نشان بده»\n'
      'همهٔ این‌ها آفلاین و روی همین دستگاه انجام می‌شود.';
}
