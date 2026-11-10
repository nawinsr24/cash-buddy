import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../data/db_key.dart';

class VaultException implements Exception {
  final String message;
  VaultException(this.message);
  @override
  String toString() => message;
}

/// Encrypts everything that leaves the phone (Drive sync segments and backup
/// files) with AES-256-GCM. The key comes from a passphrase only the user
/// knows (PBKDF2-HMAC-SHA256), so nobody else can read the files, and if the
/// passphrase is forgotten the files cannot be recovered.
///
/// File layout: "CBE1" | salt (16) | nonce (12) | ciphertext | tag (16).
/// Each file carries its own salt, so devices can read each other's files.
class Vault {
  static const _magic = [0x43, 0x42, 0x45, 0x31];
  static const _passKey = 'sync_passphrase';
  static const _saltKey = 'sync_salt';

  final SecretStore store;
  final int iterations;
  Vault(this.store, {this.iterations = 150000});

  final _aes = AesGcm.with256bits();
  final Map<String, SecretKey> _cache = {};

  /// True when [bytes] is one of our encrypted files.
  static bool isEncrypted(List<int> bytes) =>
      bytes.length > 4 + 16 + 12 + 16 &&
      bytes[0] == _magic[0] &&
      bytes[1] == _magic[1] &&
      bytes[2] == _magic[2] &&
      bytes[3] == _magic[3];

  Future<bool> get isSet async => (await store.read(_passKey)) != null;

  Future<void> setPassphrase(String pass) async {
    if (pass.length < 8) {
      throw VaultException('Use at least 8 characters.');
    }
    await store.write(_passKey, pass);
    _cache.clear();
  }

  Future<void> clear() async {
    await store.delete(_passKey);
    await store.delete(_saltKey);
    _cache.clear();
  }

  Future<List<int>> _salt() async {
    var s = await store.read(_saltKey);
    if (s == null) {
      s = randomHex(16);
      await store.write(_saltKey, s);
    }
    return _unhex(s);
  }

  static List<int> _unhex(String h) => [
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ];

  Future<SecretKey> _key(List<int> salt) async {
    final pass = await store.read(_passKey);
    if (pass == null) throw VaultException('Set a backup password first.');
    final id = base64.encode(salt);
    final hit = _cache[id];
    if (hit != null) return hit;
    final k = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pass, nonce: salt);
    return _cache[id] = k;
  }

  Future<Uint8List> encrypt(List<int> plain) async {
    final salt = await _salt();
    final box = await _aes.encrypt(plain, secretKey: await _key(salt));
    return Uint8List.fromList([
      ..._magic,
      ...salt,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> decrypt(List<int> data) async {
    if (!isEncrypted(data)) throw VaultException('Not an encrypted file.');
    final salt = data.sublist(4, 20);
    final nonce = data.sublist(20, 32);
    final cipher = data.sublist(32, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: await _key(salt),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw VaultException(
        'Wrong backup password, or the file was changed. Check your backup password.',
      );
    }
  }
}
