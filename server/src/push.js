// Tells the other phones "something new" through Firebase Cloud Messaging.
// The message carries no amounts, names or entries. Without the
// FCM_SERVICE_ACCOUNT secret nothing is sent.

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

const url64 = (data) => btoa(
  typeof data === 'string' ? data : String.fromCharCode(...new Uint8Array(data)),
).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

let cached = { token: '', until: 0 };
async function accessToken(account, now) {
  if (now < cached.until) return cached.token;
  const der = Uint8Array.from(
    atob(account.private_key.replace(/-----[^-]+-----|\s/g, '')),
    (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const seconds = Math.floor(now / 1000);
  const unsigned = `${url64(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${url64(
    JSON.stringify({
      iss: account.client_email, scope: SCOPE, aud: account.token_uri,
      iat: seconds, exp: seconds + 3600,
    }))}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const reply = await fetch(account.token_uri, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${url64(signature)}`,
    }).toString(),
  });
  if (!reply.ok) throw new Error('no access token');
  cached = { token: (await reply.json()).access_token, until: now + 3000000 };
  return cached.token;
}

/** Nudges every other phone in the group. Never lets a failure matter. */
export async function nudge(env, group, sender, now = Date.now()) {
  try {
    if (!env.FCM_SERVICE_ACCOUNT) return;
    // At most one nudge a minute per phone, however many notes arrive.
    const { results } = await env.DB.prepare(
      'SELECT member_id, token FROM push WHERE group_id = ? AND member_id <> ? ' +
      'AND nudged < ?').bind(group, sender, now - 60000).all();
    if (results.length === 0) return;
    const account = JSON.parse(env.FCM_SERVICE_ACCOUNT);
    const bearer = await accessToken(account, now);
    for (const row of results) {
      const reply = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
          method: 'POST',
          headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
          body: JSON.stringify({
            message: {
              token: row.token,
              notification: { title: 'Cash++', body: 'Your shared group has something new.' },
              data: { kind: 'group' },
              android: { collapse_key: 'group' },
            },
          }),
        });
      // 404: the app was removed from that phone.
      await env.DB.prepare(reply.status === 404
        ? 'DELETE FROM push WHERE group_id = ?1 AND member_id = ?2 AND ?3 > 0'
        : 'UPDATE push SET nudged = ?3 WHERE group_id = ?1 AND member_id = ?2')
        .bind(group, row.member_id, now).run();
    }
  } catch {
    // the notes are waiting anyway
  }
}
