# Current project status - Phase 5 progression in local implementation

## Phase 5–6 continuation

Fixed a missing Pending withdrawal action after customer agreement. Thirteen focused request tests, 75 full Flutter tests, 16 Python setup tests, 141 modeled SQL checks, formatting and analysis passed; the live-configured Web release and Android debug APK built. No APK installation, hosted acceptance or browser workflow acceptance was performed. An open rescheduling integrity defect was identified: changing the service date does not update the order due timestamp. Phase 6 is not complete and existing data/settings were not changed. Verified dedicated Customer/Baker A/B credentials and bakery are still required for real acceptance. Native acceptance remains deferred.

## Verification callback investigation (2026-10-30)

Missing PKCE verifier errors now explain browser-state recovery, and profile/database, Auth and network errors have distinct sanitized feedback. The user-reported live failure has not been reproduced, so its precise root cause and confirmation status remain unknown. Focused auth suite: 26 passed; full Flutter suite: 74 passed; formatting and analysis passed; live-configured Web release and Android debug builds passed. No email was resent, no live callback acceptance or native installation was performed. The existing listener on port 7357 predates this Web build; restart it before using the updated code. See [integration verification](integration-verification.md) for the specific evidence and blockers.

## Current all-phase audit continuation

The live onboarding form previously preselected Customer; it now requires an explicit Customer/Baker choice and shows a validation message until selected. Existing identity records and the unresolved dual-role policy are unchanged. Focused authentication widgets: 4 passed; full Flutter suite: 71 passed; formatting and Flutter analysis passed; Android debug APK compiled without installation. These are local checks, not live first-time onboarding acceptance. The phase matrix now includes phases 1–4 and 3A as well as later-phase gaps. Conversation attachment uploads and account deletion remain incomplete; real Customer/Baker A/B acceptance is blocked by missing registered baker accounts and recent Auth rate limiting. Native acceptance remains deferred. No release approval is claimed.

## Approved lifecycle and account preparation (2026-10-29)

The owner chose Confirmed → Baking → Ready → Delivered. Forward migration `20261029000800_original_production_lifecycle.sql` was dry-run inspected and applied to the linked development project without data reset; fourteen local/remote migration versions match. New transitions into Decorating are denied. Existing Decorating rows/history remain untouched, continue consuming capacity and may transition to Ready. Flutter domain and baker UI follow both paths.

Local modeled PostgreSQL: **141 checks passed**, including original transitions, legacy capacity/history and idempotency. The final full Flutter suite passed **70 tests**, including the lifecycle widget test. Formatting, analysis, SQL parsing and 16 Python setup tests passed. Web and Android debug builds succeeded; no APK was installed. The PowerShell account helper parsed successfully. The existing customer was confirmed through normal login and Customer onboarding; previous email delivery is separate evidence. Dedicated Baker A/B credentials are not yet available, so no positive Phase 5–6 multi-account acceptance has run. Rotation of the exposed Supabase secret key is not yet verified. See [phase completion and secure setup](phase-completion-matrix.md). Android/iOS device acceptance remains deferred; do not start another feature phase.

## Scope reconciliation and core acceptance (2026-10-29)

The authoritative [Phase 5–10 completion matrix](phase-completion-matrix.md) distinguishes foundations, missing/disabled work, actual live evidence and external blockers. English-only; offline functionality excluded. Preserve session persistence, unsent-input recovery and safe retries. Mandatory Decorating was introduced after the original reference lifecycle and remains an unresolved owner decision; existing data is preserved.

Starting checkpoint `f057a16` was clean. The linked development project still matches thirteen local migration versions. This continuation added five meaningful modeled PostgreSQL quote revision/history/agreement checks: **135 passed**. The setup suite has **15 passing** tests including the new Phase 6 preflight, credential-safe error parsing and linked-project safety checks. Analysis and formatting passed; the Web release build succeeded, and seven Chrome checks passed with the existing customer: login, protected home, reload, request list/Past empty state, failed-save input recovery, acknowledged profile restore and logout/route guard. **22 limited customer/anonymous HTTP checks** were rerun and passed. The three-account environment preflight remains blocked; the newly prepared Phase 6 runner has **not** executed live. The 68 Flutter tests from the previous checkpoint remain historical, not new two-baker acceptance. No native acceptance or emulator installation was attempted.

