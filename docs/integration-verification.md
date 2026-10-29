# Live Supabase integration verification

## Phase 5–6 acceptance preparation (2026-10-29)

| Scenario | Actual result | Status |
| --- | --- | --- |
| Development migration inventory | Thirteen local and remote versions matched | PASS, inventory only |
| Limited customer/anonymous HTTP | 22 checks rerun, including unowned/missing-target denial and disabled deletion | PASS, limited; no unrelated real target |
| Customer / Baker A / Baker B readiness | Test-account environment variables absent in this session; prior customer fixture exists separately | BLOCKED |
| Quote revision, old agreement invalidation, stale revision/agreement and quote history | Five new checks pass as part of 135 modeled PostgreSQL checks | PASS, modeled only |
| Web build and Chrome customer regression | Release Web bundle built; seven checks passed including request-list empty state, profile failure/retry and session logout | PASS, limited: no positive baker/order workflow |
| Acceptance-runner safety | 15 Python setup tests passed; linked project and fixture guards checked; SQLSTATE error handling is sanitized | PASS, local only |
| Real request, reference image and cross-account before/after check | No dedicated two-baker sessions supplied; no positive live execution | BLOCKED |
| Real two-request last-slot race, exact retry, fresh-session persistence | `verify_phase6.py` prepared and preflight tested; no authenticated real execution | BLOCKED |
| Approved complete production lifecycle | Mandatory Decorating differs from original requirements; owner decision pending | BLOCKED; no data changed |
| Previously exposed Supabase secret API key | Rotation/revocation unconfirmed | OPEN security incident |
| Native Android/iOS acceptance | Owner deferred; no emulator installation attempted | DEFERRED |

See [the completion matrix](phase-completion-matrix.md) for secure local prompts, fixture prerequisites, clear mutation/retention behavior of the prepared runner and unresolved lifecycle decision. Offline functionality is excluded. Historical single-account HTTP and Chrome results remain limited to their stated scope.

## Release integrity continuation: 2026-10-29

| Check | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Development migration history | Thirteen local/remote versions match; one repair was dry-run inspected and applied without reset | PASS | Linked development CLI migration list |
| Modeled PostgreSQL | 130 checks passed, including quote agreement, operation replay ownership, manual-order retry, timezone and Decorating capacity | PASS, modeled | PGlite modeled roles/Auth/Storage; not real concurrent transactions |
| Existing customer and anonymous | 22 direct HTTP checks passed, including unowned confirmation and disabled incomplete deletion | PASS, limited | Ordinary customer session; missing-target tests do not prove access to another real user's data |
| Flutter / release gate | 68 tests, formatting, analysis and SQL parsing passed; release remains NOT APPROVED | PASS, local only | `scripts/release_candidate.py` generated report; no hosted/device conclusion |
| Android compile | Debug APK built in 113.9 seconds | PASS, build only | No installation or native acceptance |
| Three-account preflight | Six BQ_TEST variables missing in runner environment; Baker A/B not configured | BLOCKED | No customer/Baker A/B cross-account request or positive order/attachment flow performed |
| Billing, encrypted backup, deletion worker | Provider adapters and actual recovery/deletion implementations absent | NOT IMPLEMENTED | No Supabase Edge Functions or provider worker present; deletion disabled, conversation uploads closed |
| Native acceptance | No installation, device or iOS build performed in this continuation | DEFERRED | Browser/local checks do not establish mobile behavior |
| Release approval | Not approved | BLOCKED | See [gap analysis](release-readiness-gap-analysis.md) for precise implementation and external prerequisites |

Use the secure local prompts below for the three-account tests. Do not paste passwords, access tokens or service-role keys into chat. No administratively confirmed identity is represented as email-delivery evidence.

## Latest Phase 4 verification: 2026-10-28

