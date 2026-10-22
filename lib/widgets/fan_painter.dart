import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vector fan — no asset needed, it can spin at any angle.
class FanPainter extends CustomPainter {
  FanPainter({
    required this.spin,
    required this.glow,
    required this.accent,
  });

  final double spin; // 0..1 -> one full turn
  final double glow; // 0 = off, 1 = on
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.5;

    // outer halo when on
    if (glow > 0.02) {
      final halo = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.26 * glow),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, halo);
    }

    final ringRect = Rect.fromCircle(center: center, radius: r * 0.95);
    canvas.drawCircle(
      center,
      r * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.14 + 0.30 * glow),
    );
    if (glow > 0.02) {
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        math.pi * 1.4 * glow,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [accent.withValues(alpha: 0.0), accent, accent.withValues(alpha: 0.0)],
          ).createShader(ringRect),
      );
    }

    // blades
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * 2 * math.pi);

    final bladeColors = [
      Color.lerp(const Color(0xFF223247), accent, glow * 0.85)!,
      Color.lerp(const Color(0xFF121C2B), accent, glow * 0.35)!,
    ];

    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5);

      final blade = Path()
        ..moveTo(0, -r * 0.11)
        ..cubicTo(r * 0.50, -r * 0.72, r * 0.96, -r * 0.40, r * 0.70, -r * 0.02)
        ..cubicTo(r * 0.50, r * 0.20, r * 0.14, r * 0.12, 0, -r * 0.11)
        ..close();

      canvas.drawPath(
        blade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bladeColors,
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );

      canvas.drawPath(
        blade,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.10 + 0.35 * glow),
      );

      canvas.restore();
    }

    canvas.restore();

    // hub
    canvas.drawCircle(center, r * 0.18, Paint()..color = const Color(0xFF0A111D));
    canvas.drawCircle(
      center,
      r * 0.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.45 + 0.45 * glow),
    );
    canvas.drawCircle(
      center,
      r * 0.07,
      Paint()..color = accent.withValues(alpha: 0.35 + 0.65 * glow),
    );
  }

  @override
  bool shouldRepaint(covariant FanPainter old) =>
      old.spin != spin || old.glow != glow || old.accent != accent;
}
