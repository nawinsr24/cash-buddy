import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db_key.dart';
import '../domain/dates.dart';
import '../domain/money.dart';
import '../domain/split.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../sync/group/group_service.dart';
import '../sync/group/note.dart';
import '../sync/group/replica.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'account_tile.dart';
import 'group_keeper.dart';

/// Null in builds without a server: then nothing about groups is shown.
final groupServiceProvider = Provider<GroupService?>((ref) {
  final account = ref.watch(accountProvider);
  if (account == null) return null;
  return GroupService(
    ref.watch(repoProvider),
    secrets: const SecureSecretStore(),
    server: Uri.parse(account.access.config.url),
  );
});

/// The one way into the group, in Settings.
class GroupCard extends ConsumerWidget {
  const GroupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(groupServiceProvider) == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.group_outlined),
        title: Text(tr('Shared group')),
        subtitle: Text(tr('Spend together, for example as a couple')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GroupPage())),
      ),
    );
  }
}

final _day = DateFormat('d MMM');

Map<String, String> _names(Replica g) => {
  for (final e in GroupService.ofKind(g, 'member'))
    e.id.substring('member:'.length): e.data['name'] as String,
};

/// Positive: this person is owed money. Positive and negative cancel out.
Map<String, int> groupBalances(Replica g) {
  final out = <String, int>{};
  for (final e in GroupService.ofKind(g, 'expense')) {
    final payer = e.data['paidBy'] as String;
    out[payer] = (out[payer] ?? 0) + (e.data['amountMinor'] as int);
    for (final s in (e.data['shares'] as Map).entries) {
      out[s.key as String] = (out[s.key] ?? 0) - (s.value as int);
    }
  }
  return out;
}