| Test | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Existing account readiness | Confirmed customer login and initial experience checked | PASS | Normal Auth session; email_confirmed_at present; customer profile |
| Cross-account readiness | Baker credentials missing; no cross-account requests made | BLOCKED | New runner and existing preflights report missing BQ_TEST account environment variables; locally stored customer fixture is separate |
| Local Flutter regression | 57 tests passed | PASS, local | Calendar conflict/input/large-text, date boundaries, saved isolation and link-through-login tests |
| Modeled PostgreSQL | 81 checks passed | PASS, modeled | Includes unchanged denied-write target, statuses, blocked/full/date boundaries, recent pruning and unpublished visibility |
| New migration | Reviewed dry-run listed one migration; applied without reset | PASS, deployment | 20261028000200_availability_recents.sql |
| New live endpoints | Nine limited tests passed | PASS, live HTTP | verify_phase4_single.py; known customer, invalid date/range, unknown calendar, recent access and raw occupancy denial |
| Final migration history | All six local/remote versions match | PASS | CLI migration list after deployment |
| Chrome regression on updated Web bundle | Six cases passed after restarting stopped loopback server | PASS, live browser | Login/onboarding, reload, injected profile-write failure/input preservation, acknowledged retry and logout/guard; initial ERR_CONNECTION_REFUSED was a stopped host |
| Final Web build, formatting and analysis | Debug Web bundle built; format and analysis clean | PASS, local | No native-device acceptance inferred |
| Android compile only | Debug APK built in 83.4 seconds | PASS, build only | No installation/emulator/native acceptance attempted; iOS build/device deferred |
| Python setup suite | Ten tests passed after synthetic credential fixture cleanup | PASS, local | New verification scripts compile; no credentials printed |
| Checkpoint credential safety | Actual configured values absent from checkpoint candidates; local files ignored | PASS, limited source scan | Synthetic rejection fixture normalized; no privileged credential used |
| Positive availability and cross-account Chrome workflow | Not executed | BLOCKED | Requires two confirmed baker identities and their owned fixture bakery; no admin-confirmed identity substitutes for email verification |
| Native acceptance | No retries attempted | DEFERRED | Android/iOS callbacks, installed links, native storage/permissions/lifecycle/device and push remain unverified |

All live authorization probes use public keys plus ordinary user sessions. The missing-target mutation probe is explicitly limited: it does not prove protection of an existing other-baker record. The prepared cross-account runner requires before/after snapshots and known-object byte comparisons. No fixture orders were inserted into hosted storage. Existing historical evidence below remains valid only for its stated test scope. Full integration acceptance is still incomplete.

Remaining owner setup: register and verify two distinct accessible baker inboxes through Flutter; if the default sender does not support them, configure authorized SMTP. Keep email confirmation enabled. Enter the six BQ_TEST environment variables using secure local prompts in [setup](hosted-development-setup.md), then run `python scripts/verify_cross_account.py`. Never send passwords/tokens here. Browser verification/recovery inbox round trips and previously exposed privileged-key rotation remain unconfirmed.

## Current result: 2026-10-28 laptop verification

**Partially verified, not end-to-end accepted.** This section supersedes historical missing-configuration, missing-login and unavailable-project statements below. Tests use the hosted development project and normal user sessions; administrative deployment/inventory is not evidence of user authorization. No service-role key was used to prove permissions. Native installation retries are stopped at the owner's request.