The prior Supabase secret API key exposure remains unresolved until an owner/operator confirms rotation/revocation; never paste the key in chat. Phase 5 and Phase 6 do **not** meet their acceptance criteria. The next milestone is a dedicated verified customer/two-baker laptop run plus the lifecycle policy decision. Release remains not approved.

## Current release audit and integrity repair (2026-10-29)

The current tree is **not release complete**. Later Phase 5–10 sources build on `ea5966f` and are preserved in the subsequent local checkpoint. The linked development project has thirteen matching migrations, including a tested, forward-only repair for the broken Storage gate, confirmation agreement/replay authorization, Decorating capacity, bakery-timezone due times and manual-order replay isolation. The incomplete deletion endpoint/control is disabled; conversation uploads remain closed. The original report that the CLI was unavailable is superseded by this observed deployment.

130 modeled SQL checks and 22 limited live customer/anonymous checks passed; ten Python setup tests and 68 Flutter tests passed. Formatting, analysis, SQL parsing and local release gates passed. An Android debug APK compiled in 113.9 seconds without installation. Release approval is blocked. Full cross-account, hosted concurrency and positive order/image acceptance remain blocked by verified Baker A/B identities. Billing providers, encrypted backup/restore and actual deletion worker are **missing implementation**, not merely external test blockers. Native Android/iOS acceptance remains deferred. See [release readiness and exact gaps](release-readiness-gap-analysis.md). Earlier completion statements below describe partial foundations and are superseded wherever they conflict with this audit.

Latest Phase 5 progression update (2026-10-29): the forward-only
`20261029000200_order_progression.sql` migration adds immutable quote revision
metadata, customer agreement records, atomic baker confirmation, monthly
first-confirmation usage enforcement, idempotent operation keys, append-only
order events, and strict production transitions through Decorating and
Delivered. The typed client adapter, detail-screen quote/agreement/confirmation
actions, lifecycle buttons and participant event display are wired without
replacing the Phase 4 request flow. The migration is deployed to the linked
development project. SQL parsing passed, Flutter analysis is clean, and the
full local Flutter suite passes (68 tests). Database-boundary concurrency
checks and customer/baker live acceptance are still pending.

Latest Phase 6 update (2026-10-29): local baker operations now include a
forward-only `20261029000300_baker_operations.sql` migration, timezone-aware
Today queries, private bakery contacts, atomic manual confirmed orders with
usage/capacity enforcement, baker-only notes and recorded advances,
rescheduling, and cancellation request resolution. The existing Calendar
availability panel remains intact and the baker Today surface now separates
confirmed production from pending requests. Quick Add and contact forms are
wired locally. The migration is deployed to the linked development project.
Database-boundary tests and live baker acceptance remain pending; Phase 6 is
not yet a hosted acceptance-complete milestone.

Latest Phase 7 update (2026-10-29): communication and moderation are now
include the forward-only `20261029000400_communication_moderation.sql`
migration. App orders have participant-only conversations, idempotent
client-message IDs, server sequencing, message length/attachment limits,
unread cursors, durable notifications, delivered-order reviews, participant
reports, and blocking. Manual orders cannot create conversations. The order
detail route includes the conversation/report/block panel. SQL parsing,
formatting, Flutter analysis, and the full local Flutter suite pass. The
migration is deployed to the linked development project. RLS/concurrency
checks, attachment upload acceptance, and live two-account
communication/moderation acceptance remain pending. Phase 7 is implemented but
not hosted acceptance-complete until those checks pass.

Latest Phase 8 update (2026-10-29): online synchronization and conflict
recovery are locally implemented through the forward-only
`20261029000500_synchronization.sql` migration. Existing append-only order
events now have a monotonic feed cursor, and authenticated participants can
page changes without receiving unrelated orders. The order detail screen
provides an explicit server refresh that advances its cursor only after a
successful response. Existing version checks reject stale writes, while
stable UUID operation IDs make lost-response command retries idempotent.
Commands remain online-only; no parallel offline application or silent
last-write-wins behavior was added. The migration is deployed to the linked
development project. SQL parsing, formatting, analysis, and the Flutter suite
pass. Stale-version concurrency, lost-response and second-device
demonstrations remain pending.

