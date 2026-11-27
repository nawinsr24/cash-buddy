import 'dart:convert';
import 'dart:typed_data';

import 'package:cash_buddy/data/budget_repo.dart';
import 'package:cash_buddy/data/invest_repo.dart';
import 'package:cash_buddy/data/loan_repo.dart';
import 'package:cash_buddy/sync/backup_data.dart';
import 'package:cash_buddy/sync/vault.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/helpers.dart';
import 'sync_test.dart' show dump;

Future<TestEnv> _filled() async {
  final e = await newEnv(opening: 10000000);
  final r = e.repo;
  await r.addSplit(mine: 40000, others: [('Ravi', 60000)]);
  await r.addLoan(
    kind: 'car',
    lender: 'HDFC',
    owed: 5000000,
    annualMilli: 9000,
    months: 12,
    emiDay: 5,
  );
  await r.createInvestment(kind: 'stock', name: 'INFY');
  await r.setBudget(3000000);
  await r.setSetting('cardBudgetMode', 'swipe');
  return e;
}

Matcher get _refused => throwsA(isA<VaultException>());

void main() {
  test('everything comes back on a new phone', () async {
    final a = await _filled();
    final file = await buildBackup(a.repo);
    final b = await newEnv(device: 'devB', opening: 999);
    await b.repo.addTransaction(type: 'debit', amountMinor: 5);
    expect(await restoreBackup(b.repo, file), greaterThan(0));
    expect(await dump(b.repo), await dump(a.repo));
    expect(await b.repo.totalBalance(), await a.repo.totalBalance());
    expect((await b.repo.budgetStatus(2026, 11))!.budget, 3000000);
    expect(await b.repo.getSetting('cardBudgetMode'), 'swipe');
    expect((await b.repo.loanStatuses()).single.owed, 5000000);
  });

  test('a protected file needs the right password', () async {
    final a = await _filled();
    final vault = await testVault();
    final file = await buildBackup(a.repo, vault: vault);
    expect(Vault.isEncrypted(file), isTrue);
    final b = await newEnv(device: 'devB', opening: 77);
    final before = await dump(b.repo);
    await expectLater(restoreBackup(b.repo, file), _refused);
    await expectLater(
      restoreBackup(b.repo, file, passphrase: 'wrong one!', iterations: 1000),
      _refused,
    );
    expect(await dump(b.repo), before);
    await restoreBackup(
      b.repo,
      file,
      passphrase: 'test passphrase',
      iterations: 1000,
    );
    expect(await dump(b.repo), await dump(a.repo));
  });

  test('damaged, foreign and newer files change nothing', () async {
    final a = await _filled();
    final before = await dump(a.repo);
    Uint8List wrap(String payload, [String? sum]) => utf8.encode(
      jsonEncode({
        'sha256': sum ?? sha256.convert(utf8.encode(payload)).toString(),
        'payload': payload,
      }),
    );
    for (final bad in [
      utf8.encode('hello'),
      wrap('{"app":"cash-buddy","schema":1}', 'nope'),
      wrap('{"app":"other","schema":1}'),
      wrap('{"app":"cash-buddy","schema":99,"accounts":[]}'),
      wrap('{"app":"cash-buddy","schema":1,"accounts":[{"id":"x"}]}'),
    ]) {
      await expectLater(restoreBackup(a.repo, bad), throwsA(anything));
    }
    expect(await dump(a.repo), before);
  });

  test('an older backup leaves what it never contained', () async {
    final a = await _filled();
    final old = jsonDecode(
      (jsonDecode(utf8.decode(await buildBackup(a.repo))) as Map)['payload']
          as String,
    ) as Map<String, dynamic>;
    old['schema'] = 1;
    for (final k in [
      'investments',
      'investment_entries',
      'budget_items',
      'settings',
    ]) {
      old.remove(k);
    }
    final payload = jsonEncode(old);
    await restoreBackup(
      a.repo,
      utf8.encode(
        jsonEncode({
          'sha256': sha256.convert(utf8.encode(payload)).toString(),
          'payload': payload,
        }),
      ),
    );
    expect(await a.repo.db.select(a.repo.db.investments).get(), hasLength(1));
    expect((await a.repo.budgetStatus(2026, 11))!.budget, 3000000);
  });
}
