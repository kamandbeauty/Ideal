import 'package:flutter/material.dart';

/// A rounded rectangle drawn with a dashed outline.
///
/// Flutter has no dashed border, and the "select video" drop zone in the
/// reference layout *is* a dashed card, so this paints it directly. The dash
/// length and gap are in logical pixels along the path.
class DashedRoundedBorder extends StatelessWidget {
  const DashedRoundedBorder({
    required this.child,
    this.radius = 18,
    this.color = const Color(0xFF3B4560),
    this.strokeWidth = 1.4,
    this.dash = 7,
    this.gap = 6,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(
        radius: radius,
        color: color,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}
