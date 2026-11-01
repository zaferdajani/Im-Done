# App Review notes (Apple / Google)

**Screenshots must match the real app** (Apple 2.3.3 / Play metadata policy): capture them from a release build showing voice capture, the nag reminder and a shared task with the confirm card. Do not show mock-ups or features that are not shipped.

## Demo login
Personal features need **no login**. For shared-task review, use the demo account:
- Create it with `FIREBASE_API_KEY=… DEMO_EMAIL=… DEMO_PASSWORD=… node scripts/seed-demo-account.mjs` (Email/Password provider enabled in Firebase).
- Put the email/password in App Store Connect / Play Console review notes only. Never commit them.
- Sign in: Settings → Sign in → "Use email".

## Features to try
1. Hold the mic button and say a task; it is parsed and saved locally.
2. Reminders nag until the task is marked done (allow notifications).
3. Switch a task to *Shared*, invite a second person, mark done, confirm.

## Purchases
No purchase is sold yet. Plan screens show "Paid" labels, Restore Purchases and Privacy/Terms links; `PurchaseService` (`lib/services/billing/`) is a no-op until IAP products exist. There is no external checkout in the app.

## Account deletion
Settings → Account → **Delete my account** → confirm. The app erases the user's tasks/memberships/invites/profile and then the Firebase Auth user. Public instructions: `/delete-account` (web/delete-account.html).

## User-generated content & moderation
Shared tasks show member names and task text. Each member row has **Report** (writes to `reports/` in Firestore, create-only) and the creator's row has **Block** (hides that person's shared tasks on this device). The owner reviews `reports/` in the Firebase console and responds within 24 h (state this in the review notes).
