import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../data/db.dart';
import '../domain/dates.dart';
import '../domain/sms_parser.dart';
import '../platform/sms_reader.dart';
import '../providers.dart';
import 'settings.dart' show scanAndReport;
import 'transactions.dart' show showTransactionSheet;
import '../ui/art.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Review queue for transactions detected in bank messages. Nothing reaches
/// the ledger until the user confirms.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSmsProvider);
    final cats = ref.watch(categoriesProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Bank messages to review')),
        actions: [
          if (SmsReader.supported)
            IconButton(
              tooltip: tr('Check for new alerts'),
              icon: const Icon(Icons.refresh),
              onPressed: () => scanAndReport(context, ref),
            ),
          // Older messages (and phones that cannot see alerts) use paste.
          IconButton(
            tooltip: 'Add from a copied message',
            icon: const Icon(Icons.content_paste),
            onPressed: () => showSheet(context, (_) => const ImportSheet()),
          ),
        ],
      ),
      body: pending.when(
        skipLoadingOnReload: true,
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              art: Art.inbox,
              icon: Icons.mark_email_read_outlined,
              title: 'All caught up',
              body: SmsReader.supported
                  ? 'New bank alerts appear here automatically. Check each one and add it, or ignore it. For older messages, copy the message and use the paste button.'
                  : 'This device cannot read your messages. Copy a bank SMS and import it to review it here.',
              action: SmsReader.supported
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.manage_search),
                      label: Text(tr('Check for new alerts')),
                      onPressed: () => scanAndReport(context, ref),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 48),
                      ),
                      icon: const Icon(Icons.content_paste),
                      label: Text(tr('Import messages')),
                      onPressed: () =>
                          showSheet(context, (_) => const ImportSheet()),
                    ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x8),
            children: [
              Card(
                color: context.scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Sp.x4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${list.length} detected transaction${list.length == 1 ? '' : 's'}',
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (list.length > 1)
                        TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Ignore all ${list.length}?'),
                                content: const Text(
                                  'Nothing is added to your records. Useful to clear old messages.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: Text(tr('Cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(tr('Ignore all')),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final repo = ref.read(repoProvider);
                              for (final s in list) {
                                await repo.discardSms(s.id);
                              }
                            }
                          },
                          child: Text(tr('Ignore all')),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Sp.x3),
              for (final s in list) _SmsTile(s, cats),
            ],
          );
        },
      ),
    );
  }
}

class _SmsTile extends ConsumerStatefulWidget {
  final SmsInboxData s;
  final List<Category> cats;
  const _SmsTile(this.s, this.cats);
  @override
  ConsumerState<_SmsTile> createState() => _SmsTileState();
}

class _SmsTileState extends ConsumerState<_SmsTile> {
  /// "→ HDFC" when the digits matched exactly one bank account.
  String? _matchedName() {
    final accs = ref.watch(accountsProvider).value ?? const [];
    final banks = accs.where((a) => a.kind == 'bank').toList();
    final ref0 = widget.s.accountRef;
    if (banks.length < 2 || ref0 == null) return null;
    final hit = banks.where((b) => b.last4 == ref0).toList();
    return hit.length == 1 ? '→ ${hit.first.name}' : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final credit = s.direction == 'credit';
    final color = credit ? context.cash.income : context.cash.spending;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    credit ? Icons.south_west : Icons.north_east,
                    color: color,
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.merchant ??
                              (credit ? 'Money received' : 'Money spent'),
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            DateFormat('d MMM y').format(Dates.parse(s.date)),
                            if (s.accountRef != null) 'a/c ••${s.accountRef}',
                            ?_matchedName(),
                          ].join(' · '),
                          style: context.text.bodySmall?.copyWith(
                            color: context.cash.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MoneyText(
                    s.amountMinor,
                    color: color,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.close),
                      label: Text(tr('Ignore')),
                      onPressed: () {
                        haptic();
                        ref.read(repoProvider).discardSms(s.id);
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: Text(tr('Review & add')),
                      onPressed: () async {
                        haptic();
                        final m = await ref
                            .read(repoProvider)
                            .accountForSms(s.accountRef);
                        if (!context.mounted) return;
                        showTransactionSheet(context, sms: s, accountId: m?.id);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// User-initiated import: paste one or more messages (works on iOS and Android).
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({super.key});
  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  final _sender = TextEditingController();
  final _text = TextEditingController();
  String? result;

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _text.text = d!.text!);
  }

  Future<void> _import() async {
    final sender = _sender.text.trim();
    final blocks = _text.text
        .split(RegExp(r'\n\s*\n|\n-{3,}\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (blocks.isEmpty) return;
    final now = DateTime.now();
    final res = await ref.read(repoProvider).ingestSms([
      for (final b in blocks) (sender: sender, body: b, receivedAt: now),
    ], SmsParser());
    setState(
      () => result =
          '${res.added} found · ${res.duplicates} already seen · ${res.rejected} ignored (OTP, promo or not a transaction)',
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import messages',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.x1),
          Text(
            'Paste bank SMS text. Separate several messages with a blank line. Messages are parsed on this device only.',
            style: context.text.bodySmall?.copyWith(
              color: context.cash.textMuted,
            ),
          ),
          const SizedBox(height: Sp.x4),
          TextField(
            controller: _sender,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Sender ID (e.g. VM-HDFCBK)',
            ),
          ),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: tr('Message text'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(tr('Paste')),
              ),
            ],
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x3),
              child: Text(result!),
            ),
          const SizedBox(height: Sp.x4),
          FilledButton(
            onPressed: _import,
            child: Text(tr('Find transactions')),
          ),
        ],
      ),
    ),
  );
}
