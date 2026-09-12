# Sharing on the free Firebase plan — how it is wired

The app runs entirely on Firebase's free (Spark) plan. There are no server
functions: every rule of the product (who may join a task, claim it done,
confirm, leave, delete an account) is enforced by Firestore security rules in
`firestore.rules`, which are tested against the Firestore emulator (38
scenarios, see below).

## What the project needs, once (Firebase console, project **Im-Done**)

1. **Build → Firestore Database → Create database**, location **europe-west2
   (London)**, production mode.
2. **Build → Authentication → Get started → Sign-in method**: enable
   **Anonymous** (the "start now" quick account) and **Google**. Under
   **Settings → Authorized domains** add `zaferdajani.github.io`.
3. Then the rules are deployed with `firebase deploy --only firestore:rules`
   (or the "Deploy Firebase rules" workflow with the two repository secrets).

The app configuration (`lib/firebase_options.dart`, `google-services.json`)
is already generated and committed; the service-account key is not in the
repository and must never be.

## Accounts

- **Quick account**: type a name, start. It is a Firebase anonymous account
  bound to that device. Settings offers "Keep this account with Google" which
  links it, so the same account works on another phone.
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
