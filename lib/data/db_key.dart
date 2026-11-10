import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the secret keys live: Android Keystore / iOS Keychain, never in the
/// app's normal files and never in backups.
abstract class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore();
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions());
  @override
  Future<String?> read(String name) => _s.read(key: name);
  @override
  Future<void> write(String name, String value) =>
      _s.write(key: name, value: value);
  @override
  Future<void> delete(String name) => _s.delete(key: name);
}

/// In-memory store for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> m = {};
  @override
  Future<String?> read(String name) async => m[name];
  @override
  Future<void> write(String name, String value) async => m[name] = value;
  @override
  Future<void> delete(String name) async => m.remove(name);
}

String randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(
    bytes,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// The database key: made once on first launch and kept in the secret store.
Future<String> databaseKey(SecretStore store) async {
  var k = await store.read('db_key');
  if (k == null || k.length != 64) {
    k = randomHex(32);
    await store.write('db_key', k);
  }
  return k;
}
