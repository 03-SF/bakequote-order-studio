> Archived phase evidence. English/Urdu requirements below are superseded by the Phase 3 English-only decision. Current commands and acceptance status are in the README and Phase 3 handoff.

# Phase 2 verification and handoff

Date: 2026-10-26. Scope: Supabase backend/authentication/access control only. **Implementation is locally validated; live integration acceptance is blocked. Stop before Phase 3.**

## Completed source

- Verified the clean Phase 1 checkpoint 7a0e150 and reran its analysis/eight tests. [Archived handoff](phase-1-handoff.md) and [README](../README.md) correct the earlier blank-looking run-command section.
- Added versioned SQL for Auth-linked profiles, customer/baker identities, owned private business drafts, safe initialization and verified/idempotent onboarding RPC. RLS plus column grants prevent cross-user changes, direct role assignment or ownership transfer. No admin/operator role can be self-assigned.
- Added profile/business/product/order-reference/conversation buckets. Own profile/business uploads are implemented in the account UI/repository. Future product/order/conversation uploads remain restrictive-denied; private membership is not invented.
- Added explicit preview/live configuration and real Supabase email/password registration, verification/resend, login, forgot/reset, logout and restoration API calls. Recovery routing is checked against PKCE exchange results; invalid/wrong-flow callbacks cannot enter the app.
- Preserved theme, Riverpod, go_router, customer/baker navigation, English/Urdu RTL and domain rules. Live pages display the actual authenticated profile, never sample orders/identity. Added profile editing and localized validation/loading/error states, duplicate action guards, invalid-session handling and stale read/write protection.
- Added local-controller, widget and SDK HTTP-mock tests; prepared transactional pgTAP and real Auth/PostgREST/Storage permission tests. Actual SQL policies are not certified by these local mocks.

## Migrations and policies

- `supabase/migrations/20261026000100_identity.sql`: profiles/customer_profiles/baker_profiles/businesses; Auth trigger; verified `complete_identity` RPC; grants/ownership RLS and bounded/path constraints.
- `supabase/migrations/20261026000200_storage.sql`: 5 MiB image buckets, own profile/business path policies, no overwrite policy, restrictive denial for unimplemented membership/product buckets.
- [Database/storage documentation](database-and-storage.md) lists every grant/path. [Backend setup](backend-setup.md) provides exact application/test commands and secure credential handling.

## Configure and run

From the workspace root:

```powershell
cd mobile
flutter pub get
flutter run -d emulator-5554 --dart-define-from-file=config/preview.json
```

For live accounts, first run/migrate the local stack or link/migrate a hosted **development** project using [backend setup](backend-setup.md). Put actual public settings into ignored `config/local.json`:

```powershell
Copy-Item config/example.json config/local.json
# Edit the local copy: actual public URL/key, APP_MODE live, native callback base.
flutter run -d emulator-5554 --dart-define-from-file=config/local.json
```

Changing dart-defines requires a restart. Never place a service-role key, database password or CLI token in this file. Register exact native callbacks in Supabase Auth; use same-installation PKCE email links.

## Separate-account acceptance scenarios (not yet executed against live services)

Use three dedicated verified fixture accounts: one customer, Baker A and Baker B. Keep passwords out of source/chat; use local secure prompts in backend setup.

1. Register the customer. Confirm no live profile screen is accessible before verification. Use resend, open the latest email on the requesting installation, then complete customer identity. Verify exactly one own profile/child identity exists. Repeat the RPC with the same choice and verify no duplicate.
2. Register/verify each baker; choose baker identity and distinct business names. Verify each receives one owned private draft and full onboarding remains false. User metadata containing `role=admin` must not grant anything. Complete identity with `admin` and direct ownership/experience updates must be rejected.
3. Sign in, save name/phone, restart the app and verify restored session/profile. Switch to Urdu, save profile and verify the stored locale at the next authenticated load. Try invalid passwords, offline startup, expired/revoked sessions and API failures; protected data must remain hidden until restoration succeeds.
4. Request password reset. Open the latest reset email on the requesting installation, set a new password, then sign in afresh. An ordinary verification callback must never show the reset form; a recovery callback must never open the order/home shell before the password flow is resolved. Test initial launch and warm links, expired/reused links and callbacks with spoofed type parameters.
5. Log out, navigate/back to protected routes and verify sign-in. Log in as a different account; old forms/profile/images must not appear. Exercise logout/session expiry while a profile request or save is delayed. Local automated tests cover these races, but live device switching is still pending.
6. Upload a JPEG/PNG/WebP (up to 5 MiB) to each profile and Baker A's public business image. Verify private signed preview, owner pointer updates, upload failure and oversized/unsupported-file errors. A customer/other baker must not upload into Baker A's business path. Personal profile bytes must not be available via public URLs or unrelated signing. Public business image bytes intentionally are public.
7. Run `npx.cmd --yes supabase@2.122.0 test db` locally and `python scripts/verify_backend.py --config config/local.json` with secure fixture-account environment variables. Inspect grants/RLS through requests, not only hidden buttons. Confirm unauthenticated profile access is rejected, unrelated profiles are invisible/unwritable, cross-baker changes fail, future private uploads stay denied and metadata cannot create privilege.

The HTTP test creates one throwaway unverified signup and mutates dedicated fixture names, then cleans up uploaded test objects. Remove the unverified Auth fixture afterward through the dashboard. It does not replace real email/device acceptance.

## Checks actually obtained

| Check | Result |
| --- | --- |
| Phase 1 Git baseline | Clean at 7a0e150; no remote |
| Baseline analyze/tests | No issues; 8 tests passed |
| PostgreSQL parser | Both migrations and pgTAP SQL parsed; PL/pgSQL function syntax parsed. No execution/permission proof |
| Python verification script | Compiled successfully; no backend requests run without configuration/accounts |
| Supabase CLI | Version 2.122.0 available through npx |
| Hosted discovery | Blocked: AccessTokenRequiredError, no local CLI login/token |
| Local stack status | Blocked: Docker/Podman not found; no linked project |
| Database tests | Attempted; DbConnectError, ECONNREFUSED 127.0.0.1:54322 |
| Flutter analysis/tests | 29 tests passed; final analysis clean; formatting check 22 files/0 changes; 3 focused auth-widget tests also passed |
| Android | Debug APK build succeeded; Kotlin cross-drive incremental-cache fallback recovered. Corrected live-mode build/install/startup succeeded; callback activity resolved. Final visual check blocked by offline/still-authorizing ADB; native authenticated email/restart checks remain pending |
| iOS | Not built/signed/run. Info.plist scheme/photo usage added; requires macOS/Xcode/device validation |
| Live Auth/RLS/Storage/email | Not executed; no migrated service/public configuration/test accounts supplied |

## Remaining blockers and decisions

Supply a migrated local development stack or hosted development project access through the local Supabase CLI login/link mechanism, public URL/key in ignored `config/local.json`, exact redirect/email sender setup, and verified test accounts. No service-role key is needed by Flutter or HTTP tests. iOS needs a separate suitable environment. Dual-role/multi-business/team policy remains unresolved; the UI provides only one initial experience. Store identifiers/universal links, legal retention/deletion, backup responsibilities and image rights remain tracked owner decisions.

No Phase 3 catalog/full bakery setup was started. Full live Phase 2 acceptance is not asserted while those checks are blocked. Source is saved as a local checkpoint on main; run `git log -1 --oneline`. There is no remote repository configured and no remote backup of these commits.
