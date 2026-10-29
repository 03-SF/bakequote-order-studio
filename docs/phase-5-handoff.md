# Phase 5 — Customer order requests

Date: 2026-10-29. Starting checkpoint was clean `ea5966f`. Phase 5 implementation is delivered; full multi-account live acceptance remains blocked. Stop before Phase 6. Flutter remains the English-only Android/iOS product; Chrome is a development verification target.

## Implemented workflow

An authenticated customer opens an active bakery, chooses **Customize request**, and uses four steps: product/customization, date/fulfilment, contact/design, review/submit. Back retains input. Current catalog variants, optional flavour/finish, distinct extras, quantity, cake message, date, pickup/delivery zone/address, contact details, instructions and private images are supported. The existing calendar supplies eligible bakery service dates without shifting them to the device timezone.

Review saves the draft and requests an authoritative itemized PKR estimate. Submission validates the current active business/product/options, minimums, fulfilment, date and attachment ownership again. A changed catalog/price requires another review; rejection preserves input. Product subtotal and delivery are separate. Pending is explicitly **not confirmed** and reserves no capacity.

Customer Orders and baker Orders now show real request lists and immutable details, including reference, initial quote, event, service date/timezone, configuration, contact/design information and private attachments. Exact pickup address is included only in the participant request snapshot, not public discovery. Lists use 20-row UUID keyset pages and explicit refresh. Past is honestly empty while Phase 6 transitions do not exist. No confirmation, quote revision/agreement, production, automatic messaging or allowance workflow was implemented.

## Draft and retry contract

- One open server draft per authenticated account and bakery. The server owns its UUID; a unique partial index plus profile lock prevents duplicate creation. A submitted draft can explicitly start another request.
- Every edit is cached under a project/account/bakery key. **Save draft** and **Review** synchronize to Supabase with a revision check. The local cache is SharedPreferences/browser local storage, not encrypted storage or a cross-device promise. Server-saved drafts reopen from the same bakery/product entry on another installation. Native storage acceptance is deferred.
- Changing bakery opens that bakery's separate draft. Choosing a different product explicitly asks before replacing size/options; contact/design information stays. Removed/inactive options require refresh and correction. Reloading the server draft explicitly asks before discarding local edits. A revision conflict never silently overwrites another edit.
- Before submission, the client persists an uncertain-outcome marker. A timeout leaves input frozen with **Check submission status** and **Retry same submission**. It never queues an offline authoritative write. The server uses draft UUID plus review token: identical retries return the same order; changed tokens/content require review or are rejected. The draft is marked submitted only in the creation transaction.
- Repository session checks and controller epochs prevent late work restoring another account's state. Local data is partitioned, not claimed erased from disk; clearing browser/device storage can lose unsynchronized edits and upload cleanup intents.

## Database and private images

[Migration 007](../supabase/migrations/20261029000100_customer_requests.sql) adds `request_drafts`, `order_requests`, `request_quotes`, `request_events`, `request_uploads`, `request_attachments`, ownership indexes, RLS and restricted functions. Direct client mutation is revoked. Internal snapshot validation cannot be executed by client roles. Security-definer functions use an empty search path and check authenticated ownership.

Draft save uses optimistic revisions. Review/submit lock the draft then the business; catalog/availability writers use the same business lock. Submission atomically inserts the request, initial estimate version 1, requested event and attachment membership, then marks the draft submitted. A late event failure rolls everything back. References are server-generated UUID-based strings, not client counters. Historical labels, units, selections, integer paisa and fulfilment/contact information are frozen; future catalog edits do not recompute them. Phase 6 must add real allocation/order foreign keys, authoritative transitions and concurrent confirmation tests; this phase deliberately writes no allocation.

Reference paths are `<auth-user-uuid>/<draft-uuid>/<object-uuid>.<jpg|png|webp>` in the private `order-references` bucket. Existing 5 MiB/JPEG/PNG/WebP bounds are retained. Maximum **three images per draft** is a provisional implementation default requiring owner review, not a commercial storage allowance. Client byte signatures and bucket MIME/size restrictions are separate checks; no server content scanner is claimed.

Upload intent is cached before registration/upload. Registered unsent objects are visible only to their customer; submitted objects are readable by the customer and owning baker. Other users cannot attach a supplied foreign path. Images are immutable; replacement is new upload plus removal. Cleanup first reconciles the authoritative draft, never deletes a submitted attachment, and retires unreferenced paths under the same draft lock. A tombstone makes delayed registration retries unable to revive cleaned paths. Cleanup is explicit/best-effort, not an automatic retention schedule. Device-cache loss may leave orphans requiring a future authorized server job. Failed uploads offer retry; after restart unavailable local bytes must be selected again. UI progress is indeterminate, not a fabricated percentage. Conversation attachments remain denied.

## Actual verification

