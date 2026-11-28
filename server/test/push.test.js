import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import test from 'node:test';

import { call, env, nudges, session } from './harness.js';

const send = (who, path, body) => call(`/group/${path}`, {
  method: 'POST', headers: { 'x-session': who }, body: JSON.stringify(body),
});

test('a new note nudges only the other phone, without its content', async () => {
  const a = await session('1', 'in_alice001');
  const b = await session('2', 'in_bob00001');
  const ma = { group: 'group-push01', member: 'malice01' };
  const mb = { group: 'group-push01', member: 'mbob0001' };
  await send(a, 'create', { ...ma, join: 't' });
  await send(b, 'join', { ...mb, join: 't' });
  assert.equal((await send(a, 'push', { ...ma, token: 'alice-phone' })).status, 200);
  assert.equal((await send(b, 'push', { ...mb, token: 'bob-phone' })).status, 200);
  assert.equal((await send(b, 'push', mb)).status, 400);

  // without the secret nothing is sent
  await send(a, 'upload', { ...ma, id: 'malice01.0:1', sealed: 'S' });
  await send(a, 'done', ma);
  assert.equal(nudges.length, 0);
  const news = async (who, m) => (await (await call(
    `/group/news?group=${m.group}&member=${m.member}`,
    { headers: { 'x-session': who } })).json()).news;
  assert.equal(await news(b, mb), true);
  assert.equal(await news(a, ma), false);

  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  env.FCM_SERVICE_ACCOUNT = JSON.stringify({
    project_id: 'p', client_email: 'x@p.example', token_uri: 'https://token.example',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  });
  await send(a, 'upload', { ...ma, id: 'malice01.0:2', sealed: 'LOCKED-TEXT' });
  await send(a, 'upload', { ...ma, id: 'malice01.0:3', sealed: 'S' });
  assert.equal(nudges.length, 0); // nothing until the sender has finished
  await send(a, 'done', ma);
  await send(a, 'done', ma); // a later change is never dropped
  assert.deepEqual(nudges.map((n) => n.token), ['bob-phone', 'bob-phone']);
  assert.doesNotMatch(JSON.stringify(nudges), /LOCKED-TEXT|malice|group-push/);
  delete env.FCM_SERVICE_ACCOUNT;
});
