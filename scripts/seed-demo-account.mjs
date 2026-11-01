#!/usr/bin/env node
// Creates (or signs in) the App Review demo account via the Firebase Auth REST
// API. No secrets in the repo: everything comes from the environment.
//   FIREBASE_API_KEY=... DEMO_EMAIL=... DEMO_PASSWORD=... node scripts/seed-demo-account.mjs
// Email/Password sign-in must be enabled in the Firebase console.
const { FIREBASE_API_KEY, DEMO_EMAIL, DEMO_PASSWORD } = process.env;
if (!FIREBASE_API_KEY || !DEMO_EMAIL || !DEMO_PASSWORD) {
  console.error('Set FIREBASE_API_KEY, DEMO_EMAIL and DEMO_PASSWORD.');
  process.exit(1);
}
const call = async (op, body) => {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${op}?key=${FIREBASE_API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ ...body, returnSecureToken: true }),
  });
  return { ok: r.ok, json: await r.json() };
};
let res = await call('signUp', { email: DEMO_EMAIL, password: DEMO_PASSWORD });
if (!res.ok && res.json?.error?.message === 'EMAIL_EXISTS') res = await call('signInWithPassword', { email: DEMO_EMAIL, password: DEMO_PASSWORD });
if (!res.ok) { console.error('Failed:', res.json?.error?.message); process.exit(1); }
await call('update', { idToken: res.json.idToken, displayName: 'App Review' });
console.log(`Demo account ready: ${DEMO_EMAIL} (uid ${res.json.localId})`);
