import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/permission_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_notification.dart';
import '../../services/native_bridge.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import 'ai_settings_screen.dart';
import 'privacy_screen.dart';

/// Tab 5 — appearance, voice, notifications, privacy and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final sources = ref.watch(notificationSourceProvider);
    final access = ref.watch(notificationAccessProvider).valueOrNull ?? false;
    final battery = ref.watch(batteryOptimizationExemptProvider).valueOrNull ?? false;
    final speak = ref.watch(speakRepliesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text('تنظیمات', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),

        const SectionHeader(title: 'ظاهر', icon: Icons.palette_outlined),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('تیره'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('روشن'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('سیستم'),
                    icon: Icon(Icons.settings_suggest_outlined),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) =>
                    ref.read(themeModeProvider.notifier).set(value.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: speak,
                onChanged: (value) =>
                    ref.read(speakRepliesProvider.notifier).set(value),
                title: const Text('خواندن پاسخ‌ها با صدا'),
                subtitle: const Text('پاسخ دستیار با موتور TTS دستگاه خوانده می‌شود.'),
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'هوش مصنوعی',
          subtitle: 'پیش‌فرض: کاملاً محلی و آفلاین',
          icon: Icons.psychology_outlined,
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hub_outlined),
            title: const Text('مدل و سرویس هوش مصنوعی'),
            subtitle: const Text('پیکربندی سرویس ابری (اختیاری) و کلید API'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ),

        const SectionHeader(
          title: 'اعلان‌ها و پیام‌ها',
          icon: Icons.notifications_active_outlined,
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  access ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: access ? AppColors.mint : AppColors.amber,
                ),
                title: const Text('دسترسی به اعلان‌ها'),
                subtitle: Text(access ? 'فعال است' : 'غیرفعال است — برای خواندن پیام‌ها لازم است'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(nativeBridgeProvider).openNotificationSettings();
                  },
                  child: Text(access ? 'مدیریت' : 'فعال‌سازی'),
                ),
              ),
              const Divider(height: 20),
              for (final source in NotificationSource.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sources[source] ?? false,
                  onChanged: (value) => ref
                      .read(notificationSourceProvider.notifier)
                      .toggle(source, value),
                  title: Text(NotificationSources.labels[source] ?? source.name),
                  subtitle: source == NotificationSource.other
                      ? const Text('سایر برنامه‌ها به‌صورت پیش‌فرض خاموش است.')
                      : null,
                ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'پایداری در پس‌زمینه',
          icon: Icons.battery_saver_outlined,
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              battery ? Icons.battery_full_rounded : Icons.battery_alert_rounded,
              color: battery ? AppColors.mint : AppColors.amber,
            ),
            title: const Text('بهینه‌سازی باتری'),
            subtitle: Text(
              battery
                  ? 'جویده از محدودیت باتری مستثناست.'
                  : 'اندروید ممکن است اجرای وظایف را به تأخیر بیندازد.',
            ),
            trailing: TextButton(
              onPressed: () async {
                await ref
                    .read(nativeBridgeProvider)
                    .requestIgnoreBatteryOptimizations();
                ref.invalidate(batteryOptimizationExemptProvider);
              },
              child: const Text('درخواست'),
            ),
          ),
        ),

        const SectionHeader(
          title: 'حریم خصوصی',
          icon: Icons.shield_outlined,
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('کنترل داده‌ها'),
            subtitle: const Text('حذف، خروجی گرفتن و توضیح دسترسی‌ها'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
        ),

        const SectionHeader(title: 'درباره', icon: Icons.info_outline_rounded),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('JavidAI', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  const StatusChip(label: 'نسخهٔ ۰.۱.۰', dense: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'دستیار صوتی فارسی‌زبان، محلی و خصوصی. ساخته‌شده با Flutter و Kotlin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'فونت Vazirmatn با مجوز SIL OFL 1.1',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => _showResetDialog(context, ref),
            child: const Text(
              'پاک‌کردن اطلاعات محلی',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌کردن همهٔ داده‌ها'),
        content: const Text(
          'یادداشت‌ها، وظایف، پیام‌های ضبط‌شده و تاریخچهٔ دستیار پاک می‌شوند. '
          'این کار بازگشت‌پذیر نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(appDatabaseProvider);
    final database = await db.open();
    await database.delete('notifications');
    await database.delete('assistant_messages');
    await database.delete('job_runs');
    await database.delete('jobs');
    await database.delete('notes');
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(unreadNotificationsProvider)
      ..invalidate(assistantMessagesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('همهٔ داده‌های محلی پاک شد.')),
      );
    }
  }
}

/// Small helper surfaced in the messages screen as well.
Future<int> deleteOldNotifications(WidgetRef ref) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return ref.read(notificationRepositoryProvider).deleteBefore(cutoff);
}
