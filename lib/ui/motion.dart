import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades and springs a child up when it first appears; [index] staggers lists.
class Reveal extends StatelessWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Interval(delay / (520 + delay), 1, curve: Curves.easeOutBack),
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 26),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: c),
        ),
      ),
      child: child,
    );
  }
}

/// Slide-up + fade page transition for pushed screens.
Route<T> softRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, secondary, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

/// Number that counts up/down to its new value.
class CountUp extends StatelessWidget {
  final int value;
  final Widget Function(int v) builder;
  const CountUp({super.key, required this.value, required this.builder});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => builder(v.round()),
  );
}

/// Press feedback: squishes while held and springs back with a little bounce.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: Duration(milliseconds: _down ? 110 : 420),
      curve: _down ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    ),
  );
}

/// Opens [page] with a circle that grows out of the widget that was tapped
/// (the card, the tile) and shrinks back into it on the way out.
Future<T?> pushReveal<T>(BuildContext context, Widget page) {
  final box = context.findRenderObject();
  Offset origin = Offset.zero;
  if (box is RenderBox && box.hasSize) {
    origin = box.localToGlobal(box.size.center(Offset.zero));
  } else {
    final s = MediaQuery.sizeOf(context);
    origin = Offset(s.width / 2, s.height / 2);
  }
  return Navigator.of(context).push<T>(_RevealRoute<T>(page, origin));
}

class _RevealRoute<T> extends PageRouteBuilder<T> {
  _RevealRoute(Widget page, Offset origin)
    : super(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (context, anim, secondary, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInCubic,
          );
          final size = MediaQuery.sizeOf(context);
          // far enough to cover the whole screen from the tapped point
          final maxR = Offset(
            math.max(origin.dx, size.width - origin.dx),
            math.max(origin.dy, size.height - origin.dy),
          ).distance;
          return AnimatedBuilder(
            animation: curved,
            builder: (_, c) => ClipPath(
              clipper: _CircleClipper(origin, maxR * curved.value + 1),
              child: Transform.scale(
                scale: 0.94 + 0.06 * curved.value,
                alignment: Alignment(
                  (origin.dx / size.width) * 2 - 1,
                  (origin.dy / size.height) * 2 - 1,
                ),
                child: c,
              ),
            ),
            child: child,
          );
        },
      );
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleClipper(this.center, this.radius);
  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  @override
  bool shouldReclip(_CircleClipper old) =>
      old.radius != radius || old.center != center;
}

/// Money that rolls like an odometer when it changes (and from zero on the
/// first appearance). Settles into a plain [Text] so it stays selectable and
/// readable by screen readers.
class RollingMoney extends StatefulWidget {
  final int minor;
  final TextStyle? style;
  final String Function(int minor) format;
  const RollingMoney({
    super.key,
    required this.minor,
    required this.format,
    this.style,
  });
  @override
  State<RollingMoney> createState() => _RollingMoneyState();
}

class _RollingMoneyState extends State<RollingMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 540),
  );
  late Animation<double> _a;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void didUpdateWidget(RollingMoney old) {
    super.didUpdateWidget(old);
    if (old.minor != widget.minor) {
      _from = old.minor.toDouble();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      if (!_c.isAnimating && _c.value >= 1) {
        return Text(widget.format(widget.minor), style: widget.style);
      }
      final v = _from + (widget.minor - _from) * _a.value;
      final text = widget.format(v.round());
      final settle = _a.value;
      // The final text sits invisibly underneath: it reserves the exact width
      // (no jitter as digits change) and keeps the value readable.
      return Semantics(
        label: widget.format(widget.minor),
        excludeSemantics: true,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: 0,
              child: Text(widget.format(widget.minor), style: widget.style),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < text.length; i++)
                  // digits tumble a little while the number is still moving
                  Transform.translate(
                    offset: Offset(
                      0,
                      math.sin((settle * 10) + i) * (1 - settle) * 5,
                    ),
                    child: Text(text[i], style: widget.style),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// A card that leans towards your finger like a real object, then springs
/// back when you let go. It only listens to pointer events, so scrolling
/// and taps still work normally.
class TiltCard extends StatefulWidget {
  final Widget child;
  final double maxTilt; // radians
  const TiltCard({super.key, required this.child, this.maxTilt = 0.16});
  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset _p = Offset.zero; // -1..1 from the centre
  bool _held = false;

  void _update(PointerEvent e) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _held = true;
      _p = Offset(
        ((e.localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
        ((e.localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _release(PointerEvent _) => setState(() {
    _held = false;
    _p = Offset.zero;
  });

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _update,
    onPointerMove: _update,
    onPointerUp: _release,
    onPointerCancel: _release,
    child: TweenAnimationBuilder<Offset>(
      tween: Tween(end: _p),
      duration: Duration(milliseconds: _held ? 90 : 650),
      curve: _held ? Curves.easeOut : Curves.elasticOut,
      builder: (_, p, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(-p.dy * widget.maxTilt)
          ..rotateY(p.dx * widget.maxTilt),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

/// Springs a child in from nothing (buttons, badges) once, when it first shows.
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const PopIn({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 250),
  });
  @override
  Widget build(BuildContext context) {
    final total = 600 + delay.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(
        delay.inMilliseconds / total,
        1,
        curve: Curves.elasticOut,
      ),
      builder: (_, t, c) => Transform.scale(
        scale: t.clamp(0.0, 1.2),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: c),
      ),
      child: child,
    );
  }
}

/// A soft diagonal gleam that sweeps across a card once after it appears, and
/// again whenever [replay] changes. Put it on top of the card's content; it
/// ignores touches. (One-shot, so it never keeps the screen animating.)
class ShineSweep extends StatefulWidget {
  final int replay;
  const ShineSweep({super.key, this.replay = 0});
  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(ShineSweep old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) _c.forward(from: 0);
  }

  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        if (_c.value == 0 || _c.value == 1) return const SizedBox.shrink();
        final t = Curves.easeInOut.transform(_c.value);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment(-1.6 + 3.2 * t, -0.6),
            end: Alignment(-0.9 + 3.2 * t, 0.6),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(r),
          child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
        );
      },
    ),
  );
}
