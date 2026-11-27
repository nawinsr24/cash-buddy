import assert from 'node:assert/strict';
import test from 'node:test';

import { call, session, env } from './harness.js';

const send = (who, path, body) => call(`/group/${path}`, {
  method: 'POST', headers: { 'x-session': who }, body: JSON.stringify(body),
});
const read = async (who, path, member) => (await call(
  `/group/${path}?group=group-123456&member=${member}`,
  { headers: { 'x-session': who } })).json();

test('invite, deliver, delete; strangers stay out', async () => {
  const a = await session('1', 'in_alice001');
  const b = await session('2', 'in_bob00001');
  const c = await session('3', 'in_carol001');
  const g = { group: 'group-123456' };
  const ma = { ...g, member: 'malice01' };
  const mb = { ...g, member: 'mbob0001' };

  assert.equal((await send('junk', 'create', { ...ma, join: 't' })).status, 401);
  assert.equal((await send(a, 'create', { ...ma, join: 't' })).status, 200);
  assert.equal((await send(b, 'join', { ...mb, join: 'wrong' })).status, 403);
  assert.equal((await send(b, 'join', { ...mb, join: 't' })).status, 200);
  // knowing a member's ID is not enough to act as them
  assert.equal((await send(c, 'ack', { ...mb, id: 'x' })).status, 403);

  const id = 'malice01.0:1';
  assert.equal((await send(a, 'upload', { ...ma, id, sealed: 'LOCKED' })).status, 200);
  assert.deepEqual(await read(a, 'fetch', 'malice01'), []);
  assert.deepEqual(await read(b, 'fetch', 'mbob0001'), ['LOCKED']);
  assert.deepEqual(await read(b, 'highest', 'mbob0001'), { 'malice01.0': 1 });
  await send(b, 'ack', { ...mb, id });
  assert.deepEqual(await read(b, 'fetch', 'mbob0001'), []);
  assert.equal(env.count('notes'), 0);

  // an invitation lasts a day
  env.expireInvites();
  const mc = { ...g, member: 'mcarol01' };
  assert.equal((await send(c, 'join', { ...mc, join: 't' })).status, 410);
  assert.equal((await send(a, 'invite', { ...ma, join: 't' })).status, 200);
  assert.equal((await send(c, 'join', { ...mc, join: 't' })).status, 200);
});
