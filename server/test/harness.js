// The whole server in Node, with a real SQLite database and a stand-in for
// Google's signing keys.
import { generateKeyPairSync, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

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
export const env = {
  count: (table) => db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get().n,
  expireInvites: () => db.exec('UPDATE groups SET join_until = 0'),
  DB,
  ADMIN_TOKEN: 'test-token',
  GOOGLE_CLIENT_ID: 'app-id',
  SIGNING_KEY: signing.export({ type: 'pkcs8', format: 'der' }).toString('base64'),
};

const rsa = () => generateKeyPairSync('rsa', { modulusLength: 2048 });
const google = rsa();
export const stranger = rsa();
/** Nudges the stand-in Firebase received. */
export const nudges = [];
globalThis.fetch = async (url, init) => String(url).includes('fcm.googleapis')
  ? (nudges.push(JSON.parse(init.body).message), Response.json({}))
  : Response.json({
  access_token: 'fcm-access',
  keys: [{ ...google.publicKey.export({ format: 'jwk' }), kid: 'k1', alg: 'RS256' }],
});

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
export async function token(claims = {}, key = google.privateKey) {
  const head = b64({ alg: 'RS256', kid: 'k1' });
  const body = b64({
    iss: 'https://accounts.google.com', aud: 'app-id', sub: '42',
    email: 'a@example.com', email_verified: true,
    exp: Math.floor(Date.now() / 1000) + 600, ...claims,
  });
  const sig = sign('sha256', Buffer.from(`${head}.${body}`), key).toString('base64url');
  return `${head}.${body}.${sig}`;
}

export const call = (path, init) => server.fetch(new Request(`http://x${path}`, init), env);
export const signIn = async (device, idToken, consent = 1) => call('/signin', {
  method: 'POST', body: JSON.stringify({ device, idToken, consent }),
});

/** A signed-in session header for account [sub] on [device]. */
export async function session(sub, device) {
  const reply = await signIn(device, await token({ sub, email: `${sub}@example.com` }));
  return Buffer.from(JSON.stringify((await reply.json()).session)).toString('base64');
}
