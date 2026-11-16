import '../core/utils/id_gen.dart';
import '../data/models/app_notification.dart';

/// Pure conversion from the Kotlin capture buffer to [CapturedNotification]s.
///
/// Kept free of Android types so it is unit-testable: the bridge returns plain
/// maps, this class validates them, filters disabled sources and builds stable
/// ids/dedupe keys.
class NotificationIngestor {
  const NotificationIngestor._();

  /// Converts [raw] maps (packageName/appLabel/sender/text/postedAt/dedupeKey)
  /// into notifications, skipping:
  ///  * entries from sources the user disabled,
  ///  * unknown package names,
  ///  * malformed or empty entries.
  static List<CapturedNotification> convert({
    required List<Map<String, Object?>> raw,
    required bool Function(NotificationSource source) isSourceEnabled,
    DateTime? capturedAt,
  }) {
    final now = capturedAt ?? DateTime.now();
    final result = <CapturedNotification>[];
    for (final entry in raw) {
      final packageName = (entry['packageName'] as String?)?.trim() ?? '';
      if (packageName.isEmpty) continue;
      final source = NotificationSources.sourceForPackage(packageName) ??
          NotificationSource.other;
      if (!isSourceEnabled(source)) continue;

      final sender = (entry['sender'] as String?)?.trim() ?? '';
      final text = (entry['text'] as String?)?.trim() ?? '';
      if (sender.isEmpty && text.isEmpty) continue;

      final postedAtMillis = _toMillis(entry['postedAt']);
      final postedAt = postedAtMillis == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(postedAtMillis);

      final dedupeKey = (entry['dedupeKey'] as String?)?.trim().isNotEmpty == true
          ? entry['dedupeKey']! as String
          : '$packageName|$sender|$text';

      result.add(
        CapturedNotification(
          id: newId(),
          packageName: packageName,
          appLabel: (entry['appLabel'] as String?) ?? packageName,
          sender: sender,
          text: text,
          postedAt: postedAt,
          capturedAt: now,
          dedupeKey: dedupeKey,
          isUrgent: _looksUrgent('$sender $text'),
        ),
      );
    }
    return result;
  }

  /// Imports [raw] into storage, returning how many new rows were written.
  static Future<int> import({
    required List<Map<String, Object?>> raw,
    required bool Function(NotificationSource source) isSourceEnabled,
    required Future<bool> Function(CapturedNotification notification) insertIfNew,
    DateTime? capturedAt,
  }) async {
    final converted = convert(
      raw: raw,
      isSourceEnabled: isSourceEnabled,
      capturedAt: capturedAt,
    );
    var inserted = 0;
    for (final notification in converted) {
      if (await insertIfNew(notification)) inserted++;
    }
    return inserted;
  }

  static int? _toMillis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static const _urgentWords = <String>[
    'فوری', 'اورژانس', 'اضطراری', 'مهلت', 'پرداخت', 'بدهی',
    'urgent', 'asap', 'deadline',
  ];

  static bool _looksUrgent(String haystack) {
    final lowered = haystack.toLowerCase();
    return _urgentWords.any(lowered.contains);
  }
}
