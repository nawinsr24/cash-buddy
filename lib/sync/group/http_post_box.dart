/// The post box on the server. Notes are locked here, before they leave the
/// phone, with a key only the group's phones have.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'replica.dart';

class GroupServerException implements Exception {
  final int status;
  GroupServerException(this.status);
  @override
  String toString() => 'Group server said $status';
}

/// Sends one request and returns (status, body).
typedef Send = Future<(int, String)> Function(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
);

Future<(int, String)> sendHttp(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
) async {
  final request = http.Request(method, url)..headers.addAll(headers);
  if (body != null) request.body = body;
  final r = await http.Response.fromStream(
    await request.send().timeout(const Duration(seconds: 20)),
  );
  return (r.statusCode, r.body);
}

class HttpPostBox implements PostBox {
  final Uri server;
  final String groupId, memberId, session;
  final List<int> key;
  final Send send;
  final _aes = AesGcm.with256bits();

  HttpPostBox({
    required this.server,
    required this.groupId,
    required this.memberId,
    required this.session,
    required this.key,
    this.send = sendHttp,
  });

  Future<String> lock(String note) async {
    final box = await _aes.encrypt(
      utf8.encode(note),
      secretKey: SecretKey(key),
    );
    return base64Encode(box.concatenation());
  }

  Future<String> unlock(String sealed) async => utf8.decode(
    await _aes.decrypt(
      SecretBox.fromConcatenation(
        base64Decode(sealed),
        nonceLength: _aes.nonceLength,
        macLength: 16,
      ),
      secretKey: SecretKey(key),
    ),
  );

  Future<dynamic> call(String path, {Map<String, Object?>? body}) async {
    final base = server.resolve('group/$path');
    final who = {'group': groupId, 'member': memberId};
    final headers = {
      'content-type': 'application/json',
      'x-session': base64Encode(utf8.encode(session)),
    };
    final (status, reply) = body == null
        ? await send('GET', base.replace(queryParameters: who), headers, null)
        : await send('POST', base, headers, jsonEncode({...who, ...body}));
    if (status != 200) throw GroupServerException(status);
    return jsonDecode(reply);
  }

  @override
  Future<void> upload(String member, String noteId, String sealed) async =>
      call('upload', body: {'id': noteId, 'sealed': await lock(sealed)});

  @override
  Future<List<String>> fetch(String member) async {
    final out = <String>[];
    for (final s in await call('fetch') as List) {
      try {
        out.add(await unlock(s as String));
      } on SecretBoxAuthenticationError {
        // not locked with our key: ignore
      }
    }
    return out;
  }

  @override
  Future<void> ack(String member, String noteId) async =>
      call('ack', body: {'id': noteId});

  @override
  Future<Map<String, int>> highest() async =>
      (await call('highest') as Map).cast<String, int>();

  @override
  Future<void> request(String member, Map<String, List<int>> missing) async =>
      call('request', body: {'missing': missing});

  @override
  Future<List<Map<String, List<int>>>> requests(String member) async => [
    for (final r in await call('requests') as List)
      {
        for (final e in (r as Map).entries)
          e.key as String: (e.value as List).cast<int>(),
      },
  ];
}
