import 'dart:async';

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
  Widget build(BuildContext context) => builder(value);
}

/// Press feedback: a slight, quick shrink while held.
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
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Opens [page] with a short fade and a small slide up (the same quiet
/// transition everywhere). The tapped widget no longer matters, so every
/// existing call keeps working.
Future<T?> pushReveal<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(_FadeSlideRoute<T>(page));

class _FadeSlideRoute<T> extends PageRouteBuilder<T> {
  _FadeSlideRoute(Widget page)
    : super(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (context, anim, secondary, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
