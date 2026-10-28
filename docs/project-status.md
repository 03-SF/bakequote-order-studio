# Current project status - Phase 4 implementation, live acceptance pending

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
