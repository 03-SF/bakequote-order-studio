# Current project status - Phase 3A

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
