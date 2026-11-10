import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Explains the month-end title and lets the user pick how it is worded.
/// Used in first-run setup and in Settings.
class ToneChooser extends StatelessWidget {
  final bool funny;
  final ValueChanged<bool> onChanged;
  const ToneChooser({super.key, required this.funny, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final spent = Money.format(Money.fromMajor(44200));
    final earned = Money.format(Money.fromMajor(40000));
    final over = Money.format(Money.fromMajor(4200));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'At the end of each month, Cash++ gives you a title based on how you spent. Choose how it is worded.',
          style: context.text.bodyMedium?.copyWith(
            color: context.cash.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Sp.x4),
        _card(
          context,
          selected: !funny,
          title: 'Friendly',
          note: 'Gentle and encouraging.',
          example:
              'You spent $over more than you earned. Try a little less next month.',
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: Sp.x3),
        _card(
          context,
          selected: funny,
          title: 'Honest and funny',
          note: 'Playful and straight-talking.',
          example:
              'You earned $earned but spent $spent. Where is the extra money coming from?',
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: Sp.x3),
        Text(
          'We never joke about health or family spending.',
          style: context.text.bodySmall?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required bool selected,
    required String title,
    required String note,
    required String example,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: '$title. $note Example: $example',
    child: InkWell(
      borderRadius: BorderRadius.circular(Sp.rCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.x4),
        decoration: BoxDecoration(
          color: context.cash.surfaceRaised,
          borderRadius: BorderRadius.circular(Sp.rCard),
          border: Border.all(
            color: selected
                ? context.scheme.primary
                : context.scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    note,
                    style: context.text.bodySmall?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    '“$example”',
                    style: context.text.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: context.scheme.primary),
          ],
        ),
      ),
    ),
  );
}

/// Settings: the same explanation in a sheet; saves as soon as you choose.
Future<void> showToneSheet(BuildContext context) => showSheet(
  context,
  (_) => Consumer(
    builder: (context, ref, _) {
      final funny = ref.watch(roastModeProvider).value ?? false;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How we talk to you',
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Sp.x2),
              ToneChooser(
                funny: funny,
                onChanged: (v) => ref
                    .read(repoProvider)
                    .setSetting('roastMode', v ? '1' : '0'),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
