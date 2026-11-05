import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/grade.dart';
import 'theme.dart';

/// Party paper: a burst of confetti that falls once and fades. Wrap the
/// content you want it to rain over.
class ConfettiBurst extends StatefulWidget {
  final Widget child;
  final bool play;
  const ConfettiBurst({super.key, required this.child, this.play = true});
  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  final double x, delay, speed, size, spin, drift;
  final Color color;
  final bool round;
  _Piece(math.Random r, List<Color> palette)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.35,
      speed = 0.6 + r.nextDouble() * 0.7,
      size = 6 + r.nextDouble() * 7,
      spin = (r.nextDouble() - 0.5) * 14,
      drift = (r.nextDouble() - 0.5) * 0.25,
      color = palette[r.nextInt(palette.length)],
      round = r.nextBool();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final List<_Piece> _pieces = () {
    final r = math.Random(7);
    const palette = [
      Color(0xFFFFC83D),
      Color(0xFFFF6B3D),
      Color(0xFFEC4899),
      Color(0xFF22B573),
      Color(0xFF38BDF8),
      Color(0xFFFFFFFF),
    ];
    return List.generate(90, (_) => _Piece(r, palette));
  }();

  @override
  void initState() {
    super.initState();
    if (widget.play) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) =>
                CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
          ),
        ),
      ),
    ],
  );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * (size.height + 40) * p.speed;
      final x =
          p.x * size.width +
          math.sin(local * 6 + p.x * 9) * 18 +
          p.drift * size.width * local;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      final paint = Paint()
        ..color = p.color.withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2.2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.5,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// "This month vs last month" card: one row per measure, with a small arrow
/// showing whether it got better or worse.
class CompareCard extends StatelessWidget {
  final String title;
  final String currentLabel, previousLabel;
  final List<CompareRow> rows;
  final bool onDark;
  const CompareCard({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.previousLabel,
    required this.rows,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : context.scheme.onSurface;
    final muted = onDark ? Colors.white60 : context.cash.textMuted;
    final good = onDark ? const Color(0xFFA7F3D0) : context.cash.income;
    final bad = onDark ? const Color(0xFFFECACA) : context.cash.spending;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.14)
            : context.cash.surfaceRaised,
        borderRadius: BorderRadius.circular(Sp.rCard),
        border: onDark
            ? null
            : Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 4,
                child: Text(
                  currentLabel,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  previousLabel,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.label,
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              r.current,
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontFeatures: moneyFeatures,
                              ),
                            ),
                          ),
                        ),
                        if (r.better != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            r.better!
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 13,
                            color: r.better! ? good : bad,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        r.previous,
                        style: TextStyle(
                          color: muted,
                          fontFeatures: moneyFeatures,
                        ),
                      ),
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
