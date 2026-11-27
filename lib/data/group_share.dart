/// My part of the shared group's spending, for my personal budget.
library;

import 'dart:convert';

import '../sync/group/note.dart';
import 'repo.dart';

extension GroupShareRepo on Repo {
  /// Date (YYYY-MM-DD) -> my share, for group expenses dated from [from] to
  /// [to]. Empty when this phone is in no group.
  Future<Map<String, int>> myGroupShare(String from, String to) async {
    final raw = await getSetting('group') ?? '';
    if (raw.isEmpty) return const {};
    final me = (jsonDecode(raw) as Map)['member'] as String;
    final rows = await db.select(db.groupNotes).get();
    final out = <String, int>{};
    for (final e in entriesOf([
      for (final r in rows) Note.decode(r.body),
    ]).values) {
      if (e.data['kind'] != 'expense') continue;
      final date = e.data['date'] as String;
      if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
      final mine = (e.data['shares'] as Map)[me] as int? ?? 0;
      if (mine > 0) out[date] = (out[date] ?? 0) + mine;
    }
    return out;
  }
}
