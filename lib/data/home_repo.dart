/// Home sharing: one budget and one spending total for two people. Everything
/// spent counts and is shared, unless ticked "Don't count this", which keeps
/// it out of the budget and off the partner's phone.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../sync/group/note.dart';
import '../sync/group/replica.dart';
import 'db.dart';
import 'invest_repo.dart';
import 'repo.dart';

/// What counts as spending between us: money paid out, including chit fund
/// instalments, but not money lent, stocks or mutual funds.
const _spend = '''
t.type = 'debit' AND t.source <> 'debt' AND t.deleted_at IS NULL
AND COALESCE(t.uncounted, 0) = 0
AND (t.source <> 'invest' OR EXISTS (
  SELECT 1 FROM investment_entries e JOIN investments i ON i.id = e.investment_id
  WHERE 'inv:' || e.id = t.source_ref AND i.kind = 'custom'))''';

class HomeSpend {
  final String paidBy, category;
  final String? sub;
  final String date, note;
  final int amount;
  const HomeSpend(
    this.paidBy,
    this.amount,
    this.date,
    this.note,
    this.category,
    this.sub,
  );
}

/// A partner's balance, shown only while you both share.
class PartnerBalance {
  final String name;
  final int amount;
  final DateTime at;
  const PartnerBalance(this.name, this.amount, this.at);
}

class HomeSummary {
  final String me;

  /// Mine and my partner's counted spends in the range.
  final List<HomeSpend> spends;

  /// The part of [spends] both phones have: what the budget is measured on.
  final int sharedTotal;
  final int? budget;

  /// Family budget per main category name.
  final Map<String, int> splits;
  final List<CatSlice> main, subs;
  final bool showMyBalance;
  final List<PartnerBalance> partnerBalances;
  const HomeSummary({
    required this.me,
    required this.spends,
    required this.sharedTotal,
    required this.budget,
    this.splits = const {},
    required this.main,
    required this.subs,
    required this.showMyBalance,
    required this.partnerBalances,
  });

  int get total => spends.fold(0, (s, e) => s + e.amount);
}

/// Whether every other member has switched balance sharing on.
bool _allShareBalance(Map<String, Entry> entries, String me) {
  final others = [
    for (final e in entries.values)
      if (e.data['kind'] == 'member' && e.id != 'member:$me')
        e.id.substring('member:'.length),
  ];
  return others.isNotEmpty &&
      others.every((m) => entries['balance:$m']?.data['on'] == true);
}

extension HomeRepo on Repo {
  /// This phone's member ID, or null when home sharing is off.
  Future<String?> homeMember() async {
    final raw = await getSetting('group') ?? '';
    return raw.isEmpty ? null : (jsonDecode(raw) as Map)['member'] as String;
  }

  /// While sharing, "Don't count this" entries stay out of the totals.
  Future<String> countedOnly([String t = 't']) async =>
      await homeMember() == null ? '' : 'AND COALESCE($t.uncounted, 0) = 0';

  /// The first date whose spends the partner may see.
  Future<String> shareFrom() async =>
      await getSetting('shareFrom') ?? Dates.str(today);

  Future<void> chooseSharing({required bool earlierToo}) =>
      setSetting('shareFrom', earlierToo ? '0000-00-00' : Dates.str(today));

  Future<bool> get showsMyBalance async =>
      await getSetting('shareBalance') == '1';

  Future<void> showMyBalance(bool on) =>
      setSetting('shareBalance', on ? '1' : '0');

  Future<void> setUncounted(String txnId, bool value) =>
      (db.update(db.transactions)..where((t) => t.id.equals(txnId))).write(
        TransactionsCompanion(
          uncounted: Value(value),
          hlc: Value(clock.next()),
        ),
      );

  /// A loan's payments, past and future.
  Future<void> setLoanUncounted(String debtId, bool value) =>
      db.transaction(() async {
        await (db.update(db.debts)..where((d) => d.id.equals(debtId))).write(
          DebtsCompanion(uncounted: Value(value), hlc: Value(clock.next())),
        );
        await reconcileDebt(debtId);
      });

  Future<void> setInvestmentUncounted(String id, bool value) => db.transaction(
    () async {
      await (db.update(db.investments)..where((i) => i.id.equals(id))).write(
        InvestmentsCompanion(uncounted: Value(value), hlc: Value(clock.next())),
      );
      await reconcileInvestment(id);
    },
  );

