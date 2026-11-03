# Data retention jobs (Firebase)

This app uses Firebase, not Postgres, so the "pg_cron" retention jobs are expressed as **Firestore TTL
policies** (apply once, owner action — nothing here touches a live project from this repo).

| Data | Rule | Mechanism |
|---|---|---|
| `reports/*` (moderation) | delete 12 months after creation | client writes `expireAt` (+365d) in `CloudTasks.reportUser`; TTL on `expireAt` |
| `usage/{uid}/days/*` (voice counter) | delete 35 days after last update | worker writes `expireAt` (+35d); TTL on `expireAt` |
| Voice audio | never stored | processed in memory in `push-worker` |
| Account + shared data | on user request | Settings → Delete my account (`eraseEverythingOf`) |
| Inactive accounts (24 months) | delete | **owner job** — see below |

## Apply the TTL policies (owner, once per project)
```
gcloud firestore fields ttls update expireAt --collection-group=reports --enable-ttl --project=<PROJECT_ID>
gcloud firestore fields ttls update expireAt --collection-group=days    --enable-ttl --project=<PROJECT_ID>
```
(Documents written before this change have no `expireAt`; they stay until deleted by hand. TTL deletion
runs within ~24 h of expiry.)

## Inactive accounts
Firebase Auth has no built-in expiry. Either run, at least quarterly, an Admin SDK script that lists users
with `metadata.lastSignInTime` older than 24 months, then calls the same erase steps as
`eraseEverythingOf` and `auth.deleteUser`; or remove the 24-month sentence from the privacy policy.

## Storage files (account deletion)
The app uses **no Firebase Storage / Cloud Storage** (`firebase_storage` is not a dependency; voice audio
is never persisted), so there are no user files to delete. If Storage is ever added, store files under
`users/{uid}/…` and delete that prefix in `CloudTasks.eraseEverythingOf`.
