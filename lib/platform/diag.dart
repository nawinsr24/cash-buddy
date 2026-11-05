import 'package:flutter/foundation.dart';

/// A small in-memory event log (last ~200 events) so a problem on a real
/// phone can be diagnosed: app lifecycle, scans, native calls and how fast
/// the database is changing. Nothing is stored or sent anywhere.
class Diag {
  Diag._();
  static final instance = Diag._();
  final _lines = <String>[];
  final ValueNotifier<int> changed = ValueNotifier(0);

  void log(String event) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _lines.add(
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}  $event',
    );
    if (_lines.length > 200) _lines.removeAt(0);
    changed.value++;
  }

  List<String> get lines => List.unmodifiable(_lines);
  String dump() => _lines.join('\n');
  void clear() {
    _lines.clear();
    changed.value++;
  }
}
