import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db.dart';
import 'data/repo.dart';
import 'domain/hlc.dart';
import 'platform/notifications.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.file();
  // Device id: stable per install, used to break HLC ties.
  final bootstrap = Repo(db, Hlc('boot'));
  var device = await bootstrap.getSetting('deviceId');
  if (device == null) {
    device = Repo.newId('d').substring(0, 9);
    await bootstrap.setSetting('deviceId', device);
  }
  final repo = Repo(
    db,
    Hlc(device, now: () => max(DateTime.now().millisecondsSinceEpoch, 0)),
  );
  // Keep new local writes ahead of everything already stored.
  for (final h
      in await db
          .customSelect('SELECT MAX(hlc) AS h FROM transactions')
          .get()) {
    final v = h.read<String?>('h');
    if (v != null) repo.clock.observe(v);
  }
  await Notifications.instance.init();
  runApp(
    ProviderScope(
      overrides: [repoProvider.overrideWithValue(repo)],
      child: const CashBuddyApp(),
    ),
  );
}
