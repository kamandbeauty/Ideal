/// The app's professional progress language: a glowing gradient ring, a
/// gradient bar, a compact spinner, and [runHeroProgress] — a modal runner
/// for long-running work (imports) with live status, cancel, and a
/// completion flash.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/utils/progress.dart';
import '../theme/app_theme.dart';
import 'common.dart';

export '../../core/utils/progress.dart'
    show HeroCancelled, HeroReport, HeroToken;

/// A glowing circular progress ring.
///
/// [value] is 0..1; `null` renders an indeterminate rotating arc. The
/// percentage counts up smoothly in the center unless [child] is given.
class HeroRing extends StatefulWidget {
  const HeroRing({
    super.key,
    required this.value,
    this.size = 160,
    this.strokeWidth = 10,
    this.child,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  State<HeroRing> createState() => _HeroRingState();
}

class _HeroRingState extends State<HeroRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    if (v == null) {
      return AnimatedBuilder(
        animation: _spin,
        builder: (BuildContext _, __) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: _HeroRingPainter(
                  arc: 0.72,
                  rotation: _spin.value * 2 * math.pi,
                  strokeWidth: widget.strokeWidth,
                  trackColor: context.theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.45),
                  glow: AppColors.violet.withValues(alpha: 0.20),
                ),
              ),
              if (widget.child != null) Center(child: widget.child),
            ],
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: v.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (BuildContext _, double t, __) {
        final frac = t.clamp(0.0, 1.0);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: _HeroRingPainter(
                  arc: frac,
                  rotation: 0,
                  strokeWidth: widget.strokeWidth,
                  trackColor: context.theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.45),
                  glow: AppColors.violet.withValues(alpha: 0.22),
                ),
              ),
              Center(
                child: widget.child ??
                    Text(
                      '${(frac * 100).round()}%',
                      style: context.theme.textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroRingPainter extends CustomPainter {
  _HeroRingPainter({
    required this.arc,
    required this.rotation,
    required this.strokeWidth,
    required this.trackColor,
    required this.glow,
  });

  /// The drawn fraction of the circle (the value, or the arc size when
  /// indeterminate).
  final double arc;
  final double rotation;
  final double strokeWidth;
  final Color trackColor;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2 + rotation;
    final sweep = 2 * math.pi * arc.clamp(0.0, 1.0);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (sweep <= 0) return;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 9
      ..strokeCap = StrokeCap.round
      ..color = glow;
    canvas.drawArc(rect, start, sweep, false, glowPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const <Color>[AppColors.violet, AppColors.blue, AppColors.mint],
        // Compress the whole gradient into the drawn arc so even small
        // fractions show the full color journey.
        stops: arc > 0.02
            ? <double>[0.0, (0.55 * arc).clamp(0.0, 0.999), arc]
            : null,
        transform: GradientRotation(start),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_HeroRingPainter old) =>
      old.arc != arc ||
      old.rotation != rotation ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor ||
      old.glow != glow;
}

/// A horizontal gradient progress bar.
///
/// [value] is 0..1; `null` renders an indeterminate sliding capsule. The bar
/// fills from the start edge, so it mirrors correctly in RTL.
class HeroBar extends StatefulWidget {
  const HeroBar({super.key, required this.value, this.height = 10});

  final double? value;
  final double height;

  @override
  State<HeroBar> createState() => _HeroBarState();
}

class _HeroBarState extends State<HeroBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final radius = BorderRadius.circular(widget.height / 2);
    return SizedBox(
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.outlineVariant
              .withValues(alpha: 0.35),
          borderRadius: radius,
        ),
        child: v == null
            ? AnimatedBuilder(
                animation: _slide,
                builder: (BuildContext _, __) {
                  const w = 0.32;
                  final t = Curves.easeInOut.transform(_slide.value);
                  // Ping-pong 0..1..0 across the available track.
                  final p = 1 - (2 * t - 1).abs();
                  final x = (2 * p - 1) * (1 - w) / 2;
                  return FractionallySizedBox(
                    widthFactor: w,
                    alignment: Alignment(x, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[AppColors.violet, AppColors.blue],
                        ),
                        borderRadius: radius,
                      ),
                    ),
                  );
                },
              )
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: v.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (BuildContext _, double t, __) {
                  return FractionallySizedBox(
                    widthFactor: t.clamp(0.008, 1.0),
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            AppColors.violet,
                            AppColors.blue,
                            AppColors.mint,
                          ],
                        ),
                        borderRadius: radius,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // Bright leading edge so the tip reads clearly.
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Container(
                          width: 2.5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Compact indeterminate hero spinner — a drop-in upgrade for plain
/// `CircularProgressIndicator`s on loading screens.
class HeroSpinner extends StatefulWidget {
  const HeroSpinner({super.key, this.size = 40, this.strokeWidth = 4});

  final double size;
  final double strokeWidth;

  @override
  State<HeroSpinner> createState() => _HeroSpinnerState();
}

class _HeroSpinnerState extends State<HeroSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (BuildContext _, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _HeroRingPainter(
            arc: 0.72,
            rotation: _spin.value * 2 * math.pi,
            strokeWidth: widget.strokeWidth,
            trackColor: context.theme.colorScheme.outlineVariant
                .withValues(alpha: 0.35),
            glow: AppColors.violet.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

enum _HeroPhase { running, done, failed, cancelled }

class _HeroUi {
  _HeroUi({
    required this.title,
    this.detail,
    this.fraction,
    this.phase = _HeroPhase.running,
    this.cancelling = false,
  });

  final String title;
  final String? detail;
  final double? fraction;
  final _HeroPhase phase;
  final bool cancelling;

  _HeroUi copyWith({
    String? detail,
    double? fraction,
    bool fractionSet = false,
    _HeroPhase? phase,
    bool? cancelling,
  }) {
    return _HeroUi(
      title: title,
      detail: detail ?? this.detail,
      fraction: fractionSet ? fraction : this.fraction,
      phase: phase ?? this.phase,
      cancelling: cancelling ?? this.cancelling,
    );
  }
}

/// Runs [task] behind a modal hero progress card and returns its result.
///
/// The card shows [title] plus a live line ([HeroReport] updates the ring,
/// the bar, and an optional [detail]), animates in and out, flashes a mint
/// check on success, and rethrows task errors so callers can report them.
/// Returns `null` when the user cancelled (or the task produced nothing).
Future<T?> runHeroProgress<T>(
  BuildContext context, {
  required String title,
  String? detail,
  required Future<T?> Function(HeroReport report, HeroToken token) task,
  bool cancellable = false,
  String? cancelLabel,
  String? cancellingLabel,
}) async {
  final notifier = ValueNotifier<_HeroUi>(_HeroUi(title: title, detail: detail));
  final token = HeroToken();
  final cancelText = cancelLabel;
  final cancellingText = cancellingLabel;

  final taskFuture = task(
    (double? fraction, {String? detail}) {
      notifier.value = notifier.value.copyWith(
        detail: detail,
        fraction: fraction,
        fractionSet: true,
      );
      notifier.notifyListeners();
    },
    token,
  );

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD905050C),
    builder: (BuildContext ctx) => _HeroCard(
      notifier: notifier,
      token: token,
      cancellable: cancellable,
      cancelLabel: cancelText ?? ctx.l10n.t('action_cancel'),
      cancellingLabel: cancellingText ?? ctx.l10n.t('action_cancelling'),
    ),
  ));

  try {
    final value = await taskFuture;
    if (value != null) {
      notifier.value = notifier.value.copyWith(
        phase: _HeroPhase.done,
        fraction: 1,
        fractionSet: true,
      );
      notifier.notifyListeners();
    }
    return value;
  } on HeroCancelled {
    notifier.value = notifier.value.copyWith(phase: _HeroPhase.cancelled);
    notifier.notifyListeners();
    return null;
  } catch (_) {
    notifier.value = notifier.value.copyWith(phase: _HeroPhase.failed);
    notifier.notifyListeners();
    rethrow;
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.notifier,
    required this.token,
    required this.cancellable,
    required this.cancelLabel,
    required this.cancellingLabel,
  });

  final ValueNotifier<_HeroUi> notifier;
  final HeroToken token;
  final bool cancellable;
  final String cancelLabel;
  final String cancellingLabel;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  bool _closing = false;

  void _onUi() {
    if (_closing) return;
    switch (widget.notifier.value.phase) {
      case _HeroPhase.running:
        break;
      case _HeroPhase.done:
        _close(after: const Duration(milliseconds: 700));
      case _HeroPhase.failed:
        _close(after: const Duration(milliseconds: 120));
      case _HeroPhase.cancelled:
        _close(after: const Duration(milliseconds: 120));
    }
  }

  void _close({required Duration after}) {
    _closing = true;
    Future<void>.delayed(after, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onUi);
    _onUi();
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onUi);
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
          ),
          child: ListenableBuilder(
            listenable: widget.notifier,
            builder: (BuildContext _, __) {
              final ui = widget.notifier.value;
              final done = ui.phase == _HeroPhase.done;
              final value = done ? 1.0 : ui.fraction;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 44,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        HeroRing(
                          value: value,
                          size: 140,
                          strokeWidth: 9,
                          child: done
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.4, end: 1.0),
                                  duration:
                                      const Duration(milliseconds: 380),
                                  curve: Curves.easeOutBack,
                                  builder: (BuildContext ___,
                                      double s, ___child) {
                                    return Transform.scale(
                                      scale: s,
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 56,
                                        color: AppColors.mint,
                                      ),
                                    );
                                  },
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          ui.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (ui.detail != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            ui.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        HeroBar(value: value, height: 9),
                        if (widget.cancellable &&
                            ui.phase == _HeroPhase.running) ...<Widget>[
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: ui.cancelling
                                ? null
                                : () {
                                    widget.notifier.value = widget
                                        .notifier.value
                                        .copyWith(cancelling: true);
                                    widget.notifier.notifyListeners();
                                    widget.token.cancel();
                                  },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              ui.cancelling
                                  ? widget.cancellingLabel
                                  : widget.cancelLabel,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
