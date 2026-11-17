import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/job.dart';

void main() {
  group('JobSchedule.nextRun', () {
    test('one-off returns its anchor only when in the future', () {
      final at = DateTime(2026, 11, 17, 9, 0);
      final schedule = JobSchedule.once(at);
      expect(schedule.nextRun(DateTime(2026, 11, 16, 10)), at);
      expect(schedule.nextRun(DateTime(2026, 11, 18, 10)), isNull);
    });

    test('daily fires today when the time is still ahead', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.daily,
        hour: 20,
        minute: 0,
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10)),
        DateTime(2026, 11, 16, 20),
      );
    });

    test('daily rolls to tomorrow when the time has passed', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.daily,
        hour: 8,
        minute: 0,
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10)),
        DateTime(2026, 11, 17, 8),
      );
    });

    test('weekly finds the next matching weekday', () {
      // now is Monday 2026-11-16; weekly on Saturday at 10:00.
      final schedule = const JobSchedule(
        kind: JobScheduleKind.weekly,
        hour: 10,
        minute: 0,
        weekday: DateTime.saturday,
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10)),
        DateTime(2026, 11, 21, 10),
      );
    });

    test('weekly returns today when it is the right day and still ahead', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.weekly,
        hour: 18,
        minute: 0,
        weekday: DateTime.monday,
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10)),
        DateTime(2026, 11, 16, 18),
      );
    });

    test('interval advances from the anchor in fixed steps', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.interval,
        intervalMinutes: 60,
        anchor: DateTime(2026, 11, 16, 8),
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10, 30)),
        DateTime(2026, 11, 16, 11),
      );
    });

    test('interval returns the anchor when it is still in the future', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.interval,
        intervalMinutes: 30,
        anchor: DateTime(2026, 11, 16, 12),
      );
      expect(
        schedule.nextRun(DateTime(2026, 11, 16, 10)),
        DateTime(2026, 11, 16, 12),
      );
    });

    test('invalid schedules return null instead of throwing', () {
      const schedule = const JobSchedule(kind: JobScheduleKind.daily);
      expect(schedule.isValid, isFalse);
      expect(schedule.nextRun(DateTime(2026)), isNull);
    });
  });

  group('JobSchedule JSON round-trip', () {
    test('daily schedule survives serialisation', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.daily,
        hour: 8,
        minute: 30,
      );
      final restored = JobSchedule.fromJson(schedule.toJson());
      expect(restored.kind, JobScheduleKind.daily);
      expect(restored.hour, 8);
      expect(restored.minute, 30);
    });

    test('one-off anchor survives serialisation', () {
      final at = DateTime(2026, 11, 17, 9, 15);
      final restored = JobSchedule.fromJson(JobSchedule.once(at).toJson());
      expect(restored.anchor, at);
      expect(restored.kind, JobScheduleKind.once);
    });

    test('malformed JSON yields an invalid schedule rather than crashing', () {
      final restored = JobSchedule.fromJson('not json at all');
      expect(restored.isValid, isFalse);
    });
  });

  group('labels', () {
    test('daily label uses 24h times', () {
      final schedule = const JobSchedule(kind: JobScheduleKind.daily, hour: 8, minute: 0);
      expect(schedule.label, 'هر روز ساعت 08:00');
    });

    test('weekly label names the weekday', () {
      final schedule = const JobSchedule(
        kind: JobScheduleKind.weekly,
        hour: 10,
        minute: 0,
        weekday: DateTime.saturday,
      );
      expect(schedule.label, contains('شنبه'));
    });

    test('interval label prefers hours for whole hours', () {
      const schedule = JobSchedule(
        kind: JobScheduleKind.interval,
        intervalMinutes: 120,
      );
      expect(schedule.label, 'هر 2 ساعت');
    });
  });
}
