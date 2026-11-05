/// Shared, app-wide widgets. Kept deliberately small and composable so screens
/// read like layout descriptions.
library;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Convenience accessor: `context.l10n.t('key')`.
extension L10nContext on BuildContext {
  L10n get l10n => L10n(Localizations.localeOf(this).languageCode);
  ThemeData get theme => Theme.of(this);
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  void snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ));
  }
}

/// Centres content and caps the width on tablets.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.child,
    this.padding,
    this.maxWidth = AppTheme.maxContentWidth,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppTheme.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// App logo: a gradient aperture inside a rounded square.
class MotionShotLogo extends StatelessWidget {
  const MotionShotLogo({this.size = 44, this.showWordmark = false, super.key});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.videocam_rounded, color: Colors.white, size: size * 0.56),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        const SizedBox(width: 12),
        Text(
          context.l10n.t('app_name'),
          style: context.theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// A titled settings/editor section.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.subtitle,
    super.key,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title,
                      style: context.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      )),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ],
            const SizedBox(height: AppTheme.s12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Labelled slider with a value readout. Used all over the motion editor so the
/// numeric formatting stays consistent.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.format,
    this.divisions,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? format;
  final int? divisions;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = format?.call(value) ?? value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon,
                  size: 16,
                  color: context.theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(label,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(text,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

/// Segmented choice row with horizontal scroll for narrow screens.
class SegmentedChoice<T extends Object> extends StatelessWidget {
  const SegmentedChoice({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.enabledBuilder,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final bool Function(T)? enabledBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final v in values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(labelBuilder(v)),
                selected: v == selected,
                onSelected: (enabledBuilder?.call(v) ?? true)
                    ? (_) => onChanged(v)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo tile used in the gallery grid and the editor strip.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.image,
    this.selected = false,
    this.badge,
    this.overlay,
    this.onTap,
    this.onLongPress,
    this.missing = false,
    super.key,
  });

  final Widget? image;
  final bool selected;
  final Widget? badge;
  final Widget? overlay;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (image != null) image!,
              if (missing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.white70, size: 28),
                  ),
                ),
              if (overlay != null) overlay!,
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              if (badge != null)
                PositionedDirectional(
                  start: 6,
                  top: 6,
                  child: badge!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill label.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.theme.colorScheme.primary;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }
}

/// Empty-state block.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                size: 56,
                color: context.theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.titleMedium),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Gradient primary action button used for Start / Export.
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = 54,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.violet.withValues(alpha: enabled ? 0.4 : 0.1),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else if (icon != null)
                Icon(icon, color: Colors.white, size: 20),
              if (busy || icon != null) const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                    decoration: TextDecoration.none,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// A destructive-but-recoverable confirmation dialog.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.t('action_cancel')),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? l10n.t('action_ok')),
        ),
      ],
    ),
  );
  return result ?? false;
}