class GroupPage extends ConsumerStatefulWidget {
  const GroupPage({super.key});
  @override
  ConsumerState<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends ConsumerState<GroupPage> {
  Replica? _group;
  var _loading = true;
  String? _problem;

  GroupService get _service => ref.read(groupServiceProvider)!;

  @override
  void initState() {
    super.initState();
    groupSynced.addListener(_redraw);
    _open();
  }

  @override
  void dispose() {
    groupSynced.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    final g = await _service.open();
    if (!mounted) return;
    setState(() {
      _group = g;
      _loading = false;
    });
    if (g != null) await _sync();
  }

  /// Offline is normal: changes are kept and sent later.
  Future<void> _sync() async {
    String? problem;
    try {
      await _service.sync();
    } on GroupProblem catch (e) {
      problem = e.message;
    }
    final g = await _service.open();
    if (mounted) {
      setState(() {
        _group = g;
        _problem = problem;
      });
    }
  }

  Future<void> _change(void Function(Replica g) edit) async {
    await _service.change(edit);
    // the personal budget counts my share
    ref.invalidate(budgetStatusProvider);
    setState(() {});
    await _sync();
  }

  Future<void> _attempt(Future<void> Function() work) async {
    try {
      await work();
    } on GroupProblem catch (e) {
      if (mounted) toast(context, tr(e.message));
    }
  }

  Future<String?> _ask(
    String title, {
    String initial = '',
    bool number = false,
  }) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(title)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _start({required bool joining}) async {
    final account = ref.read(accountProvider)!;
    if ((await account.email ?? '').isEmpty) {
      if (!mounted || !await signInWithConsent(context, account)) return;
    }
    if (!mounted) return;
    final code = joining ? await _ask('Invite code') : null;
    if (joining && code == null) return;
    final name = await _ask('Your name');
    if (name == null) return;
    await _attempt(() async {
      joining ? await _service.join(code!, name) : await _service.create(name);
      await _open();
    });
  }

  Future<void> _invite() => _attempt(() async {
    final code = await _service.inviteCode();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Invite code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(code),
            const SizedBox(height: Sp.x3),
            Text(
              tr(
                'Valid for one day. Send it only to the person joining: it opens the group.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(d);
            },
            child: Text(tr('Copy')),
          ),
        ],
      ),
    );
  });

  Future<void> _setBudget(int? current) async {
    final text = await _ask(
      'Group budget for each month',
      initial: current == null ? '' : Money.edit(current),
      number: true,
    );
    final v = text == null ? null : Money.parse(text);
    if (v == null || v < 0) return;
    await _change((g) => g.put('budget', {'kind': 'budget', 'limitMinor': v}));
  }

  Future<void> _editExpense([Entry? entry]) async {
    final g = _group!;
    final data = await showSheet<Map<String, Object?>>(
      context,
      (_) => _ExpenseForm(
        names: _names(g),
        me: g.disk.member,
        initial: entry?.data,
      ),
    );
    if (data == null) return;
    await _change(
      (g) => entry == null ? g.add([data]) : g.edit(entry.id, data),
    );
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Leave this group?')),
        content: Text(
          tr(
            'It is removed from this phone. Others keep what they already have.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Leave')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _attempt(() async {
      await _service.leave();
      ref.invalidate(budgetStatusProvider);
      if (mounted) setState(() => _group = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Shared group')),
        actions: [
          if (g != null)
            IconButton(
              tooltip: tr('Invite'),
              icon: const Icon(Icons.person_add_alt),
              onPressed: _invite,
            ),
          if (g != null)
            IconButton(
              tooltip: tr('Leave'),
              icon: const Icon(Icons.logout),
              onPressed: _leave,
            ),
        ],
      ),
      floatingActionButton: g == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _editExpense,
              icon: const Icon(Icons.add),
              label: Text(tr('Group spend')),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : g == null
          ? _welcome()
          : RefreshIndicator(onRefresh: _sync, child: _list(g)),
    );
  }

  Widget _welcome() => ListView(
    padding: const EdgeInsets.all(Sp.x5),
    children: [
      Text(
        tr(
          'Create a group, or join one with a code from the other person. Only what you add here is shared.',
        ),
      ),
      const SizedBox(height: Sp.x4),
      FilledButton(
        onPressed: () => _start(joining: false),
        child: Text(tr('Create a group')),
      ),
      const SizedBox(height: Sp.x3),
      OutlinedButton(
        onPressed: () => _start(joining: true),
        child: Text(tr('Join with a code')),
      ),
    ],
  );

  Widget _list(Replica g) {
    final names = _names(g);
    final me = g.disk.member;
    final month = Dates.str(ref.read(repoProvider).today).substring(0, 7);
    final all = GroupService.ofKind(g, 'expense').toList()
      ..sort(
        (a, b) =>
            (b.data['date'] as String).compareTo(a.data['date'] as String),
      );
    final thisMonth = all.where(
      (e) => (e.data['date'] as String).startsWith(month),
    );
    final spent = thisMonth.fold<int>(
      0,
      (s, e) => s + (e.data['amountMinor'] as int),
    );
    final mine = thisMonth.fold<int>(
      0,
      (s, e) => s + ((e.data['shares'] as Map)[me] as int? ?? 0),
    );
    final limit = g.entries['budget']?.data['limitMinor'] as int?;
    final balances = groupBalances(g);
    String who(String id) => id == me ? tr('You') : names[id] ?? tr('Person');
    final muted = TextStyle(color: context.cash.textMuted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 96),
      children: [
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: Text(tr(_problem!), style: muted),
          ),
        if (g.needsUpdate)
          Text(tr('Update the app to see newer group entries.')),
        Card(
          child: InkWell(
            onTap: () => _setBudget(limit),
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Group spending this month'), style: muted),
                  MoneyText(
                    spent,
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (limit == null || limit == 0)
                    Text(tr('Tap to set a group budget'), style: muted)
                  else ...[
                    const SizedBox(height: Sp.x2),
                    LinearProgressIndicator(
                      value: (spent / limit).clamp(0, 1).toDouble(),
                    ),
                    const SizedBox(height: Sp.x2),
                    Text(
                      spent <= limit
                          ? '${Money.format(limit - spent)} ${tr('left of')} ${Money.format(limit)}'
                          : '${Money.format(spent - limit)} ${tr('over')} ${Money.format(limit)}',
                    ),
                  ],
                  const SizedBox(height: Sp.x2),
                  Text('${tr('Your share')}: ${Money.format(mine)}'),
                ],
              ),
            ),
          ),
        ),
        for (final b in balances.entries)
          if (b.value != 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${who(b.key)} · ${tr(b.value > 0 ? 'to get back' : 'to pay')}',
              ),
              trailing: Text(Money.format(b.value.abs())),
            ),
        SectionTitle(tr('Spends')),
        for (final e in all)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              (e.data['note'] as String).isEmpty
                  ? tr('Spent')
                  : e.data['note'] as String,
            ),
            subtitle: Text(
              [
                _day.format(Dates.parse(e.data['date'] as String)),
                '${tr('paid by')} ${who(e.data['paidBy'] as String)}',
                if (e.needsReview) tr('needs review'),
              ].join(' · '),
              style: e.needsReview
                  ? TextStyle(color: context.cash.spending)
                  : null,
            ),
            trailing: Text(Money.format(e.data['amountMinor'] as int)),
            onTap: () => _details(g, e.id),
          ),
        if (g.deleted.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(tr('Deleted')),
            children: [
              for (final id in g.deleted)
                for (final c in g.history(id))
                  if (c.kind == ChangeKind.deleted && c.before != null)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${c.before!['note']} · ${Money.format(c.before!['amountMinor'] as int)}',
                      ),
                      subtitle: Text('${tr('deleted by')} ${who(c.member)}'),
                    ),
            ],
          ),
      ],
    );
  }

  /// One spend: choose between competing edits, change it, and its history.
  Future<void> _details(Replica g, String id) async {
    final e = g.entries[id];
    if (e == null) return;
    final names = _names(g);
    String who(String m) =>
        m == g.disk.member ? tr('You') : names[m] ?? tr('Person');
    const kinds = {
      ChangeKind.added: 'added',
      ChangeKind.changed: 'changed',
      ChangeKind.settled: 'settled',
      ChangeKind.deleted: 'deleted',
    };
    await showSheet<void>(
      context,
      (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (e.needsReview) ...[
                Text(
                  tr('Both of you changed this. Which one is right?'),
                  style: context.text.titleMedium,
                ),
                for (final (i, v) in e.heads.indexed)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _change((g) => g.resolve(id, i));
                    },
                    child: Text(
                      '${Money.format(v.data['amountMinor'] as int)} ${v.data['note']}',
                    ),
                  ),
              ],
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _editExpense(e);
                    },
                    child: Text(tr('Edit')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _change((g) => g.delete(id));
                    },
                    child: Text(tr('Delete')),
                  ),
                ],
              ),
              SectionTitle(tr('History')),
              for (final c in g.history(id).reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      '${who(c.member)} ${tr(kinds[c.kind]!)}',
                      if (c.before != null)
                        Money.format(c.before!['amountMinor'] as int),
                      if (c.after != null)
                        Money.format(c.after!['amountMinor'] as int),
                    ].join(' · '),
                  ),
                  subtitle: Text(
                    DateFormat('d MMM, h:mm a')
                        .format(DateTime.fromMillisecondsSinceEpoch(c.at)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amount, note, who paid and how it is shared. Returns the row to save.
class _ExpenseForm extends ConsumerStatefulWidget {
  final Map<String, String> names;
  final String me;
  final Map<String, Object?>? initial;
  const _ExpenseForm({required this.names, required this.me, this.initial});
  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : Money.edit(widget.initial!['amountMinor'] as int),
  );
  late final _note = TextEditingController(
    text: widget.initial?['note'] as String? ?? '',
  );
  late String _paidBy = widget.initial?['paidBy'] as String? ?? widget.me;
  late var _by = widget.initial == null ? SplitBy.equal : SplitBy.amount;
  late final List<String> _others = [
    for (final id in widget.names.keys)
      if (id != widget.me) id,
  ];
  late final _values = {
    for (final id in _others)
      id: TextEditingController(
        text: widget.initial == null
            ? ''
            : Money.edit((widget.initial!['shares'] as Map)[id] as int? ?? 0),
      ),
  };
  String? _error;

  void _save() {
    final total = Money.parse(_amount.text) ?? 0;
    var shares = <String, int>{widget.me: total};
    if (total > 0 && _others.isNotEmpty) {
      // "My" share takes whatever does not divide evenly.
      final split = splitShares(total, _by, _others.length, [
        for (final id in _others)
          _by == SplitBy.percent
              ? ((double.tryParse(_values[id]!.text) ?? -1) * 100).round()
              : Money.parse(_values[id]!.text),
      ]);
      if (split == null) {
        setState(
          () => _error = 'Your share and every other share must be above zero.',
        );
        return;
      }
      shares = {
        widget.me: split.mine,
        for (var i = 0; i < _others.length; i++) _others[i]: split.others[i],
      };
    }
    if (total <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop<Map<String, Object?>>(context, {
      'kind': 'expense',
      'amountMinor': total,
      'note': _note.text.trim(),
      'paidBy': _paidBy,
      'date':
          widget.initial?['date'] ?? Dates.str(ref.read(repoProvider).today),
      'shares': shares,
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountField(controller: _amount, autofocus: widget.initial == null),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: tr('Note (optional)')),
          ),
          const SizedBox(height: Sp.x3),
          DropdownButtonFormField<String>(
            initialValue: widget.names.containsKey(_paidBy) ? _paidBy : null,
            decoration: InputDecoration(labelText: tr('Paid by')),
            items: [
              for (final n in widget.names.entries)
                DropdownMenuItem(value: n.key, child: Text(n.value)),
            ],
            onChanged: (v) => _paidBy = v!,
          ),
          if (_others.isNotEmpty) ...[
            const SizedBox(height: Sp.x3),
            SegmentedButton<SplitBy>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: SplitBy.equal, label: Text(tr('Equally'))),
                const ButtonSegment(value: SplitBy.percent, label: Text('%')),
                ButtonSegment(value: SplitBy.amount, label: Text(tr('Amount'))),
              ],
              selected: {_by},
              onSelectionChanged: (s) => setState(() {
                _by = s.first;
                for (final c in _values.values) {
                  c.clear();
                }
              }),
            ),
            if (_by != SplitBy.equal)
              for (final id in _others)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.x3),
                  child: TextField(
                    controller: _values[id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${widget.names[id]} ${_by == SplitBy.percent ? '%' : Money.symbol}',
                    ),
                  ),
                ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x2),
              child: Text(
                tr(_error!),
                style: TextStyle(color: context.cash.spending),
              ),
            ),
          const SizedBox(height: Sp.x4),
          FilledButton(onPressed: _save, child: Text(tr('Save'))),
        ],
      ),
    ),
  );
}
