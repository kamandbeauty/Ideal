import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/app_notification.dart';
import 'package:javid_ai/services/notification_ingestor.dart';

void main() {
  final captured = DateTime(2026, 11, 16, 12);
  bool allSources(NotificationSource source) => true;

  Map<String, Object?> entry({
    String packageName = 'com.whatsapp',
    String sender = 'علی',
    String text = 'سلام',
    Object? postedAt = 1763290800000,
    String? dedupeKey = 'k1',
  }) =>
      {
        'packageName': packageName,
        'appLabel': 'WhatsApp',
        'sender': sender,
        'text': text,
        'postedAt': postedAt,
        'dedupeKey': dedupeKey,
      };

  test('converts a valid native entry', () {
    final result = NotificationIngestor.convert(
      raw: [entry()],
      isSourceEnabled: allSources,
      capturedAt: captured,
    );
    expect(result, hasLength(1));
    final notification = result.single;
    expect(notification.packageName, 'com.whatsapp');
    expect(notification.sender, 'علی');
    expect(notification.text, 'سلام');
    expect(notification.postedAt.millisecondsSinceEpoch, 1763290800000);
    expect(notification.id, isNotEmpty);
  });

  test('skips entries from disabled sources', () {
    final result = NotificationIngestor.convert(
      raw: [entry()],
      isSourceEnabled: (source) => source != NotificationSource.whatsapp,
      capturedAt: captured,
    );
    expect(result, isEmpty);
  });

  test('keeps unknown packages only when "other" is enabled', () {
    final raw = [entry(packageName: 'com.example.app', dedupeKey: 'x')];
    expect(
      NotificationIngestor.convert(
        raw: raw,
        isSourceEnabled: (source) => source == NotificationSource.other,
        capturedAt: captured,
      ),
      hasLength(1),
    );
    expect(
      NotificationIngestor.convert(
        raw: raw,
        isSourceEnabled: (source) => source != NotificationSource.other,
        capturedAt: captured,
      ),
      isEmpty,
    );
  });

  test('drops empty and malformed rows', () {
    final result = NotificationIngestor.convert(
      raw: [
        {'packageName': '', 'sender': 'x', 'text': 'y'},
        entry(sender: '', text: ''),
        entry(packageName: 'org.telegram.messenger', dedupeKey: 't'),
      ],
      isSourceEnabled: allSources,
      capturedAt: captured,
    );
    expect(result, hasLength(1));
    expect(result.single.packageName, 'org.telegram.messenger');
  });

  test('falls back to capture time for invalid timestamps', () {
    final result = NotificationIngestor.convert(
      raw: [entry(postedAt: 'not-a-number')],
      isSourceEnabled: allSources,
      capturedAt: captured,
    );
    expect(result.single.postedAt, captured);
  });

  test('builds a dedupe key when the native one is missing', () {
    final result = NotificationIngestor.convert(
      raw: [entry(dedupeKey: '')],
      isSourceEnabled: allSources,
      capturedAt: captured,
    );
    expect(result.single.dedupeKey, 'com.whatsapp|علی|سلام');
  });

  test('flags urgent messages without inventing content', () {
    final result = NotificationIngestor.convert(
      raw: [entry(text: 'پرداخت قبض تا فردا')],
      isSourceEnabled: allSources,
      capturedAt: captured,
    );
    expect(result.single.isUrgent, isTrue);
    expect(result.single.text, 'پرداخت قبض تا فردا');
  });

  test('import() writes through and reports new rows only', () async {
    final seen = <String>{};
    final raw = [entry(), entry()];
    final inserted = await NotificationIngestor.import(
      raw: raw,
      isSourceEnabled: allSources,
      capturedAt: captured,
      insertIfNew: (notification) async {
        return seen.add(notification.dedupeKey);
      },
    );
    expect(inserted, 1, reason: 'identical dedupe keys collapse to one row');
  });
}
