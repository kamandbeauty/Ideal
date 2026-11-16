import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/app_notification.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/data/repositories/job_repository.dart';
import 'package:javid_ai/data/repositories/note_repository.dart';
import 'package:javid_ai/features/agent/agent_core.dart';
import 'package:javid_ai/features/agent/intent_parser.dart';
import 'package:javid_ai/services/briefing_service.dart';
import 'package:javid_ai/services/job_service.dart';
import 'package:javid_ai/services/note_service.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpSqfliteFfi);

  final now = DateTime(2026, 11, 16, 10, 0);
  late TestDatabase database;
  late NoteService notes;
  late JobService jobs;
  late AgentCore agent;

  setUp(() async {
    database = await openCleanDatabase();
    notes = NoteService(NoteRepository(database));
    jobs = JobService(JobRepository(database), clock: () => now);
    agent = AgentCore(
      parser: IntentParser(clock: () => now),
      notes: notes,
      jobs: jobs,
      briefing: const BriefingService(),
      clock: () => now,
    );
  });

  tearDown(() async {
    await database.close();
  });

  CapturedNotification message(String sender, String text) => CapturedNotification(
        id: sender,
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
        sender: sender,
        text: text,
        postedAt: now.subtract(const Duration(minutes: 30)),
        capturedAt: now,
        dedupeKey: sender,
      );

  group('notes through the agent', () {
    test('note creation asks for confirmation and only saves on execute', () async {
      final turn = await agent.handle('یادداشت جدید بساز: خرید نان');
      expect(turn.requiresConfirmation, isTrue);
      expect(turn.toolCall, isNotNull);
      expect(await notes.count(), 0, reason: 'must not write before confirmation');

      final result = await turn.toolCall!.execute();
      expect(result.success, isTrue);
      expect(await notes.count(), 1);
    });

    test('lists notes as a bullet list', () async {
      await notes.create(body: 'اولی');
      await notes.create(body: 'دومی');
      final turn = await agent.handle('یادداشت‌ها را نشان بده');
      expect(turn.reply, contains('۲ یادداشت'));
      expect(turn.reply, contains('•'));
    });

    test('reading the latest note returns its body', () async {
      await notes.create(body: 'متن آخر');
      final turn = await agent.handle('آخرین یادداشت را بخوان');
      expect(turn.reply, contains('متن آخر'));
    });

    test('empty note commands ask for text instead of creating junk', () async {
      final turn = await agent.handle('یادداشت جدید بساز');
      expect(turn.toolCall, isNull);
      expect(turn.reply, contains('متن یادداشت'));
    });

    test('deleting a note needs confirmation and reports no data without it', () async {
      await notes.create(body: 'حذف‌شدنی');
      final turn = await agent.handle('یادداشت را حذف کن');
      expect(turn.requiresConfirmation, isTrue);
      expect(await notes.count(), 1);
      await turn.toolCall!.execute();
      expect(await notes.count(), 0);
    });
  });

  group('jobs through the agent', () {
    test('creates a daily job after confirmation', () async {
      final turn = await agent.handle('هر روز ساعت ۸ صبح خلاصهٔ پیام‌ها را بگو');
      expect(turn.requiresConfirmation, isTrue);
      expect(await jobs.list(), isEmpty);

      final result = await turn.toolCall!.execute();
      expect(result.success, isTrue);
      final created = await jobs.list();
      expect(created, hasLength(1));
      expect(created.single.action, JobAction.messageSummary);
      expect(created.single.nextRunAt, DateTime(2026, 11, 16, 20));
    });

    test('creates a one-off reminder for tomorrow', () async {
      final turn = await agent.handle('یادآوری کن فردا ساعت ۹ تماس بگیرم');
      await turn.toolCall!.execute();
      final created = (await jobs.list()).single;
      expect(created.nextRunAt, DateTime(2026, 11, 17, 9));
      expect(created.title, contains('تماس'));
    });

    test('lists active jobs', () async {
      final turn = await agent.handle('هر روز ساعت ۹ یادآوری کن ورزش');
      await turn.toolCall!.execute();
      final list = await agent.handle('وظیفه‌هایم را نشان بده');
      expect(list.reply, contains('ورزش'));
    });

    test('pausing a job requires confirmation', () async {
      final createTurn = await agent.handle('هر روز ساعت ۹ یادآوری کن ورزش');
      await createTurn.toolCall!.execute();
      final pause = await agent.handle('وظیفهٔ ورزش را غیرفعال کن');
      expect(pause.requiresConfirmation, isTrue);
      await pause.toolCall!.execute();
      final jobsAfter = await jobs.list();
      expect(jobsAfter.single.enabled, isFalse);
    });
  });

  group('briefing through the agent', () {
    test('briefing uses injected notifications and never invents data', () async {
      final quiet = await agent.handle('خلاصهٔ امروز را بگو');
      expect(quiet.reply, contains('پیام تازه‌ای ثبت نشده'));

      final noisy = AgentCore(
        parser: IntentParser(clock: () => now),
        notes: notes,
        jobs: jobs,
        briefing: const BriefingService(),
        notifications: [message('سارا', 'جلسه ساعت ۱۰')],
        clock: () => now,
      );
      final turn = await noisy.handle('خلاصهٔ امروز را بگو');
      expect(turn.reply, contains('۱ پیام'));
      expect(turn.reply, contains('واتساپ'));
    });

    test('greeting mentions the time of day', () async {
      final turn = await agent.handle('سلام');
      expect(turn.reply, contains('صبح بخیر'));
    });

    test('help lists real capabilities', () async {
      final turn = await agent.handle('چه کارهایی می‌توانی انجام بدهی؟');
      expect(turn.reply, contains('یادداشت'));
      expect(turn.reply, contains('یادآوری'));
    });

    test('unknown input gets a helpful fallback with examples', () async {
      final turn = await agent.handle('آب و هوا چطور است؟');
      expect(turn.reply, contains('متوجه نشدم'));
      expect(turn.toolCall, isNull);
    });
  });
}
