// I'm Done push sender — the one piece of server the free Firebase plan
// lacks. A phone calls POST /notify with its Firebase sign-in token and
// {taskId, kind, toUid?}; this worker checks the caller really is a member
// of that task, decides who may be told (logic.mjs), and sends the push
// through Firebase Cloud Messaging with a service-account key that never
// leaves here.
import { KINDS, message, recipients } from './logic.mjs';

const GOOGLE_CERTS = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

export default {
  async fetch(request, env) {
    const cors = corsHeaders(request);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/notify') {
      return json({ error: 'not found' }, 404, cors);
    }
    try {
      const auth = request.headers.get('Authorization') ?? '';
      const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : null;
      if (!idToken) return json({ error: 'unauthenticated' }, 401, cors);
      const claims = await verifyFirebaseIdToken(idToken, env.FIREBASE_PROJECT_ID);
      const senderUid = claims.sub;

      const body = await request.json().catch(() => ({}));
      const kind = String(body.kind ?? '');
      const taskId = String(body.taskId ?? '');
      const toUid = body.toUid ? String(body.toUid) : undefined;
      if (!KINDS.includes(kind) || !/^[A-Za-z0-9-]{8,64}$/.test(taskId)) return json({ error: 'bad request' }, 400, cors);

      const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      const accessToken = await serviceAccountToken(sa, ['https://www.googleapis.com/auth/datastore', 'https://www.googleapis.com/auth/firebase.messaging']);
      const task = await getDoc(env.FIREBASE_PROJECT_ID, accessToken, `tasks/${taskId}`);
      if (!task || task.archived) return json({ error: 'no such task' }, 404, cors);

      const who = String(task.members?.find((m) => m.uid === senderUid)?.name ?? task.ownerName ?? '');
      const uids = recipients(kind, task, senderUid, toUid);
      let sent = 0;
      for (const uid of uids) {
        const user = await getDoc(env.FIREBASE_PROJECT_ID, accessToken, `users/${uid}`);
        const tokens = Array.isArray(user?.tokens) ? user.tokens : [];
        const msg = message(kind, user?.languageCode, String(task.title ?? ''), who);
        for (const token of tokens) {
          const ok = await sendFcm(env.FIREBASE_PROJECT_ID, accessToken, token, msg, { taskId, kind });
          if (ok) sent++;
        }
      }
      return json({ ok: true, recipients: uids.length, sent }, 200, cors);
    } catch (e) {
      return json({ error: String(e?.message ?? e) }, 500, cors);
    }
  },
};

function corsHeaders(request) {
  return {
    'Access-Control-Allow-Origin': request.headers.get('Origin') ?? '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}
function json(obj, status, headers) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...headers } });
}

// ---------------------------------------------------------------- Firebase ID token
const b64url = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '=')), (c) => c.charCodeAt(0));
const b64urlEncode = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function verifyFirebaseIdToken(token, projectId) {
  const [h, p, s] = token.split('.');
  if (!h || !p || !s) throw new Error('malformed token');
  const header = JSON.parse(new TextDecoder().decode(b64url(h)));
  const payload = JSON.parse(new TextDecoder().decode(b64url(p)));
  const certs = await (await fetch(GOOGLE_CERTS, { cf: { cacheTtl: 3600 } })).json();
  const pem = certs[header.kid];
  if (!pem) throw new Error('unknown key');
  const key = await importX509(pem);
  const ok = await crypto.subtle.verify({ name: 'RSASSA-PKCS1-v1_5' }, key, b64url(s), new TextEncoder().encode(`${h}.${p}`));
  const now = Math.floor(Date.now() / 1000);
  if (!ok || payload.aud !== projectId || payload.iss !== `https://securetoken.google.com/${projectId}` || payload.exp < now || !payload.sub) {
    throw new Error('invalid token');
  }
  return payload;
}

async function importX509(pem) {
  const der = b64url(pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '').replace(/\+/g, '-').replace(/\//g, '_'));
  // Extract SubjectPublicKeyInfo from the certificate (first SEQUENCE inside TBS after serial/sig/issuer/validity/subject).
  const spki = extractSpki(der);
  return crypto.subtle.importKey('spki', spki, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
}

// Minimal DER walker: certificate → tbsCertificate → skip to subjectPublicKeyInfo.
function extractSpki(der) {
  let i = 0;
  const readTL = () => {
    const tag = der[i++];
    let len = der[i++];
    if (len & 0x80) { const n = len & 0x7f; len = 0; for (let k = 0; k < n; k++) len = (len << 8) | der[i++]; }
    return { tag, len, start: i };
  };
  readTL(); // Certificate SEQUENCE
  readTL(); // tbsCertificate SEQUENCE
  let t = readTL(); // version [0] (optional) or serialNumber
  if (t.tag === 0xa0) { i = t.start + t.len; t = readTL(); } // skip version, now serial
  i = t.start + t.len; // skip serial
  t = readTL(); i = t.start + t.len; // signature algorithm
  t = readTL(); i = t.start + t.len; // issuer
  t = readTL(); i = t.start + t.len; // validity
  t = readTL(); i = t.start + t.len; // subject
  const begin = i; t = readTL(); const end = t.start + t.len; // subjectPublicKeyInfo
  return der.slice(begin, end);
}

// ---------------------------------------------------------------- service account → access token
async function serviceAccountToken(sa, scopes) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = b64urlEncode(new TextEncoder().encode(JSON.stringify({ iss: sa.client_email, scope: scopes.join(' '), aud: sa.token_uri, iat: now, exp: now + 3600 })));
  const pkcs8 = b64url(sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '').replace(/\+/g, '-').replace(/\//g, '_'));
  const key = await crypto.subtle.importKey('pkcs8', pkcs8, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'RSASSA-PKCS1-v1_5' }, key, new TextEncoder().encode(`${header}.${claim}`));
  const assertion = `${header}.${claim}.${b64urlEncode(sig)}`;
  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${assertion}`,
  });
  if (!res.ok) throw new Error('token exchange failed: ' + (await res.text()));
  return (await res.json()).access_token;
}

// ---------------------------------------------------------------- Firestore REST
async function getDoc(projectId, token, path) {
  const res = await fetch(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error('firestore read failed: ' + res.status);
  return fromFirestore((await res.json()).fields ?? {});
}
function fromFirestore(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fromValue(v);
  return out;
}
function fromValue(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(fromValue);
  if ('mapValue' in v) return fromFirestore(v.mapValue.fields ?? {});
  return null;
}

// ---------------------------------------------------------------- FCM HTTP v1
async function sendFcm(projectId, token, deviceToken, msg, data) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token: deviceToken,
        notification: msg,
        data,
        android: { priority: 'high', notification: { channel_id: 'task_reminders_v1' } },
        apns: { payload: { aps: { sound: 'default', 'thread-id': data.taskId } } },
        webpush: { notification: { ...msg, icon: '/Im-Done/icons/Icon-192.png' } },
      },
    }),
  });
  return res.ok;
}
