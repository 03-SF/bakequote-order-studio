# Supabase development setup

Latest attempt and scenario-by-scenario evidence: [live integration verification](integration-verification.md). Live acceptance remains blocked until the documented development project/configuration/accounts exist.

Start with the short numbered [hosted development owner guide](hosted-development-setup.md) when Docker/Podman are unavailable. HTTP runners now validate configuration and every required account before requests; `--preflight-only` checks these inputs without contacting Supabase. Missing setup reports `BLOCKED` (exit 2), not a raw file exception. No key values are printed. Actual registration, verification/resend and recovery are explicitly manual Flutter/email acceptance; the HTTP runner no longer sends signup to an invented example.test mailbox.

## Observed environment

The current checkout has an ignored `config/local.json` template with empty URL/key, but no linked project or usable Supabase configuration. Supabase CLI 2.122.0 is available through npx. Project listing failed with `AccessTokenRequiredError`: no CLI login/access token. Local status failed with `StatusDbInspectError`: Docker and Podman were not found. No migrations or permission tests have executed against Supabase services. Phase 3 separately executes all migrations and ownership/pricing checks in a local PostgreSQL/WASM model; it does not verify Supabase Auth/PostgREST/Storage. SQL parsing remains syntax-only.

Architecture and acceptance boundaries are in [architecture.md](architecture.md) and [non-functional-requirements.md](non-functional-requirements.md). The local SQL model is not a hosted backend check. Execute identity and catalog RLS/storage tests against an isolated development project before treating live behavior as verified.

## Local stack (requires Docker Desktop or Podman)

Install and start a supported container engine. From `mobile`, use the pinned CLI:

```powershell
npx.cmd --yes supabase@2.122.0 start
npx.cmd --yes supabase@2.122.0 status
```

The CLI reads [config.toml](../supabase/config.toml) and applies versioned migrations on first start. To rebuild a **disposable local** database from the migrations:

```powershell
npx.cmd --yes supabase@2.122.0 db reset --local
npx.cmd --yes supabase@2.122.0 test db
```

Reset deletes local development data. Do not use it to reset a hosted project. Local API is `http://127.0.0.1:54321`, Studio `http://127.0.0.1:54323`, local mail UI `http://127.0.0.1:54324`. Copy only the displayed public publishable/anon key to ignored `config/local.json`; keep the service-role key out of the app. Local configuration requires email confirmation, minimum eight-character passwords and the exact redirect allowlist.

For an Android emulator/device connected by ADB, reverse the local API and mail UI ports so the default links in local email work inside the device browser:

```powershell
adb -s emulator-5554 reverse tcp:54321 tcp:54321
adb -s emulator-5554 reverse tcp:54324 tcp:54324
Copy-Item config/example.json config/local.json
```

Set SUPABASE_URL to `http://127.0.0.1:54321` in that file. Run `flutter run -d emulator-5554 --dart-define-from-file=config/local.json`. Alternatively the Android emulator can reach the API at `http://10.0.2.2:54321`, but email verification URLs must reach that same local API; ADB reverse avoids editing email URLs. Debug networking allows these loopback hosts only; release builds use HTTPS.

## Existing hosted development project

The project owner must log in locally and link the exact project. These commands prompt through the CLI rather than storing secrets in source:

```powershell
npx.cmd --yes supabase@2.122.0 login
npx.cmd --yes supabase@2.122.0 projects list
npx.cmd --yes supabase@2.122.0 link --project-ref <development-project-ref>
npx.cmd --yes supabase@2.122.0 db push --dry-run
npx.cmd --yes supabase@2.122.0 db push
```

Review the dry-run against the chosen development schema. These migrations create new BakeQuote tables/buckets; they do not reconcile arbitrary existing tables with the same names. Access tokens and database passwords belong only in CLI prompts/credential storage or a local secret environment. Supply public URL/key through ignored `config/local.json`, not chat. The project reference is not a service credential. No new hosted project was created here.

In Auth settings, enable email signup/confirmation, choose an authorized sender/SMTP configuration and set the password minimum to match the app's eight-character validation or stronger. Add exactly:

- `dev.bakequote.mobile://auth/verify`
- `dev.bakequote.mobile://auth/reset`

Keep email templates using Supabase's confirmation URL so request-specific redirect URLs survive. Do not disable confirmation to bypass profile initialization. The database RPC also requires a verified Auth identity. Configure an owner-approved Site URL; no owner domain has been invented. PKCE links require the same installation/browser that initiated the request. Requesting another auth email can supersede the previous local code verifier; use the latest link. Email throttling and network failures surface as messages, never simulated success.

## Native and optional web callbacks

