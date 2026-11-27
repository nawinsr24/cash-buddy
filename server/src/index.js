// Blocking server. The app asks "may I run?"; the answer is signed so that
// nobody else can block or unblock a phone.

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

async function signed(env, device, blocked) {
  const payload = JSON.stringify({
    device,
    status: blocked ? 'blocked' : 'active',
    issuedAt: Date.now(),
  });
  const key = await crypto.subtle.importKey(
    'pkcs8', bytes(env.SIGNING_KEY), { name: 'Ed25519' }, false, ['sign']);
  const signature = await crypto.subtle.sign(
    'Ed25519', key, new TextEncoder().encode(payload));
  return json({ payload, signature: base64(signature) });
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
    'SELECT blocked, last_seen FROM devices WHERE id = ?').bind(device).first();
  if (row) {
    // At most one write an hour per phone, to stay inside the free limits.
    if (now - row.last_seen > 3600000) {
      await env.DB.prepare('UPDATE devices SET last_seen = ? WHERE id = ?')
        .bind(now, device).run();
    }
    return signed(env, device, row.blocked === 1);
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

async function admin(request, env, url) {
  if (!(await isAdmin(request, env))) return json({ error: 'no' }, 401);
  if (url.pathname === '/admin/devices' && request.method === 'GET') {
    const { results } = await env.DB.prepare(
      'SELECT id, blocked, first_seen, last_seen FROM devices ORDER BY last_seen DESC LIMIT 200')
      .all();
    return json(results);
  }
  const action = { '/admin/block': 1, '/admin/unblock': 0 }[url.pathname];
  if (action === undefined || request.method !== 'POST') {
    return json({ error: 'not found' }, 404);
  }
  const device = url.searchParams.get('device') ?? '';
  const done = await env.DB.prepare('UPDATE devices SET blocked = ? WHERE id = ?')
    .bind(action, device).run();
  return done.meta.changes === 1
    ? json({ device, blocked: action === 1 })
    : json({ error: 'unknown device' }, 404);
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
    if (url.pathname.startsWith('/admin/')) return admin(request, env, url);
    return json({ error: 'not found' }, 404);
  },
};
