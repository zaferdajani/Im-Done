# Turning on sharing (Firebase) — what is needed, and who does what

Sharing a task needs a Firebase project: it holds the accounts (Google / Apple
sign-in), the shared tasks, and sends the push notifications. Everything in the
code is ready; the project itself has to be created under the owner's Google
account, which is the one step nobody else can do.

## The owner's one-time part (in a browser, about ten minutes)

1. Go to https://console.firebase.google.com, sign in with your Google account,
   and create a project called **imdone** (turn Google Analytics off when asked;
   it is not needed).
2. In the project: **Build → Authentication → Get started → Sign-in method**,
   enable **Google** and **Apple**.
3. **Build → Firestore Database → Create database**, location **europe-west2
   (London)**, start in production mode.
4. **Project settings (gear) → Service accounts → Generate new private key**.
   A JSON file downloads.
5. In the GitHub repository **Im-Done → Settings → Secrets and variables →
   Actions → New repository secret**, add:
   - `FIREBASE_PROJECT_ID` = the project id shown in Project settings
     (usually `imdone` or `imdone-xxxxx`)
   - `FIREBASE_SERVICE_ACCOUNT` = the whole contents of the JSON file from step 4

Then tell Claude it is done. Everything after that is automated.

## What happens after that (automated)

The **Deploy Firebase** workflow generates the app's configuration file,
deploys the server functions and the security rules, and commits the config.
The next app build then has sharing switched on: choosing "Shared" asks for
sign-in, invite links work, and members get notified.

## Still separate

- **Sign in with Apple on iPhone** also needs the Apple Developer account
  (Service ID + key uploaded to Firebase Authentication → Apple). Google
  sign-in works without it, on Android and on the web.
- **Push notifications on iPhone** need the APNs key from the same Apple account
  uploaded under Project settings → Cloud Messaging.
- **Google sign-in on Android** needs the SHA-1 and SHA-256 fingerprints of the
  signing key added to the Firebase Android app; for the CI debug build the
  debug key's fingerprints, later the Play App Signing key's.
