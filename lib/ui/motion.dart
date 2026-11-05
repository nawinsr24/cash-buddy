import 'package:flutter/material.dart';

/// Fades and slides a child up when it first appears; [index] staggers lists.
class Reveal extends StatelessWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 55;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: c),
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

/// Press feedback: gently shrinks while held.
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
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: widget.child,
    ),
  );
}
