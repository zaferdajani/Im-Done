// I'm Done's only server, a free Cloudflare Worker with two jobs:
//
//   POST /notify      push between phones. The caller sends its Firebase
//                     sign-in token and {taskId, kind, toUid?}; the worker
//                     checks membership, decides recipients (logic.mjs) and
//                     sends through Firebase Cloud Messaging with a
//                     service-account key that never leaves here.
//   POST /transcribe  voice → task. The caller sends the recorded audio; the
//                     worker transcribes it with automatic language detection
//                     (Groq's Whisper large-v3-turbo, free tier), then asks a
//                     free language model to turn the words into task fields
//                     and, for Arabic, to name the dialect (understand.mjs).
//                     Falls back to Gemini when a key for it is set. Audio is
//                     processed in memory and never stored.
import { KINDS, message, recipients } from './logic.mjs';
import { audioAcceptable, buildSystemPrompt, buildUserPrompt, languageCode, parseUnderstanding } from './understand.mjs';

const GOOGLE_CERTS = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

export default {
  async fetch(request, env) {
    const cors = corsHeaders(request);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, transcribe: Boolean(env.GROQ_API_KEY || env.GEMINI_API_KEY) }, 200, cors);
    }
    if (request.method !== 'POST' || !['/notify', '/transcribe'].includes(url.pathname)) {
      return json({ error: 'not found' }, 404, cors);
    }
    try {
      const auth = request.headers.get('Authorization') ?? '';
      const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : null;
      if (!idToken) return json({ error: 'unauthenticated' }, 401, cors);
      let senderUid;
      try {
        senderUid = (await verifyFirebaseIdToken(idToken, env.FIREBASE_PROJECT_ID)).sub;
      } catch {
        return json({ error: 'unauthenticated' }, 401, cors);
      }
      if (url.pathname === '/transcribe') return transcribe(request, env, cors);

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
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Now, X-Weekday, X-Ui-Language, X-Preferred-Language',
  };
}

