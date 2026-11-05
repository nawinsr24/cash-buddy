import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sync/sync_engine.dart';
import '../sync/sync_service.dart';
import 'theme.dart';

String stageLabel(SyncStage s) => switch (s) {
  SyncStage.signingIn => 'Signing in to Google',
  SyncStage.finding => 'Finding your data',
  SyncStage.downloading => 'Downloading',
  SyncStage.merging => 'Merging',
  SyncStage.rebuilding => 'Rebuilding your totals',
  SyncStage.sending => 'Sending changes',
};

/// A ring that keeps sweeping, with an icon in the middle. Used while the app
/// is working and nothing else on screen can show progress.
class SweepLoader extends StatefulWidget {
  final double size;
  final IconData icon;
  final Color? color;
  const SweepLoader({
    super.key,
    this.size = 120,
    this.icon = Icons.cloud_sync_outlined,
    this.color,
  });
  @override
  State<SweepLoader> createState() => _SweepLoaderState();
}

class _SweepLoaderState extends State<SweepLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.scheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _SweepPainter(
            _c.value,
            context.scheme.outlineVariant,
            color,
          ),
          child: Center(
            child: Transform.scale(
              scale: 1 + math.sin(_c.value * 2 * math.pi) * 0.06,
              child: Icon(widget.icon, size: widget.size * 0.34, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double t;
  final Color track, color;
  _SweepPainter(this.t, this.track, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.06;
    final r = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    final start = t * math.pi * 2;
    final sweep = math.pi * (0.5 + 0.35 * math.sin(t * math.pi * 2));
    canvas.drawArc(
      r,
      start,
      sweep,
      false,
      p
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.1), color],
          transform: GradientRotation(start),
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter o) => o.t != t;
}

/// The list of steps with the current one highlighted and finished ones ticked.
class StepList extends StatelessWidget {
  final List<SyncStage> steps;
  final SyncStage? current;
  final int done, total;
  const StepList({
    super.key,
    required this.steps,
    required this.current,
    this.done = 0,
    this.total = 0,
  });
  @override
  Widget build(BuildContext context) {
    final cur = current == null ? -1 : steps.indexOf(current!);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: i < cur
                        ? Icon(
                            Icons.check_circle,
                            key: ValueKey('d$i'),
                            size: 22,
                            color: context.cash.income,
                          )
                        : i == cur
                        ? SizedBox(
                            key: ValueKey('a$i'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: context.scheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            key: ValueKey('p$i'),
                            size: 20,
                            color: context.scheme.outline,
                          ),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Text(
                    stageLabel(steps[i]) +
                        (i == cur && total > 0 ? '  ($done of $total)' : ''),
                    style: TextStyle(
                      fontWeight: i == cur ? FontWeight.w700 : FontWeight.w500,
                      color: i <= cur
                          ? context.scheme.onSurface
                          : context.cash.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Full-screen "Restoring your money" view that follows the sync's real steps,
/// then shows a short welcome with what came back.
class RestoreScreen extends StatelessWidget {
  final ValueNotifier<SyncProgress> progress;
  final String? welcome; // when set, the restore is done
  const RestoreScreen({super.key, required this.progress, this.welcome});

  static const steps = [
    SyncStage.signingIn,
    SyncStage.finding,
    SyncStage.downloading,
    SyncStage.merging,
    SyncStage.rebuilding,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: welcome != null
                ? _done(context)
                : ValueListenableBuilder<SyncProgress>(
                    valueListenable: progress,
                    builder: (context, p, _) => _working(context, p),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _working(BuildContext context, SyncProgress p) {
    final frac = p.total > 0 ? (p.done / p.total).clamp(0.0, 1.0) : null;
    return Column(
      key: const ValueKey('working'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const SweepLoader(size: 132),
        const SizedBox(height: Sp.x6),
        Text(
          'Restoring your money',
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Sp.x1),
        Text(
          'Please keep the app open. This takes a moment.',
          style: context.text.bodyMedium?.copyWith(
            color: context.cash.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Sp.x6),
        StepList(steps: steps, current: p.stage, done: p.done, total: p.total),
        const SizedBox(height: Sp.x4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: context.scheme.outlineVariant,
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _done(BuildContext context) => Column(
    key: const ValueKey('done'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, t, c) => Transform.scale(scale: t.clamp(0, 1.1), child: c),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: context.cash.income.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 64,
            color: context.cash.income,
          ),
        ),
      ),
      const SizedBox(height: Sp.x5),
      Text(
        'Welcome back',
        style: context.text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: Sp.x2),
      Text(
        welcome!,
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(color: context.cash.textMuted),
      ),
    ],
  );
}

/// Inline progress for "Sync now": a slim bar and the current step.
class SyncProgressLine extends StatelessWidget {
  final SyncProgress p;
  const SyncProgressLine({super.key, required this.p});
  @override
  Widget build(BuildContext context) {
    final label = p.stage == null ? 'Syncing…' : stageLabel(p.stage!);
    final detail = p.total > 0 ? '  ${p.done}/${p.total}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label$detail',
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.total > 0 ? (p.done / p.total).clamp(0.0, 1.0) : null,
            minHeight: 5,
            backgroundColor: context.scheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}
