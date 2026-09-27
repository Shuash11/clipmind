import 'package:flutter/material.dart';

/// Paints a dashed rounded-rect border. Flutter has no built-in dashed
/// BorderSide, so the hub's dropzone and blank-project card draw their
/// dashed outlines with this painter.
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 16,
    this.dash = 6,
    this.gap = 5,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    // Dash along each contour; corners are followed naturally.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

/// Convenience wrapper: paints a dashed border around [child]'s bounds.
/// Inset the child with its own padding so content clears the outline.
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedRRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        radius: radius,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}
