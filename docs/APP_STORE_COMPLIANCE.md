# App Store / Google Play compliance summary

Stack: Flutter + Firebase (not Supabase/Capacitor). See also `docs/STORE_COMPLIANCE.md` (long checklist) and `docs/APP_REVIEW.md`.

| # | Reason | Status |
|---|---|---|
| 1 | External checkout for digital goods | **N/A today**: no Stripe/web checkout exists. Paid plans are not sold. `PurchaseService` abstraction (`lib/services/billing/purchase_service.dart`) + `Flags.purchasesEnabled` added. *Owner:* create RevenueCat account (or StoreKit/Play products), add `purchases_flutter`, implement `PurchaseService`, set `--dart-define=PURCHASES_ENABLED=true`. |
| 2 | Sign in with Apple | **Already done** (`auth_service.dart`, shown on iOS beside Google). *Owner:* enable Apple provider + keys in Firebase. |
| 3 | Account deletion | **Verified real**: Settings → Account → Delete my account → confirm → `CloudTasks.eraseEverythingOf` + `user.delete()`, with re-auth retry. Client-side (no server function exists; earlier docs mentioning `functions/` were inaccurate). Added public `web/delete-account.html` and an in-app link. *Owner:* consider a server function for atomic deletion; make sure `https://imdone.me/delete-account` is live. |
| 4 | Native value | Added offline banner (`onlineProvider`, `OfflineBanner`), in-app browser for external links, max-width tablet layout. Haptics, local/push notifications and voice already existed. *Weak/remaining:* splash screen branding, home-screen widgets/Siri shortcuts, status-bar styling. |
| 5 | Reviewer demo account | `scripts/seed-demo-account.mjs`, `.env.example`, `docs/APP_REVIEW.md`. *Owner:* pick credentials, enable Email/Password. |
| 6 | iPad 768–1366px | No fixed-width layouts found; content is now capped at 900px and centered via `OfflineBanner` wrapper. Not visually tested (no Flutter SDK in this environment). |
| 7 | Screenshots match app | Documented in `APP_REVIEW.md`. *Owner:* capture from a real build. |
| 8 | Coming-soon screens | "Purchases will be available…" text now only in debug builds (`Flags.showComingSoon`). |
| 9 | Privacy / Terms / Support | `web/privacy.html`, `terms.html`, `support.html` (placeholder text, marked for owner review); linked in Settings, the sign-in sheet and plan screen. *Owner:* real legal text, support email, host at imdone.me (or update `Cloud.*Url`). |
| 10 | UGC moderation | Report + Block on shared-task members; `reports` collection with create-only Firestore rule; blocked owners' tasks hidden (stored locally in settings). *Remaining:* an admin review UI (reports reviewed in Firebase console), server-side block list, deploy `firestore.rules`. |
| 11 | Restore Purchases | Button on the plan screen via `PurchaseService.restore()` (no-op until implemented). |
| 12 | Paid labelling | Family/Team plan cards carry a "Paid" badge. *Owner:* add real price strings from the store once products exist. |

New UI strings were added to all 16 `l10n/*.json` in English; native translations are owed. Not verified by build: no `flutter`/`dart` in this environment; only `python3 tool/gen_l10n.py` was run.
