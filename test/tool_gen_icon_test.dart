// Generates the launcher icon PNGs (run: flutter test test/tool_gen_icon_test.dart).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(String path, void Function(Canvas, double) paint) async {
  const size = 1024.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  paint(c, size);
  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void _wallet(Canvas c, double s, {required double scale}) {
  final cx = s / 2, cy = s / 2;
  final w = s * 0.56 * scale, h = s * 0.42 * scale;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy + h * 0.06), width: w, height: h),
    Radius.circular(h * 0.2),
  );
  final flap = RRect.fromRectAndCorners(
    Rect.fromLTWH(body.left, body.top - h * 0.12, w, h * 0.34),
    topLeft: Radius.circular(h * 0.2),
    topRight: Radius.circular(h * 0.2),
  );
  c.drawRRect(body, Paint()..color = Colors.white);
  c.drawRRect(flap, Paint()..color = const Color(0xFFCFE0FF));
  c.drawCircle(
    Offset(body.right - w * 0.17, body.center.dy + h * 0.1),
    h * 0.1,
    Paint()..color = const Color(0xFF2F6BFF),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        body.left + w * 0.12,
        body.top + h * 0.5,
        w * 0.34,
        h * 0.07,
      ),
      const Radius.circular(8),
    ),
    Paint()..color = const Color(0xFFCFE0FF),
  );
}

void main() {
  testWidgets('generate icons', (tester) async {
    await tester.runAsync(() async {
      // full icon (iOS / legacy): blue square + wallet
      await _write('assets/icon/icon.png', (c, s) {
        c.drawRect(
          Rect.fromLTWH(0, 0, s, s),
          Paint()..color = const Color(0xFF2F6BFF),
        );
        _wallet(c, s, scale: 1.0);
      });
      // adaptive foreground: transparent, wallet inside the 66% safe zone
      await _write(
        'assets/icon/foreground.png',
        (c, s) => _wallet(c, s, scale: 0.8),
      );
    });
  });
}
