import 'dart:math';

import 'package:cash_buddy/sync/group/replica.dart';

class Offline implements Exception {}

class _Parcel {
  final String sealed;
  final Set<String> waitingFor = {};
  int expiresOn = 0;
  _Parcel(this.sealed);
}

/// A post box that loses requests and replies, repeats and reorders notes,
/// goes down, and throws notes away after [keepDays].
class FakePostBox implements PostBox {
  static const keepDays = 90;
  final List<String> members;
  final Random random;
  final Map<String, _Parcel> _parcels = {};
  final Map<String, int> _highest = {};
  final Map<String, Map<String, List<int>>> _requests = {};

  /// Every note the box ever accepted, and those it dropped undelivered.
  final Set<String> accepted = {};
  final Set<String> expired = {};
  int day = 0;
  bool down = false;
  double faultRate = 0;

  FakePostBox(this.members, this.random);

  bool get _unlucky => random.nextDouble() < faultRate;

  void _network() {
    if (down || _unlucky) throw Offline();
  }

  void pass(int days) {
    day += days;
    _parcels.removeWhere((id, p) {
      if (p.expiresOn > day) return false;
      expired.add(id);
      return true;
    });
  }

  @override
  Future<void> upload(String member, String noteId, String sealed) async {
    _network();
    final p = _parcels[noteId] ??= _Parcel(sealed);
    p.waitingFor.addAll(members.where((m) => m != member));
    p.expiresOn = day + keepDays;
    accepted.add(noteId);
    final cut = noteId.lastIndexOf(':');
    final writer = noteId.substring(0, cut);
    _highest[writer] = max(
      _highest[writer] ?? 0,
      int.parse(noteId.substring(cut + 1)),
    );
    _network(); // stored, but the reply is lost
  }

  @override
  Future<List<String>> fetch(String member) async {
    _network();
    final out = [
      for (final p in _parcels.values)
        if (p.waitingFor.contains(member) && !_unlucky) p.sealed,
    ];
    if (faultRate > 0 && out.isNotEmpty) {
      out.add(out[random.nextInt(out.length)]); // delivered twice
      out.shuffle(random);
    }
    return out;
  }

  @override
  Future<void> ack(String member, String noteId) async {
    _network();
    final p = _parcels[noteId];
    p?.waitingFor.remove(member);
    if (p != null && p.waitingFor.isEmpty) _parcels.remove(noteId);
  }

  @override
  Future<Map<String, int>> highest() async {
    _network();
    return Map.of(_highest);
  }

  @override
  Future<void> request(String member, Map<String, List<int>> missing) async {
    _network();
    _requests[member] = missing;
  }

  @override
  Future<List<Map<String, List<int>>>> requests(String member) async {
    _network();
    return [
      for (final r in _requests.entries)
        if (r.key != member) r.value,
    ];
  }
}