// ---------------------------------------------------------------- voice → task
const GROQ = 'https://api.groq.com/openai/v1';
const WHISPER_MODEL = 'whisper-large-v3-turbo';
const CHAT_MODELS = ['openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'qwen/qwen3.6-27b'];
const GEMINI_MODEL = 'gemini-2.5-flash';

async function transcribe(request, env, cors) {
  if (!env.GROQ_API_KEY && !env.GEMINI_API_KEY) return json({ error: 'transcription not configured' }, 503, cors);
  const contentType = request.headers.get('Content-Type') ?? 'audio/wav';
  const audio = new Uint8Array(await request.arrayBuffer());
  const check = audioAcceptable(audio.byteLength, contentType);
  if (!check.ok) return json({ error: check.reason }, 400, cors);
  const context = {
    now: sanitize(request.headers.get('X-Now'), 40) || new Date().toISOString(),
    weekday: sanitize(request.headers.get('X-Weekday'), 12) || 'unknown weekday',
    uiLanguage: sanitize(request.headers.get('X-Ui-Language'), 8) || 'en',
    preferred: (sanitize(request.headers.get('X-Preferred-Language'), 8) || '').toLowerCase() || null,
  };
  const warnings = [];

  let transcript = null;
  let detected = null;
  let engine = null;
  if (env.GROQ_API_KEY) {
    try {
      let w = await groqWhisper(env.GROQ_API_KEY, audio, contentType);
      // The person told us their language. Whisper cannot be given a
      // preference, only a certainty, so it runs free first; when it lands
      // on a language that is routinely confused with the preferred one
      // (Urdu heard as Hindi, Malay as Indonesian, Ukrainian as Russian…)
      // the preferred language is checked first, as asked.
      if (context.preferred && w.language !== context.preferred && confusable(context.preferred, w.language)) {
        try {
          const again = await groqWhisper(env.GROQ_API_KEY, audio, contentType, context.preferred);
          if (again.text.trim()) { w = { text: again.text, language: context.preferred }; warnings.push(`re-heard as preferred ${context.preferred} (first guess ${w.language})`); }
        } catch (e) { warnings.push(`preferred re-run failed: ${String(e?.message ?? e).slice(0, 120)}`); }
      }
      transcript = w.text;
      detected = w.language;
      engine = 'groq-whisper';
    } catch (e) {
      if (!env.GEMINI_API_KEY) return json({ error: 'transcription failed', detail: String(e?.message ?? e) }, 502, cors);
    }
  }
  if (transcript === null && env.GEMINI_API_KEY) {
    // Gemini hears the audio and structures it in one call.
    try {
      const raw = await geminiUnderstand(env.GEMINI_API_KEY, audio, contentType, context);
      const parsed = parseUnderstanding(raw, extractTranscript(raw), null);
      return json({ ...parsed, engine: 'gemini' }, 200, cors);
    } catch (e) {
      return json({ error: 'transcription failed', detail: String(e?.message ?? e) }, 502, cors);
    }
  }
  if (!transcript || !transcript.trim()) return json({ error: 'nothing heard' }, 422, cors);

  let raw = null;
  if (env.GROQ_API_KEY) {
    for (const model of CHAT_MODELS) {
      try {
        raw = await groqChat(env.GROQ_API_KEY, model, buildSystemPrompt(context), buildUserPrompt(transcript, detected));
        engine += `+${model}`;
        break;
      } catch (e) { warnings.push(`${model}: ${String(e?.message ?? e).slice(0, 160)}`); }
    }
  }
  if (raw === null && env.GEMINI_API_KEY) {
    try {
      raw = await geminiText(env.GEMINI_API_KEY, buildSystemPrompt(context), buildUserPrompt(transcript, detected));
      engine += '+gemini';
    } catch (e) { warnings.push(`gemini: ${String(e?.message ?? e).slice(0, 160)}`); }
  }
  // With no structuring model the transcript itself becomes the task title.
  const parsed = parseUnderstanding(raw ?? '{}', transcript, detected);
  return json({ ...parsed, engine, ...(warnings.length ? { warnings } : {}) }, 200, cors);
}

/** Language pairs Whisper mixes up when the speaker's own language is known. */
const CONFUSABLE = [['ur', 'hi'], ['ms', 'id'], ['uk', 'ru'], ['gu', 'hi'], ['pa', 'hi'], ['fa', 'ar'], ['ur', 'ar'], ['pt', 'es'], ['it', 'es'], ['nl', 'de'], ['sv', 'no'], ['sv', 'da'], ['zh', 'ja'], ['ko', 'ja']];
function confusable(preferred, detected) {
  if (!detected) return true; // nothing detected at all: try what they told us
  return CONFUSABLE.some(([a, b]) => (a === preferred && b === detected) || (b === preferred && a === detected));
}

function sanitize(v, max) {
  return v ? String(v).replace(/[^A-Za-z0-9:+\-T.Z _]/g, '').slice(0, max) : '';
}
function extractTranscript(raw) {
  try {
    const m = String(raw).match(/\{[\s\S]*\}/);
    const j = m ? JSON.parse(m[0]) : {};
    return typeof j.transcript === 'string' ? j.transcript : '';
  } catch {
    return '';
  }
}

async function groqWhisper(key, audio, contentType, language) {
  const form = new FormData();
  const ext = /wav/.test(contentType) ? 'wav' : /webm/.test(contentType) ? 'webm' : /ogg/.test(contentType) ? 'ogg' : /mpeg|mp3/.test(contentType) ? 'mp3' : /mp4|m4a|aac/.test(contentType) ? 'm4a' : 'wav';
  form.append('file', new Blob([audio], { type: contentType }), `speech.${ext}`);
  form.append('model', WHISPER_MODEL);
  form.append('response_format', 'verbose_json');
  form.append('temperature', '0');
  // No `language` = automatic detection; set only for the preferred re-run.
  if (language) form.append('language', language);
  const res = await fetch(`${GROQ}/audio/transcriptions`, { method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form });
  if (!res.ok) throw new Error(`whisper ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  return { text: String(j.text ?? ''), language: languageCode(j.language) };
}

async function groqChat(key, model, system, user) {
  const res = await fetch(`${GROQ}/chat/completions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      temperature: 0,
      // gpt-oss "thinks" before answering and the thinking counts against
      // max_tokens: a low cap cut the JSON off and the task fell back to a
      // plain title. Keep the cap generous; medium effort reads dialect words
      // ("ونص المسا") that low effort waves through as standard Arabic.
      max_tokens: 1500,
      ...(model.startsWith('openai/gpt-oss') ? { reasoning_effort: 'medium' } : {}),
      // Groq's JSON mode rejected valid answers carrying Arabic text; the
      // object is extracted from the reply instead (parseUnderstanding).
      messages: [{ role: 'system', content: system }, { role: 'user', content: user }],
    }),
  });
  if (!res.ok) throw new Error(`chat ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  return j.choices?.[0]?.message?.content ?? '{}';
}

async function geminiUnderstand(key, audio, contentType, context) {
  const prompt = buildSystemPrompt(context) + '\nAlso include "transcript": the exact words spoken, in their original language.';
  return geminiGenerate(key, [
    { text: prompt },
    { inlineData: { mimeType: contentType.split(';')[0], data: base64(audio) } },
  ]);
}
async function geminiText(key, system, user) {
  return geminiGenerate(key, [{ text: `${system}\n\n${user}` }]);
}
async function geminiGenerate(key, parts) {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents: [{ role: 'user', parts }], generationConfig: { temperature: 0, responseMimeType: 'application/json' } }),
  });
  if (!res.ok) throw new Error(`gemini ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  return j.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '{}';
}
function base64(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
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
