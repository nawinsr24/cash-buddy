import 'dart:convert';

import 'package:cash_buddy/data/db_key.dart';
import 'package:cash_buddy/sync/sync_engine.dart';
import 'package:cash_buddy/sync/vault.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show dev, dump, syncAll;

Vault vault(MemorySecretStore s) => Vault(s, iterations: 1000);

void main() {
  test(
    'encrypts and decrypts, and the secret never shows in the bytes',
    () async {
      final v = vault(MemorySecretStore());
      await v.setPassphrase('correct horse');
      final enc = await v.encrypt(utf8.encode('SALARY 1,00,000'));
      expect(Vault.isEncrypted(enc), isTrue);
      expect(String.fromCharCodes(enc).contains('SALARY'), isFalse);
      expect(utf8.decode(await v.decrypt(enc)), 'SALARY 1,00,000');
    },
  );

  test('wrong passphrase and tampering are rejected', () async {
    final a = MemorySecretStore();
    final v = vault(a);
    await v.setPassphrase('correct horse');
    final enc = await v.encrypt(utf8.encode('hello world'));
    final b = MemorySecretStore();
    final other = vault(b);
    await other.setPassphrase('battery staple');
    expect(() => other.decrypt(enc), throwsA(isA<VaultException>()));
    final bad = List<int>.of(enc)..[40] ^= 1;
    expect(() => v.decrypt(bad), throwsA(isA<VaultException>()));
  });

  test('short passphrase is refused', () async {
    expect(
      () => vault(MemorySecretStore()).setPassphrase('short'),
      throwsA(isA<VaultException>()),
    );
  });

  test(
    'two devices with the same passphrase sync through encrypted files',
    () async {
      final remote = InMemoryRemote();
      final a = await dev('devA', remote);
      final b = await dev('devB', remote);
      final sa = MemorySecretStore(), sb = MemorySecretStore();
      final va = vault(sa)..setPassphrase('one passphrase');
      final vb = vault(sb)..setPassphrase('one passphrase');
      await Future<void>.delayed(Duration.zero);
      await a.repo.addTransaction(type: 'debit', amountMinor: 4200);
      final ea = SyncEngine(a.repo, remote, 'devA', vault: va);
      final eb = SyncEngine(b.repo, remote, 'devB', vault: vb);
      for (var i = 0; i < 3; i++) {
        expect((await ea.sync()).ok, isTrue);
        expect((await eb.sync()).ok, isTrue);
      }
      for (final bytes in remote.files.values) {
        expect(Vault.isEncrypted(bytes), isTrue);
      }
      expect(await dump(b.repo), await dump(a.repo));
    },
  );

  test('a device without the passphrase cannot read encrypted data', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    final va = vault(MemorySecretStore());
    await va.setPassphrase('one passphrase');
    await a.repo.addTransaction(type: 'debit', amountMinor: 4200);
    expect(
      (await SyncEngine(a.repo, remote, 'devA', vault: va).sync()).ok,
      isTrue,
    );
    final r = await SyncEngine(b.repo, remote, 'devB').sync();
    expect(r.ok, isFalse);
    expect(r.error, contains('password'));
    final wrong = vault(MemorySecretStore());
    await wrong.setPassphrase('some other one');
    final r2 = await SyncEngine(b.repo, remote, 'devB', vault: wrong).sync();
    expect(r2.ok, isFalse);
  });

  test('old unencrypted files are still read', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    await a.repo.addTransaction(type: 'debit', amountMinor: 999);
    await syncAll([a, b]);
    final vb = vault(MemorySecretStore());
    await vb.setPassphrase('one passphrase');
    final r = await SyncEngine(b.repo, remote, 'devB', vault: vb).sync();
    expect(r.ok, isTrue);
  });
}
