import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/data/models/note.dart';
import 'package:javid_ai/features/agent/intent.dart';
import 'package:javid_ai/features/agent/intent_parser.dart';

void main() {
  // Fixed "now": Monday 2026-11-16, 10:00 local time.
  final now = DateTime(2026, 11, 16, 10, 0);
  late IntentParser parser;

  setUp(() => parser = IntentParser(clock: () => now));

  group('greetings and help', () {
    test('recognises a greeting', () {
      expect(parser.parse('سلام جویده').type, IntentType.greeting);
    });

    test('recognises a help request', () {
      expect(parser.parse('چه کارهایی می‌توانی انجام بدهی؟').type, IntentType.help);
    });
  });

  group('notes', () {
    test('creates a note from an explicit save command', () {
      final intent = parser.parse('این متن را ذخیره کن: جلسهٔ فردا ساعت ده');
      expect(intent.type, IntentType.createNote);
      expect(intent.slot<String>('body'), 'جلسهٔ فردا ساعت ده');
    });

    test('creates a note from «یادداشت جدید بساز»', () {
      final intent = parser.parse('یادداشت جدید بساز خرید نان و شیر');
      expect(intent.type, IntentType.createNote);
      expect(intent.slot<String>('body'), contains('خرید نان'));
    });

    test('extracts quoted note bodies', () {
      final intent = parser.parse('این را ذخیره کن «شمارهٔ دفتر: ۰۲۱۱۲۳۴۵»');
      expect(intent.type, IntentType.createNote);
      // Quoted content is stored exactly as dictated: the user picked those
      // characters (ZWNJ, Persian digits) on purpose.
      expect(intent.slot<String>('body'), 'شمارهٔ دفتر: ۰۲۱۱۲۳۴۵');
    });

    test('infers the work category', () {
      final intent = parser.parse('یادداشت جدید بساز: جلسهٔ پروژه');
      expect(intent.slot<String>('category'), NoteCategories.work);
    });

    test('asks for the body when the command has none', () {
      final intent = parser.parse('یادداشت جدید بساز');
      expect(intent.type, IntentType.createNote);
      expect(intent.slot<bool>('needsBody'), isTrue);
    });

    test('lists notes', () {
      expect(parser.parse('یادداشت‌هایم را نشان بده').type, IntentType.listNotes);
    });

    test('deletes the latest note with confirmation', () {
      expect(parser.parse('یادداشت را حذف کن').type, IntentType.deleteNote);
    });
  });

  group('job creation', () {
    test('daily reminder with a Persian word hour', () {
      final intent = parser.parse('هر روز ساعت ۸ صبح خلاصهٔ پیام‌ها را بگو');
      expect(intent.type, IntentType.createJob);
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.daily);
      expect(schedule.hour, 8);
      expect(schedule.minute, 0);
      expect(intent.slot<JobAction>('action'), JobAction.messageSummary);
    });

    test('daily news summary keeps the briefing action', () {
      final intent = parser.parse('هر روز ساعت ۸ اخبار مهم را خلاصه کن');
      expect(intent.type, IntentType.createJob);
      expect(intent.slot<JobAction>('action'), JobAction.dailyBriefing);
      expect(intent.slot<String>('title'), contains('اخبار'));
    });

    test('one-off reminder for tomorrow at 09:00', () {
      final intent = parser.parse('یادآوری کن فردا ساعت ۹ تماس بگیرم');
      expect(intent.type, IntentType.createJob);
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.once);
      expect(schedule.onceAt, DateTime(2026, 11, 17, 9, 0));
      expect(schedule.onceAt!.isAfter(now), isTrue);
    });

    test('handles «نه و نیم» clock expressions', () {
      final intent = parser.parse('فردا ساعت نه و نیم یادآوری کن جلسه دارم');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.onceAt, DateTime(2026, 11, 17, 9, 30));
    });

    test('handles «و ربع» quarter hours', () {
      final intent = parser.parse('فردا ساعت ۱۰ و ربع یادآوری کن');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.hour, 10);
      expect(schedule.minute, 15);
    });

    test('«۸ شب» becomes 20:00', () {
      final intent = parser.parse('هر شب ساعت ۸ شب خلاصه بده');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.daily);
      expect(schedule.hour, 20);
    });

    test('interval schedules respect the 15 minute minimum', () {
      final intent = parser.parse('هر ۵ دقیقه خلاصه بده');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.interval);
      expect(schedule.intervalMinutes, greaterThanOrEqualTo(15));
    });

    test('weekly schedule on Saturday', () {
      final intent = parser.parse('هر شنبه ساعت ۱۰ یادآوری کن');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.weekly);
      expect(schedule.weekday, DateTime.saturday);
    });

    test('a past clock time rolls over to tomorrow', () {
      final intent = parser.parse('ساعت ۸ یادآوری کن');
      final schedule = intent.slot<ScheduleRequest>('schedule')!;
      expect(schedule.kind, JobScheduleKind.once);
      expect(schedule.onceAt, DateTime(2026, 11, 17, 8, 0));
    });
  });

  group('briefing', () {
    test('recognises a spoken briefing request', () {
      final intent = parser.parse('خلاصهٔ امروز را بگو');
      expect(intent.type, IntentType.dailyBriefing);
    });

    test('message summary without a schedule is not a job', () {
      final intent = parser.parse('پیام‌های امروز را خلاصه کن');
      expect(intent.type, IntentType.dailyBriefing);
    });
  });

  group('unrecognised input', () {
    test('falls back to unknown', () {
      expect(parser.parse('گربه‌ها چرا خرخر می‌کنند؟').type, IntentType.unknown);
    });

    test('empty input is unknown', () {
      expect(parser.parse('   ').type, IntentType.unknown);
    });
  });
}
