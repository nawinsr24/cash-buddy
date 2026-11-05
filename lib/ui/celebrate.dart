import 'dart:async';
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

/// Hearts drifting up the screen.
class HeartsRain extends StatefulWidget {
  final Widget child;
  const HeartsRain({super.key, required this.child});
  @override
  State<HeartsRain> createState() => _HeartsRainState();
}

class _Heart {
  final double x, delay, speed, size, sway, phase;
  final Color color;
  _Heart(math.Random r, List<Color> palette)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.5,
      speed = 0.7 + r.nextDouble() * 0.6,
      size = 14 + r.nextDouble() * 22,
      sway = 10 + r.nextDouble() * 26,
      phase = r.nextDouble() * 6.28,
      color = palette[r.nextInt(palette.length)];
}

class _HeartsRainState extends State<HeartsRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();
  late final List<_Heart> _hearts = () {
    final r = math.Random(11);
    const palette = [
      Color(0xFFFF4D6D),
      Color(0xFFFF758F),
      Color(0xFFFF8FA3),
      Color(0xFFE11D48),
      Color(0xFFFFB3C1),
    ];
    return List.generate(26, (_) => _Heart(r, palette));
  }();

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
                CustomPaint(painter: _HeartsPainter(_hearts, _c.value)),
          ),
        ),
      ),
    ],
  );
}

Path _heartPath(double s) {
  final p = Path();
  p.moveTo(0, s * 0.35);
  p.cubicTo(-s * 0.7, -s * 0.25, -s * 0.2, -s * 0.75, 0, -s * 0.3);
  p.cubicTo(s * 0.2, -s * 0.75, s * 0.7, -s * 0.25, 0, s * 0.35);
  p.close();
  return p;
}

class _HeartsPainter extends CustomPainter {
  final List<_Heart> hearts;
  final double t;
  _HeartsPainter(this.hearts, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final h in hearts) {
      final local = ((t - h.delay) / (1 - h.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = size.height + 30 - local * (size.height + 80) * h.speed;
      final x = h.x * size.width + math.sin(local * 7 + h.phase) * h.sway;
      final fade = local < 0.1
          ? local / 0.1
          : (local > 0.8 ? (1 - local) / 0.2 : 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(local * 5 + h.phase) * 0.35);
      canvas.drawPath(
        _heartPath(h.size),
        Paint()..color = h.color.withValues(alpha: (fade * 0.92).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.t != t;
}

/// Shown after money is sent home: party paper, hearts and a warm thank-you.
class HomeCelebration extends StatefulWidget {
  final String amount;
  const HomeCelebration({super.key, required this.amount});
  @override
  State<HomeCelebration> createState() => _HomeCelebrationState();
}

class _HomeCelebrationState extends State<HomeCelebration> {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    // closes itself after a few seconds (cancelled if the user taps first)
    _auto = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  String get amount => widget.amount;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).maybePop(),
    child: ConfettiBurst(
      child: HeartsRain(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, t, c) => Opacity(
              opacity: ((t - 0.4) / 0.6).clamp(0, 1),
              child: Transform.scale(scale: t, child: c),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: Sp.x8),
              padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x6, Sp.x6, Sp.x5),
              decoration: BoxDecoration(
                color: context.cash.surfaceRaised,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏡', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'Home is proud of you',
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    '$amount sent home',
                    style: context.text.titleMedium?.copyWith(
                      color: const Color(0xFFE11D48),
                      fontWeight: FontWeight.w800,
                      fontFeatures: moneyFeatures,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'Looking after the people who looked after you.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens [HomeCelebration] over everything; it closes itself after a few seconds.
Future<void> showHomeCelebration(NavigatorState nav, String amount) {
  return nav.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => HomeCelebration(amount: amount),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}
