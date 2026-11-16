import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/app_notification.dart';
import 'package:javid_ai/data/repositories/notification_repository.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpSqfliteFfi);

  late TestDatabase database;
  late NotificationRepository repository;

  setUp(() async {
    database = await openCleanDatabase();
    repository = NotificationRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  CapturedNotification build({
    String id = 'n1',
    String packageName = 'com.whatsapp',
    String dedupeKey = 'k1',
    DateTime? postedAt,
    bool read = false,
    bool summary = false,
  }) {
    final posted = postedAt ?? DateTime(2026, 11, 16, 9);
    return CapturedNotification(
      id: id,
      packageName: packageName,
      appLabel: 'WhatsApp',
      sender: 'علی',
      text: 'سلام',
      postedAt: posted,
      capturedAt: posted,
      dedupeKey: dedupeKey,
      isRead: read,
      isGroupSummary: summary,
    );
  }

  test('stores and lists notifications newest first', () async {
    await repository.insertIfNew(build(id: 'a', dedupeKey: 'a', postedAt: DateTime(2026, 11, 16, 8)));
    await repository.insertIfNew(build(id: 'b', dedupeKey: 'b', postedAt: DateTime(2026, 11, 16, 9)));
    final items = await repository.list();
    expect(items.map((item) => item.id), ['b', 'a']);
  });

  test('deduplicates by dedupe key', () async {
    final first = await repository.insertIfNew(build());
    final second = await repository.insertIfNew(build(id: 'n2'));
    expect(first, isTrue);
    expect(second, isFalse);
    expect(await repository.list(), hasLength(1));
  });

  test('group summaries are never surfaced', () async {
    await repository.insertIfNew(build(summary: true));
    expect(await repository.list(), isEmpty);
  });

  test('unread counts only unread, non-summary rows', () async {
    await repository.insertIfNew(build(id: '1', dedupeKey: '1'));
    await repository.insertIfNew(build(id: '2', dedupeKey: '2', read: true));
    await repository.insertIfNew(build(id: '3', dedupeKey: '3', summary: true));
    expect(await repository.unreadCount(), 1);
  });

  test('markRead and markAllRead update rows', () async {
    await repository.insertIfNew(build(id: '1', dedupeKey: '1'));
    await repository.insertIfNew(build(id: '2', dedupeKey: '2'));
    await repository.markRead('1');
    expect(await repository.unreadCount(), 1);
    await repository.markAllRead();
    expect(await repository.unreadCount(), 0);
  });

  test('since filters by post time', () async {
    await repository.insertIfNew(
      build(id: 'old', dedupeKey: 'old', postedAt: DateTime(2026, 11, 14, 9)),
    );
    await repository.insertIfNew(
      build(id: 'new', dedupeKey: 'new', postedAt: DateTime(2026, 11, 16, 9)),
    );
    final recent = await repository.since(DateTime(2026, 11, 16));
    expect(recent.map((item) => item.id), ['new']);
  });

  test('deleteBefore removes old rows and deleteAll clears everything', () async {
    await repository.insertIfNew(
      build(id: 'old', dedupeKey: 'old', postedAt: DateTime(2026, 10, 1)),
    );
    await repository.insertIfNew(build(id: 'new', dedupeKey: 'new'));
    expect(await repository.deleteBefore(DateTime(2026, 11, 1)), 1);
    expect(await repository.list(), hasLength(1));
    await repository.deleteAll();
    expect(await repository.list(), isEmpty);
  });

  test('source labels map packages to Persian names', () {
    expect(build(packageName: 'com.whatsapp').sourceLabel, 'واتساپ');
    expect(build(packageName: 'org.telegram.messenger').sourceLabel, 'تلگرام');
    expect(build(packageName: 'com.google.android.apps.messaging').sourceLabel, 'پیامک');
    expect(build(packageName: 'com.example.other').sourceLabel, 'WhatsApp');
  });

  test('package classification matches the Kotlin implementation', () {
    expect(NotificationSources.sourceForPackage('com.whatsapp.w4b'), NotificationSource.whatsapp);
    expect(NotificationSources.sourceForPackage('org.thunderdog.challegram'), NotificationSource.telegram);
    expect(NotificationSources.sourceForPackage('com.miui.smsextra'), NotificationSource.sms);
    expect(NotificationSources.sourceForPackage('com.example'), isNull);
  });
}
