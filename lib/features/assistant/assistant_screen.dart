import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/permission_providers.dart';
import '../../core/providers/voice_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/assistant_message.dart';
import '../../services/permission_service.dart';
import '../../ui/widgets/glass_card.dart';
import '../dashboard/dashboard_screen.dart';
import '../../ui/widgets/mic_button.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import 'assistant_state.dart';
import 'confirm_action_sheet.dart';

/// Tab 1 — the voice assistant and morning briefing.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onMicPressed() async {
    final granted = await ref
        .read(permissionServiceProvider)
        .request(JavidPermission.microphone);
    if (!mounted) return;
    if (granted != PermissionOutcome.granted) {
      _showPermissionHint();
      return;
    }
    await ref.read(assistantControllerProvider.notifier).toggleListening();
  }

  void _showPermissionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('برای گفتگو با دستیار اجازهٔ میکروفون لازم است.'),
        action: SnackBarAction(
          label: 'تنظیمات',
          onPressed: () =>
              ref.read(permissionServiceProvider).openSettings(),
        ),
      ),
    );
  }

  Future<void> _submitTyped(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    await ref.read(assistantControllerProvider.notifier).submitText(text);
  }

  /// Speaks the daily briefing (also available from the dashboard shortcut).
  Future<void> _speakBriefing() async {
    await ref
        .read(assistantControllerProvider.notifier)
        .submitText('خلاصهٔ امروز را بگو');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final controller = ref.read(assistantControllerProvider.notifier);
    final activity = ref.watch(assistantActivityProvider);
    final now = DateTime.now();
    final theme = Theme.of(context);

    ref.listen<AssistantState>(assistantControllerProvider, (previous, next) {
      final confirmation = next.pendingConfirmation;
      if (confirmation != null && previous?.pendingConfirmation != confirmation) {
        showConfirmActionSheet(context, confirmation, ref);
      }
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PersianDate.greeting(now),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PersianDate.weekdayDate(now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: state.isMuted ? 'وصل صدا' : 'قطع صدا',
                  onPressed: controller.toggleMute,
                  icon: Icon(
                    state.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              child: Column(
                children: [
                  MicButton(
                    status: state.status,
                    onTap: _onMicPressed,
                    semanticLabel: state.status == AssistantStatus.listening
                        ? 'پایان گفتگو'
                        : 'شروع گفتگو',
                  ),
                  const SizedBox(height: 4),
                  if (state.transcript.isNotEmpty || state.reply.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          if (state.transcript.isNotEmpty)
                            _Bubble(
                              text: state.transcript,
                              isUser: true,
                              label: 'شما',
                            ),
                          if (state.reply.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _Bubble(
                              text: state.reply,
                              isUser: false,
                              label: 'جویده',
                            ),
                          ],
                          if (state.reply.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'پخش دوباره',
                                    onPressed: controller.repeat,
                                    icon: const Icon(Icons.replay_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'توقف',
                                    onPressed: controller.stopAll,
                                    icon: const Icon(Icons.stop_circle_outlined),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.amber),
                            ),
                          ),
                          IconButton(
                            onPressed: controller.clearError,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submitTyped,
                    decoration: const InputDecoration(
                      hintText: 'بنویس یا بگو… مثلاً «یادداشت جدید بساز»',
                      prefixIcon: Icon(Icons.keyboard_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _submitTyped(_textController.text),
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'ارسال',
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: DashboardSummary(),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: SectionHeader(
              title: 'پیشنهادهای آماده',
              icon: Icons.auto_awesome_rounded,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final suggestion in const [
                  'خلاصهٔ امروز را بگو',
                  'یادداشت جدید بساز',
                  'یادآوری کن فردا ساعت ۹ تماس بگیرم',
                  'وظیفه‌هایم را نشان بده',
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _submitTyped(suggestion),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SectionHeader(
              title: 'فعالیت‌های اخیر',
              subtitle: 'همهٔ پردازش‌ها روی همین دستگاه انجام می‌شود',
              icon: Icons.history_rounded,
              action: TextButton(
                onPressed: _speakBriefing,
                child: const Text('پخش'),
              ),
            ),
          ),
        ),
        if (activity.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _EmptyActivity(),
            ),
          )
        else
          SliverList.separated(
            itemCount: activity.length > 8 ? 8 : activity.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final message = activity[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, index == 7 ? 24 : 0),
                child: _ActivityTile(message: message),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser, required this.label});

  final String text;
  final bool isUser;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isUser
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.navy800.withValues(alpha: 0.05));
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AssistantRole.user;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUser ? Icons.person_outline_rounded : Icons.auto_awesome_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  PersianDate.relative(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const StatusChip(label: 'آماده', icon: Icons.check_circle_outline_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هنوز گفتگویی ثبت نشده است. اولین دستور را بگو یا پیشنهادهای بالا را امتحان کن.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
