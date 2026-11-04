import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../domain/dates.dart';
import '../domain/sms_parser.dart';
import '../providers.dart';
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
        title: const Text('Inbox'),
        actions: [
          IconButton(
            tooltip: 'Import messages',
            icon: const Icon(Icons.content_paste),
            onPressed: () => showSheet(context, (_) => const ImportSheet()),
          ),
        ],
      ),
      body: pending.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => ErrorState(e),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'All caught up',
              body: Platform.isIOS
                  ? 'iOS does not let apps read your messages. Copy a bank SMS and import it, or use the share sheet.'
                  : 'Import bank messages to find transactions. You approve each one before it is added.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                icon: const Icon(Icons.content_paste),
                label: const Text('Import messages'),
                onPressed: () => showSheet(context, (_) => const ImportSheet()),
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
                                title: Text('Confirm all ${list.length}?'),
                                content: const Text(
                                  'They will be added as uncategorised. You can edit categories later.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Confirm all'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final repo = ref.read(repoProvider);
                              for (final s in list) {
                                await repo.confirmSms(s.id);
                              }
                            }
                          },
                          child: const Text('Confirm all'),
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
  String? categoryId;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final credit = s.direction == 'credit';
    final color = credit ? context.cash.income : context.cash.spending;
    final cats = widget.cats.where((c) => c.kind == s.direction).toList();
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
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Uncategorised'),
                  ),
                  for (final c in cats)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.parentId == null ? c.name : '   ${c.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => categoryId = v),
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
                      label: const Text('Discard'),
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
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm'),
                      onPressed: () async {
                        haptic();
                        await ref
                            .read(repoProvider)
                            .confirmSms(s.id, categoryId: categoryId);
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
            decoration: const InputDecoration(
              labelText: 'Message text',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
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
            child: const Text('Find transactions'),
          ),
        ],
      ),
    ),
  );
}
