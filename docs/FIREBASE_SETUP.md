# Sharing on the free Firebase plan — how it is wired

The app runs entirely on Firebase's free (Spark) plan. There are no server
functions: every rule of the product (who may join a task, claim it done,
confirm, leave, delete an account) is enforced by Firestore security rules in
`firestore.rules`, which are tested against the Firestore emulator (38
scenarios, see below).

## What the project needs, once — DONE (verified against the live project 2026-09-12)

- Firestore database exists in **europe-west2 (London)**.
- Authentication has **Email/Password**, **Google** and **Anonymous** enabled, and
  `zaferdajani.github.io` is an authorized domain (so the web app can sign in).
- `firestore.rules` is published (release `cloud.firestore`, done through the
  Firebase Rules API — the "Deploy Firebase rules" workflow does the same on
  every push that changes the file).
- The Android app carries a **committed debug signing key** (`android/app/debug.keystore`,
  password `android`) whose SHA-1/SHA-256 are registered on the Firebase Android
  app, and `google-services.json` was regenerated with the matching OAuth client —
  Google sign-in on the CI-built APK works because every build is signed the same
  way. That key is a debug key, not a secret; the store release key will be separate.

The app configuration (`lib/firebase_options.dart`, `google-services.json`)
is generated and committed; the service-account key is not in the repository
and must never be.

## Accounts

- **Quick account**: type a name, start. It is a Firebase anonymous account
  bound to that device. Settings offers "Keep this account with Google" which
  links it, so the same account works on another phone.
- **Email + password**: a full account with no Google or Apple involved; a
  quick account can be upgraded to it from Settings, and "Forgot password"
  sends Firebase's reset mail.
- **Google / Apple**: full accounts. Apple needs the Apple developer account
  (Service ID + key uploaded to Authentication → Apple) and is required on
  iOS whenever Google is offered.
- Every account gets a **personal code** (8 characters) shown in Settings as
  text and as a QR. A task's creator adds people by typing the code or
  scanning the QR; a scanned/opened code lands on "add this person to which
  task?". Invite links still work too.

## Push notifications between phones — the free sender

Sending a push needs a server holding a secret key. Firebase only gives one on
the paid plan, so the sender lives on **Cloudflare Workers** (free tier) in
`push-worker/`. A phone calls it with its Firebase sign-in token and
`{taskId, kind, toUid?}`; the worker verifies the token, reads the task, checks
the caller is a member, decides who may be told (`src/logic.mjs`, unit-tested)
and sends through Firebase Cloud Messaging. Kinds: added, joined, claimed,
confirmed, rejected. Deploy: `.github/workflows/deploy-push.yml` (secrets
`CLOUDFLARE_API_TOKEN`, `FIREBASE_SERVICE_ACCOUNT`). Web push (browser
notifications) additionally needs a VAPID key from Firebase console → Cloud
Messaging → Web Push certificates; not set up yet.
- **Server-side cleanup on account deletion.** The app does it client-side:
  leaves every task, archives owned ones, removes the code and profile, then
  deletes the Auth user (re-signing in first if Firebase asks).

## Testing the rules

`tests/rules/` runs against the emulator: `cd tests/rules && npm install &&
firebase emulators:exec --only firestore --project demo-imdone "node rules.test.mjs"`.