| Test | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Formatting and static analysis | Formatting clean; analyzer reports no issues | PASS, local | 37 Dart files; no analyzer issues |
| Flutter unit/widget suite | All tests passed | PASS, local | 53 tests; includes discovery error recovery and narrow/large-text layout |
| Setup validation | All checks passed | PASS, local | 10 Python tests; verification scripts compile |
| PostgreSQL behavior | All modeled runtime checks passed | PASS, modeled backend | 56 PGlite checks; Auth/Storage schemas modeled, not hosted multi-account acceptance |
| Web compatibility/build | Debug web bundle built and served locally | PASS | Flutter Web, installed Chrome, localhost:7357; mobile product direction unchanged |
| Migration deployment | Customer-discovery migration applied after an initial connection timeout | PASS | 20261028000100 applied; no reset; deployed RPCs exercised |
| Browser redirect configuration | Remote allowlist matches native verify/reset plus localhost:7357 verify/reset | PASS, configuration | CLI diff after interrupted push has zero declared updates; email confirmations remain true; native Site URL preserved |
| Signup email delivery | Owner confirmed receipt of the one requested email | PASS, receipt only | Earlier normal login confirmed email_confirmed_at; no repeated resend |
| Single-customer Auth/profile/Storage | All checks passed using a normal account session | PASS, live HTTP | 15 checks: login, initialized profile, write/refresh/read, privilege denial, private image upload/read/sign/public denial, closed attachment uploads, cleanup and logout |
| New discovery endpoint restrictions | All checks passed | PASS, limited live HTTP | Six checks: login, unknown-code empty menu, invalid page size rejected, anonymous saved access denied, own saved list, unavailable-business save rejected |
| Chrome login/onboarding | Real authentication and customer onboarding succeeded | PASS, live browser | Auth session received; protected customer discovery screen reached |
| Browser session restoration | Reload retained authenticated customer route | PASS, live browser | Reload and discovery assertions passed; not native process-restart evidence |
| Interrupted profile save and retry | Failure displayed, input preserved, acknowledged retry restored original data | PASS, injected browser network failure | Playwright aborted profile PATCH; no false success; original value restored |
| Browser logout/route guard | Logout cleared access and protected account redirected to login | PASS, live browser | Final six-case Chrome suite passed |
| Verification/recovery browser callbacks | Allowlist configured; actual email PKCE round trips not exercised | BLOCKED | Requires controlled inbox interaction; receipt alone does not verify callback handling; no recovery email sent in this pass |
| Two-baker ownership and customer isolation | Full multi-account suites did not execute | BLOCKED | Two separately verified baker accounts unavailable; runner preflights report missing dedicated account credentials |
| Business/catalog creation, edits, restart and live PKR 4,100 pricing | Positive real-baker workflow not executed | BLOCKED | Requires dedicated baker fixtures; modeled SQL results do not replace it |
| Business/product image restart and interrupted upload | Not exercised end to end | BLOCKED | Private-profile image HTTP checks passed, but do not establish business/product image UI acceptance |
| Unrelated-user private object/profile denial and account switching | Not fully exercised | BLOCKED | Anonymous/public denial and closed attachment upload checks passed; separate confirmed identities still required |
| Android/iOS callbacks, native storage, permissions, background/resume and device acceptance | Not executed in this pass | DEFERRED | Owner explicitly postponed native acceptance; no emulator installation retry; no iOS build/device claim |
| Push notifications | Not implemented or tested | DEFERRED | Future feature scope |

### Reproduction and remaining setup