Latest Phase 9 update (2026-10-29): the local billing and lifecycle foundation
is implemented through `20261029000600_billing_lifecycle.sql`. Store
transactions and entitlements are server-owned, transaction IDs are unique,
expiry/revocation/grace states are represented, and no client path can grant
Pro. Authenticated users can request a scoped account snapshot and request
deletion after recent-session confirmation; active orders block deletion and
cleanup jobs are idempotent and retry-oriented. Account controls are wired
into the live Account screen. The migration is deployed to the linked
development project. Store purchase adapters, provider callbacks,
encrypted backup/restore, media cleanup workers, and actual Auth deletion
remain externally dependent and are explicitly not simulated. Phase 9 is
deployed as a server-owned foundation but not commercially or hosted
acceptance-complete.

Latest Phase 10 update (2026-10-29): the release-candidate validation phase
now has a reproducible `scripts/release_candidate.py` gate for formatting,
analysis, Flutter tests, SQL parsing, optional web/APK builds, and config
safety. It emits a local JSON report and intentionally returns
`NOT_APPROVED` while hosted AT01–AT24 evidence, provider verification,
backup/restore recovery, deletion workers, performance measurements, and
native-device coverage are unavailable. The acceptance matrix and release
decision are documented in [release-candidate.md](release-candidate.md).

Latest Phase 4 update (2026-10-28): availability/calendar/settings/blocking, public availability/fulfilment, shared browser link destination and server-persisted recent bakeries are implemented. All six migrations match remotely after safe deployment. 57 Flutter tests and 81 modeled SQL checks passed; nine new limited live HTTP checks and six refreshed Chrome regression cases passed with the confirmed customer. Web debug build, formatting and analysis passed. Dedicated verified Baker A/B sessions are still missing, so full cross-account and positive baker/customer Chrome acceptance remain blocked. See [current handoff](phase-4-handoff.md) and [verification](integration-verification.md). Scheduling defaults are explicitly provisional; dual-role remains unresolved. Native acceptance is deferred. Stop before Phase 5. This work is being saved as the requested local Git checkpoint; no remote is configured. Older partial/uncommitted implementation notes below are historical.

Current update (2026-10-28): development Supabase is linked and all five migrations are deployed. Laptop verification passed 53 Flutter tests, 10 Python setup tests, 56 modeled PostgreSQL checks, 15 single-account live HTTP checks, six limited discovery endpoint checks and six live Chrome cases. Formatting/analysis and the Flutter Web debug build passed. Browser callbacks are now allowlisted separately; a read-only CLI diff confirms zero declared configuration changes outstanding and email confirmation remains enabled. Actual browser email verification/recovery round trips remain untested.

