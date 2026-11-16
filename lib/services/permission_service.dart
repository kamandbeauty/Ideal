import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request, in language the UI can present directly.
enum PermissionOutcome { granted, denied, permanentlyDenied }

/// All device permissions JavidAI asks for, with Persian explanations.
enum JavidPermission {
  microphone(
    label: 'میکروفون',
    why: 'برای شنیدن دستورهای صوتی و تبدیل گفتار به متن لازم است. '
        'صدا فقط هنگام فشردن دکمهٔ میکروفون ضبط می‌شود.',
  ),
  notifications(
    label: 'اعلان‌ها',
    why: 'برای نمایش یادآوری وظیفه‌ها و خلاصهٔ روزانه لازم است.',
  ),
  notificationAccess(
    label: 'دسترسی به اعلان‌ها',
    why: 'برای خواندن پیام‌های واتساپ، تلگرام و پیامک از نوار اعلان. '
        'این دسترسی با تأیید خودت در تنظیمات اندروید فعال می‌شود.',
  );

  const JavidPermission({required this.label, required this.why});

  final String label;
  final String why;
}

/// Thin wrapper over `permission_handler` so the rest of the app never touches
/// plugin types directly (and tests can fake it).
class PermissionService {
  const PermissionService();

  Future<PermissionOutcome> request(JavidPermission permission) async {
    final target = _map(permission);
    if (target == null) return PermissionOutcome.denied;
    var status = await target.status;
    if (status.isGranted) return PermissionOutcome.granted;
    status = await target.request();
    if (status.isGranted || status.isLimited) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }

  Future<bool> isGranted(JavidPermission permission) async {
    final target = _map(permission);
    if (target == null) return false;
    return (await target.status).isGranted;
  }

  /// Opens the system settings page where the user can re-enable a permission.
  Future<bool> openSettings() => openAppSettings();

  Permission? _map(JavidPermission permission) => switch (permission) {
        JavidPermission.microphone => Permission.microphone,
        JavidPermission.notifications => Permission.notification,
        // Notification *listener* access is granted through a special system
        // screen, handled natively (see NativeBridge.openNotificationSettings).
        JavidPermission.notificationAccess => null,
      };
}
