// Checks a Google ID token: signed by Google, meant for this app, not expired.

const CERTS = 'https://www.googleapis.com/oauth2/v3/certs';
const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

const fromUrl = (s) => Uint8Array.from(
  atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const parse = (s) => JSON.parse(new TextDecoder().decode(fromUrl(s)));

let cached = { keys: [], until: 0 };
async function googleKeys(now) {
  if (now < cached.until) return cached.keys;
  const response = await fetch(CERTS);
  if (!response.ok) throw new Error('no certs');
  cached = { keys: (await response.json()).keys, until: now + 3600000 };
  return cached.keys;
}

/** The token's claims, or null for anything that is not entirely right. */
export async function verifyGoogleToken(token, audience, now = Date.now()) {
  try {
    const [head, body, signature, extra] = token.split('.');
    if (!audience || extra !== undefined || !signature) return null;
    const header = parse(head);
    if (header.alg !== 'RS256') return null;
    const jwk = (await googleKeys(now)).find((k) => k.kid === header.kid);
    if (!jwk) return null;
    const key = await crypto.subtle.importKey(
      'jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false,
      ['verify']);
    const genuine = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5', key, fromUrl(signature),
      new TextEncoder().encode(`${head}.${body}`));
    if (!genuine) return null;
    const claims = parse(body);
    const right = ISSUERS.includes(claims.iss) && claims.aud === audience &&
      claims.exp * 1000 > now && claims.email_verified === true &&
      typeof claims.sub === 'string';
    return right ? claims : null;
  } catch {
    return null;
  }
}