Android main manifest declares the `dev.bakequote.mobile` scheme/`auth` host and INTERNET permission. Flutter's automatic deep linking is disabled so AppLinks owns delivery. iOS Info.plist declares the same scheme and disables Flutter deep linking; photo-library usage text supports image selection. Initial and warm links go to one controller; only `/verify` and `/reset` are accepted. Unsupported links do not change the session. PKCE exchange results determine recovery independently of query parameters. Invalid/mismatched links clear the local account view and return to sign-in with an error.

The scheme is a development default. Final owned app IDs/universal links, associated domains and store signing are unresolved release decisions; custom schemes do not provide verified domain ownership. iOS configuration has not been validated on a simulator or device.

For an optional local Flutter web auth check, use a separate ignored configuration file with AUTH_CALLBACK_BASE `http://localhost:7357/auth`, then run:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=7357 --dart-define-from-file=config/web.local.json
```

Add `http://localhost:7357/auth/verify` and `/auth/reset` to hosted Auth redirect settings, or use the committed local config which already includes them. The app captures the startup URI before the router clears sensitive query parameters. Hosted web auth/universal domains are outside the mobile development setup.

## Backend permission verification

SQL tests in [identity_rls.test.sql](../supabase/tests/identity_rls.test.sql) run transactionally/roll back using pgTAP. They exercise trigger initialization, ownership, grants, RLS, immutable ownership/experience, unverified onboarding and private storage denials. Run `npx.cmd --yes supabase@2.122.0 test db` with the migrated local stack. A PostgreSQL syntax check is separately available:

```powershell
python -m pip install -r scripts/requirements-dev.txt
python scripts/validate_sql.py
```

The optional HTTP test [verify_backend.py](../scripts/verify_backend.py) uses real Auth/PostgREST/Storage requests, never a service-role key. First create and verify three dedicated development accounts (one customer, two bakers) and choose their corresponding initial experiences. Provide their credentials through ephemeral process environment using secure local prompts:

```powershell
$testRoles = @('CUSTOMER', 'BAKER_A', 'BAKER_B')
foreach ($testRole in $testRoles) {
    [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_EMAIL", (Read-Host "$testRole email"), 'Process')
    $testSecret = Read-Host "$testRole password" -AsSecureString
    $testCredential = New-Object System.Management.Automation.PSCredential('test', $testSecret)
    [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_PASSWORD", $testCredential.GetNetworkCredential().Password, 'Process')
}
python scripts/verify_backend.py --config config/local.json
foreach ($testRole in $testRoles) {
    [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_EMAIL", $null, 'Process')
    [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_PASSWORD", $null, 'Process')
}
```

Use isolated fixture accounts: the script initializes/updates their names, tests token refresh and ownership, and uploads/removes test images. Request bodies/tokens are not printed. The script verifies anonymous rejection, cross-profile/cross-business writes, forbidden experience assignment, own uploads, unrelated private-file access and closed future buckets. It does not test new registration, actual email delivery, app restarts, native callbacks or UI account caching; follow the [current evidence matrix](integration-verification.md) for those. Real registration must be observed in Flutter with a fresh permitted inbox; a placeholder signup address or an enumeration-safe response is not evidence of delivered verification.

## What is needed to unblock live acceptance

Provide a running migrated local stack, or an existing development project with local CLI login/link completed. Put its public API URL/key into ignored `config/local.json`. Configure the exact callbacks and email sender. Supply dedicated test-account credentials only through the secure local prompts above. macOS/Xcode and an iOS simulator/device are separately required for iOS checks. No service-role key is required in the Flutter app or HTTP permission test.

## Primary references

