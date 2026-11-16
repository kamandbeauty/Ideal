import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/permission_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import '../../services/permission_service.dart';

/// Privacy center: what is stored, why, and how to delete or export it.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static const _permissions = JavidPermission.values;

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final database = await ref.read(appDatabaseProvider).open();
    final tables = ['notes', 'jobs', 'job_runs', 'notifications', 'assistant_messages'];
    final buffer = StringBuffer('JavidAI export\n');
    buffer.writeln('generatedAt: ${DateTime.now().toIso8601String()}\n');
    for (final table in tables) {
      final rows = await database.query(table);
      buffer.writeln('## $table (${rows.length} rows)');
      for (final row in rows) {
        buffer.writeln(row.toString());
      }
      buffer.writeln();
    }
    final text = buffer.toString();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${text.split('\n').length} خط از داده‌ها در کلیپ‌بورد کپی شد.'),
        ),
      );
    }
  }

  Future<void> _deleteNotifications(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'حذف همهٔ پیام‌های ضبط‌شده',
      body: 'همهٔ پیام‌های ذخیره‌شده از نوار اعلان پاک می‌شوند.',
    );
    if (confirmed != true) return;
    await ref.read(notificationRepositoryProvider).deleteAll();
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(unreadNotificationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیام‌های ذخیره‌شده حذف شدند.')),
      );
    }
  }

  Future<void> _deleteHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'حذف تاریخچهٔ دستیار',
      body: 'متن گفتگوها و نتایج اجرای وظایف پاک می‌شود.',
    );
    if (confirmed != true) return;
    await ref.read(assistantRepositoryProvider).clear();
    ref.invalidate(assistantMessagesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخچه پاک شد.')),
      );
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bridge = ref.watch(nativeBridgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حریم خصوصی و داده‌ها')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionHeader(
            title: 'چه چیزی ذخیره می‌شود؟',
            icon: Icons.inventory_2_outlined,
          ),
          _Bullet(
            icon: Icons.sticky_note_2_outlined,
            title: 'یادداشت‌ها',
            body: 'متن، عنوان، دسته و زمان ایجاد/ویرایش — فقط روی دستگاه.',
          ),
          _Bullet(
            icon: Icons.alarm_rounded,
            title: 'وظایف',
            body: 'عنوان، زمان‌بندی، وضعیت و تاریخچهٔ اجرا — فقط روی دستگاه.',
          ),
          _Bullet(
            icon: Icons.forum_outlined,
            title: 'پیام‌ها',
            body: 'برنامهٔ فرستنده، نام فرستنده، متن اعلان و زمان — با قابلیت حذف.',
          ),
          _Bullet(
            icon: Icons.history_rounded,
            title: 'فعالیت دستیار',
            body: 'متن دستورها و پاسخ‌ها برای نمایش تاریخچه — با قابلیت حذف.',
          ),
          _Bullet(
            icon: Icons.vpn_key_outlined,
            title: 'کلید API',
            body: 'در Keystore اندروید؛ در پایگاه‌داده یا کد ذخیره نمی‌شود.',
          ),
          const SectionHeader(
            title: 'دسترسی‌ها',
            icon: Icons.verified_user_outlined,
          ),
          for (final permission in _permissions)
            _Bullet(
              icon: Icons.check_circle_outline_rounded,
              title: permission.label,
              body: permission.why,
            ),
          const SectionHeader(
            title: 'کنترل‌ها',
            icon: Icons.tune_rounded,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('خروجی گرفتن از داده‌ها'),
            subtitle: const Text('یک نسخهٔ متنی از همهٔ داده‌ها در کلیپ‌بورد کپی می‌شود.'),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.coral),
            title: const Text('حذف همهٔ پیام‌های ضبط‌شده'),
            onTap: () => _deleteNotifications(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_delete_outlined, color: AppColors.coral),
            title: const Text('حذف تاریخچهٔ دستیار'),
            onTap: () => _deleteHistory(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('باز کردن تنظیمات دسترسی‌ها'),
            onTap: () async {
              final permission = ref.read(permissionServiceProvider);
              await bridge.openNotificationSettings();
              await permission.openSettings();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const StatusChip(
                label: 'خارج از دستگاه: هیچ‌چیز',
                color: AppColors.mint,
                icon: Icons.lock_rounded,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مگر این‌که خودت سرویس ابری را در بخش هوش مصنوعی فعال کنی.',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
