import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/util/rtl_text.dart';
import '../theme/app_colors.dart';

// Progress machinery for the operations that actually take time: exporting a
// video, transcribing, importing a clip, downloading a model.
//
// Three rules shaped this file:
//
//  * Never lie about the number. A bar that fills to 95% and sits there is
//    worse than an honest spinner, so indeterminate mode is a first-class
//    state and callers opt into it explicitly.
//  * Motion, not decoration. The sweep and the head glow are tied to real work:
//    they keep moving while the engine reports progress, which is how a stuck
//    task looks stuck.
//  * Reduced motion wins. Every animation is skipped when the platform asks for
//    it, because a pulsing bar is a real accessibility problem.


/// Shared colour ramp: violet to electric blue, the app's two accents.
const LinearGradient _sfProgressGradient = LinearGradient(
  colors: <Color>[AppColors.primarySoft, AppColors.secondarySoft],
  begin: Alignment.centerRight,
  end: Alignment.centerLeft,
);

/// Formats a duration as short Persian text ("۱:۲۰" / "۲ دقیقه").
String sfFormatRemaining(int seconds) {
  if (seconds < 0) return '';
  if (seconds < 60) return '${RtlText.toPersianDigits('$seconds')} ثانیه';
  final int minutes = seconds ~/ 60;
  final int rest = seconds % 60;
  if (minutes < 60) {
    return rest == 0
        ? '${RtlText.toPersianDigits('$minutes')} دقیقه'
        : '${RtlText.toPersianDigits('$minutes')}:${RtlText.toPersianDigits(rest.toString().padLeft(2, '0'))}';
  }
  final int hours = minutes ~/ 60;
  return '${RtlText.toPersianDigits('$hours')} ساعت و '
      '${RtlText.toPersianDigits('${minutes % 60}')} دقیقه';
}

/// Drives one task's progress, including a time estimate.
///
/// The estimate is a straight ratio of elapsed time to completed fraction: for
/// a video export that is the only honest model (frame cost is not uniform),
/// and it self-corrects because it is recomputed from the start of the task
/// rather than accumulated per tick.
class SfProgressController extends ChangeNotifier {
  SfProgressController();

  final Stopwatch _watch = Stopwatch();
  double _value = 0;
  String? _detail;
  DateTime? _lastPaint;
  bool _disposed = false;

  double get value => _value.clamp(0.0, 1.0);
  String? get detail => _detail;
  bool get isRunning => _watch.isRunning;
  bool get isFinished => _value >= 1;

  /// Coalesces bursts of progress callbacks: the engine can report faster than
  /// 60 Hz, and rebuilding a dialog per callback drops frames for no reason.
  void begin([String? detail]) {
    _watch
      ..reset()
      ..start();
    _value = 0;
    _detail = detail;
    notifyListeners();
  }

  void update(double value, {String? detail}) {
    final double next = value.clamp(0.0, 1.0);
    final bool changedDetail = detail != null && detail != _detail;
    if (changedDetail) _detail = detail;
    final DateTime now = DateTime.now();
    final bool due = _lastPaint == null ||
        now.difference(_lastPaint!) >= const Duration(milliseconds: 90);
    // The engine can report faster than the screen refreshes; coalescing here
    // keeps a 60 fps render loop from turning into 200 dialog rebuilds/second.
    if (!changedDetail && !due && next < 1) {
      _value = next;
      return;
    }
    _lastPaint = now;
    _value = next;
    notifyListeners();
  }

  void fail() {
    _watch.stop();
    notifyListeners();
  }

  /// Remaining seconds, or null while the task is too young to extrapolate.
  int? get remainingSeconds {
    final int elapsedMs = _watch.elapsedMilliseconds;
    if (!_watch.isRunning || elapsedMs < 1200 || _value <= 0.03) return null;
    final double elapsed = elapsedMs / 1000;
    final double remaining = elapsed * (1 - _value) / _value;
    if (!remaining.isFinite) return null;
    return remaining.clamp(0, 6 * 3600).round();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch.stop();
    super.dispose();
  }
}

