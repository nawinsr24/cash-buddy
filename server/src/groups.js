// The post box. Notes arrive locked with a key only the group's phones hold,
// wait until each other phone has them (at most 90 days) and are deleted.
import { nudge } from './push.js';

const DAY = 86400000;
const KEEP = 90 * DAY;
const INVITE = DAY;
const MAX_MEMBERS = 6;
const MAX_NOTE = 20000; // characters
const ID = /^[A-Za-z0-9_-]{8,64}$/;
const MEMBER = /^m[A-Za-z0-9_-]{6,32}$/;
const NOTE = /^m[A-Za-z0-9_-]{6,32}\.\d{1,6}:\d{1,9}$/;

const json = (body, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});

const hex = (buf) => [...new Uint8Array(buf)]
  .map((b) => b.toString(16).padStart(2, '0')).join('');
const sha = async (s) => hex(
  await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));

/** who: the signed-in account, already checked and not blocked. */
export async function groups(request, env, url, who) {
  const now = Date.now();
  const body = request.method === 'POST'
    ? await request.json().catch(() => ({})) : {};
  const group = body.group ?? url.searchParams.get('group') ?? '';
  const member = body.member ?? url.searchParams.get('member') ?? '';
  if (!ID.test(group) || !MEMBER.test(member)) {
    return json({ error: 'bad request' }, 400);
  }
  const path = url.pathname.slice('/group/'.length);
  const db = env.DB;
  const q = (sql, ...args) => db.prepare(sql).bind(...args);

  // The join token is derived from the group key; only its hash is kept.
  if (path === 'create' || path === 'join' || path === 'invite') {
    if (typeof body.join !== 'string') return json({ error: 'bad request' }, 400);
    const hash = await sha(body.join);
    const found = await q('SELECT join_hash, join_until FROM groups WHERE id = ?', group).first();
    if (path === 'create') {
      if (found) return json({ error: 'taken' }, 409);
      await q('INSERT INTO groups (id, join_hash, join_until) VALUES (?, ?, ?)',
        group, hash, now + INVITE).run();
    } else {
      if (!found || found.join_hash !== hash) return json({ error: 'no' }, 403);
      if (path === 'join') {
        if (found.join_until < now) return json({ error: 'invite expired' }, 410);
        const n = await q('SELECT COUNT(*) AS n FROM members WHERE group_id = ?', group).first();
        if (n.n >= MAX_MEMBERS) return json({ error: 'full' }, 409);
      }
    }
    if (path !== 'invite') {
      await q('INSERT OR REPLACE INTO members (group_id, member_id, account_id) VALUES (?, ?, ?)',
        group, member, who).run();
    }
  }

  const mine = await q('SELECT account_id FROM members WHERE group_id = ? AND member_id = ?',
    group, member).first();
  if (mine?.account_id !== who) return json({ error: 'not a member' }, 403);

  switch (path) {
    case 'create':
    case 'join':
      return json({ ok: true });
    case 'invite': // opens the invitation for another day
      await q('UPDATE groups SET join_until = ? WHERE id = ?', now + INVITE, group).run();
      return json({ ok: true });
    case 'leave':
      await q('DELETE FROM members WHERE group_id = ? AND member_id = ?', group, member).run();
      await q('DELETE FROM waiting WHERE group_id = ? AND member_id = ?', group, member).run();
      await q('DELETE FROM push WHERE group_id = ? AND member_id = ?', group, member).run();
      return json({ ok: true });
    case 'push': { // this phone's address for nudges
      if (typeof body.token !== 'string' || !body.token || body.token.length > 4096) {
        return json({ error: 'bad request' }, 400);
      }
      await q('INSERT INTO push (group_id, member_id, token) VALUES (?, ?, ?) ' +
        'ON CONFLICT(group_id, member_id) DO UPDATE SET token = excluded.token',
        group, member, body.token).run();
      return json({ ok: true });
    }
    case 'upload': {
      const { id, sealed } = body;
      if (!NOTE.test(id ?? '') || typeof sealed !== 'string' || sealed.length > MAX_NOTE) {
        return json({ error: 'bad note' }, 400);
      }
      await q('DELETE FROM notes WHERE expires < ?', now).run();
      await q('INSERT INTO notes (group_id, note_id, sealed, expires) VALUES (?, ?, ?, ?) ' +
        'ON CONFLICT(group_id, note_id) DO UPDATE SET expires = excluded.expires',
        group, id, sealed, now + KEEP).run();
      await q('INSERT OR IGNORE INTO waiting (group_id, note_id, member_id) ' +
        'SELECT group_id, ?, member_id FROM members WHERE group_id = ? AND member_id <> ?',
        id, group, member).run();
      const cut = id.lastIndexOf(':');
      await q('INSERT INTO highest (group_id, writer, seq) VALUES (?, ?, ?) ' +
        'ON CONFLICT(group_id, writer) DO UPDATE SET seq = MAX(seq, excluded.seq)',
        group, id.slice(0, cut), Number(id.slice(cut + 1))).run();
      await nudge(env, group, member, now);
      return json({ ok: true });
    }
    case 'fetch': {
      const { results } = await q(
        'SELECT n.sealed FROM waiting w JOIN notes n ' +
        'ON n.group_id = w.group_id AND n.note_id = w.note_id ' +
        'WHERE w.group_id = ? AND w.member_id = ? AND n.expires >= ? LIMIT 200',
        group, member, now).all();
      return json(results.map((r) => r.sealed));
    }
    case 'ack': {
      await q('DELETE FROM waiting WHERE group_id = ? AND note_id = ? AND member_id = ?',
        group, body.id ?? '', member).run();
      await q('DELETE FROM notes WHERE group_id = ?1 AND note_id = ?2 AND NOT EXISTS ' +
        '(SELECT 1 FROM waiting WHERE group_id = ?1 AND note_id = ?2)',
        group, body.id ?? '').run();
      return json({ ok: true });
    }
    case 'highest': {
      const { results } = await q('SELECT writer, seq FROM highest WHERE group_id = ?', group).all();
      return json(Object.fromEntries(results.map((r) => [r.writer, r.seq])));
    }
    case 'request':
      await q('INSERT OR REPLACE INTO requests (group_id, member_id, missing) VALUES (?, ?, ?)',
        group, member, JSON.stringify(body.missing ?? {}).slice(0, MAX_NOTE)).run();
      return json({ ok: true });
    case 'requests': {
      const { results } = await q(
        'SELECT missing FROM requests WHERE group_id = ? AND member_id <> ?', group, member).all();
      return json(results.map((r) => JSON.parse(r.missing)));
    }
    default:
      return json({ error: 'not found' }, 404);
  }
}
