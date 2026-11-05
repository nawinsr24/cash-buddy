import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Cash++ mark: a glowing coin "C" with two plus signs.
/// [transparent] draws only the symbol (for the adaptive icon foreground).
class CashMarkPainter extends CustomPainter {
  final bool background;
  const CashMarkPainter({this.background = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.26)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C5CFF), Color(0xFF2F6BFF), Color(0xFF19C6C6)],
          ).createShader(rect),
      );
      // soft top-left shine
      canvas.drawCircle(
        Offset(w * 0.2, w * 0.1),
        w * 0.55,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(w * 0.2, w * 0.1),
                  radius: w * 0.55,
                ),
              ),
      );
    }
    // the "C" ring
    final c = Offset(w * 0.45, w * 0.52);
    final r = w * 0.27;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.115
      ..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 0.28,
      math.pi * 1.44,
      false,
      ring,
    );
    // two plus signs
    final plus = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.062
      ..color = Colors.white;
    void drawPlus(Offset o, double s) {
      canvas.drawLine(o.translate(-s, 0), o.translate(s, 0), plus);
      canvas.drawLine(o.translate(0, -s), o.translate(0, s), plus);
    }

    drawPlus(Offset(w * 0.75, w * 0.40), w * 0.062);
    drawPlus(Offset(w * 0.75, w * 0.62), w * 0.062);
  }

  @override
  bool shouldRepaint(CashMarkPainter old) => old.background != background;
}

/// Mark + wordmark for the top bar.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CustomPaint(painter: CashMarkPainter()),
        ),
        const SizedBox(width: 10),
        Text(
          'Cash',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: scheme.onSurface,
          ),
        ),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF5B3DF5), Color(0xFF0A8FB0)],
          ).createShader(r),
          child: const Text(
            '++',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
