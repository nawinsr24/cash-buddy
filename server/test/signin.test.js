import assert from 'node:assert/strict';
import test from 'node:test';

import { call, signIn, stranger, token } from './harness.js';

const statusOf = async (device) => JSON.parse(
  (await (await call(`/status?device=${device}`)).json()).payload).status;
const admin = (action, query) => call(`/admin/${action}?${query}`, {
  method: 'POST', headers: { authorization: 'Bearer test-token' },
});

test('only a genuine token for this app signs in', async () => {
  for (const bad of [
    'nonsense',
    await token({}, stranger.privateKey),
    await token({ aud: 'another-app' }),
    await token({ exp: 1 }),
    await token({ iss: 'https://evil.example' }),
    await token({ email_verified: false }),
  ]) {
    assert.equal((await signIn('in_first01', bad)).status, 401);
  }
  assert.equal((await signIn('in_first01', await token(), 0)).status, 400);
  const ok = await signIn('in_first01', await token());
  assert.equal(ok.status, 200);
  assert.equal((await ok.json()).email, 'a@example.com');
});

test('blocking the account follows it to a reinstalled phone', async () => {
  assert.equal((await admin('block', 'email=a@example.com')).status, 200);
  assert.equal(await statusOf('in_first01'), 'blocked');
  // reinstall: a new install ID is free until it signs in again
  assert.equal(await statusOf('in_second1'), 'active');
  const again = await signIn('in_second1', await token());
  assert.equal(JSON.parse((await again.json()).payload).status, 'blocked');
  assert.equal((await admin('unblock', 'email=a@example.com')).status, 200);
  assert.equal(await statusOf('in_second1'), 'active');
});

test('admin needs the token', async () => {
  const no = await call('/admin/block?device=in_first01', { method: 'POST' });
  assert.equal(no.status, 401);
});
