import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/native_bridge.dart';
import '../../services/permission_service.dart';

/// Permission requests, overridable in tests.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

/// Native bridge (notification access, alarms, battery optimisation).
final nativeBridgeProvider = Provider<NativeBridge>((ref) => nativeBridge);

/// Whether the notification listener is enabled in Android settings.
final notificationAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(nativeBridgeProvider).hasNotificationAccess(),
);

/// Whether the app may run background jobs without battery restrictions.
final batteryOptimizationExemptProvider = FutureProvider<bool>(
  (ref) => ref.watch(nativeBridgeProvider).isIgnoringBatteryOptimizations(),
);