| Layer | Actual result | Limit |
| --- | --- | --- |
| Flutter | Full suite: 67 passed; final focused request suite: 10 passed | Domain/controller/widget and mocked HTTP/local preferences; not live service proof |
| Formatting / analysis | 50 files formatted without changes; analysis clean before final async guard refinement; final check recorded in integration table | No device accessibility claim |
| Python | 10 setup tests passed; new runners compile | Prepared three-account runner has not run beyond preflight |
| PostgreSQL | 114 checks passed across all seven migrations in PGlite | Modeled Auth/Storage schemas, not actual Storage services or concurrent multi-connection stress |
| Development deployment | Sole pending migration inspected by dry run, applied without reset; all seven local/remote versions match | Development only |
| Live ordinary customer + anonymous HTTP | 20 checks passed | Endpoint/grant/negative checks only; missing-target denial is not proof about another real account's record |
| Builds | Release Web built; Android debug APK compiled | Final rebuild/check evidence is in integration verification; APK not installed |
| Chrome | Login, reload and live request empty state observed; expanded regression final result in integration verification | Positive builder/customer-to-baker journey requires baker fixture |
| Full three-account acceptance | BLOCKED | No BQ_TEST customer/baker credentials in the runner environment; separate existing customer fixture works. Dedicated verified Baker A/B missing |
| Native | DEFERRED | Android installation/callbacks/native image picker/storage/permissions/lifecycle/device; iOS build/signing/device; push is future scope |

SQL tests include PKR 4,100, current availability rejection after review, stale price rejection, rollback with an injected event failure, exact duplicate retry, historical snapshots, other-baker private reads, attachment restrictions and abandoned cleanup. Flutter tests include backward navigation at 200% text/390 logical-pixel width, restart/account/project cache isolation, lost submission response, duplicate taps, stale results and upload failure/retry.

See the authoritative [integration evidence table](integration-verification.md) for final results, including any test-harness corrections. No real email was sent in this phase. Confirmation stays enabled. Previously received email is historical delivery evidence; browser verification/reset round trips remain outstanding.

## Run and demonstrate

From the repository directory, with the existing ignored configuration:

```powershell
flutter pub get
flutter run -d chrome --web-port 7357 --dart-define-from-file=config/web.local.json
```

For deterministic laptop acceptance, use two terminals:

```powershell
# Terminal 1, mobile directory
flutter build web --release --dart-define-from-file=config/web.local.json
python scripts/serve_flutter_web.py
# Terminal 2, same directory
python scripts/verify_web_account.py
python scripts/verify_phase5_single.py
```

Preview remains separate: `flutter run -d chrome --web-port 7358 --dart-define=APP_MODE=preview`. Preview does not submit real requests. Exact native/browser callback configuration remains in [backend setup](backend-setup.md).

1. Sign in as a dedicated verified baker. Activate a complete bakery/catalog and configure an available date. For the regression demo only, explicitly configure base PKR 3,000, finish 500, topper 300 and delivery 300. Do not seed real businesses automatically.
2. In a separate customer Chrome session, open that code, select the cake and **Customize request**. Select size/finish/topper, eligible date and delivery zone. Fill contact/address/design, upload a private image and save.
3. Reload and reopen the same product: the unsent draft must restore. Review: subtotal PKR 3,800, delivery 300, total 4,100. Change the price or block the date in the baker session before submitting to verify rejection/re-review without losing input.
4. Restore eligibility, review again and submit. Open the persisted Pending request from Orders. Reload/sign in again and compare its snapshot. Repeating the exact submission must return one order.
5. Baker A opens Orders and the same request/image. Baker B must see neither; direct denial tests must compare the original record/bytes afterward. No enabled Phase 6 actions should appear.
6. Test offline save/upload and uncertain submission with controlled network interruption. No success appears without authoritative persistence; exact retry recovers rather than duplicates.

Use [secure local prompts](integration-verification.md) for `BQ_TEST_CUSTOMER_EMAIL/PASSWORD`, `BQ_TEST_BAKER_A_EMAIL/PASSWORD`, `BQ_TEST_BAKER_B_EMAIL/PASSWORD`. Run:

```powershell
python scripts/verify_cross_account.py --preflight-only
python scripts/verify_cross_account.py
python scripts/verify_phase5.py --preflight-only
python scripts/verify_phase5.py
```

The last runner intentionally retains one Pending development request/reference for browser inspection, refuses to overwrite an existing unsent draft and requires a suitable active dedicated catalog. It never changes account roles or confirms email administratively. Default sender restrictions may require authorized SMTP for extra inboxes; do not disable confirmation or grant organization admin access for test mail.

## Outstanding gates and checkpoint

Full live customer/baker persistence, positive reference upload/signing, two-baker privacy, true concurrent transaction tests and interactive builder acceptance remain unverified until accounts/fixtures are available. Native acceptance, actual browser email/recovery callbacks, performance targets, server orphan retention, dual-role enrollment, scheduling semantics and previously exposed privileged-key rotation confirmation remain open. None is represented as passed.

The requested local commit preserves history; obtain it with `git log -1 --oneline`. No Git remote is configured and no remote backup is claimed. Stop before Phase 6.
