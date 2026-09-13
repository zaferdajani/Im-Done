# Plans: family and team

*Written 2026-09-13. Numbers marked "proposed" are the owner's to set.*

## The shape

- A **workspace** is a payer's environment: a *family* or a *team*. Its owner
  adds people by personal code, QR, or one invite link; everyone in it gets
  the plan's access. A person belongs to at most one workspace.
- An **entitlement** is what was paid for that workspace: the plan, the number
  of seats, and until when. Only the server writes it (the Cloudflare Worker,
  with the service account). The app can never grant itself a plan — the
  rules refuse `plan` on a workspace and refuse every client write to
  `entitlements/*` (tested).
- **Nothing is gated until `config/billing.enforced` is switched on** (a
  server-only document). While it is off the product is fully usable, which is
  the state for testing and for the first users. Switching it on later changes
  no data.

## What a plan buys (proposed, all enforced when billing is on)

| | Free | Family | Team |
|---|---|---|---|
| Personal tasks, groups, categories, importance | ✓ | ✓ | ✓ |
| Voice in every language | 10 recordings a day | unlimited | unlimited |
| People on one shared task | up to 3 | up to 50 | up to 50 |
| People in the workspace | — | up to 6 | as many seats as bought (min 5) |
| Price (proposed) | 0 | $2.99 / month or $24.99 / year, one price for all six | $2 per seat / month, billed to the organisation |

The two gates are real code, not labels: the task member cap is in
`firestore.rules` (`memberCap`), the voice allowance in the worker
(`voiceQuota`, counted per person per day in `usage/`), and the seat cap in
the rules (`seatCap`). Each is switched off by `enforced = false`.

## Why these numbers

Todoist charges $5 / month for Pro and $8 per user for Business (2026), and
has no family plan; TickTick is $3 / month per person with no family or team
plan at all. A family price that covers six people for less than one Todoist
seat, and a team seat at a quarter of Todoist's, is deliberately the cheap
option: the app's cost base is a free Firebase project, a free worker and
Groq's free tier, so the price is for reach, not margin.

## How purchases will work

- **Family (consumers) must be bought in-app** — Apple guideline 3.1.1 and
  Google's equivalent — through App Store / Google Play subscriptions. Both
  stores support family sharing of a subscription, but the app's own
  workspace is what actually grants access to the six people, so the store's
  family-sharing feature is not relied on.
- **Team (organisations) may be sold outside the stores** — Apple 3.1.3(c)
  allows enterprise services sold directly to organisations for their
  members. So a clinic can pay by bank transfer or card on the web, and the
  server writes the entitlement (`source: 'manual'`), no store cut.
- **Receipts and renewals**: RevenueCat (free up to $2,500 of monthly
  revenue) validates store receipts and posts renewals, cancellations and
  expirations to the worker's `/billing/revenuecat`, which maps the product
  id to a plan and seats (`plans.mjs`) and writes the entitlement. The
  webhook is already deployed and waits for its secret.
- **Trial**: any workspace owner gets one 30-day family trial, granted by the
  server (`/workspace/trial`), once per person.

## What is needed to sell (owner's side, when ready)

1. Apple Developer account ($99 / year) and Google Play Console ($25 once).
2. Products created in both stores with the ids in `plans.mjs`
   (`imdone_family_monthly`, `imdone_family_yearly`, `imdone_team_5_monthly`…).
3. A RevenueCat account (free) connected to both stores, its webhook pointed
   at `https://imdone-push.imdone-push.workers.dev/billing/revenuecat` with a
   secret, and that secret stored on the worker as `REVENUECAT_WEBHOOK_SECRET`.
4. The `purchases_flutter` SDK wired into the Plan screen's buttons (a small,
   contained change once the keys exist).
5. Then `config/billing.enforced = true`.

Sources: Todoist pricing 2026 (costbench.com, buyersprint.com); TickTick
pricing 2026 (lifestack.ai); RevenueCat pricing (costbench.com); Apple App
Review Guidelines 3.1.1 / 3.1.3(c).