  /// My counted spends in [from]..[to] (YYYY-MM-DD), keyed by transaction ID.
  Future<Map<String, HomeSpend>> _mySpends(
    String me, [
    String from = '0000-00-00',
    String to = '9999-12-31',
  ]) async {
    final rows = await db
        .customSelect(
          '''SELECT t.id, t.amount_minor AS a, t.date AS d, t.note AS n,
                    COALESCE(p.name, c.name, CASE t.source
                      WHEN 'invest' THEN 'Chit and investments'
                      WHEN 'emi' THEN 'Loan EMI' END) AS main,
                    CASE WHEN p.id IS NULL THEN NULL ELSE c.name END AS sub
             FROM transactions t
             LEFT JOIN categories c ON c.id = t.category_id
             LEFT JOIN categories p ON p.id = c.parent_id
             WHERE $_spend AND t.date BETWEEN ? AND ?''',
          variables: [Variable(from), Variable(to)],
          readsFrom: {db.transactions, db.categories, db.investments},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): HomeSpend(
          me,
          r.read<int>('a'),
          r.read<String>('d'),
          r.read<String>('n'),
          r.read<String?>('main') ?? 'No category',
          r.read<String?>('sub'),
        ),
    };
  }

  Future<Map<String, Entry>> _groupEntries() async => entriesOf([
    for (final n in await db.select(db.groupNotes).get()) Note.decode(n.body),
  ]);

  /// Null when home sharing is off.
  Future<HomeSummary?> homeSummary(DateRange range) async {
    final me = await homeMember();
    if (me == null) return null;
    final entries = await _groupEntries();
    final mine = (await _mySpends(me, range.startStr, range.endStr)).values;
    final theirs = [
      for (final e in entries.values)
        if (e.data['kind'] == 'expense' &&
            e.data['paidBy'] != me &&
            (e.data['date'] as String).compareTo(range.startStr) >= 0 &&
            (e.data['date'] as String).compareTo(range.endStr) <= 0)
          HomeSpend(
            e.data['paidBy'] as String,
            e.data['amountMinor'] as int,
            e.data['date'] as String,
            e.data['note'] as String? ?? '',
            e.data['cat'] as String? ?? 'No category',
            e.data['sub'] as String?,
          ),
    ];
    final spends = [...mine, ...theirs];
    final from = await shareFrom();
    final shared =
        theirs.fold<int>(0, (s, e) => s + e.amount) +
        mine
            .where((e) => e.date.compareTo(from) >= 0)
            .fold<int>(0, (s, e) => s + e.amount);

    // Slices use my category of the same name for its colour, when I have it.
    final cats = await categories(kind: 'debit');
    List<CatSlice> slices(bool bySub) {
      final totals = <(String, String?), int>{};
      for (final e in spends) {
        final key = bySub && e.sub != null
            ? (e.sub!, e.category)
            : (e.category, null);
        totals[key] = (totals[key] ?? 0) + e.amount;
      }
      return [
        for (final t in totals.entries)
          () {
            final c = cats.where((c) => c.name == t.key.$1).firstOrNull;
            return CatSlice(
              c?.id ?? 'home_${t.key.$1}',
              t.key.$1,
              c?.colorValue ?? 0xFF64748B,
              t.value,
              parentName: t.key.$2,
            );
          }(),
      ]..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    }

    final share = await showsMyBalance;
    return HomeSummary(
      me: me,
      spends: spends,
      sharedTotal: shared,
      budget: entries['budget']?.data['limitMinor'] as int?,
      splits:
          (entries['budget']?.data['splits'] as Map?)?.cast<String, int>() ??
          const {},
      main: slices(false),
      subs: slices(true),
      showMyBalance: share,
      partnerBalances: [
        if (share && _allShareBalance(entries, me))
          for (final e in entries.values)
            if (e.data['kind'] == 'balance' &&
                e.id != 'balance:$me' &&
                e.data['balanceMinor'] != null)
              PartnerBalance(
                entries['member:${e.id.substring('balance:'.length)}']
                            ?.data['name']
                        as String? ??
                    '',
                e.data['balanceMinor'] as int,
                DateTime.fromMillisecondsSinceEpoch(e.data['at'] as int),
              ),
      ],
    );
  }

  /// Brings the shared notes in line with this phone: my counted spends, and
  /// my balance once everyone has agreed to share theirs.
  Future<void> publishHome(Replica group) async {
    final me = group.disk.member;
    final spends = await _mySpends(me, await shareFrom());
    final shared = {
      for (final e in group.entries.values)
        if (e.data['paidBy'] == me && e.data['txn'] != null)
          e.data['txn'] as String: e,
    };
    for (final s in spends.entries) {
      final row = <String, Object?>{
        'kind': 'expense',
        'txn': s.key,
        'paidBy': me,
        'amountMinor': s.value.amount,
        'date': s.value.date,
        'note': s.value.note,
        'cat': s.value.category,
        'sub': s.value.sub,
        'shares': {me: s.value.amount},
      };
      final old = shared[s.key];
      if (old == null) {
        group.add([row]);
      } else if ([
        'amountMinor',
        'date',
        'note',
        'cat',
        'sub',
      ].any((k) => old.data[k] != row[k])) {
        group.edit(old.id, row);
      }
    }
    for (final e in shared.entries) {
      if (!spends.containsKey(e.key)) group.delete(e.value.id);
    }

    // The amount leaves this phone only when both sides have said yes.
    final want = await showsMyBalance;
    final old = group.entries['balance:$me']?.data;
    if (!want && old == null) return;
    final amount = want && _allShareBalance(group.entries, me)
        ? await totalBalance()
        : null;
    if (old?['on'] == want && old?['balanceMinor'] == amount) return;
    group.put('balance:$me', {
      'kind': 'balance',
      'on': want,
      'balanceMinor': amount,
      'at': now().millisecondsSinceEpoch,
    });
  }
}
