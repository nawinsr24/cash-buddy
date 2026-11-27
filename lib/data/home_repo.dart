/// Mine and Home. A spend I mark Home leaves my balance like any other, but
/// counts in the home budget instead of mine, and my partner sees it.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../sync/group/note.dart';
import '../sync/group/replica.dart';
import 'db.dart';
import 'invest_repo.dart';
import 'repo.dart';

const _spend =
    "t.type='debit' AND t.source NOT IN ('debt','invest') AND t.deleted_at IS NULL";

/// What counts as home spending: anything I marked, including chit fund
/// instalments, but not money that was only lent.
const _homeSpend =
    "t.type='debit' AND t.source <> 'debt' AND t.deleted_at IS NULL AND t.home = 1";

/// One home spend, mine or my partner's.
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

class HomeSummary {
  final String me;

  /// My own spending and what I put into the home.
  final int mine, iPaidHome;
  final List<HomeSpend> home;
  final Map<String, String> names;
  final int? homeBudget;
  final List<CatSlice> main, subs;
  const HomeSummary({
    required this.me,
    required this.mine,
    required this.iPaidHome,
    required this.home,
    required this.names,
    required this.homeBudget,
    required this.main,
    required this.subs,
  });

  int get homeTotal => home.fold(0, (s, e) => s + e.amount);
  int get iPaidInTotal => mine + iPaidHome;

  /// Member -> what they paid for the home.
  Map<String, int> get byPerson {
    final out = <String, int>{me: 0};
    for (final e in home) {
      out[e.paidBy] = (out[e.paidBy] ?? 0) + e.amount;
    }
    return out;
  }
}

extension HomeRepo on Repo {
  /// This phone's member ID in the home, or null when home sharing is off.
  Future<String?> homeMember() async {
    final raw = await getSetting('group') ?? '';
    return raw.isEmpty ? null : (jsonDecode(raw) as Map)['member'] as String;
  }

  /// Leaves Home spends out of "my" figures, only while home sharing is on.
  Future<String> mineOnly([String t = 't']) async =>
      await homeMember() == null ? '' : 'AND COALESCE($t.home, 0) = 0';

  Future<void> setHome(String txnId, bool home) =>
      (db.update(db.transactions)..where((t) => t.id.equals(txnId))).write(
        TransactionsCompanion(home: Value(home), hlc: Value(clock.next())),
      );

  /// A loan's payments, past and future, count as Mine or Home.
  Future<void> setLoanHome(String debtId, bool home) =>
      db.transaction(() async {
        await (db.update(db.debts)..where((d) => d.id.equals(debtId))).write(
          DebtsCompanion(home: Value(home), hlc: Value(clock.next())),
        );
        await reconcileDebt(debtId);
      });

  Future<void> setInvestmentHome(String id, bool home) =>
      db.transaction(() async {
        await (db.update(db.investments)..where((i) => i.id.equals(id))).write(
          InvestmentsCompanion(home: Value(home), hlc: Value(clock.next())),
        );
        await reconcileInvestment(id);
      });

  /// Categories last saved as Home, to preselect the button next time.
  Future<Set<String>> homeCategories() async => {
    ...(jsonDecode(await getSetting('homeCategories') ?? '[]') as List)
        .cast<String>(),
  };

  Future<void> rememberHomeCategory(String? categoryId, bool home) async {
    final set = await homeCategories();
    final key = categoryId ?? '';
    home ? set.add(key) : set.remove(key);
    await setSetting('homeCategories', jsonEncode(set.toList()));
  }

  /// My own Home spends in [from]..[to] (YYYY-MM-DD), keyed by transaction ID.
  Future<Map<String, HomeSpend>> _myHomeSpends(
    String me, [
    String from = '0000-01-01',
    String to = '9999-12-31',
  ]) async {
    final rows = await db
        .customSelect(
          '''SELECT t.id, t.amount_minor AS a, t.date AS d, t.note AS n,
                    COALESCE(p.name, c.name, CASE t.source WHEN 'invest' THEN 'Chit and investments' WHEN 'emi' THEN 'Loan EMI' END) AS main,
                    CASE WHEN p.id IS NULL THEN NULL ELSE c.name END AS sub
             FROM transactions t
             LEFT JOIN categories c ON c.id = t.category_id
             LEFT JOIN categories p ON p.id = c.parent_id
             WHERE $_homeSpend AND t.date BETWEEN ? AND ?''',
          variables: [Variable(from), Variable(to)],
          readsFrom: {db.transactions, db.categories},
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

  /// Null when home sharing is off.
  Future<HomeSummary?> homeSummary(DateRange range) async {
    final me = await homeMember();
    if (me == null) return null;
    final notes = await db.select(db.groupNotes).get();
    final entries = entriesOf([for (final n in notes) Note.decode(n.body)]);
    final names = <String, String>{
      for (final e in entries.values)
        if (e.data['kind'] == 'member')
          e.id.substring('member:'.length): e.data['name'] as String,
    };
    final home = <HomeSpend>[
      ...(await _myHomeSpends(me, range.startStr, range.endStr)).values,
      // my partner's, as their phone sent them
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
    final mine = await db
        .customSelect(
          'SELECT COALESCE(SUM(t.amount_minor),0) AS s FROM transactions t '
          'WHERE $_spend AND COALESCE(t.home,0) = 0 AND t.date BETWEEN ? AND ?',
          variables: [Variable(range.startStr), Variable(range.endStr)],
          readsFrom: {db.transactions},
        )
        .getSingle();

    // Slices use my category of the same name for its colour, when I have it.
    final cats = await categories(kind: 'debit');
    List<CatSlice> slices(bool bySub) {
      final totals = <(String, String?), int>{};
      for (final e in home) {
        final key = bySub && e.sub != null
            ? (e.sub!, e.category)
            : (e.category, null);
        totals[key] = (totals[key] ?? 0) + e.amount;
      }
      final out = [
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
      return out;
    }

    return HomeSummary(
      me: me,
      mine: mine.read<int>('s'),
      iPaidHome: home
          .where((e) => e.paidBy == me)
          .fold(0, (s, e) => s + e.amount),
      home: home,
      names: names,
      homeBudget: entries['budget']?.data['limitMinor'] as int?,
      main: slices(false),
      subs: slices(true),
    );
  }

  /// Brings the shared notes in line with my Home spends: adds new ones, edits
  /// changed ones and removes those deleted or moved back to Mine.
  Future<void> publishHome(Replica group) async {
    final me = group.disk.member;
    final spends = await _myHomeSpends(me);
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
  }
}
