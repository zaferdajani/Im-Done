# Doneby — Store Compliance Checklist (App Store + Google Play)

*Compiled 2026-09-12 against the current guidelines. Each row says how THIS codebase satisfies
it, or what is still owed before submission. "verify" = confirm at submission time.*

**Dates in force:** Apple Xcode 26 / iOS 26 SDK mandatory since 28 Apr 2026. Apple age-rating
questionnaire required since 31 Jan 2026. Play targetSdk 36 mandatory since 31 Aug 2026.
Play 16 KB page size since 1 Nov 2025. Android developer verification first enforcement
30 Sep 2026 (four countries), global 2027.

## A. Built into the code (done)

| Requirement | How Doneby satisfies it | Source |
|---|---|---|
| No login wall (Apple 5.1.1, Play User Data) | Personal tasks, voice capture and reminders work with no account. Sign-in is asked only when a task is switched to *Shared* or an invite link is opened. `lib/ui/task_editor_sheet.dart`, `lib/app.dart` | [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/) |
| Sign in with Apple when other third-party login is offered (Apple 4.8) | Google + Apple, both wired in `lib/services/cloud/auth_service.dart`; Apple button shown on iOS; entitlement in `ios/Runner/Runner.entitlements` | same |
| In-app account deletion (Apple 5.1.1(v), Play policy since 2024) | Settings → Delete my account → `deleteAccount` Cloud Function erases owned tasks, memberships, invites, profile, tokens, then the Auth user. `functions/src/index.ts` | [Apple](https://developer.apple.com/news/?id=12m75xbj), [Play](https://support.google.com/googleplay/android-developer/answer/13327111) |
| Microphone purpose string (`NSMicrophoneUsageDescription`) + speech (`NSSpeechRecognitionUsageDescription`) | Specific, honest strings in `ios/Runner/Info.plist`, Arabic in `ar.lproj/InfoPlist.strings` | Apple 5.1.1 |
| Recording consent + visible indicator (Apple 2.5.14) | Own explanation dialog before the OS prompt; pulsing coral mic + live transcript while recording. `lib/ui/widgets/hold_to_talk_button.dart` | same |
| Prominent disclosure before RECORD_AUDIO prompt (Play User Data) | Same dialog, shown once, tracked in settings | [Play](https://support.google.com/googleplay/android-developer/answer/10144311) |
| `POST_NOTIFICATIONS` asked in context, never at launch | Asked after the first task is saved, with an explanation dialog | [Android](https://developer.android.com/develop/ui/compose/notifications/notification-permission) |
| Exact alarms: `SCHEDULE_EXACT_ALARM` (user-granted), NOT `USE_EXACT_ALARM`, NOT `USE_FULL_SCREEN_INTENT` | Manifest declares only `SCHEDULE_EXACT_ALARM`; app checks `canScheduleExactNotifications()` and falls back to inexact; Settings offers the grant. No full-screen intent anywhere | [Play](https://support.google.com/googleplay/android-developer/answer/16558241) |
| No unused background modes (Apple 2.5.4) | Only `remote-notification` (push for shared tasks). Reminders are local notifications, no background execution | Apple 2.5.4 |
| iOS 64 pending-notification cap | `ReminderScheduler.syncAll` schedules soonest-first within a budget of 58 | `lib/services/reminder_scheduler.dart` |
| Push must not be required; no marketing push (Apple 4.5.4) | Push is used only for shared-task events; every feature works without it | Apple 4.5.4 |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in Info.plist (HTTPS only) | [Apple](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption) |
| Privacy manifest (`PrivacyInfo.xcprivacy`) with required-reason APIs | Declares email, name, user ID, device ID (push token), user content; UserDefaults CA92.1, file timestamps C617.1; tracking = false | [Apple](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) |
| Third-party SDK manifests/signatures | Firebase, Google Sign-In and Flutter plugins at current versions ship their own manifests; run `find ios/Pods -name PrivacyInfo.xcprivacy` after `pod install` to confirm (verify) | [Apple](https://developer.apple.com/support/third-party-SDK-requirements) |
| targetSdk 36, 16 KB pages | Flutter 3.47 defaults: compileSdk/targetSdk 36, minSdk 24; AGP 9.1 + current NDK build 16 KB-aligned libraries | [Play](https://support.google.com/googleplay/android-developer/answer/11926878) |
| Arabic + RTL | Every string in `lib/l10n/strings.dart` has en + ar; Material localizations for ar; RTL from the locale | Play pre-launch accessibility |
| Speech data handling | Audio goes to the OS recogniser (Apple Speech / Android SpeechRecognizer) and is never written to disk or sent to Doneby's backend; only the transcript text is kept | Data safety / App Privacy |
| Deep links | Android App Links intent filter with `autoVerify` for `https://doneby.me/j/*` + `doneby://join`; iOS associated domain `applinks:doneby.me` + URL scheme | see B |
| Age rating / Kids | No child-directed content; do not opt into Families or Kids categories; target 4+ | Apple age ratings 2026 |

## B. Owed before the first submission (not code)

- [ ] **Apple Developer Program** ($99/yr) — individual needs no D-U-N-S; a company needs one.
  Then App Store Connect → Business: sign the Paid Applications Agreement, add bank + tax
  (W-8BEN). **Check Jordan is selectable as bank territory** (see MARKET_RESEARCH §4).
- [ ] **Google Play Console** ($25) + identity verification. Personal accounts created after
  Nov 2023 must run a **closed test with 12 testers for 14 days** before production
  ([Play](https://support.google.com/googleplay/android-developer/answer/14151465)). Plan ~3 weeks.
- [ ] **Firebase project** (Auth: Google + Apple providers; Firestore in `europe-west2`; Cloud
  Functions; Cloud Messaging with APNs key). Then `flutterfire configure` to replace
  `lib/firebase_options.dart`, add the Play App Signing SHA-1/SHA-256 to the Firebase Android
  app, set `GOOGLE_SERVER_CLIENT_ID` at build time, deploy `functions/` and `firestore.rules`.
- [ ] **Domain `doneby.me`** (or whatever is chosen) serving: `/.well-known/apple-app-site-association`
  (JSON, no extension, no redirect), `/.well-known/assetlinks.json` (SHA-256 of the **Play App
  Signing** key, not the upload key), `/j/<code>` landing page that opens the app or falls back to
  the store listing, `/privacy`, `/terms`, `/delete-account` (Play requires a web deletion route).
- [ ] **Privacy policy + Terms** hosted at public HTTPS URLs, EN + AR — draft in `docs/PRIVACY_POLICY.md`.
- [ ] **App Privacy (Apple) / Data safety (Play) forms**, consistent with the build:
  *Email, Name, User ID* (account, only if the user signs in), *Device ID* (push token),
  *User content* (task text), all "not used for tracking", encrypted in transit, deletable.
  **Audio:** declare voice as processed but not collected only if the final speech path is
  on-device; Android's `SpeechRecognizer` and Apple's server recognition may route audio through
  Google/Apple — say so in the policy (verify against the shipping build; this is the most
  commonly mis-declared item for voice apps).
- [ ] **Demo account in review notes** (Apple 2.1): a Google-authenticated test account already
  inside a populated shared task, and a note that personal features need no login.
- [ ] **Screenshots** showing voice capture, the nag, and a shared task with the confirm card —
  not the login screen (Apple 2.3.3, 4.2 minimum functionality). Full Arabic listing.
- [ ] **Metadata:** name ≤ 30 chars, subtitle ≤ 30, keywords ≤ 100 chars, no competitor names,
  no "#1" claims, no emoji spam (Apple 2.3.7, Play metadata policy).
- [ ] **Build with Xcode 26 / iOS 26 SDK** (CI workflow uses latest stable Xcode on macOS 15).
- [ ] **Signing:** Android upload keystore as a GitHub secret + `assembleRelease`/AAB; iOS
  distribution certificate + profile. The `aps-environment` entitlement flips to `production`
  automatically on App Store builds.
- [ ] **Play pre-launch report** on every release (crashes, RTL layout).
- [ ] **Subscriptions (when Pro ships):** StoreKit / Play Billing only (Apple 3.1.1); paywall
  shows price, period, trial length and that it converts, plus working Terms + Privacy links
  (Apple 3.1.2, Play subscription policy). RevenueCat handles receipts and entitlements.

## C. Cross-cutting law

- **Jordan PDPL 24/2023**: explicit consent for collection, breach notification, adequate
  protection for transfers — the Firebase region is London (adequate for Jordan's regime as
  argued in the TeamManager regulatory assessment); disclose it in the policy.
- **GDPR / UK GDPR** if EU/UK users: lawful basis, Firebase Data Processing Terms, access and
  erasure (the deletion function is the erasure route).
- **CCPA**: state plainly that data is not sold or shared for advertising.
- **COPPA**: general-audience rating, no child-directed marketing.

## D. Common rejections for to-do apps, and the countermeasure

| Rejection | Countermeasure in Doneby |
|---|---|
| Apple 4.2 not enough functionality | Voice capture, nag-until-done, shared confirmation, Arabic — all visible in screenshots and review notes |
| Apple 2.1 crashes / incomplete | Real device test on an IPv6-only network, backend live, demo account |
| Apple 4.8 | Sign in with Apple present beside Google |
| Apple 5.1.1(v) | Deletion button two taps from the home screen (Settings → Account) |
| Play permissions block | No `USE_EXACT_ALARM`, no `USE_FULL_SCREEN_INTENT`, no foreground service |
| Play Data safety mismatch | Re-audit the form against the build every release, especially audio |
| Play account-deletion policy | In-app button AND the public web route |