The locked SDK implementation was inspected for PKCE exchange/session behavior. Reference guidance: [Supabase Flutter SDK](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), [bucket configuration](https://supabase.com/docs/guides/storage/buckets/fundamentals). These describe APIs and policy behavior; they do not certify this project's unexecuted live integration.

## Phase 3 development verification

Environment discovery was repeated: no ignored `config/local.json`, no Supabase CLI login/token or linked project, and no Docker/Podman. Missing infrastructure is separate from implementation defects. Migrations 003/004 must be applied after 001/002; do not skip 004, which fixes storage object-name qualification and enables owner-scoped product/cover images.

Local independent SQL runtime checks require Node.js and use the committed lockfile:

```powershell
npm.cmd ci --prefix scripts/sql-test
node scripts/sql-test/verify.mjs
```

For the actual local Supabase services, after installing/starting the container engine:

```powershell
npx.cmd --yes supabase@2.122.0 start
npx.cmd --yes supabase@2.122.0 db reset --local
npx.cmd --yes supabase@2.122.0 test db
```

Reset only a disposable local stack. For an existing development project, use the login/link/dry-run/push commands above. Supply its public URL/key in the ignored local configuration and configure exact verification/reset callbacks. Keep email confirmation enabled.

Create three verified fixture accounts: Customer, Baker A, Baker B. Complete their corresponding initial identity in the app. Use the secure prompts above, then run both HTTP suites:

```powershell
python scripts/verify_backend.py --config config/local.json
python scripts/verify_phase3.py --config config/local.json --confirm-development
```

The Phase 3 suite mutates Baker A's disposable business details, activates it, adds a cake/customizations/delivery fixture, tests PKR 4,100, uploads/detaches/removes a public product image and deactivates the fixture. Existing catalog/zones omitted by its save are deactivated. Do not use real operational businesses or production. The explicit flag confirms this development-only test intent. It verifies two-owner writes/public projections through HTTP; email/device restart and signed private-file checks remain covered separately by the Phase 2 suite and manual acceptance.

To unblock live checks, the owner must supply **locally**, not in chat:

1. Running Docker/Podman Supabase stack, or CLI login/link access to an identified hosted development project. Database password/access token remain in CLI secure prompts/credential storage.
2. Actual public API URL and public publishable/anon key in ignored `config/local.json` (no service-role key).
3. Configured email sender/confirmation/reset redirects and three dedicated verified account credentials through the secure process-environment prompts.

Then execute migrations, pgTAP/HTTP suites and the native sign-up/email/restart/account-switch/upload demonstration. These live checks remain blocked until those steps run. iOS separately requires macOS/Xcode and an appropriate simulator/device.


## Laptop-only Flutter Web verification

2026-10-28 configuration confirmation: the hosted development allowlist now contains both native callbacks plus `http://localhost:7357/auth/verify` and `http://localhost:7357/auth/reset`. A read-only CLI diff confirms the declared allowlist matches. Email confirmation remains enabled and the native Site URL is preserved. This is configuration evidence only; browser verification/recovery email round trips still need testing.

The owner deferred Android APK installation and native acceptance on 2026-10-28. Do not retry emulators for this verification. Android/iOS remain the product; this browser host is development-only.

Use ignored `config/web.local.json` (copy the exact public URL/key from `config/local.json`, set `APP_MODE` to `live`, and `AUTH_CALLBACK_BASE` to `http://localhost:7357/auth`). A credential-free example is `config/web.example.json`. Do not change the native callback base. Add `http://localhost:7357/auth/verify` and `http://localhost:7357/auth/reset` to hosted Auth Redirect URLs **alongside** both mobile URLs. Keep the native Site URL. Browser redirects must be confirmed in the dashboard; a local config file alone does not apply them. Use the same browser profile/origin for PKCE initiation and email return. No automated email is sent by these checks.

From the Flutter repository in PowerShell:

```powershell
$env:Path = "D:\flutter\flutter\bin;" + $env:Path
flutter pub get
flutter build web --debug --no-web-resources-cdn --dart-define-from-file=config/web.local.json
python scripts/serve_flutter_web.py
```

Open `http://localhost:7357` in Chrome. This static debug server has SPA callback fallback and does not log request URLs containing auth codes. It binds loopback only. Port 5173 is the separate React reference, not this Flutter app. Browser session tokens use SDK/browser storage; use dedicated development browser profiles and log out after testing. Changing dart-defines requires rebuilding. Native token storage, callback handlers, gallery permissions, push and device acceptance are not proven by Chrome.

Automated checks (a second terminal while the host runs):

```powershell
python -m pip install --target build/browser-tools playwright==1.55.0
python scripts/verify_single_account.py
python scripts/verify_web_account.py
```

Run these two account-mutating suites sequentially. They use the existing ignored `config/email-check.local.json` fixture credentials. Do not create or expose credentials in source; the browser script may complete customer onboarding for that dedicated fixture. It requires installed Google Chrome and modifies/restores the test profile name. No signup/resend/reset is performed. Multi-account suites still require their six `BQ_TEST_*` environment variables; these single-account checks do not replace them.

Native callbacks, native storage/session lifecycle, permissions, push notifications, Android/iOS builds/devices and device acceptance are deferred, not passed. Browser reset/verification callbacks remain separately unverified until allowlist confirmation and an actual same-browser email flow.

## Phase 4 verification commands

Run from mobile in the terminal containing securely entered BQ_TEST account variables:

```powershell
python scripts/verify_cross_account.py --preflight-only
python scripts/verify_cross_account.py
python scripts/verify_phase3.py --confirm-development
python scripts/verify_phase4_single.py
node scripts/sql-test/verify.mjs
```

The Phase 3 suite replaces a dedicated fixture catalog; never point it at a real business. The cross-account suite requires three distinct verified identities, tests both baker directions and compares target records/bytes after denial. It never administratively confirms users. The single-account Phase 4 script uses the existing ignored email-test fixture, sends no mail, and is explicitly limited. Missing accounts block those tests, not independent local implementation. Six migrations are now versioned; inspect dry-run/history before any future deployment. Do not reset the development project.

Native setup commands elsewhere are historical alternatives; Android installation and iOS/native acceptance are currently deferred. Use the laptop browser commands above. Phase 5 is not authorized by this handoff.
