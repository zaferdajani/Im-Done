# Incident (personal-data breach) response plan

Owner/incident lead: **[NAME, phone, email]** · Deputy: **[NAME, phone, email]** ·
Privacy mailbox: **privacy@[YOUR-DOMAIN]** · Legal counsel: **[NAME / FIRM]**

A personal-data breach is any loss, theft, unauthorised access, alteration or disclosure of personal
data (e.g. leaked Firebase service-account key, mis-deployed Firestore rules exposing `tasks`/`users`,
leaked Cloudflare/Groq/Gemini keys, compromised owner Google account).

## 1. Detection
- Firebase/GCP: enable Cloud Audit Logs and budget/usage alerts; alert on unusual Firestore read spikes.
- Cloudflare: Workers error-rate and request-spike notifications.
- Reports from users to privacy@/support@; app-store or researcher disclosures.
- GitHub secret-scanning alerts on this repo; Dependabot alerts for `push-worker`.
- Anyone who notices a possible incident tells the incident lead **immediately** and writes down the time.

## 2. Containment (first hours)
1. Open an incident record (date/time discovered, who, what, systems). Keep evidence; don't delete logs.
2. Revoke/rotate exposed secrets: Firebase service-account key (`FIREBASE_SERVICE_ACCOUNT`), `GROQ_API_KEY`,
   `GEMINI_API_KEY`, `REVENUECAT_WEBHOOK_SECRET` (`wrangler secret put …`), GitHub tokens.
3. If rules are wrong: redeploy last known-good `firestore.rules` (`firebase deploy --only firestore:rules`).
4. If severe: disable the Worker route / set `config/billing` and sign-in providers off in the Firebase console.
5. Force sign-out: revoke refresh tokens for affected users (Admin SDK `revokeRefreshTokens`).

## 3. Assessment (within 24 h)
What data (names, emails, task text, push tokens), how many people, which countries (Saudi, EU/UK, Jordan,
other), was it encrypted, is it ongoing, likelihood of harm to individuals. Record the decision and reasons.

## 4. Notification — **clock starts when we become aware**
| Who | When | How / content |
|---|---|---|
| **SDAIA** (Saudi PDPL — if Saudi residents' data is affected and harm is likely) | **within 72 hours** | via the SDAIA / National Data Governance platform notification channel; content: nature of breach, categories and approximate number of people, likely consequences, measures taken, contact point |
| **GDPR supervisory authority** (lead/national authority of affected EU residents; ICO for UK) | **within 72 hours** unless unlikely to risk individuals (Art. 33) | authority's online breach form; same content; if info is incomplete, file in phases |
| **Jordan** data-protection authority (when established/active) | as the law requires | per counsel |
| **Affected users** | without undue delay when high risk (GDPR Art. 34; PDPL) | email/in-app notice in plain language: what happened, what data, what we've done, what they should do (e.g. change passwords), contact privacy@ |
| Processors/vendors affected | immediately | notify Google/Cloudflare/Groq per their DPA contact |
| App stores | if required by their policies | developer consoles |

## 5. Recovery & review
Restore from known-good state, verify, monitor 30 days. Within 14 days write a post-incident review (root cause,
fixes, owner/date). Keep the breach register (below) for at least 5 years.

## 6. Breach register (copy per incident)
Date/time discovered · Date/time notified (authority, users) · Description · Data/people affected ·
Consequences · Measures · Decision on notification & reasons · Lead.

## Notes for this repo
There is no `breach_incidents` table or mailer in this Firebase/Cloudflare stack, so alert wiring is operational
(Cloud Monitoring + Cloudflare notifications above) rather than in code.
