# Performance audit

Audited on 2026-11-02 on `claude/perf`. This repository contains a Flutter
Android/iOS/web client, Riverpod state, Firestore, and a Cloudflare Worker.
There is no React app, SQL database, or root npm build. Scope is deliberately
small: no deployment configuration, live database access, new dependencies,
paid services, or environment file changes.

| # | Item | Status | Reason |
|---|---|---|---|
| 1 | Skeleton loaders | Not applicable | Existing progress indicators cover explicit actions; replacing them with skeletons would change presentation without measured benefit. |
| 2 | WebP/AVIF images | Not applicable | No content image feed; web icons and native launcher assets need their existing platform formats. |
| 3 | Deduplicate API calls | Applied | `/me/plan` reuses the fetched user profile; Riverpod already shares client streams/futures. |
| 4 | Debounce search | Not applicable | No search input issuing requests on keystrokes. |
| 5 | Paginate API results | Not applicable | Current task stream powers all reminders, group operations, and upcoming dates; truncating it would change behavior. |
| 6 | CDN for static files | Recommended (infra) | Verify deployed static asset delivery and cache behavior with the existing host; configuration unchanged. |
| 7 | Background jobs | Not applicable | Voice results are required to open the editor; moving them to jobs requires a new interaction/protocol. |
| 8 | Fix N+1 queries | Not applicable | Push fan-out reads recipient profiles individually; batching needs separate REST/error-semantics work and a measured large-recipient workload. |
| 9 | Brotli/gzip | Recommended (infra) | Measure compression on deployed Flutter bundles; local source cannot verify hosting behavior. |
| 10 | Free caching | Already in place | Certificate fetch requests an HTTP edge cache TTL; Riverpod retains shared state; no Redis added. |
| 11 | Remove unused dependencies | Not applicable | No dependency was verified unused across native, web, and tooling entry points; none removed. |
| 12 | External API timeouts | Applied | All Worker upstream fetches use abort deadlines: 15 seconds normally and 30 seconds for AI; Dart HTTP calls already have deadlines. |
| 13 | Stream AI responses | Not applicable | Voice produces a structured task JSON object consumed atomically, rather than incremental chat text. |
| 14 | Optimistic UI | Already in place | Local task notifier updates state before persistence; Firestore listeners provide local write updates. |
| 15 | Lazy-load images | Not applicable | No scrolling content images or network image widgets. |
| 16 | Parallel independent requests | Applied | `/me/plan` fetches billing configuration and user profile concurrently after obtaining authorization. |
| 17 | DB indexes | Already in place | Current queries use Firestore automatic single-field indexes/index merging; no SQL schema or new query requiring a migration. |
| 18 | Trace slow requests | Not applicable | No latency baseline or tracing sink; avoid adding routine logging of requests containing personal data. |
| 19 | Servers near DB | Recommended (infra) | Measure Worker-to-Firestore latency and review regional placement before making infrastructure decisions. |
| 20 | SSR/static rendering | Not applicable | Stateful Flutter application with native clients; an SSR conversion is a rewrite. |
| 21 | Defer third-party scripts | Already in place | Web entry point loads the Flutter bootstrap asynchronously and contains no third-party script tags. |
| 22 | Route code splitting | Not applicable | No React routes; Flutter deferred imports require a separate web/native compatibility and bundle investigation. |
| 23 | Virtualize long lists | Not applicable | No measured long-list workload; home uses eager widget lists, with builder/sliver conversion deferred until Flutter validation is available. |
| 24 | Select needed columns | Not applicable | Client Firestore snapshots deserialize complete task documents; there are no SQL `select('*')` calls. |
| 25 | Connection pooling | Not applicable | SDK-managed Firestore connections and Worker fetch; no application-owned SQL connection pool. |
| 26 | Avoid unnecessary rerenders | Already in place | Riverpod provider boundaries and const widgets provide existing controls; no broad rebuild rewrite without profiling. |
| 27 | Browser cache headers | Recommended (infra) | Verify versioned bundle caching and prompt entry-point updates at the host; deployment configuration unchanged. |
| 28 | Load balancing | Recommended (infra) | Hosting platforms manage request distribution; assess only if measured traffic warrants changes. |
| 29 | Self-host fonts/limit weights | Not applicable | No external font stylesheet or configured custom font family; preserve Flutter defaults and multilingual fallback. |
| 30 | Free real-user monitoring | Not applicable | No existing browser metrics endpoint; web-vitals alone would not measure native Flutter frame performance. |
| 31 | Slow device/network testing | Applied | Added a deterministic stalled-upstream/cancellation test; physical-device and browser throttling checks remain pending. |

## Changes and limits

`push-worker/src/http.mjs` supplies a shared deadline signal, retaining request
options (including certificate cache settings) and caller cancellation. The
signal stays active through response consumption. Existing provider fallback
and error paths remain in charge; writes and push sends are never retried by
the helper. A timed-out write can still have reached the upstream server.
Deadlines bound each upstream operation, not the entire transcription pipeline:
multiple model fallbacks can still exceed the client's existing 40-second limit.
No authenticated user or entitlement data is cached across requests.

The plan endpoint removes one Firestore profile read per request and overlaps
its two independent reads. Membership checks and entitlement lookup remain
ordered as before. No measured end-to-end speedup is claimed.

## Validation

- Baseline: `npm test --prefix push-worker` passed all 3 existing test files.
- After changes: the same command passes all 4 test files, including deadline,
  stalled body, request option preservation, and caller cancellation coverage.
- `node --check` passes for Worker source and tests; `git diff --check` passes.
- `flutter analyze --no-fatal-infos`, `flutter test`, and
  `flutter build web --release` were attempted but cannot run: Flutter/Dart SDKs
  are unavailable in this environment. No Flutter source was changed.
- `npm test --prefix tests/rules` was attempted but cannot run: Firebase CLI is
  unavailable. No live database connection or rules deployment was attempted.
- The npm packages define no lint, typecheck, or build scripts. Worker JavaScript
  syntax checks and its existing Node test runner are the available checks.
- Local commits were attempted but `.git` is mounted read-only: Git cannot create
  `.git/index.lock`. No commits, pushes, or remote changes were made.

## What's left

1. Run Flutter analysis, tests, and release web build in an SDK-equipped checkout;
   run Firestore rules tests with the local emulator tooling installed.
2. Profile home-screen startup and scrolling with hundreds of tasks on a slow
   Android phone and browser CPU/network throttling. If list construction is a
   bottleneck, convert sections to lazy slivers while preserving ordering and
   the complete task collection used by reminders and group actions.
3. Measure push fan-out, authentication, and transcription phase latency before
   introducing bounded concurrent sends, batched profile reads, or a whole-request
   voice budget. Exercise stalled headers/bodies in a real Worker runtime too;
   the unit transport is mocked because this sandbox disallows listening sockets.
4. Verify static asset compression, cache headers, CDN delivery, regions, and
   load distribution on the deployed host. Consider free browser-only vitals
   logging after measuring the Flutter-specific startup/frame metrics separately.
5. In a writable Git checkout, commit the Worker change/tests and this audit as
   small `perf:` commits. Nothing has been deployed or applied to a database.
