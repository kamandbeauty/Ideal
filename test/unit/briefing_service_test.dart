import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/app_notification.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/services/briefing_service.dart';

void main() {
  final now = DateTime(2026, 11, 16, 8, 30);
  const briefing = BriefingService();

  CapturedNotification notification({
    required String packageName,
    required String sender,
    required String text,
    required DateTime postedAt,
  }) {
    return CapturedNotification(
      id: '${packageName}_${postedAt.millisecondsSinceEpoch}',
      packageName: packageName,
      appLabel: 'App',
      sender: sender,
      text: text,
      postedAt: postedAt,
      capturedAt: postedAt,
      dedupeKey: '${packageName}_$sender',
    );
  }

  Job job({
    required String title,
    required DateTime nextRunAt,
    bool enabled = true,
  }) {
    return Job(
      id: title,
      title: title,
      prompt: title,
      kind: JobKind.reminder,
      schedule: JobSchedule.once(nextRunAt),
      action: JobAction.reminder,
      nextRunAt: nextRunAt,
      createdAt: now,
      enabled: enabled,
    );
  }

  test('briefing says so honestly when nothing happened', () {
    final text = briefing.build(now: now, notifications: const [], jobs: const []);
    expect(text, contains('پیام تازه‌ای ثبت نشده'));
    expect(text, contains('صبح بخیر'));
  });

  test('briefing counts messages per source with Persian digits', () {
    final items = [
      notification(
        packageName: 'com.whatsapp',
        sender: 'علی',
        text: 'سلام',
        postedAt: now.subtract(const Duration(hours: 1)),
      ),
      notification(
        packageName: 'com.whatsapp',
        sender: 'مریم',
        text: 'پروژه چیست؟',
        postedAt: now.subtract(const Duration(hours: 2)),
      ),
      notification(
        packageName: 'org.telegram.messenger',
        sender: 'گروه',
        text: 'جلسه ساعت ۱۰',
        postedAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
    final text = briefing.build(now: now, notifications: items, jobs: const []);
    expect(text, contains('۳ پیام'));
    expect(text, contains('۲ پیام از واتساپ'));
    expect(text, contains('۱ پیام از تلگرام'));
  });

  test('briefing highlights the next job and urgent items', () {
    final items = [
      notification(
        packageName: 'com.whatsapp',
        sender: 'مدیر',
        text: 'این موضوع فوری است',
        postedAt: now.subtract(const Duration(minutes: 10)),
      ),
    ];
    final jobs = [job(title: 'تماس با پزشک', nextRunAt: DateTime(2026, 11, 16, 10))];
    final text = briefing.build(now: now, notifications: items, jobs: jobs);
    expect(text, contains('تماس با پزشک'));
    expect(text, contains('۱۰:۰۰'));
    expect(text, contains('فوری'));
  });

  test('briefing ignores notifications from previous days', () {
    final items = [
      notification(
        packageName: 'com.whatsapp',
        sender: 'دیروز',
        text: 'پیام قدیمی',
        postedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    final text = briefing.build(now: now, notifications: items, jobs: const []);
    expect(text, contains('پیام تازه‌ای ثبت نشده'));
  });

  test('briefing never invents content when asked for details', () {
    final text = briefing.build(
      now: now,
      notifications: const [],
      jobs: const [],
      includeContent: true,
    );
    expect(text, isNot(contains('خلاصهٔ پیام‌ها:')));
  });

  test('urge detector matches Persian and English keywords', () {
    expect(
      BriefingService.isUrgent(
        notification(
          packageName: 'com.whatsapp',
          sender: 'x',
          text: 'پرداخت قبض',
          postedAt: now,
        ),
      ),
      isTrue,
    );
    expect(
      BriefingService.isUrgent(
        notification(
          packageName: 'com.whatsapp',
          sender: 'x',
          text: 'سلام، خوبی؟',
          postedAt: now,
        ),
      ),
      isFalse,
    );
  });

  test('summarize builds a compact one-liner', () {
    final summary = briefing.summarize(
      now: now,
      notifications: [
        notification(
          packageName: 'org.telegram.messenger',
          sender: 'x',
          text: 'hi',
          postedAt: now,
        ),
      ],
      jobs: [job(title: 'j', nextRunAt: now.add(const Duration(hours: 1)))],
    );
    expect(summary, contains('۱ پیام'));
    expect(summary, contains('تلگرام: ۱'));
    expect(summary, contains('۱ وظیفه'));
  });
}
