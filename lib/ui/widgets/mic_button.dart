import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/assistant/assistant_state.dart';

/// The hero microphone: a tappable orb with animated pulsing rings, a level
/// glow while listening and a rotating gradient while thinking or speaking.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 148,
    this.semanticLabel = 'شروع گفتگو',
  });

  final AssistantStatus status;
  final VoidCallback onTap;
  final double size;
  final String semanticLabel;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      if (widget.status == AssistantStatus.listening) {
        _pulse.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.status) {
        AssistantStatus.idle => Icons.mic_none_rounded,
        AssistantStatus.listening => Icons.mic_rounded,
        AssistantStatus.processing => Icons.auto_awesome_rounded,
        AssistantStatus.speaking => Icons.volume_up_rounded,
      };

  String get _hint => switch (widget.status) {
        AssistantStatus.idle => 'برای صحبت ضربه بزن',
        AssistantStatus.listening => 'در حال شنیدن… برای پایان ضربه بزن',
        AssistantStatus.processing => 'در حال پردازش…',
        AssistantStatus.speaking => 'در حال پاسخ دادن… برای قطع ضربه بزن',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = widget.status == AssistantStatus.listening
        ? AppColors.violetLight
        : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: widget.semanticLabel,
          hint: _hint,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.size + 56,
              height: widget.size + 56,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _spin]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _OrbPainter(
                      progress: _pulse.value,
                      spin: _spin.value,
                      status: widget.status,
                      ringColor: ringColor,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.violet, AppColors.indigo],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet.withValues(
                                alpha: widget.status == AssistantStatus.listening ? 0.65 : 0.35,
                              ),
                              blurRadius: widget.status == AssistantStatus.listening ? 42 : 24,
                              spreadRadius: widget.status == AssistantStatus.listening ? 6 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _icon,
                          size: widget.size * 0.36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _hint,
            key: ValueKey(widget.status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ),
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.progress,
    required this.spin,
    required this.status,
    required this.ringColor,
    required this.isDark,
  });

  final double progress;
  final double spin;
  final AssistantStatus status;
  final Color ringColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.29;

    // Two expanding rings while listening.
    if (status == AssistantStatus.listening) {
      for (var i = 0; i < 2; i++) {
        final t = (progress + i * 0.5) % 1.0;
        final radius = baseRadius + t * (size.width * 0.16);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = ringColor.withValues(alpha: (1 - t) * 0.55);
        canvas.drawCircle(center, radius, paint);
      }
    }

    // Static soft ring in other states.
    if (status != AssistantStatus.listening) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ringColor.withValues(alpha: 0.25);
      canvas.drawCircle(center, baseRadius + 14, paint);
    }

    // Orbiting progress arc while processing or speaking.
    if (status == AssistantStatus.processing || status == AssistantStatus.speaking) {
      final rect = Rect.fromCircle(center: center, radius: baseRadius + 22);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            ringColor.withValues(alpha: 0.0),
            ringColor,
            ringColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(spin * 2 * math.pi),
        ).createShader(rect);
      canvas.drawArc(rect, spin * 2 * math.pi, math.pi * 1.3, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.spin != spin ||
      oldDelegate.status != status;
}
