# Hosted development setup: owner actions

Use this guide from the Flutter repository, `D:\GOOGLE DRIVE BACKUP\Seventh Semester\BakeQuote\mobile`. No local Docker stack is required for the hosted path. No paid resource, project, database reset, or account has been created by the agent. An existing project cannot be selected until the owner identifies it or CLI discovery becomes authenticated.

1. **Select a development project.** Open https://supabase.com/dashboard. Prefer an existing dedicated BakeQuote development project. Confirm it contains no operational/production data and no unrelated reference-app schema. If none exists, create a separate project only under a Free plan without paid add-ons; if the dashboard requires payment, stop. Keep its database password in a password manager. Reply only with the project name/reference and confirmation that it is development.

2. **Authenticate and link locally.** In PowerShell, run the following. Complete CLI login in your terminal/browser; enter any access token or database password only in the CLI's secure flow. The CLI credential can administer projects and is never a Flutter key.

   ```powershell
   Set-Location 'D:\GOOGLE DRIVE BACKUP\Seventh Semester\BakeQuote\mobile'
   npx.cmd --yes supabase@2.122.0 login
   npx.cmd --yes supabase@2.122.0 projects list
   $developmentProjectRef = Read-Host 'Confirmed development project reference'
   npx.cmd --yes supabase@2.122.0 link --project-ref $developmentProjectRef
   ```

   Sanitized confirmation: `CLI login complete; development project linked: <reference>`. No token/password output is needed.

3. **Configure Flutter from that same project.** Obtain the API Project URL and public publishable key from the selected project's Connect/API settings. A legacy `anon` key is supported too. Never select `service_role` or `sb_secret_`. Create the ignored file only if absent:

   ```powershell
   if (-not (Test-Path config/local.json)) { Copy-Item config/example.json config/local.json }
   notepad config/local.json
   git check-ignore -v config/local.json
   ```

   Use exactly these keys. The values below are placeholders, not a working configuration:

   ```json
   {
     "APP_MODE": "live",
     "SUPABASE_URL": "https://<development-project-reference>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<public-publishable-or-anon-key-from-that-project>",
     "AUTH_CALLBACK_BASE": "dev.bakequote.mobile://auth"
   }
   ```

   The exact file location is `mobile/config/local.json` relative to the workspace root. Flutter reads its entries at compile time **only when passed with `--dart-define-from-file=config/local.json`**, not as a runtime asset or `.env` file. Supported modes are `preview` (default, isolated fixtures) and `live`. Hosted URLs require HTTPS. Local HTTP supports localhost, 127.0.0.1 and Android emulator 10.0.2.2. Native callback base must be `dev.bakequote.mobile://auth`; optional Flutter web supports a localhost/127.0.0.1 HTTP base with path `/auth`, for example `http://localhost:7357/auth`. Restart the app after changing defines. Sanitized confirmation: `local config saved`; do not paste its key.