**Integration remains partially verified.** Dedicated verified Baker A/B accounts are still required for cross-account restrictions, positive business/catalog/pricing/image persistence and account switching. Native callbacks/storage/permissions/push/device acceptance are deferred, not passed; emulator installation retries stopped. The [current verification matrix](integration-verification.md#current-result-2026-10-28-laptop-verification) is authoritative; older entries below are historical and their missing-configuration statements are superseded.

The owner authorized Phase 4 after laptop checks pass or exact blockers are documented. Customer code/pasted-link discovery, approved public profile/menu and saved bakeries are implemented with bounded queries and ownership enforcement. Availability remains pending explicit lead-time/timezone/capacity decisions; Phase 4 is partial and Phase 5 has not begun. See [Phase 4 handoff](phase-4-handoff.md). The product remains English-only Flutter for Android/iOS; web is a development verification target.

Current source checkpoint remains `886ed70`; subsequent changes are local and uncommitted. No Git remote or remote backup is configured. A privileged key previously exposed in chat requires owner-confirmed rotation; it was not used for user-permission tests.

## Historical status and checks

Final Phase 4 compile evidence: Android debug APK built in 83.4 seconds, without installation or emulator attempts. Web debug build and six live Chrome regression cases passed. Ten setup-validator tests passed. The requested checkpoint includes the previously uncommitted laptop setup/discovery work as well as availability; ignored account/client configuration is excluded. Git remote remains absent.

Latest update (2026-10-27): CLI authentication and development linking succeeded. All four migrations deployed without reset and remote history confirmed. Read-only deployed inventory confirms RLS on all six public tables, restricted function execution and all five correctly configured storage buckets. Anonymous private profile/business requests return HTTP 401. Live Android APK built, but initial streamed installation failed. Full user-session/email/device verification remains pending. The latest table in [integration verification](integration-verification.md) supersedes older missing-config/login/deployment observations below.

Latest live integration attempt: **blocked, not verified**. See [integration verification](integration-verification.md) for the per-scenario actual-result matrix and [owner setup guide](hosted-development-setup.md) for exact actions. An ignored empty live configuration template is now prepared. CLI discovery still returns `AccessTokenRequiredError`; no linked development project or Docker/Podman stack is available. Both HTTP runners now validate inputs and report actionable `BLOCKED` diagnostics before requests instead of `FileNotFoundError`. Flutter also identifies the required configuration file and startup argument. No next-phase features or live data changes were made.

Setup-preparation verification (2026-10-26): formatting passed for 32 Dart files; analysis found no issues; all 49 Flutter tests and 10 Python setup-validator tests passed; Android debug APK built successfully. No device installation or iOS build was attempted in this setup pass. Prior modeled PostgreSQL results below are historical; SQL was unchanged and those checks were not rerun. Live registration/email/recovery/session, persistence, uploads, ownership and network-failure acceptance remain blocked. Current local HEAD is `886ed70`; preparation changes are uncommitted. No Git remote is configured.

Date: 2026-10-26. Verified baseline: clean commit `7c6b03c` (Phase 3), preceded by `f5c5986` and `7a0e150`. No remote is configured. Current authorized scope is Phase 3A architecture/NFR baseline; do not start Phase 4.

**Phase 3 functionality is implemented. Local validation and live acceptance are distinct. Supabase integration is still unverified because development infrastructure/configuration is unavailable.**

## Implemented

- English-only application, font/assets/dependency/control cleanup, safe fallback for old locale preferences, and updated active acceptance criteria. Historical bilingual records are explicitly superseded.
- Owned business draft creation through existing verified/idempotent identity onboarding; business setup, private contact/pickup details, public area, logo/cover, setup progress, draft saves, review/activation/editing and server-generated unique code with copy/native share.
- Cakes/cupcakes with names/descriptions, image, weight/pack variants, product-specific flavours/finishes/extras, exact prices, minimum quantity, editing and active flags. No deletion of catalog records.
- Pickup/delivery settings, named zones/fees, subtotal minimum and responsive pricing preview. The authoritative RPC calculates saved catalog selections; the PKR 4,100 fixture is opt-in preview/test data only.
- Transactional revision checks, server activation validation, own-business/catalog RLS/grants, approved-field public business projection and image-pointer checks. A migration fixes the storage object-name ambiguity discovered in actual local SQL execution.
- Public logo/cover/product selection/upload stages/retry/preview/replacement/removal and persisted best-effort orphan cleanup. Referenced objects are protected from deletion. Order/chat uploads stay private and closed.
- Preview workspace persists under a separate device-only key. Live repositories use Supabase; account changes invalidate scoped providers and stale repositories reject another session.

## Verification

| Layer | Actual result |
| --- | --- |
| Baseline | Phase 2 analysis clean; all 29 baseline tests passed before changes |
| English cleanup gate | Analysis clean after correction; all five English auth/navigation widgets passed before feature UI |
| Flutter final analysis/tests | Formatting passed (30 files, 0 changed); analysis has no issues; all 48 Flutter tests passed. Local domain/fake/HTTP-mocked data, not live Supabase |
| Local PostgreSQL runtime | All four migrations applied in PGlite 0.5.11; 41 actual SQL/grant/RLS/function checks passed against modeled Auth/Storage schemas |
| SQL syntax | All four migrations and two pgTAP suites parsed, including PL/pgSQL; not live permission verification |
| Python | Backend verification scripts compile; real Phase 3 runner reports FileNotFoundError for missing local configuration |
| Real pgTAP | Attempted; ECONNREFUSED 127.0.0.1:54322, no stack/container engine |
| Hosted discovery | AccessTokenRequiredError, no logged-in/linked development project |
| Android | Final debug APK built successfully in 41.8 seconds. Streamed install failed; emulator state listed device, installed hash differs, UIAutomator returned null root. An alternate non-streamed install timed out after 45 seconds. Phase 3 on-device demonstration not accepted |
| iOS | Info.plist parsed and callback scheme checked. Swift sharing source added but not compiled. No macOS/Xcode build/sign/simulator/device verification |
| Live Auth/email/PostgREST/Storage | None verified; no development public config/credentials/environment |

The final [handoff](phase-3-handoff.md) provides configuration/run commands, demonstration, validation detail and limits. Android source/build validation is separate from device acceptance. Optional web rendering and physical-device accessibility remain unverified.

## External blockers and unresolved owner decisions

Supply a running migrated local Supabase stack or locally authenticated/linked hosted **development** project, public URL/key in ignored config/local.json, configured email callbacks/sender and dedicated customer/Baker A/Baker B credentials via secure prompts in [backend setup](backend-setup.md). Do not send passwords, CLI access tokens or service keys through chat or put them in Flutter.

Live registration/initialization/verification/resend/recovery/login/restart/logout, two-account privacy/ownership, actual uploads/bucket limits/private signing and account-switch cache checks remain blocked. These are missing-environment acceptance checks, not passing mock results.

Dual-role enrollment/navigation, teams/multiple businesses, final bundle IDs/universal links, production policies/retention/deletion, server orphan cleanup after device data loss, asset rights and remote backup remain unresolved. Existing initial experience/one owned draft are preserved provisionally; no preview control grants a real role. Personal Phase 2 profile-photo replacement retention is unchanged.

Phase 4 customer discovery, saved bakeries, lead times/capacity/blocked dates and all later ordering/communication workflows are not implemented. Stop here. Local commits preserve work on this machine only; there is no remote backup.

## Phase 3A architecture and NFR baseline

Created `docs/architecture.md`, `docs/non-functional-requirements.md` and `docs/architecture-nfr-audit.md`. Moved auth and baker repository contracts into their feature domain folders, moved image signature/size validation into `core/media`, and moved auth repository construction out of the data implementation into the application provider. Domain/provider/UI tests were updated accordingly.

Known contained architecture debt: `BakerWorkspace` remains a mutable JSON-shaped persistence model in domain, baker error mapping still detects some SQL failures through message text, app-layer auth composition imports the concrete SDK implementation, and presentation screens still invoke repository operations through providers rather than dedicated workflow controllers. The audit identifies focused follow-up corrections. No access-control defect was found by source/modeled review; live policy acceptance remains unverified. Performance and broader platform targets are proposals, not owner-approved commitments or measured results. Android merged manifest resolves minSdk 24 with Flutter 3.41.1; iOS Xcode project target is 13.0. Neither is a device support claim.

Phase 3A checks are recorded in `phase-3-handoff.md`. Supabase development credentials/project remain unavailable; Android emulator installation/UI inspection remains unverified; iOS build/device testing requires macOS/Xcode and was not performed. No availability, recovery, database-backup or user-export commitment is configured. Source Git, database backups and user data export are separate concerns; no remote Git backup exists.


Latest hosted setup follow-up: ignored client configuration repaired and validated. Auth settings endpoint returned HTTP 200 using the public key; email signup enabled and confirmation required. Profile REST endpoint returned HTTP 404/PGRST205, so schema deployment remains unverified. CLI still reports AccessTokenRequiredError; both verification preflights require dedicated test-account credentials. See the final follow-up table in integration-verification.md. These limited live reads do not constitute end-to-end verification.
