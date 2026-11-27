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

  /// Uploads as an older version did: locked with the backup password.
  Future<void> uploadLocked(InMemoryRemote remote, Vault v) async {
    for (final name in remote.files.keys.toList()) {
      remote.files[name] = await v.encrypt(remote.files[name]!);
    }
  }

  test('new uploads need no password, even when one is stored', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final v = vault(MemorySecretStore());
    await v.setPassphrase('one passphrase');
    await a.repo.addTransaction(type: 'debit', amountMinor: 4200);
    expect(
      (await SyncEngine(a.repo, remote, 'devA', vault: v).sync()).ok,
      isTrue,
    );
    expect(remote.files.values.any(Vault.isEncrypted), isFalse);
  });

  test('data locked by an older version needs its password', () async {
    final remote = InMemoryRemote();
    final a = await dev('devA', remote);
    final b = await dev('devB', remote);
    await a.repo.addTransaction(type: 'debit', amountMinor: 4200);
    await syncAll([a]);
    final old = vault(MemorySecretStore());
    await old.setPassphrase('one passphrase');
    await uploadLocked(remote, old);

    final none = await SyncEngine(b.repo, remote, 'devB').sync();
    expect(none.ok, isFalse);
    expect(none.error, contains('password'));
    final wrong = vault(MemorySecretStore());
    await wrong.setPassphrase('some other one');
    expect(
      (await SyncEngine(b.repo, remote, 'devB', vault: wrong).sync()).ok,
      isFalse,
    );
    final right = await SyncEngine(b.repo, remote, 'devB', vault: old).sync();
    expect(right.ok, isTrue, reason: right.error);
    expect(await dump(b.repo), await dump(a.repo));
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
