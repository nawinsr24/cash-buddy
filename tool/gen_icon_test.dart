import 'dart:io';
import 'dart:ui' as ui;

import 'package:cash_buddy/ui/brand.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> render(String path, bool bg, double symbolScale) async {
  const n = 1024.0;
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  if (bg) {
    const CashMarkPainter().paint(canvas, const ui.Size(n, n));
  } else {
    // adaptive foreground: symbol only, shrunk into the safe zone
    canvas.translate(n * (1 - symbolScale) / 2, n * (1 - symbolScale) / 2);
    canvas.scale(symbolScale);
    const CashMarkPainter(background: false).paint(canvas, const ui.Size(n, n));
  }
  final img = await rec.endRecording().toImage(1024, 1024);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('generate icons', () async {
    await render('assets/icon/icon.png', true, 1);
    await render('assets/icon/foreground.png', false, 0.62);
  });
}
