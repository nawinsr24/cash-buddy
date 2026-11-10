import 'dart:io';

import 'package:cash_buddy/data/db_crypto.dart';
import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/data/db_open_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cbcrypto');
    path = '${dir.path}/t.sqlite';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void makePlain() {
    final d = sqlite3.open(path);
    d.execute('CREATE TABLE t(a TEXT)');
    d.execute("INSERT INTO t VALUES ('SECRET-SALARY-12345')");
    d.close();
  }

  test('plain file is readable, encrypting hides it and keeps the data', () {
    makePlain();
    expect(isPlainDatabase(path), isTrue);
    expect(
      String.fromCharCodes(File(path).readAsBytesSync()),
      contains('SECRET-SALARY-12345'),
    );
    expect(encryptInPlace(path, 'k' * 64), isTrue);
    expect(isPlainDatabase(path), isFalse);
    expect(File(path).readAsBytesSync().length, greaterThan(0));
    expect(
      String.fromCharCodes(File(path).readAsBytesSync())
          .contains('SECRET-SALARY'),
      isFalse,
    );
    final d = openWithKey(path, 'k' * 64);
    expect(d.select('SELECT a FROM t').first['a'], 'SECRET-SALARY-12345');
    d.close();
    expect(File('$path.plain.bak').existsSync(), isFalse);
  });

  test('wrong key cannot open the file', () {
    makePlain();
    encryptInPlace(path, 'k' * 64);
    expect(() => openWithKey(path, 'x' * 64), throwsA(anything));
  });

  test('prepareDatabase: new install gets a key and keeps it', () async {
    final store = MemorySecretStore();
    final k1 = await prepareDatabase(path, store);
    final k2 = await prepareDatabase(path, store);
    expect(k1, isNotNull);
    expect(k1, k2);
    expect(k1!.length, 64);
  });

  test('prepareDatabase: an old plain file is encrypted, data kept', () async {
    makePlain();
    final key = await prepareDatabase(path, MemorySecretStore());
    expect(key, isNotNull);
    expect(isPlainDatabase(path), isFalse);
    final d = openWithKey(path, key!);
    expect(d.select('SELECT a FROM t').length, 1);
    d.close();
  });

  test(
    'prepareDatabase: a file with a lost key is set aside, not deleted',
    () async {
      makePlain();
      encryptInPlace(path, 'z' * 64);
      final key = await prepareDatabase(path, MemorySecretStore());
      expect(key, isNotNull);
      expect(File(path).existsSync(), isFalse);
      expect(
        dir.listSync().any((e) => e.path.contains('.unreadable.')),
        isTrue,
      );
    },
  );
}
