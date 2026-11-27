/// How one expense is shared between me and others. Money is in minor units;
/// whatever does not divide evenly stays with me.
enum SplitBy { equal, percent, amount }

class Shares {
  final int mine;
  final List<int> others;
  const Shares(this.mine, this.others);
}

/// [values] holds one number per other person: hundredths of a percent for
/// [SplitBy.percent], minor units for [SplitBy.amount], ignored for equal.
/// Null when it cannot be split: everyone, me included, must owe something.
Shares? splitShares(int total, SplitBy by, int people, List<int?> values) {
  if (total <= 0 || people <= 0) return null;
  final others = <int>[];
  for (var i = 0; i < people; i++) {
    final v = by == SplitBy.equal ? 0 : (i < values.length ? values[i] : null);
    if (v == null) return null;
    others.add(switch (by) {
      SplitBy.equal => total ~/ (people + 1),
      SplitBy.percent => total * v ~/ 10000,
      SplitBy.amount => v,
    });
  }
  final mine = total - others.fold<int>(0, (a, b) => a + b);
  if (mine <= 0 || others.any((o) => o <= 0)) return null;
  return Shares(mine, others);
}
