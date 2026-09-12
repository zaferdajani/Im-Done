# I'm Done

**Say it. Get nagged. Get it done.** A Flutter app (iOS + Android, English + Arabic) that turns
a spoken sentence into a task, reminds you at the time you set and keeps reminding you until you
mark it done, and lets you share a task with other people — they are all reminded, one of them
marks it done, and **you, the creator, confirm**.

```
hold the mic → "call the pharmacy every day at 9" → task: Call the pharmacy · every day · 09:00
                                                     ↓
                            09:00 reminder, again at 09:10, 09:20 … until "Done"
                                                     ↓ (shared)
                     Sara taps Done → you get "Sara marked it done — confirm?" → confirm
```

## What is built

| Area | Where | Status |
|---|---|---|
| Hold-to-speak capture (Apple Speech / Android SpeechRecognizer) | `lib/ui/widgets/hold_to_talk_button.dart`, `lib/services/speech_service.dart` | done |
| Sentence → task fields, EN + AR ("every day at 9 pm", "كل يوم الساعة ٩ مساء", "for two weeks", "tomorrow") | `lib/services/voice_parser.dart` + 8 unit tests | done |
| Frequency (once / daily / weekdays / weekly on chosen days / every N days), time, period (start/end), note | `lib/models/task.dart`, `lib/ui/task_editor_sheet.dart` | done |
| Nag-until-done local reminders with a "Done" action, exact-alarm fallback, iOS 64-notification budget | `lib/services/reminder_scheduler.dart`, `lib/models/task_logic.dart` + 9 unit tests | done |
| Personal tasks stored on-device (no account) | `lib/services/local_store.dart` | done |
| Shared tasks: Google / Apple sign-in, invite link shared to WhatsApp/Instagram/anything, join, claim done, creator confirm / reject, leave, push to members | `lib/services/cloud/*`, `functions/src/index.ts`, `firestore.rules` | code done, **needs a Firebase project** (see Setup) |
| Settings: language, reminder permission, precise timing (Android), account, delete account, privacy/terms | `lib/ui/settings_screen.dart` | done |
| Store compliance built in (purpose strings, privacy manifest, Sign in with Apple, account deletion, no login wall, SCHEDULE_EXACT_ALARM only) | `ios/Runner/*`, `android/app/src/main/AndroidManifest.xml` | done — remaining paperwork in `docs/STORE_COMPLIANCE.md` |
| Web app (same code, built with `flutter build web`; hosted on Firebase Hosting from `firebase.json`) | `web/` | done — reminders are the phone app's job, the web app manages and confirms |
| CI: analyze + tests + debug APK + iOS simulator compile + web bundle | `.github/workflows/app.yml` | done |

Research: `docs/MARKET_RESEARCH.md` (monetization, pricing, payouts to Jordan),
`docs/COMPETITORS.md` (free alternatives, the gap, open-source to build on),
`docs/STORE_COMPLIANCE.md`, `docs/PRIVACY_POLICY.md` (EN + AR draft).

## How it works

- **Personal tasks never leave the phone.** They live in one JSON file; reminders are local
  notifications rebuilt from the task list on every change (`syncAll`), so "done" and "reminded"
  can never disagree.
- **A shared task is one Firestore document** read by all its members; each member's phone
  schedules its own reminders from it. The creator writes the document; members go through
  small server functions (`claimDone`, `undoClaim`, `joinTask`, `leaveTask`) so nobody can
  confirm their own work or add strangers. `onTaskWritten` pushes "new task / marked done /
  confirmed / not done" to the right people in their language.
- **The app boots in personal-only mode** until `lib/firebase_options.dart` is replaced by the
  real configuration; choosing *Shared* then says so plainly instead of failing.

## Setup (engineering steps — not for the owner to run)

1. `flutter pub get && flutter test && flutter analyze` — all green today (17 tests).
2. Firebase: create a project, enable Auth (Google + Apple), Firestore (`europe-west2`),
   Functions, Cloud Messaging (upload the APNs key). Run `flutterfire configure` in this folder
   (replaces `lib/firebase_options.dart`; set `isConfigured` to `true` there), then
   `cd functions && npm install && npm run build && firebase deploy --only functions,firestore:rules`.
3. Google Sign-In on Android needs the web client id: `flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=…`
   and the Play App Signing SHA-1/SHA-256 in the Firebase Android app. iOS needs the reversed
   client id URL scheme in `Info.plist` (flutterfire prints it).
4. Invite links: point `INVITE_BASE_URL` (`--dart-define`) at a domain that serves the AASA and
   assetlinks files (checklist in `docs/STORE_COMPLIANCE.md` §B).
5. Builds: GitHub Actions → "I'm Done app (Flutter)" → run → download `imdone-android-debug` or `imdone-web`.
6. Web hosting: `flutter build web --release && firebase deploy --only hosting` publishes to the Firebase project's `*.web.app` address (free tier). Point `imdone.me` at it so the same domain serves the invite links, the privacy page and the app.

## Layout

```
lib/
  main.dart, app.dart          bootstrap, MaterialApp, notification/deep-link plumbing
  l10n/strings.dart            every string, en + ar
  models/task.dart             Task / Completion / TaskMember (+ JSON)
  models/task_logic.dart       due days, occurrences, nag moments, notification ids (pure)
  services/                    local_store, reminder_scheduler, speech_service, voice_parser,
                               settings_store, deep_links, cloud/{cloud,auth,cloud_tasks,push}
  state/                       bootstrap + Riverpod providers + TaskActions
  ui/                          home, editor sheet, tile, detail, sign-in, settings, hold-to-talk
functions/src/index.ts         joinTask, claimDone, undoClaim, leaveTask, deleteAccount, onTaskWritten
firestore.rules                members read, creator writes, everything else via functions
```
