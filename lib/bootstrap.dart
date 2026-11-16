import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/database_provider.dart';
import 'core/providers/permission_providers.dart';
import 'core/providers/repository_providers.dart';
import 'core/providers/settings_providers.dart';
import 'data/local/app_database.dart';
import 'services/notification_ingestor.dart';

/// Opens the database, wires the provider graph and pulls in notifications that
/// were captured natively while the app was closed.
Future<ProviderContainer> bootstrap() async {
  final database = AppDatabase();
  await database.open();

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );

  await _importPendingNotifications(container);
  unawaited(_purgeOldNotifications(container));

  return container;
}

/// Copies notifications buffered by the Kotlin listener into SQLite.
Future<int> _importPendingNotifications(ProviderContainer container) async {
  final bridge = container.read(nativeBridgeProvider);
  final hasAccess = await bridge.hasNotificationAccess();
  if (!hasAccess) return 0;

  final raw = await bridge.fetchCapturedNotifications(limit: 100);
  if (raw.isEmpty) return 0;

  final enabledSources = container.read(notificationSourceProvider);
  final repository = container.read(notificationRepositoryProvider);
  final imported = await NotificationIngestor.import(
    raw: raw,
    isSourceEnabled: (source) => enabledSources[source] ?? false,
    insertIfNew: repository.insertIfNew,
  );
  if (imported > 0) {
    container.invalidate(notificationsProvider);
    container.invalidate(unreadNotificationsProvider);
  }
  return imported;
}

/// Applies the retention window (default 30 days) to captured messages.
Future<int> _purgeOldNotifications(ProviderContainer container) async {
  final settings = container.read(settingsRepositoryProvider);
  final raw = await settings.read(SettingsKeys.notificationRetentionDays);
  final days = int.tryParse(raw ?? '') ?? 30;
  if (days <= 0) return 0;
  final deleted = await container
      .read(notificationRepositoryProvider)
      .deleteBefore(DateTime.now().subtract(Duration(days: days)));
  if (deleted > 0) {
    container.invalidate(notificationsProvider);
    container.invalidate(unreadNotificationsProvider);
  }
  return deleted;
}

/// Exposed for tests and for a manual "refresh" action in settings.
Future<int> importCapturedNotifications(ProviderContainer container) =>
    _importPendingNotifications(container);
