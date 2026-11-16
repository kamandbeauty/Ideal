import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'assistant_state.dart';

/// Modal bottom sheet that previews a sensitive action and requires an explicit
/// "yes" before anything happens.
Future<void> showConfirmActionSheet(
  BuildContext context,
  PendingConfirmation confirmation,
  WidgetRef ref,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ConfirmSheet(confirmation: confirmation),
  );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.confirmation});

  final PendingConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = confirmation.isDestructive ? AppColors.coral : theme.colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    confirmation.isDestructive
                        ? Icons.warning_amber_rounded
                        : Icons.verified_user_outlined,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(confirmation.title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(confirmation.summary, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      confirmation.onCancel();
                    },
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tone,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      confirmation.onConfirm();
                    },
                    child: Text(confirmation.actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
