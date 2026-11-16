import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/permission_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/app_notification.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';

/// Tab 4 — messages captured from the notification bar, with honest limits.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(notificationAccessProvider);
    final notifications = ref.watch(notificationsProvider).valueOrNull;
    final theme = Theme.of(context);
    final granted = access.valueOrNull ?? false;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text('پیام‌ها', style: theme.textTheme.headlineMedium),
                ),
                if (notifications != null && notifications.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await ref.read(notificationRepositoryProvider).markAllRead();
                      ref
                        ..invalidate(notificationsProvider)
                        ..invalidate(unreadNotificationsProvider);
                    },
                    child: const Text('خوانده شد'),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _ScopeNotice(),
          ),
        ),
        if (!granted)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _EnableAccessCard(
                onEnable: () async {
                  await ref.read(nativeBridgeProvider).openNotificationSettings();
                    ref.invalidate(notificationAccessProvider);
                },
                onRefresh: () => ref.invalidate(notificationAccessProvider),
              ),
            ),
          ),
        if (notifications != null && notifications.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: SectionHeader(
                title: '${notifications.length} پیام اخیر',
                subtitle: 'همهٔ داده‌ها فقط روی همین دستگاه ذخیره می‌شود',
                icon: Icons.mark_chat_unread_outlined,
              ),
            ),
          ),
        if (notifications == null)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (notifications.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'پیامی ثبت نشده',
              description: 'پس از فعال‌کردن دسترسی، پیام‌های واتساپ، تلگرام و '
                  'پیامک در همین‌جا نمایش داده می‌شوند.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            sliver: SliverList.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _MessageTile(
                notification: notifications[index],
                onTap: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markRead(notifications[index].id);
                  ref
                    ..invalidate(notificationsProvider)
                    ..invalidate(unreadNotificationsProvider);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      accent: AppColors.amber,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'جویده فقط متن اعلان‌ها را می‌خواند؛ به تاریخچهٔ کامل چت واتساپ یا '
              'تلگرام دسترسی ندارد. پیام‌هایی که اعلانشان نمایش داده شده باشد دیده '
              'می‌شوند و در مرورگری که قبلاً خوانده‌ای، ممکن است ثبت نشوند.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableAccessCard extends StatelessWidget {
  const _EnableAccessCard({required this.onEnable, required this.onRefresh});

  final Future<void> Function() onEnable;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: AppColors.violetLight),
              const SizedBox(width: 8),
              Text('دسترسی به اعلان‌ها هنوز فعال نشده',
                  style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'برای نمایش پیام‌ها، در تنظیمات اندروید مسیر «دسترسی به اعلان» را باز کن '
            'و جویده را فعال کن. این دسترسی کاملاً با تأیید خودت انجام می‌شود و '
            'هر زمان قابل لغو است.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEnable,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('باز کردن تنظیمات'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'بررسی دوباره',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.notification, required this.onTap});

  final CapturedNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    return SurfaceCard(
      onTap: onTap,
      accent: unread ? theme.colorScheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: notification.sourceLabel,
                dense: true,
                color: switch (notification.sourceLabel) {
                  'واتساپ' => AppColors.mint,
                  'تلگرام' => AppColors.indigo,
                  'پیامک' => AppColors.amber,
                  _ => theme.colorScheme.primary,
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification.sender.isEmpty ? 'بدون فرستنده' : notification.sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                PersianDate.relative(notification.postedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (notification.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                notification.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (notification.isUrgent)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StatusChip(
                label: 'ممکن است فوری باشد',
                color: AppColors.coral,
                icon: Icons.priority_high_rounded,
                dense: true,
              ),
            ),
        ],
      ),
    );
  }
}
