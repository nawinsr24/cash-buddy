import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/summary.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'score_ui.dart';

/// "✨ Performance": a 3-line summary of the month, written on the phone from
/// the user's own numbers.
void showPerformanceSheet(BuildContext context) =>
    showSheet(context, (_) => const _PerformanceBody());

class _PerformanceBody extends ConsumerWidget {
  const _PerformanceBody();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(plusScoreProvider).value;
    final roast = ref.watch(roastModeProvider).value ?? true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
        child: data == null
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            : _content(context, data.stats, data.grade, data.prevScore, roast),
      ),
    );
  }

  Widget _content(BuildContext context, stats, grade, int? prev, bool roast) {
    final lines = performanceSummary(stats, grade, roast: roast);
    final delta = prev == null || grade.building ? null : grade.score - prev;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GradeRing(grade: grade, size: 76),
            const SizedBox(width: Sp.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Your performance',
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    grade.building
                        ? 'Money Health: building…'
                        : 'Money Health: ${grade.level}${delta == null || delta == 0
                              ? ''
                              : delta > 0
                              ? '  ▲$delta'
                              : '  ▼${-delta}'}',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.x4),
        for (final (i, l) in lines.indexed)
          Reveal(
            index: i + 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: Sp.x2),
              padding: const EdgeInsets.all(Sp.x3),
              decoration: BoxDecoration(
                color: CashColors.tile(
                  i == 0 ? 2 : (i == 1 ? 3 : 1),
                  Theme.of(context).brightness,
                ),
                borderRadius: BorderRadius.circular(Sp.rCard),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      l.text,
                      style: context.text.bodyMedium?.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Sp.x1),
        Text(
          'Made on your phone from your own numbers. A guide to your habits, not financial advice.',
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
      ],
    );
  }
}