/// Rounded gradient bar with a moving highlight and a glowing head.
///
/// `value == null` renders an indeterminate travelling band.
class SfProgressBar extends StatefulWidget {
  const SfProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.trackColor = AppColors.surfaceHigher,
    this.gradient = _sfProgressGradient,
    this.glow = true,
    this.animate = true,
  });

  final double? value;
  final double height;
  final Color trackColor;
  final Gradient gradient;

  /// A soft halo around the filled part. Turn it off inside dense lists.
  final bool glow;

  /// Tests and reduced-motion builds set this to false.
  final bool animate;

  @override
  State<SfProgressBar> createState() => _SfProgressBarState();
}

class _SfProgressBarState extends State<SfProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SfProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool shouldRun = widget.animate && (widget.value == null || widget.value! < 1);
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double target = widget.value?.clamp(0.0, 1.0) ?? 0;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: target, end: target),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animated, Widget? _) {
              return CustomPaint(
                painter: _BarPainter(
                  value: widget.value == null ? null : animated,
                  phase: reduceMotion ? 0.35 : _controller.value,
                  gradient: widget.gradient,
                  track: widget.trackColor,
                  glow: widget.glow && !reduceMotion,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.value,
    required this.phase,
    required this.gradient,
    required this.track,
    required this.glow,
  });

  final double? value;
  final double phase;
  final Gradient gradient;
  final Color track;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    final Radius radius = Radius.circular(height / 2);
    final Rect full = Rect.fromLTWH(0, 0, size.width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(full, radius),
      Paint()..color = track,
    );

    final double? progress = value;
    if (progress == null) {
      // Indeterminate: a band of light that travels, so the bar reads as
      // "working" without pretending to know how far along it is.
      final double bandWidth = math.max(size.width * 0.34, height * 3);
      final double travel = size.width + bandWidth;
      final double x = -bandWidth + travel * phase;
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(full, radius));
      final Rect band = Rect.fromLTWH(x, 0, bandWidth, height);
      canvas.drawRect(
        band,
        Paint()..shader = gradient.createShader(full),
      );
      canvas.restore();
      return;
    }

    final double filled = size.width * progress;
    if (filled <= 0.6) return;
    final Rect done = Rect.fromLTWH(0, 0, filled, height);
    final RRect doneR = RRect.fromRectAndRadius(done, radius);
    final Shader shader = gradient.createShader(full);

    if (glow) {
      canvas.drawRRect(
        doneR,
        Paint()
          ..shader = shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.min(7, height * 0.7))
          ..color = Colors.white.withOpacity(0.55),
      );
    }
    canvas.drawRRect(doneR, Paint()..shader = shader);

    // A highlight that keeps moving across the filled part: the bar stays
    // visibly alive during long single-report stretches.
    canvas.save();
    canvas.clipRRect(doneR);
    final double streak = math.max(height * 5, 60);
    final double x = -streak + (filled + streak * 2) * phase;
    canvas.drawRect(
      Rect.fromLTWH(x, 0, streak, height),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.34),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(x, 0, streak, height)),
    );
    canvas.restore();

    if (glow && progress < 1) {
      final Offset head = Offset(filled - height / 2, height / 2);
      canvas.drawCircle(
        head,
        height * 0.42,
        Paint()
          ..color = Colors.white
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.gradient != gradient ||
      old.track != track ||
      old.glow != glow;
}

/// Compact determinate ring for places where a bar does not fit (buttons,
/// model cards, per-file rows).
class SfProgressRing extends StatefulWidget {
  const SfProgressRing({
    super.key,
    required this.value,
    this.size = 46,
    this.stroke = 4,
    this.child,
    this.trackColor = AppColors.surfaceHigher,
    this.gradient = _sfProgressGradient,
  });

  final double? value;
  final double size;
  final double stroke;
  final Widget? child;
  final Color trackColor;
  final Gradient gradient;

  @override
  State<SfProgressRing> createState() => _SfProgressRingState();
}

class _SfProgressRingState extends State<SfProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.value == null) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SfProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double end = widget.value?.clamp(0.0, 1.0) ?? 0;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: end, end: end),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animated, Widget? _) {
              return CustomPaint(
                painter: _RingPainter(
                  value: widget.value == null ? null : animated,
                  stroke: widget.stroke,
                  track: widget.trackColor,
                  phase: reduceMotion ? 0.2 : _controller.value,
                ),
                child: Center(child: child),
              );
            },
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.phase,
  });

  final double? value;
  final double stroke;
  final Color track;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );
    final double? progress = value;
    final double start = -math.pi / 2;
    final double sweep = progress == null ? math.pi * 0.55 : math.pi * 2 * progress;
    final double from = progress == null ? start + math.pi * 2 * phase : start;
    canvas.drawArc(
      rect,
      from,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: <Color>[AppColors.primarySoft, AppColors.secondarySoft],
          startAngle: 0,
          endAngle: math.pi * 2,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.phase != phase || old.stroke != stroke;
}