See [backend setup](backend-setup.md#laptop-only-flutter-web-verification) for exact configuration/build/server commands. Run the single-account and Chrome scripts sequentially because both use the same ignored local test fixture. Never paste fixture passwords or tokens into chat or commit them.

To unblock remaining laptop tests, create/confirm two dedicated baker accounts using organization-member inboxes supported by the default sender, or configure an approved SMTP sender. Keep confirmation enabled. Supply credentials only through the local secure setup described in [hosted setup](hosted-development-setup.md), then run both multi-account HTTP suites and the positive baker UI workflow. A browser signup/recovery test must start in the same browser installation used to open its link. Do not reuse the old mobile callback email as proof of browser callback acceptance.

The previously exposed privileged key must be revoked/rotated in the dashboard; rotation has not been confirmed. It was not used in these authorization tests. Local Git changes are not remotely backed up; no remote is configured.

Per the owner's revised gate, Phase 4 customer discovery proceeded after documenting these exact blockers. [Phase 4 handoff](phase-4-handoff.md) records implemented code lookup, approved public profile/menu and saved bakeries. Availability remains incomplete pending lead-time units, business timezone and daily-capacity semantics. Phase 4 is not marked complete; Phase 5 has not begun.

## Latest status: 2026-10-27 hosted deployment

The owner completed CLI login. The configured development project was found active, matched to the local client URL and linked. All four migrations were pending; the dry-run listed exactly those versions. `db push --linked --yes` applied them without a reset, and subsequent remote/local migration history matched. Historical missing-login/configuration findings below are superseded by this section. End-to-end acceptance remains blocked by test-account/email/device checks.

| Test | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Project access/link | Authenticated CLI matched configured development project | PASS | Project ACTIVE_HEALTHY; link succeeded |
| Migration deployment/history | Four versions applied and confirmed remote | PASS | 20261026000100, 20261026000200, 20261026000300, 20261026000400 |
| Deployed database inventory | Six public tables have RLS; owner/self policies and restricted function ACLs present | PASS (schema inspection) | Read-only scripts/inspect_deployed_backend.sql executed via CLI; no user data read |
| Storage inventory | Five buckets, expected visibility, 5242880-byte limits and JPEG/PNG/WebP MIME types | PASS (schema inspection) | Profile/order/conversation private; business/product public; ownership and closed-membership policies present |
| Anonymous private profile/business reads | Rejected | PASS | Both actual REST requests returned HTTP 401 |
| Anonymous bucket/private object listings | No records returned | PASS (limited check) | HTTP 200 with empty arrays; not proof of unrelated-user denial for an existing object |
| Live Android build | Debug APK built | PASS | flutter run with ignored live dart-defines; assembleDebug completed |
| Android installation/startup | Streamed installation failed; fallback stalled and was interrupted | BLOCKED | ADB exit 1; Flutter then reported uninstalling old version with no further output; no successful startup observed |
| User authentication, email, recovery and restart | Not executed | BLOCKED | Dedicated customer/two-baker credentials and email/callback setup status pending |
| User-session RLS, pricing, persistence and image uploads | Not executed | BLOCKED | No test user sessions; administrative schema inspection is not authorization proof |
| Network interruption and account switching | Not executed | BLOCKED | Live device session not established |
| iOS | Not executed | BLOCKED | macOS/Xcode unavailable |

No service-role credential was used for authorization checks. Deployment used the authenticated CLI, and anonymous HTTP checks used the public client key. No Phase 4 work performed. Source changes remain uncommitted; no Git remote is configured.


Attempt date: 2026-10-26. Source checkpoint: `886ed70`. Starting working tree was clean. **Overall status: BLOCKED; live integration is not verified.** No next-phase features were started. This report supersedes no historical test results: prior Flutter mocks and PGlite checks remain local evidence only.

## Initial attempt environment (before setup preparation)

Read AGENTS.md, backend setup, configuration interfaces, local Supabase configuration, all four versioned migrations, Phase 2/3 handoffs, and both HTTP verification runners. Only `config/example.json` and `config/preview.json` exist. The example has live mode but empty URL/key; preview has no URL/key. `config/local.json` and `supabase/.temp/project-ref` are absent. No SUPABASE or BQ_TEST process environment variable names were present. Values were not printed. No direct Supabase project-management connector is available; the separate Lovable reference is not an identified development backend for Flutter.

Fresh CLI discovery returned `AccessTokenRequiredError` for `projects list`. `status` returned `StatusDbInspectError`, no linked project, and Docker/Podman not found. Both existing HTTP runners stopped with sanitized `FAILED: FileNotFoundError` before making backend requests. These are environment blockers, not demonstrated product failures. No project, credentials, policies or fixtures were changed; no privileged credential was used.

## Test results and sanitized evidence

PASS below describes only the stated source/preflight inspection. BLOCKED means the live test did not execute. No live scenario passed or failed in this attempt.

| ID | Test | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- | --- |
| PRE-01 | Inspect repository configuration and preserve preview isolation | Configuration interfaces and preview/live selection inspected; no config changes | PASS (source inspection) | Preview defaults to explicit fixture mode; no live URL/key in available configuration files |
| LIVE-01 | Confirm URL/key belong to intended development project | Ignored template prepared, but actual URL/key and intended project remain missing | BLOCKED | CLI discovery still returns `AccessTokenRequiredError`; no linked reference |
| LIVE-02 | Confirm migration history, grants and RLS are applied | Four local migrations inspected; remote database unavailable | BLOCKED | Versions 20261026000100, 20261026000200, 20261026000300, 20261026000400 exist in source only |
| LIVE-03 | Confirm buckets, MIME/size limits and object policies | Source definitions inspected; deployed Storage unavailable | BLOCKED | Five expected buckets listed below; local stack `StatusDbInspectError` |
| LIVE-04 | Run Flutter with actual live configuration | App was not launched with empty configuration | BLOCKED | `config/local.json` now contains only the empty template; shared port 5173 page is not Flutter live evidence |
| LIVE-05 | Registration and trigger-initialized private profile | No real registration executed | BLOCKED | Updated runner reports `BLOCKED: Set SUPABASE_URL in the ignored live configuration` before HTTP; real signup/email is a manual Flutter check |
| LIVE-06 | Email verification and resend | No inbox, project or delivery configuration available | BLOCKED | Real verification link and PKCE callback not exercised |
| LIVE-07 | Login with customer/Baker A/Baker B | No test credentials or development endpoint available | BLOCKED | No BQ_TEST process environment variable names present |
| LIVE-08 | Forgot password, recovery callback and password change | Not executed | BLOCKED | No project/email/device session; no reset email requested |
| LIVE-09 | Session restoration after process restart; invalid/expired session | Not executed | BLOCKED | Flutter live session cannot be established; token refresh mocks are not restart evidence |
| LIVE-10 | Logout, protected routes and account-switch cache isolation | Not executed live | BLOCKED | No authenticated app session or separate account sessions |
| LIVE-11 | Create and edit bakery/product/options; compare Flutter and PostgreSQL after restart | Not executed | BLOCKED | Updated Phase 3 runner reports `BLOCKED: Set SUPABASE_URL in the ignored live configuration` before HTTP |
| LIVE-12 | Authoritative pricing, minimums and delivery fee | No live RPC calculation executed | BLOCKED | PKR 4,100 fixture is prepared but not run against Supabase |
| LIVE-13 | Upload business/product images; re-open after restart | Not executed | BLOCKED | No live owning record or Storage endpoint |
| LIVE-14 | Direct two-baker ownership tests using user sessions | Not executed | BLOCKED | Existing HTTP suites require actual user access tokens obtained through login |
| LIVE-15 | Private profile read/write denial and anonymous rejection | Not executed | BLOCKED | Source RLS review does not establish deployed permissions |
| LIVE-16 | Unrelated private image/attachment read, signing and upload denial | Not executed | BLOCKED | No Storage service or known private test object; a missing-object 404 alone would not prove privacy |
| LIVE-17 | Network loss during save/upload; no false success; reconcile uncertain commit | Not executed | BLOCKED | No live app/backend; repository mocks are not a live network-failure test |
| LIVE-18 | Android and iOS live callback, picker and lifecycle behavior | Neither platform tested live in this attempt | BLOCKED | No live configuration; historical Android install failure remains separate; iOS needs macOS/Xcode |

## Expected deployed database and storage

Apply migrations in order, including 004 (it fixes object-name qualification). Confirm migration history and inspect actual table/function/policy definitions; migration version entries alone do not prove absence of drift.

- 001 identity: profiles/customer_profiles/baker_profiles/businesses, profile trigger, verified identity RPC, grants and owner/self RLS.
- 002 storage: private profile images, public business images, reserved product images and restrictive private attachment policies.
- 003 catalog: English-only constraint, business details/revision/code, products/delivery zones, revision-checked workspace/activation RPCs, approved public projection and authoritative integer-paisa estimate.
- 004 catalog storage: owned product/cover uploads, pointer revision RPC, referenced-image deletion protection and continued private attachment denial.
- Expected buckets: `profile-images` private, `business-images` public, `product-images` public, `order-references` private, `conversation-attachments` private. Each is limited to 5 MiB and JPEG/PNG/WebP. Order/conversation uploads remain denied until real membership models exist.

Administrative schema inspection may use the development dashboard/CLI database connection. Authorization acceptance must use the public client key plus each actor's own Auth session, never service-role access.

## Exact setup needed from the owner

Choose an identified hosted **development** project or disposable local stack. Do not reuse the separate reference application's project without confirming its purpose and schema. The non-secret project name/reference can be supplied in chat; passwords, CLI tokens and privileged keys must remain in local secure prompts/credential storage.

### Hosted development

From the workspace root in PowerShell:

```powershell
cd mobile
npx.cmd --yes supabase@2.122.0 login
npx.cmd --yes supabase@2.122.0 projects list
$developmentProjectRef = Read-Host 'Confirmed development project reference'
npx.cmd --yes supabase@2.122.0 link --project-ref $developmentProjectRef
npx.cmd --yes supabase@2.122.0 migration list --linked
npx.cmd --yes supabase@2.122.0 db push --dry-run
```

Verify the selected project identity and review the dry-run before applying to that development project:

```powershell
npx.cmd --yes supabase@2.122.0 db push
npx.cmd --yes supabase@2.122.0 migration list --linked
if (-not (Test-Path config/local.json)) { Copy-Item config/example.json config/local.json }
notepad config/local.json
```

In the ignored file, set APP_MODE to `live`, SUPABASE_URL to the selected project's API URL, SUPABASE_PUBLISHABLE_KEY to its public publishable/anon key, and AUTH_CALLBACK_BASE to `dev.bakequote.mobile://auth`. Obtain the URL and key from the same project's dashboard; match the hosted URL project reference to the linked project. A publishable-key prefix alone does not prove project ownership. Never put a service-role key, secret key, DB password or CLI access token in this file.

Enable signup/email confirmation and an authorized email sender. Allow exactly `dev.bakequote.mobile://auth/verify` and `dev.bakequote.mobile://auth/reset`. Use real accessible test mailboxes and request each PKCE link from the installation that will open it. Confirmed fixture accounts alone do not replace testing new registration/verification/reset email delivery.

### Disposable local alternative

Install/start Docker Desktop or Podman, then from `mobile`:

```powershell
npx.cmd --yes supabase@2.122.0 start
npx.cmd --yes supabase@2.122.0 test db
if (-not (Test-Path config/local.json)) { Copy-Item config/example.json config/local.json }
notepad config/local.json
adb -s emulator-5554 reverse tcp:54321 tcp:54321
adb -s emulator-5554 reverse tcp:54324 tcp:54324
```

Use API URL `http://127.0.0.1:54321` and only the stack's public publishable/anon key in the file. Keep all CLI key output local. Local mail UI is `http://127.0.0.1:54324`. The existing setup documents disposable resets if required; do not reset operational data.

### Flutter and authenticated HTTP tests

```powershell
$env:Path = "D:\flutter\flutter\bin;D:\SDK\platform-tools;" + $env:Path
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/local.json
```

Replace the device ID with an available device from `flutter devices`. Changing dart-defines requires full restart. Register and verify one customer and two baker accounts using disposable test data; complete their corresponding identity setup. Use separate accounts while dual-role behavior remains unresolved.

Run both HTTP scripts in the same terminal as the secure prompts (credentials in a different process are not automatically available to this agent). Review their fixture effects first: the Phase 3 runner replaces/deactivates the dedicated Baker A catalog/zone fixture. Do not use an operational bakery.

```powershell
$testRoles = @('CUSTOMER', 'BAKER_A', 'BAKER_B')
try {
    foreach ($testRole in $testRoles) {
        [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_EMAIL", (Read-Host "$testRole email"), 'Process')
        $testSecret = Read-Host "$testRole password" -AsSecureString
        $testCredential = New-Object System.Management.Automation.PSCredential('test', $testSecret)
        [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_PASSWORD", $testCredential.GetNetworkCredential().Password, 'Process')
    }
    python scripts/verify_backend.py --config config/local.json
    if ($LASTEXITCODE -ne 0) { throw 'Identity/permission suite did not pass; inspect sanitized results before continuing.' }
    python scripts/verify_phase3.py --config config/local.json --confirm-development
    if ($LASTEXITCODE -ne 0) { throw 'Catalog suite did not pass; inspect sanitized results.' }
} finally {
    foreach ($testRole in $testRoles) {
        [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_EMAIL", $null, 'Process')
        [Environment]::SetEnvironmentVariable("BQ_TEST_${testRole}_PASSWORD", $null, 'Process')
    }
    $testSecret = $null
    $testCredential = $null
}
```

## Required interactive completion once unblocked

Use the [Phase 3 demonstration](phase-3-handoff.md#demonstration) in live mode. Save bakery and cake/size/finish/extra/delivery settings, record sanitized revision and expected integer totals, terminate/relaunch Flutter, and compare reloaded values to PostgreSQL. Verify PKR 3,800 subtotal plus PKR 300 delivery = PKR 4,100 (410000 paisa). Repeat after edits. Upload/replace a real image, restart, and verify both persisted pointer and returned bytes.

Test registration/resend/verification and reset with delivered email on the same installation; then password login, cold restart, logout, expired sessions and account switching. Capture only status, timestamps, row counts/revisions and redacted test aliases; never tokens, passwords, email-link codes, exact private contact data or signed URLs.

For failure handling, interrupt the test device connection before saving, during upload, and after request dispatch before response. Confirm no success message is shown without acknowledgement, input remains available, duplicate taps do not create duplicate records, and reconnect/reload reconciles whether an uncertain write committed. A committed image must remain referenced and protected; an abandoned upload must be queued for cleanup. Record actual UI and backend state for each timing case; do not treat all network failures as rollback.

Private-object denial checks must first establish a known existing private test object accessible to its owner, then attempt unrelated/anonymous download/sign/list/write using their user sessions. For closed future attachment buckets, confirm upload denial and inspect deployed restrictive policies; any pre-existing test objects must also be inaccessible. Tests and schema inspection must not weaken policies to populate private buckets.

The initial blocked attempt changed only documentation. Subsequent setup preparation is recorded below. Resume LIVE-01 through LIVE-18 after configuration and access are supplied; keep overall live acceptance blocked until the recorded evidence actually supports it.

## Owner-assisted setup preparation

The [numbered hosted development guide](hosted-development-setup.md) specifies the exact loader keys, file path, CLI deployment process, callback settings, supported modes and secure test-account prompts. A credential-free `config/local.json` was copied from the existing example only because it was absent; Git confirms it is ignored. It is a template, not a configured or verified connection. The owner must choose/confirm the development project, complete local CLI login/link, fill the public URL/key, deploy pending migrations after a dry-run, configure permitted email delivery and register three distinct test accounts. No project or paid resource was created; no database was reset or migrated remotely.

Implementation changes: Flutter now identifies missing live URL/key and the required dart-define file in its error. Both HTTP runners share sanitized configuration validation, reject preview/privileged keys and placeholders, validate all required account variables before requests, and support `--preflight-only`. Setup errors use exit 2 (`BLOCKED`), assertions/network failures remain exit 1 (`FAILED`). Successful preflight explicitly states that live behavior and project identity are not verified. The invented example.test signup request was removed because it cannot prove delivered verification and is unsuitable for restricted hosted senders; the runner labels fresh registration/email/recovery as manual required checks. This does not weaken Auth confirmation or replace real acceptance with admin-created accounts.

Current fresh evidence: CLI `projects list` returns `AccessTokenRequiredError`; both runner preflights stop before network with `BLOCKED: Set SUPABASE_URL in the ignored live configuration`. The ignore check matches `.gitignore: config/local.json`. Local validation results are recorded separately below; no LIVE row is promoted to PASS by them.

### Local setup-preparation checks (2026-10-26)

| Check | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Dart formatting | 32 files unchanged | PASS | `dart format --output=none --set-exit-if-changed lib test`, exit 0 |
| Flutter analysis | No issues | PASS | `flutter analyze --no-pub`, exit 0 |
| Flutter automated tests | 49 tests passed | PASS | `flutter test --no-pub`; includes missing-configuration widget regression; uses local/fake/mocked dependencies |
| Setup validator tests | 10 tests passed | PASS | `python -m unittest discover -s scripts -p test_backend_setup.py -v`; rejects privileged keys, malformed/placeholder config and missing accounts without echoing values |
| Android debug build | APK produced | PASS | `flutter build apk --debug --no-pub`, exit 0; build is not device or live acceptance |
| Hosted discovery | CLI authentication absent | BLOCKED | `AccessTokenRequiredError`; no project selected or created |
| HTTP runner preflights | Missing URL identified before requests | BLOCKED | Both exit 2 with `Set SUPABASE_URL in the ignored live configuration` |
| PostgreSQL checks | Not rerun; migrations unchanged | NOT RUN | Earlier 41 modeled checks remain historical evidence only |
| Android device / iOS | Not attempted in this setup pass | BLOCKED | No live config; previous Android installation problem unresolved; iOS requires macOS/Xcode |

Changes remain local and uncommitted on `886ed70`. No Git remote is configured. Owner access/setup is still required before live verification can resume; Phase 4 has not started.


## Configuration repair and hosted reachability follow-up

This follow-up supersedes earlier missing/invalid-configuration findings. The owner identified the development project; the ignored local configuration was rewritten as valid JSON with only the four supported client settings. No privileged key was saved or used. A privileged credential disclosed in conversation must be revoked/rotated by the owner; it is deliberately omitted from this report.

| Check | Actual result | Status | Sanitized evidence |
| --- | --- | --- | --- |
| Local configuration and ignore rule | Client-only JSON validated; Git ignores file | PASS | Shared setup validator passed; git check-ignore matched |
| Hosted Auth reachability with public key | Request accepted | PASS | GET /auth/v1/settings returned HTTP 200 |
| Email Auth settings | Email provider enabled; auto-confirm disabled | PASS | Boolean settings only; email delivery untested |
| Profile REST availability | Endpoint unavailable in schema cache | FAIL | GET /rest/v1/profiles?select=id&limit=1 returned HTTP 404, PGRST205; migration deployment/schema inspection required |
| CLI project discovery/deployment | Authentication missing | BLOCKED | AccessTokenRequiredError; no remote migrations applied by agent |
| Identity authorization suite | Test identities not supplied locally | BLOCKED | Missing CUSTOMER, BAKER_A and BAKER_B email/password environment variables; preflight only |
| Catalog authorization suite | Baker test identities not supplied locally | BLOCKED | Missing BAKER_A and BAKER_B email/password environment variables; preflight only |
| Full Flutter/Auth/email/storage lifecycle | Not executed | BLOCKED | Deployment and test accounts pending; reachability does not establish live acceptance |

Next: owner completes CLI login locally, then agent can inspect/link the identified development project and review migration history/dry-run before deployment. Register separate test identities after schema and email setup. Keep passwords in secure terminal prompts. No Phase 4 work performed.


### Email delivery guided check (2026-10-27)

Owner reports custom SMTP disabled; callbacks and all three test identities remain unconfirmed. Prepared scripts/check_signup_email.py for one interactive signup using the exact organization-member inbox and a locally entered hidden password. It checks confirmation remains enabled, performs at most one signup POST without retries, and prints only timestamp/status. Syntax and mocked single-request/confirmation-guard checks passed; no real signup request executed by this preparation. Receipt remains UNVERIFIED until owner confirms it. An accepted signup response alone is insufficient. On failure, inspect sanitized Auth logs for this request timestamp before any resend. This terminal transport check does not verify Flutter PKCE or callbacks; Phase 4 remains paused.


### Single signup email request executed

Owner authorized one request to their organization-member inbox. Auth settings confirmed email signup enabled and auto-confirm disabled immediately before sending. One POST /auth/v1/signup was executed at 2026-10-26T23:59:42+00:00 (2026-10-27 04:59:42 Pakistan time), returning HTTP 200. No retry/resend performed. Generated test credentials and attempt marker are stored only in a Git-ignored local file; credentials and response bodies were not logged. Delivery remains UNVERIFIED pending owner receipt confirmation. HTTP 200 alone does not prove email delivery, new account creation or Flutter callback success. If receipt fails, inspect sanitized Auth logs for this timestamp before further sending. Phase 4 remains paused.


### Email receipt and failed browser redirect follow-up

Owner confirmed receipt of the one signup email, then reported localhost ERR_CONNECTION_REFUSED after clicking. Email delivery for this organization-member inbox is PASS (owner-observed); arbitrary customer inbox delivery remains unverified with default SMTP. A diagnostic password login using the locally saved test credentials returned HTTP 200, email_confirmed_at was present, own-profile read returned HTTP 200 with one profile, and diagnostic session logout returned HTTP 204. No response bodies/tokens were logged and no email was resent. This confirms email confirmation, one-account password login, trigger initialization and server logout; it does not verify native session restoration, UI logout or cross-account access.

Callback remains FAIL/UNVERIFIED: localhost redirect suggests fallback to the hosted Site URL, but hosted URL settings have not yet been inspected. Native manifests register dev.bakequote.mobile://auth; expected redirect allowlist entries are /verify and /reset. The terminal signup checks transport only and did not initiate Flutter PKCE, so its link cannot establish a passing Flutter callback test. Next owner step: inspect hosted Authentication URL Configuration and add the exact native callbacks. An installed live app is needed before a fresh Flutter-originated callback check. Do not reuse/resend the consumed signup link. Phase 4 remains paused.


### Hosted callback settings confirmed by owner screenshot

Owner confirmed saving Site URL dev.bakequote.mobile://auth/verify. Screenshot shows that exact value and both native /verify and /reset allowlist entries. Configuration is confirmed by owner-provided UI evidence; no fresh Flutter PKCE or recovery callback has yet been executed. No email was sent during this step. Android emulator is booted with 3.1 GiB free, package manager responsive, and an installed older APK launches; its hash does not match the latest live build. Non-streamed live APK update is being checked separately.

Non-streamed adb install -r timed out after 55 seconds. Installed APK still does not match live build; device callback acceptance blocked. No reset, data clear or uninstall was performed. No email was sent.
