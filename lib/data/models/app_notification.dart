/// A notification captured from the Android notification listener.
///
/// Only the fields required by the product are kept: application, sender, a
/// trimmed body, the timestamp and a deduplication key. Media, images, replies
/// and any other notification payload are never stored.
class CapturedNotification {
  const CapturedNotification({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.sender,
    required this.text,
    required this.postedAt,
    required this.capturedAt,
    required this.dedupeKey,
    this.isGroupSummary = false,
    this.isRead = false,
    this.isUrgent = false,
  });

  final String id;
  final String packageName;
  final String appLabel;
  final String sender;

  /// Trimmed notification text (subject/title + first lines of the body).
  final String text;
  final DateTime postedAt;
  final DateTime capturedAt;
  final String dedupeKey;
  final bool isGroupSummary;
  final bool isRead;
  final bool isUrgent;

  /// Display name of the source application in Persian.
  String get sourceLabel => switch (packageName) {
        'com.whatsapp' || 'com.whatsapp.w4b' => 'واتساپ',
        'org.telegram.messenger' ||
        'org.telegram.messenger.web' ||
        'org.thunderdog.challegram' =>
          'تلگرام',
        'com.google.android.apps.messaging' ||
        'com.android.mms' ||
        'com.samsung.android.messaging' =>
          'پیامک',
        _ => appLabel,
      };

  CapturedNotification copyWith({bool? isRead, bool? isUrgent}) => CapturedNotification(
        id: id,
        packageName: packageName,
        appLabel: appLabel,
        sender: sender,
        text: text,
        postedAt: postedAt,
        capturedAt: capturedAt,
        dedupeKey: dedupeKey,
        isGroupSummary: isGroupSummary,
        isRead: isRead ?? this.isRead,
        isUrgent: isUrgent ?? this.isUrgent,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'package_name': packageName,
        'app_label': appLabel,
        'sender': sender,
        'text': text,
        'posted_at': postedAt.millisecondsSinceEpoch,
        'captured_at': capturedAt.millisecondsSinceEpoch,
        'dedupe_key': dedupeKey,
        'is_group_summary': isGroupSummary ? 1 : 0,
        'is_read': isRead ? 1 : 0,
        'is_urgent': isUrgent ? 1 : 0,
      };

  static CapturedNotification fromMap(Map<String, Object?> map) => CapturedNotification(
        id: map['id']! as String,
        packageName: (map['package_name'] as String?) ?? '',
        appLabel: (map['app_label'] as String?) ?? '',
        sender: (map['sender'] as String?) ?? '',
        text: (map['text'] as String?) ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch(map['posted_at']! as int),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at']! as int),
        dedupeKey: (map['dedupe_key'] as String?) ?? '',
        isGroupSummary: (map['is_group_summary'] as int? ?? 0) == 1,
        isRead: (map['is_read'] as int? ?? 0) == 1,
        isUrgent: (map['is_urgent'] as int? ?? 0) == 1,
      );
}

/// Notification sources the user can toggle individually.
enum NotificationSource { whatsapp, telegram, sms, other }

abstract final class NotificationSources {
  /// Package names grouped by source. Kept in Dart so the mapping is testable
  /// and can evolve without touching the native service.
  static const packages = <NotificationSource, List<String>>{
    NotificationSource.whatsapp: ['com.whatsapp', 'com.whatsapp.w4b'],
    NotificationSource.telegram: [
      'org.telegram.messenger',
      'org.telegram.messenger.web',
      'org.thunderdog.challegram',
      'org.telegram.plus',
    ],
    NotificationSource.sms: [
      'com.google.android.apps.messaging',
      'com.android.mms',
      'com.samsung.android.messaging',
      'com.miui.smsextra',
    ],
  };

  static NotificationSource? sourceForPackage(String packageName) {
    for (final entry in packages.entries) {
      if (entry.value.contains(packageName)) return entry.key;
    }
    return null;
  }

  static const labels = <NotificationSource, String>{
    NotificationSource.whatsapp: 'واتساپ',
    NotificationSource.telegram: 'تلگرام',
    NotificationSource.sms: 'پیامک',
    NotificationSource.other: 'سایر برنامه‌ها',
  };
}
