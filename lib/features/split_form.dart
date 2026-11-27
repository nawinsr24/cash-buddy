import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/money.dart';
import '../domain/split.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';

class SplitPerson {
  final name = TextEditingController();
  final value = TextEditingController();
}

/// What the user has typed in the split section of the expense form.
class SplitDraft {
  SplitBy by = SplitBy.equal;
  final people = <SplitPerson>[SplitPerson()];

  Shares? shares(int total) => splitShares(total, by, people.length, [
    for (final p in people)
      // "25" percent and "25" rupees both parse to 2500 hundredths.
      by == SplitBy.percent
          ? _hundredths(p.value.text)
          : Money.parse(p.value.text),
  ]);

  static int? _hundredths(String s) {
    final v = double.tryParse(s.trim());
    return v == null ? null : (v * 100).round();
  }

  List<(String, int)> others(Shares s) => [
    for (var i = 0; i < people.length; i++)
      (people[i].name.text.trim(), s.others[i]),
  ];
}

class SplitFields extends StatelessWidget {
  final SplitDraft draft;
  final TextEditingController total;
  final VoidCallback onChanged;
  const SplitFields({
    super.key,
    required this.draft,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SegmentedButton<SplitBy>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: SplitBy.equal, label: Text(tr('Equally'))),
          const ButtonSegment(value: SplitBy.percent, label: Text('%')),
          ButtonSegment(value: SplitBy.amount, label: Text(tr('Amount'))),
        ],
        selected: {draft.by},
        onSelectionChanged: (s) {
          draft.by = s.first;
          for (final p in draft.people) {
            p.value.clear();
          }
          onChanged();
        },
      ),
      for (final (i, p) in draft.people.indexed)
        Padding(
          padding: const EdgeInsets.only(top: Sp.x3),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: ValueKey('split-name-$i'),
                  controller: p.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('Name')),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (draft.by != SplitBy.equal) ...[
                const SizedBox(width: Sp.x2),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: ValueKey('split-value-$i'),
                    controller: p.value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(Money.inputPattern),
                    ],
                    decoration: InputDecoration(
                      labelText: draft.by == SplitBy.percent
                          ? '%'
                          : Money.symbol,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
              if (draft.people.length > 1)
                IconButton(
                  tooltip: tr('Remove person'),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    draft.people.removeAt(i);
                    onChanged();
                  },
                ),
            ],
          ),
        ),
      TextButton.icon(
        icon: const Icon(Icons.person_add_alt),
        label: Text(tr('Add person')),
        onPressed: () {
          draft.people.add(SplitPerson());
          onChanged();
        },
      ),
      ListenableBuilder(
        listenable: total,
        builder: (context, _) {
          final amount = Money.parse(total.text) ?? 0;
          final s = draft.shares(amount);
          return Text(
            s == null
                ? tr('Your share and every other share must be above zero.')
                : [
                    '${tr('You')} ${Money.format(s.mine)}',
                    for (var i = 0; i < s.others.length; i++)
                      '${draft.people[i].name.text.trim().isEmpty ? '${tr('Person')} ${i + 1}' : draft.people[i].name.text.trim()} ${Money.format(s.others[i])}',
                  ].join(' · '),
            style: context.text.bodyMedium?.copyWith(
              color: s == null ? context.cash.textMuted : null,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    ],
  );
}
