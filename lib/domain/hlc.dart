/// Hybrid logical clock producing lexicographically ordered strings:
/// `<15-digit ms>-<4-hex counter>-<deviceId>`. String comparison == causal
/// order (ties broken by deviceId), so last-writer-wins merges converge.
class Hlc {
  final String deviceId;
  final int Function() _now;
  int _ms = 0;
  int _counter = 0;

  Hlc(this.deviceId, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  String next() {
    final t = _now();
    if (t > _ms) {
      _ms = t;
      _counter = 0;
    } else {
      _counter++;
    }
    return _format();
  }

  /// Fold in a timestamp seen from another device so later local writes sort
  /// after everything already merged.
  void observe(String remote) {
    final p = remote.split('-');
    if (p.length < 3) return;
    final ms = int.tryParse(p[0]) ?? 0;
    final c = int.tryParse(p[1], radix: 16) ?? 0;
    if (ms > _ms || (ms == _ms && c > _counter)) {
      _ms = ms;
      _counter = c;
    }
  }

  String _format() =>
      '${_ms.toString().padLeft(15, '0')}-${_counter.toRadixString(16).padLeft(4, '0')}-$deviceId';
}
