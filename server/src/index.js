// Blocking server. The app asks "may I run?"; the answer is signed so that
// nobody else can block or unblock a phone. Signing in with Google links the
// phone to an account, so that a block survives reinstalling.
import { verifyGoogleToken } from './google.js';

/** Install IDs the app makes. Anything else is refused. */
const DEVICE = /^in_[A-Za-z0-9_-]{6,64}$/;
/** Stops a script from filling the free database. */
const NEW_DEVICES_PER_DAY = 500;
const DAY = 86400000;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

const bytes = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
const base64 = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)));

async function sign(env, claims) {
  const payload = JSON.stringify(claims);
  const key = await crypto.subtle.importKey(
    'pkcs8', bytes(env.SIGNING_KEY), { name: 'Ed25519' }, false, ['sign']);
  const signature = await crypto.subtle.sign(
    'Ed25519', key, new TextEncoder().encode(payload));
  return { payload, signature: base64(signature) };
}

const signed = async (env, device, blocked) => json(await sign(env, {
  device,
  status: blocked ? 'blocked' : 'active',
  issuedAt: Date.now(),
}));

/** Blocked if the phone or the account it belongs to is. */
async function isBlocked(env, device) {
  const row = await env.DB.prepare(
    'SELECT d.blocked OR COALESCE(a.blocked, 0) AS blocked FROM devices d ' +
    'LEFT JOIN accounts a ON a.id = d.account_id WHERE d.id = ?')
    .bind(device).first();
  return row?.blocked === 1;
}

/** Compares without leaking how much of the token matched. */
async function isAdmin(request, env) {
  const given = request.headers.get('authorization') ?? '';
  if (!env.ADMIN_TOKEN) return false;
  const digest = async (s) => new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));
  const [a, b] = await Promise.all(
    [digest(given), digest(`Bearer ${env.ADMIN_TOKEN}`)]);
  return a.reduce((diff, x, i) => diff | (x ^ b[i]), 0) === 0;
}

async function status(env, device) {
  const now = Date.now();
  const row = await env.DB.prepare(
    'SELECT last_seen FROM devices WHERE id = ?').bind(device).first();
  if (row) {
    // At most one write an hour per phone, to stay inside the free limits.
    if (now - row.last_seen > 3600000) {
      await env.DB.prepare('UPDATE devices SET last_seen = ? WHERE id = ?')
        .bind(now, device).run();
    }
    return signed(env, device, await isBlocked(env, device));
  }
  const today = await env.DB.prepare(
    'SELECT COUNT(*) AS n FROM devices WHERE first_seen > ?')
    .bind(now - DAY).first();
  // The app ignores errors, so a refused new phone simply carries on.
  if (today.n >= NEW_DEVICES_PER_DAY) return json({ error: 'busy' }, 429);
  await env.DB.prepare(
    'INSERT OR IGNORE INTO devices (id, first_seen, last_seen) VALUES (?, ?, ?)')
    .bind(device, now, now).run();
  return signed(env, device, false);
}

/** The consent text the app shows; raise it when that text changes. */
const CONSENT = 1;

async function signIn(request, env) {
  const { device, idToken, consent } = await request.json().catch(() => ({}));
  if (!DEVICE.test(device ?? '') || typeof idToken !== 'string') {
    return json({ error: 'bad request' }, 400);
  }
  if (consent !== CONSENT) return json({ error: 'consent needed' }, 400);
  const who = await verifyGoogleToken(idToken, env.GOOGLE_CLIENT_ID);
  if (!who) return json({ error: 'sign-in not accepted' }, 401);
  const registered = await status(env, device);
  if (registered.status !== 200) return registered;
  const now = Date.now();
  await env.DB.prepare(
    'INSERT INTO accounts (id, email, consent_version, consented_at, first_seen) ' +
    'VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET email = excluded.email, ' +
    'consent_version = excluded.consent_version, consented_at = excluded.consented_at')
    .bind(who.sub, who.email, consent, now, now).run();
  await env.DB.prepare('UPDATE devices SET account_id = ? WHERE id = ?')
    .bind(who.sub, device).run();
  // Proof of who this is for later requests, good for 30 days.
  const session = await sign(env, { sub: who.sub, device, exp: now + 30 * DAY });
  const reply = await sign(env, {
    device,
    status: (await isBlocked(env, device)) ? 'blocked' : 'active',
    issuedAt: Date.now(),
  });
  return json({ email: who.email, session, ...reply });
}

async function admin(request, env, url) {
  if (!(await isAdmin(request, env))) return json({ error: 'no' }, 401);
  if (url.pathname === '/admin/devices' && request.method === 'GET') {
    const { results } = await env.DB.prepare(
      'SELECT d.id, d.blocked, d.first_seen, d.last_seen, a.email, ' +
      'a.blocked AS account_blocked FROM devices d ' +
      'LEFT JOIN accounts a ON a.id = d.account_id ' +
      'ORDER BY d.last_seen DESC LIMIT 200').all();
    return json(results);
  }
  const action = { '/admin/block': 1, '/admin/unblock': 0 }[url.pathname];
  if (action === undefined || request.method !== 'POST') {
    return json({ error: 'not found' }, 404);
  }
  // ?device=<id> for one phone, ?email=<address> for a person everywhere.
  const email = url.searchParams.get('email');
  const who = email ?? url.searchParams.get('device') ?? '';
  const done = await env.DB.prepare(email
    ? 'UPDATE accounts SET blocked = ? WHERE email = ?'
    : 'UPDATE devices SET blocked = ? WHERE id = ?').bind(action, who).run();
  return done.meta.changes >= 1
    ? json({ who, blocked: action === 1 })
    : json({ error: 'unknown' }, 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // The web build calls from another address.
    const cors = { 'access-control-allow-origin': '*' };
    if (url.pathname === '/status' && request.method === 'GET') {
      const device = url.searchParams.get('device') ?? '';
      const reply = DEVICE.test(device)
        ? await status(env, device)
        : json({ error: 'bad device' }, 400);
      Object.entries(cors).forEach(([k, v]) => reply.headers.set(k, v));
      return reply;
    }
    if (url.pathname === '/signin' && request.method === 'POST') {
      return signIn(request, env);
    }
    if (url.pathname.startsWith('/admin/')) return admin(request, env, url);
    return json({ error: 'not found' }, 404);
  },
};
