# Supabase development setup

## Observed environment

The current checkout has no `config/local.json`, linked project or Supabase environment configuration. Supabase CLI 2.122.0 is available through npx. Project listing failed with `AccessTokenRequiredError`: no CLI login/access token. Local status failed with `StatusDbInspectError`: Docker and Podman were not found. No migrations or permission tests have executed against an actual database in this session. SQL parsing is not database verification.

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

Use isolated fixture accounts: the script initializes/updates their names, tests token refresh and ownership, uploads/removes test images, and creates one unverified signup fixture. Remove that signup fixture through the Auth dashboard afterward. Request bodies/tokens are not printed. The script verifies anonymous rejection, cross-profile/cross-business writes, forbidden experience assignment, own uploads, unrelated private-file access and closed future buckets. It does not test actual email delivery, app restarts, native callbacks or UI account caching; follow the [handoff matrix](phase-2-handoff.md) for those.

## What is needed to unblock live acceptance

Provide a running migrated local stack, or an existing development project with local CLI login/link completed. Put its public API URL/key into ignored `config/local.json`. Configure the exact callbacks and email sender. Supply dedicated test-account credentials only through the secure local prompts above. macOS/Xcode and an iOS simulator/device are separately required for iOS checks. No service-role key is required in the Flutter app or HTTP permission test.

## Primary references

The locked SDK implementation was inspected for PKCE exchange/session behavior. Reference guidance: [Supabase Flutter SDK](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), [bucket configuration](https://supabase.com/docs/guides/storage/buckets/fundamentals). These describe APIs and policy behavior; they do not certify this project's unexecuted live integration.