/// The polite version of "please wait": a card that shows what is happening,
/// how far along it is, how much is left, and a way out.
///
/// Used by the exporter, the importer and the transcription screen so a long
/// job looks the same everywhere instead of three different spinners.
class SfProgressDialog extends StatelessWidget {
  const SfProgressDialog({
    super.key,
    required this.title,
    required this.controller,
    this.caption,
    this.icon = Icons.movie_filter_outlined,
    this.onCancel,
    this.cancelLabel = 'لغو',
    this.footnote,
  });

  final String title;
  final SfProgressController controller;
  final String? caption;
  final IconData icon;
  final Future<void> Function()? onCancel;
  final String cancelLabel;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: onCancel == null,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? _) {
            final int percent = (controller.value * 100).round().clamp(0, 100);
            final int? remaining = controller.remainingSeconds;
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppColors.card,
                border: Border.all(color: AppColors.outline.withOpacity(0.8)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.16),
                    blurRadius: 40,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.primary.withOpacity(0.28),
                              AppColors.secondary.withOpacity(0.2),
                            ],
                          ),
                        ),
                        child: Icon(icon, size: 21, color: AppColors.primarySoft),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (caption != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  caption!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.6,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${RtlText.toPersianDigits('$percent')}٪',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SfProgressBar(value: controller.value, height: 12),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          controller.detail ??
                              (remaining == null
                                  ? 'در حال آماده‌سازی…'
                                  : 'حدود ${sfFormatRemaining(remaining)} مانده'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.7,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (remaining != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sfFormatRemaining(remaining),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (footnote != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      footnote!,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                  if (onCancel != null) ...<Widget>[
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => onCancel!(),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        label: Text(cancelLabel, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows [SfProgressDialog] and resolves when the dialog is closed.
Future<T?> showSfProgress<T>(
  BuildContext context, {
  required String title,
  required SfProgressController controller,
  String? caption,
  IconData icon = Icons.movie_filter_outlined,
  Future<void> Function()? onCancel,
  String? footnote,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.62),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext context, Animation<double> a, Animation<double> b) {
      return SfProgressDialog(
        title: title,
        controller: controller,
        caption: caption,
        icon: icon,
        onCancel: onCancel,
        footnote: footnote,
      );
    },
    transitionBuilder: (BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
      final Animation<double> eased = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(eased), child: child),
      );
    },
  );
}

/// Full-bleed "working" overlay for a screen that must not be tapped mid-task.
///
/// Unlike [SfProgressDialog] this is a widget, not a route: the importing or
/// loading screen keeps its own navigation and just stacks this on top, so
/// finishing the task can move to the next page without racing a dialog pop.
class SfTaskOverlay extends StatelessWidget {
  const SfTaskOverlay({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon = Icons.auto_awesome_outlined,
  });

  final String label;

  /// Null when the task cannot report a real fraction yet.
  final double? value;
  final String? caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, Widget? child) {
          return Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
          );
        },
        child: ColoredBox(
          color: Colors.black.withOpacity(0.66),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.outline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 34,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.primary.withOpacity(0.3),
                              AppColors.secondary.withOpacity(0.22),
                            ],
                          ),
                        ),
                        child: Icon(icon, size: 19, color: AppColors.primarySoft),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (caption != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  caption!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.6,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SfProgressBar(value: value, height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
