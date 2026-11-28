import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/app_lock.dart';
import '../platform/features.dart';
import '../platform/notifications.dart';
import '../platform/reminders.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'budget_editor.dart';
import 'group.dart';

/// "Finish setting up" on Home after the short setup: the optional steps,
/// one tap each. Gone once all are done or the user hides it.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value;
    final hidden = ref.watch(_hiddenProvider).value ?? true;
    if (s == null || hidden) return const SizedBox.shrink();
    final budget = ref.watch(budgetStatusProvider).value != null;
    final home = ref.watch(homeOnProvider).value == true;
    final smsAllowed = Features.smsReading(remoteFlag: s.smsAllowed);
    final items = <_Item>[
      _Item(
        '🎯',
        tr('Monthly budget'),
        tr('The most you want to spend'),
        budget,
        () => _open(context, const _BudgetStep()),
      ),
      if (smsAllowed && SmsReader.supported)
        _Item(
          '✉️',
          tr('Bank message alerts'),
          tr('Entries filled from bank SMS'),
          s.smsEnabled,
          () => _open(context, const BankAlertsStep()),
        ),
      _Item(
        '🏡',
        tr('Link your family'),
        tr('Share one home budget'),
        home,
        () => _open(context, const GroupPage()),
      ),
      _Item(
        '🔔',
        tr('Daily reminder'),
        tr('One quiet nudge a day'),
        s.reminderEnabled,
        () => _open(context, const ReminderStep()),
      ),
    ];
    final done = items.where((i) => i.done).length;
    if (done == items.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x2, Sp.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Finish setting up'),
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$done / ${items.length}',
                    style: context.text.labelLarge?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Hide'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () async {
                      await ref
                          .read(repoProvider)
                          .setSetting('setupHidden', '1');
                      ref.invalidate(_hiddenProvider);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: Sp.x2, bottom: Sp.x2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: done / items.length,
                    minHeight: 5,
                    color: context.cash.income,
                  ),
                ),
              ),
              for (final i in items)
                ListTile(
                  contentPadding: const EdgeInsets.only(right: Sp.x2),
                  onTap: i.done ? null : i.onTap,
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(i.emoji, style: const TextStyle(fontSize: 19)),
                  ),
                  title: Text(
                    i.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(i.sub),
                  trailing: i.done
                      ? Icon(Icons.check_circle, color: context.cash.income)
                      : const Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget page) =>
      pushReveal(context, page);
}

final _hiddenProvider = FutureProvider.autoDispose<bool>(
  (ref) async => await ref.watch(repoProvider).getSetting('setupHidden') == '1',
);

class _Item {
  final String emoji, title, sub;
  final bool done;
  final VoidCallback onTap;
  _Item(this.emoji, this.title, this.sub, this.done, this.onTap);
}

class _BudgetStep extends StatelessWidget {
  const _BudgetStep();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Monthly budget'))),
    body: BudgetEditor(
      onSaved: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).pop(),
    ),
  );
}

/// Shared look for a one-step page: big emoji, title, words, then content,
/// with the main button at the bottom.
class _StepPage extends StatelessWidget {
  final String emoji, title, body;
  final List<Widget> content;
  final String cta;
  final VoidCallback? onCta;
  final String later;
  const _StepPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.content,
    required this.cta,
    required this.onCta,
    required this.later,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: Sp.x5),
        Text(
          title,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Sp.x2),
        Text(
          body,
          style: context.text.bodyLarge?.copyWith(
            color: context.cash.textMuted,
          ),
        ),
        const SizedBox(height: Sp.x5),
        ...content,
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x2, Sp.x6, Sp.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: onCta, child: Text(cta)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(later),
            ),
          ],
        ),
      ),
    ),
  );
}

class BankAlertsStep extends ConsumerWidget {
  const BankAlertsStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider).value?.smsEnabled ?? false;
    Widget tick(String t) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Row(
        children: [
          Icon(Icons.check, size: 18, color: context.cash.income),
          const SizedBox(width: Sp.x2),
          Expanded(child: Text(t)),
        ],
      ),
    );
    return _StepPage(
      emoji: '✉️',
      title: tr('Spend once. We note it.'),
      body: tr(
        'When your bank sends an alert, Cash++ fills in the entry. You confirm it with one tap.',
      ),
      content: [
        tick(tr('Read on this phone only')),
        tick(tr('Only bank alerts, never personal messages')),
        tick(tr('Turn it off any time in Settings')),
        if (on)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x3),
            child: Text(
              tr('Almost there: switch on Cash++ in the list that opened'),
              style: TextStyle(
                color: context.cash.income,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
      cta: on ? tr('Done') : tr('Turn on notification access'),
      later: tr('Not now'),
      onCta: () async {
        if (on) {
          Navigator.of(context).pop();
          return;
        }
        AppLockGate.holdOff();
        await SmsReader.instance.requestPermission();
        final repo = ref.read(repoProvider);
        await repo.setSetting('smsEnabled', '1');
        await SmsReader.instance.setAutoDetect(true);
        ref.invalidate(settingsProvider);
      },
    );
  }
}

class ReminderStep extends ConsumerStatefulWidget {
  const ReminderStep({super.key});
  @override
  ConsumerState<ReminderStep> createState() => _ReminderStepState();
}

class _ReminderStepState extends ConsumerState<ReminderStep> {
  TimeOfDay _at = const TimeOfDay(hour: 21, minute: 0);
  static const _times = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final custom = !_times.contains(_at);
    Widget chip(String label, bool on, VoidCallback tap) => Expanded(
      child: Pressable(
        onTap: () {
          haptic();
          tap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: Sp.x3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? context.scheme.primaryContainer
                : context.cash.surfaceRaised,
            borderRadius: BorderRadius.circular(Sp.rField),
            border: Border.all(
              color: on
                  ? context.scheme.onSurface
                  : context.scheme.outlineVariant,
            ),
          ),
          child: FittedBox(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    return _StepPage(
      emoji: '🔔',
      title: tr('A nudge to note today\'s spends'),
      body: tr('One quiet notification a day. Nothing else.'),
      content: [
        Text(
          tr('Remind me at'),
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Sp.x2),
        Row(
          children: [
            for (final t in _times) ...[
              chip(t.format(context), _at == t, () => setState(() => _at = t)),
              const SizedBox(width: Sp.x2),
            ],
            chip(custom ? _at.format(context) : tr('Custom'), custom, () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _at,
              );
              if (t != null && mounted) setState(() => _at = t);
            }),
          ],
        ),
      ],
      cta: tr('Allow notifications'),
      later: tr('No reminder'),
      onCta: () async {
        AppLockGate.holdOff();
        final ok = await Notifications.instance.requestPermission();
        if (!context.mounted) return;
        if (!ok) {
          toast(
            context,
            'Notifications are blocked. You can allow them later in Settings.',
          );
          return;
        }
        final repo = ref.read(repoProvider);
        await repo.setSetting('reminderEnabled', '1');
        await repo.setSetting(
          'reminderTime',
          '${_at.hour.toString().padLeft(2, '0')}:${_at.minute.toString().padLeft(2, '0')}',
        );
        await refreshReminder(repo);
        ref.invalidate(settingsProvider);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
