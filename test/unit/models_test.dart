import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/assistant_message.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/data/models/job_run.dart';
import 'package:javid_ai/data/models/note.dart';

void main() {
  group('Note', () {
    final note = Note(
      id: 'n1',
      title: 'عنوان',
      body: 'متن',
      category: NoteCategories.work,
      createdAt: DateTime(2026, 11, 16, 8),
      updatedAt: DateTime(2026, 11, 16, 9),
      isPinned: true,
      source: NoteSource.voice,
    );

    test('round-trips through a map', () {
      final restored = Note.fromMap(note.toMap());
      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.isPinned, isTrue);
      expect(restored.source, NoteSource.voice);
      expect(restored.createdAt, note.createdAt);
    });

    test('displayTitle falls back to the body', () {
      final untitled = note.copyWith(title: '');
      expect(untitled.displayTitle, 'متن');
    });

    test('preview flattens newlines', () {
      expect(note.copyWith(body: 'خط اول\nخط دوم').preview, 'خط اول خط دوم');
    });

    test('category labels are Persian', () {
      expect(NoteCategories.label(NoteCategories.general), 'عمومی');
      expect(NoteCategories.label('unknown'), 'عمومی');
    });
  });

  group('Job', () {
    final job = Job(
      id: 'j1',
      title: 'خلاصه',
      prompt: 'خلاصه بده',
      kind: JobKind.briefing,
      schedule: const JobSchedule(kind: JobScheduleKind.daily, hour: 8, minute: 0),
      action: JobAction.dailyBriefing,
      nextRunAt: DateTime(2026, 11, 17, 8),
      createdAt: DateTime(2026, 11, 16, 8),
      lastStatus: JobStatus.success,
      runCount: 3,
    );

    test('round-trips through a map', () {
      final restored = Job.fromMap(job.toMap());
      expect(restored.title, job.title);
      expect(restored.schedule.hour, 8);
      expect(restored.action, JobAction.dailyBriefing);
      expect(restored.lastStatus, JobStatus.success);
      expect(restored.runCount, 3);
    });

    test('isRecurring and isActive reflect the schedule', () {
      expect(job.isRecurring, isTrue);
      expect(job.isActive, isTrue);
      final expired = Job(
        id: 'x',
        title: 'x',
        prompt: 'x',
        kind: JobKind.reminder,
        schedule: JobSchedule.once(DateTime(2026, 11, 16, 9)),
        action: JobAction.reminder,
        nextRunAt: null,
        createdAt: DateTime(2026, 11, 16, 8),
        runCount: 1,
      );
      expect(expired.isExpired, isTrue);
      expect(expired.isActive, isFalse);
    });

    test('copyWith can clear nullable fields', () {
      final updated = job.copyWith(clearNextRunAt: true, clearLastError: true);
      expect(updated.nextRunAt, isNull);
      expect(updated.lastError, isNull);
    });
  });

  group('JobRun', () {
    test('round-trips and computes duration', () {
      final run = JobRun(
        id: 'r1',
        jobId: 'j1',
        startedAt: DateTime(2026, 11, 16, 8),
        finishedAt: DateTime(2026, 11, 16, 8, 0, 2),
        status: JobStatus.success,
        output: 'ok',
      );
      final restored = JobRun.fromMap(run.toMap());
      expect(restored.jobId, 'j1');
      expect(restored.duration, const Duration(seconds: 2));
    });
  });

  group('AssistantMessage', () {
    test('round-trips meta', () {
      final message = AssistantMessage(
        id: 'm1',
        text: 'سلام',
        role: AssistantRole.user,
        createdAt: DateTime(2026, 11, 16, 8),
        source: AssistantTurnSource.voice,
        meta: const {'intent': 'greeting'},
      );
      final restored = AssistantMessage.fromMap(message.toMap());
      expect(restored.text, 'سلام');
      expect(restored.role, AssistantRole.user);
      expect(restored.source, AssistantTurnSource.voice);
    });
  });
}