4. **Review and apply ordered migrations without resetting.**

   ```powershell
   npx.cmd --yes supabase@2.122.0 migration list --linked
   npx.cmd --yes supabase@2.122.0 db push --dry-run
   ```

   Expected versions, in order: `20261026000100` identity, `20261026000200` storage, `20261026000300` catalog/pricing, `20261026000400` catalog storage. If tables/buckets already exist without matching migration history, stop for schema reconciliation; do not mark migrations applied blindly, overwrite tables or reset the project. After checking the target and pending migration list:

   ```powershell
   npx.cmd --yes supabase@2.122.0 db push
   npx.cmd --yes supabase@2.122.0 migration list --linked
   ```

   Sanitized confirmation: applied version numbers or an error code with credentials removed. Review deployed grants/RLS/function definitions too; migration history alone does not exclude schema drift. [Database/storage policy contract](database-and-storage.md) covers all five buckets: private profile/order-reference/conversation images, public business/product images, 5 MiB JPEG/PNG/WebP limits and denied order/conversation uploads until membership exists. No service-role key is needed for the user-session HTTP tests. [Supabase migration guidance](https://supabase.com/docs/guides/deployment/managing-environments).

5. **Configure Auth and email in the hosted dashboard.** Enable email/password signup and email confirmation; minimum password length must be at least eight characters. Under Auth URL Configuration, add exactly `dev.bakequote.mobile://auth/verify` and `dev.bakequote.mobile://auth/reset`. For a native-only development project the Site URL can use `dev.bakequote.mobile://auth/verify`; app requests explicitly supply verify/reset redirects. Keep the default confirmation-URL template behavior. Local `supabase/config.toml` does not automatically configure hosted Auth settings through `db push`.

   Android manifest and iOS Info.plist already register the native scheme; Flutter automatic deep linking is disabled so AppLinks handles callbacks. PKCE emails must open on the installation that requested them. Optional web needs its own ignored `config/web.local.json`, base `http://localhost:7357/auth`, and exact web verify/reset redirects. Do not treat the separate reference site on port 5173 as the Flutter app.

   Supabase's default sender permits only organization-team email addresses and is heavily rate-limited; custom SMTP is needed for other test inboxes. Configure an existing authorized sender locally in the dashboard if available; do not purchase a service or grant project-admin access merely to make a customer test inbox eligible. SMTP credentials stay in the dashboard. If delivery remains unavailable, record email verification/reset tests blocked rather than disabling confirmation. [Current Supabase SMTP restrictions](https://supabase.com/docs/guides/auth/auth-smtp). Sanitized confirmation: `callbacks configured; email delivery available` or the specific remaining email limitation.

6. **Prepare separate real test identities.** Use three distinct accessible inboxes: Customer, Baker A, Baker B. Register/verify them through Flutter and complete their corresponding initial experience. Do not use real customer data. The runners require `BQ_TEST_CUSTOMER_EMAIL`, `BQ_TEST_CUSTOMER_PASSWORD`, `BQ_TEST_BAKER_A_EMAIL`, `BQ_TEST_BAKER_A_PASSWORD`, `BQ_TEST_BAKER_B_EMAIL`, `BQ_TEST_BAKER_B_PASSWORD`. Supply these with the secure PowerShell prompts in [integration verification](integration-verification.md#flutter-and-authenticated-http-tests). Variables exist only in that terminal; run the scripts there. These passwords authenticate ordinary users, not deployment privileges. Account creation remains pending until project and mail access exist. The HTTP suite no longer sends signup to an invented example.test address: real registration, delivered verification and recovery must be observed through Flutter using fresh accessible inboxes. Creating already-confirmed users through an admin dashboard does not verify those flows.

7. **Run and verify.**

   ```powershell
   $env:Path = "D:\flutter\flutter\bin;D:\SDK\platform-tools;" + $env:Path
   flutter pub get
   flutter devices
   flutter run -d emulator-5554 --dart-define-from-file=config/local.json
   ```

   Substitute the actual device ID. In the terminal containing secure test-account variables, first check inputs without network requests:

   ```powershell
   python scripts/verify_backend.py --config config/local.json --preflight-only
   python scripts/verify_phase3.py --config config/local.json --confirm-development --preflight-only
   ```

   Successful preflight proves only input presence/shape; it cannot establish the project's identity, deployed policies or live behavior. Then run without `--preflight-only` against dedicated disposable fixture accounts. Phase 3 replaces/deactivates Baker A's fixture catalog/zones. The [evidence table](integration-verification.md#test-results-and-sanitized-evidence) must also record actual email/native callback, restart, image retrieval and network interruption results. Share only sanitized PASS/FAILED labels, error codes and blockers.

**Current handoff (2026-10-28, supersedes historical setup blockers):** development project selected/linked; six migrations applied; native and browser redirect allowlists configured; email confirmation enabled; one confirmed customer is available. Phase 4 is implemented and local/limited live evidence is recorded in integration-verification.md. Two separately verified baker accounts, positive cross-account browser workflows and actual browser email verification/recovery remain outstanding. Native acceptance is deferred. Stop before Phase 5. Do not print test-account credentials or use privileged keys for authorization tests.
