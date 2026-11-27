// The whole server in Node, with a real SQLite database and a stand-in for
// Google's signing keys.
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import test from 'node:test';

import server from '../src/index.js';

const db = new DatabaseSync(':memory:');
db.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
const DB = {
  prepare(sql) {
    let args = [];
    const q = {
      bind: (...a) => ((args = a), q),
      first: async () => db.prepare(sql).get(...args) ?? null,
      all: async () => ({ results: db.prepare(sql).all(...args) }),
      run: async () => ({ meta: { changes: db.prepare(sql).run(...args).changes } }),
    };
    return q;
  },
};
const signing = generateKeyPairSync('ed25519').privateKey;
const env = {
  DB,
  ADMIN_TOKEN: 'test-token',
  GOOGLE_CLIENT_ID: 'app-id',
  SIGNING_KEY: signing.export({ type: 'pkcs8', format: 'der' }).toString('base64'),
};

const rsa = () => generateKeyPairSync('rsa', { modulusLength: 2048 });
const google = rsa();
const stranger = rsa();
globalThis.fetch = async () => Response.json({
  keys: [{ ...google.publicKey.export({ format: 'jwk' }), kid: 'k1', alg: 'RS256' }],
});

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
async function token(claims = {}, key = google.privateKey) {
  const head = b64({ alg: 'RS256', kid: 'k1' });
  const body = b64({
    iss: 'https://accounts.google.com', aud: 'app-id', sub: '42',
    email: 'a@example.com', email_verified: true,
    exp: Math.floor(Date.now() / 1000) + 600, ...claims,
  });
  const { sign } = await import('node:crypto');
  const sig = sign('sha256', Buffer.from(`${head}.${body}`), key).toString('base64url');
  return `${head}.${body}.${sig}`;
}

const call = (path, init) => server.fetch(new Request(`http://x${path}`, init), env);
const signIn = async (device, idToken, consent = 1) => call('/signin', {
  method: 'POST', body: JSON.stringify({ device, idToken, consent }),
});
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
