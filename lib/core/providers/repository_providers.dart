import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import '../../data/models/assistant_message.dart';
import '../../data/repositories/notification_repository.dart';
import 'database_provider.dart';

/// Captured notifications, newest first.
final notificationsProvider = FutureProvider<List<CapturedNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).list(),
);

/// Assistant activity log, newest first.
final assistantMessagesProvider = FutureProvider<List<AssistantMessage>>(
  (ref) => ref.watch(assistantRepositoryProvider).recent(),
);

/// Number of unread notifications (badge on the navigation bar).
final unreadNotificationsProvider = FutureProvider<int>(
  (ref) => ref.watch(notificationRepositoryProvider).unreadCount(),
);

/// Exposes the repository through the container for one-off writes.
final notificationActionsProvider = Provider<NotificationRepository>(
  (ref) => ref.watch(notificationRepositoryProvider),
);
