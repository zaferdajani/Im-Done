# Privacy compliance summary (Saudi PDPL + GDPR) — Im-Done

Stack: Flutter + Firebase (Auth/Firestore/FCM) + Cloudflare Worker (voice → Groq/Gemini). No Supabase,
no Postgres, no Storage buckets, no analytics SDK.

## Done
| Item | Result |
|---|---|
| 1, 2, 3, 4 | **N/A** to this repo (TeamManager / sm-mena / image-perfect-share / clinic-clock-guardian items). Voice data minimisation already exists (audio in memory, only date/weekday/language sent). |
| 5 Delete Storage files | **N/A**: app has no Firebase Storage; documented in `docs/RETENTION.md`. Deletion now also removes the consent log. |
| 6 Incident response | `docs/INCIDENT_RESPONSE.md` (72 h SDAIA + GDPR authority, users, owner placeholders). No `breach_incidents`/mailer exists here, so alerting is operational, not code. |
| 7 Policy + sign-up consent | Full draft in `docs/PRIVACY_POLICY.md` and `web/privacy.html` (real vendors: Firebase London, Cloudflare, Groq, Gemini; OpenAI explained). Sign-in sheet: required "agree to Privacy Policy/Terms" box, required age box, **unticked** optional marketing box; all sign-in methods disabled until both required boxes ticked. |
| 8 Consent log / age gate / export / retention / subprocessors | `users/{uid}/consents/{policyVersion}` written at sign-up (Firestore rules: create-only, validated). Under-16 blocked (confirmation box; no parental flow). Settings → *Download my data* (JSON via share sheet). Retention via Firestore TTL (`reports`, `usage`) — `docs/RETENTION.md` (pg_cron is N/A on Firebase). `web/subprocessors.html`, linked in app + all pages. gtag item N/A. |
| 9 | `docs/DPA_CHECKLIST.md` |

## Test status
- `python3 tool/gen_l10n.py` OK (16 languages, new keys in English in all).
- `push-worker`: `node --test` → 22 pass, 0 fail (before and after).
- **Not verified**: Dart code (no Flutter SDK in this environment: `flutter analyze/test` must be run by CI or you).
- **Not run**: Firestore rules tests (`tests/rules`, 7 new consent tests added) — need Firebase emulator/CLI.

## Owner must do
1. Review/replace policy text; fill `[OWNER LEGAL NAME]`, address, `privacy@[YOUR-DOMAIN]`; get counsel review; translate Arabic fully; host `web/*.html` at imdone.me (incl. `/subprocessors`).
2. Sign/accept the DPAs in `docs/DPA_CHECKLIST.md` (Google, Cloudflare, Groq, Gemini paid tier, GitHub); do a transfer impact assessment for US voice processing.
3. Deploy `firestore.rules`; run `gcloud … ttls` commands in `docs/RETENTION.md`; schedule inactive-account purge or delete that sentence.
4. Run `flutter analyze && flutter test` and `cd tests/rules && npm i && npm test`.
5. Decide on remaining gaps: (a) voice is sent to US providers by default — consider a one-time in-app voice-consent prompt before the first recording (the anonymous account is created silently by `ensureSignedIn`); (b) no parental-consent flow (under-16s blocked by self-declaration only); (c) non-English translations of the new strings; (d) marketing opt-in is recorded but no sending mechanism exists; (e) `lib` sign-in `showSignInSheet` reused for re-auth records a consent entry only once per policy version.
