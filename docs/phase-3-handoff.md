# Phase 3 verification and handoff

Date: 2026-10-26. Baseline verified at `f5c5986` (clean tree); Phase 1 checkpoint `7a0e150` preserved. **Phase 3 source is implemented and locally verified; live Supabase acceptance remains blocked. Stop before Phase 4.**

## Completed functionality

The application is English-only. Urdu translations, language controls, locale switching, Urdu font/assets and localization dependencies were removed before feature UI. Old locale values are ignored in Flutter and normalized by migration. Large-text and directional layout APIs remain; prior bilingual acceptance is marked superseded in the decisions/traceability documents.

Bakers complete identity to create one private business draft, then open the workspace from Today. Setup supports business name/description, owner/contact name/phone, public area, private pickup address, public logo/cover images and draft saves. Review exposes progress, code copy/native share, server-validated activation, saved-data reopening and cleanup retry. Active businesses can be edited while remaining complete.

Catalog supports cake/cupcake product creation/edit/deactivation, descriptions, public product image, cake grams/descriptive sizes, cupcake pack counts, base prices, product-specific flavour/finish/extra surcharges and availability. Fulfilment supports pickup/delivery flags, named zones/fees, minimum item subtotal and per-product minimum cakes/packs. Pricing has responsive integer-paisa preview and a saved-data server RPC. No sample data is generated for real users.

Loading/saving stages, invalid fields, safe errors, repeated-submit guards, unsaved-change prompts and account-scoped repository invalidation are implemented. Live mode never falls back to preview persistence. Public image replacement uses immutable paths, referenced-object protection and a persistent best-effort cleanup queue. Device data loss can leave server orphans; no undisclosed scheduled cleanup or retention policy exists.

## Schema and permissions

- `20261026000300_baker_catalog.sql`: normalize English locale; business details/private/public fields, generated code and revision; owned products with validated variants/options; owned delivery zones; RLS/private raw reads; locked revision-checked workspace saves; server activation; active-only approved-field public business projection; backend estimate with availability/minimum/relationship checks. Money is integer paisa (100 = PKR 1); totals must remain exactly representable by native/optional web clients.
- `20261026000400_catalog_storage.sql`: explicitly qualify storage object names (fixing a Phase 2 binding/product ambiguity), add owned covers/product images, validate and attach/remove pointers, protect referenced public images, retain restrictive order/conversation denial.
- Existing migrations remain versioned and unchanged. Privileged functions have empty search_path, ownership checks and deliberate execute grants. There is no admin self-assignment or new role exclusivity.
- Product variants/customizations are product-owned JSON arrays with stable UUIDs. Deactivate rather than delete; future orders must save immutable configuration/price/image-reference snapshots. Current estimates create no order, quote agreement, payment or capacity reservation.

See [database/storage](database-and-storage.md), [decisions](decisions.md) and [requirements](requirements-traceability.md) for exact contracts and unresolved choices.

## Exact configure/run commands

From the workspace root in PowerShell (the SDK and ADB directories must be on PATH):

```powershell
cd mobile
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/preview.json
```

This is **preview**, with device-only workspace storage. Substitute an actual listed device ID. On this workstation, PATH can be set for the current process:

```powershell
$env:Path = "D:\flutter\flutter\bin;D:\SDK\platform-tools;" + $env:Path
```

For a disposable local development backend, first install/start Docker Desktop or Podman, then:

```powershell
npx.cmd --yes supabase@2.122.0 start
npx.cmd --yes supabase@2.122.0 status
npx.cmd --yes supabase@2.122.0 db reset --local
npx.cmd --yes supabase@2.122.0 test db
Copy-Item config/example.json config/local.json
adb -s emulator-5554 reverse tcp:54321 tcp:54321
adb -s emulator-5554 reverse tcp:54324 tcp:54324
```

Reset only disposable local data. Edit ignored config/local.json locally: APP_MODE live, SUPABASE_URL http://127.0.0.1:54321, actual public publishable/anon key from local status and native AUTH_CALLBACK_BASE dev.bakequote.mobile://auth. Then:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config/local.json
```

For a hosted **development** project, use local CLI login, projects list, link, db push --dry-run and db push as documented in [backend setup](backend-setup.md). Configure exact `/verify` and `/reset` native callbacks, email confirmation/sender and same-installation PKCE. No credentials, service-role key, database password or CLI token belong in Flutter or chat. Compile-time configuration changes require a full restart.

The archived Phase 1/2 handoffs already contain executable run blocks; this section and the README are the current canonical commands.

## Demonstration

### Preview (works without Supabase)

1. Start preview, select Explore baker preview, then Open baker setup. The workspace explicitly says device-only preview. Fill Setup: business name, description, owner/contact name and phone, public area and private pickup address. Save draft changes.
2. Open Catalog, Add product. Choose Cake, enter name/description, minimum quantity 1. Add size/pack: label `2 lb`, weight `907` grams, base price `3000`. Add finish `Buttercream`, additional price `500`; add extra `Topper`, additional price `300`. Leave these options active and enable Product active. Use product changes, then Save draft changes.
3. Fulfilment: enable pickup and delivery, minimum subtotal `0`. Add named delivery zone with fee `300`; keep it active. Save draft changes.
4. Pricing: select the cake and its size, Buttercream, Topper, quantity 1 and the delivery zone. Verify subtotal PKR 3800.00, delivery PKR 300.00, estimated total PKR 4100.00. Check saved pricing reports Device preview; it is not a backend acceptance result.
5. Review the public/private distinction and setup issues, save if needed, then Review and activate. Copy/share the code. Reopen saved workspace or terminate/relaunch the app, revisit baker setup and verify saved business/catalog settings. Edit/deactivate a product and save; its record remains.
6. After saving an owning product, select logo/cover/product images. Observe upload/save stages and public image preview. Replace/remove. Induce a connection failure only in live testing to verify retry; local SDK-mock tests cover failure sequencing. Review offers Retry image cleanup.

An explicit **Load PKR 4,100 example (preview only)** action is available at the bottom of the workspace to populate the same fixture quickly. It replaces the preview workspace's product/zone list in memory; Save draft persists it on this device. That action does not exist in live mode.

### Separate live accounts (blocked until configured)

Use verified, disposable Customer, Baker A and Baker B accounts. Complete customer identity for the first and baker identity for each baker. Each baker receives its own draft, with no shared fixtures. Run the manual flow above as Baker A, using your chosen prices rather than relying on automatic seed data. Restart and verify server persistence; log out and log in as Baker B, who must not see/modify A's private business/catalog. Customer navigation must stay customer-only under the existing initial-experience model.

Run the prepared backend request suites with account credentials from secure local prompts in backend setup:

```powershell
python scripts/verify_backend.py --config config/local.json
python scripts/verify_phase3.py --config config/local.json --confirm-development
```

The Phase 3 test replaces/deactivates catalog/zone availability in the dedicated Baker A fixture business; never use an operational/production business. It tests cross-owner writes, public field projection, catalog price, product uploads and deactivation through actual HTTP when configured. The first script also checks private profiles, private image signing/download denials and registration/refresh/logout. Actual email delivery/native verification/recovery/restart/account-switch UI still require manual execution.

## Verification executed

Baseline analysis and all 29 tests passed. English cleanup analysis and five auth/navigation widget tests passed before feature UI. Full final-source check results are recorded below; SQL runtime and HTTP mocks are deliberately separate from live Supabase.

| Check | Result |
| --- | --- |
| Format/analyze/full Flutter tests | Passed: dart format --output=none --set-exit-if-changed lib test (30 files, 0 changed); flutter analyze --no-pub (no issues); flutter test --no-pub (all 48 tests) |
| Android debug build | Successful initial Phase 3 build 170.2s; edge-case rebuild 52.1s; final image-error/preview-label rebuild succeeded in 41.8s |
| Local PostgreSQL runtime | 41 checks passed; all four migrations actually applied in PGlite 0.5.11 with modeled Auth/Storage schemas/roles |
| SQL parser | Four migrations: 30/10/27/17 statements; pgTAP suites: 43/34 statements; SQL and PL/pgSQL parsing passed |
| Python scripts | py_compile passed for both HTTP runners and SQL validator |
| Real pgTAP | Attempted; failed ECONNREFUSED 127.0.0.1:54322 because no local stack |
| Hosted/local discovery | No config/local.json, CLI login/token or linked project; Docker/Podman absent; CLI projects list AccessTokenRequiredError |
| Real Phase 3 HTTP suite | Attempted; FileNotFoundError for config/local.json; no requests verified |
| Android demonstration | ADB listed emulator-5554 as device. Streamed APK install failed with empty failure detail. Launch command returned, but installed APK SHA differs from new build and UIAutomator returned null root; an alternate non-streamed install timed out after 45 seconds; no Phase 3 emulator acceptance claimed |
| iOS | Info.plist parsed; native callback scheme dev.bakequote.mobile confirmed. Swift share implementation uncompiled; no iOS build/sign/simulator/device on Windows |

Local Flutter tests cover English startup/old preference/large text, activation validation, catalog editing/deactivation/persistence, exact PKR 4,100 and minima/delivery rules, upload failure/pointer conflict/referenced cleanup/account change, and original auth/order rules. PGlite verifies SQL ownership/grants/RLS/activation/pricing/object policies, but not Supabase Auth/email/PostgREST/Storage HTTP/bucket type-size enforcement. None is claimed live-verified.

## Outstanding acceptance and owner decisions

Live sign-up/profile initialization, email verification/resend/recovery, login/authenticated restart/logout, two-user private profiles/business ownership, bucket limits/uploads/private signing, live business/catalog restart and account switching remain blocked by missing development configuration/services/accounts. [Backend setup](backend-setup.md) lists precisely what to supply locally and commands to apply/test migrations. This is an external acceptance blocker; implementation defects found locally were corrected and retested.

The dual-role product question remains open: may an existing customer enroll as a baker using the same account, and how should navigation/membership expose it? Current initial-experience and one-business draft behavior are preserved provisionally. Business ownership does not depend on a preview role or an invented admin flag. Teams/multiple businesses, production retention/deletion/server orphan cleanup, final IDs/verified links/signing, photo rights and backup ownership remain explicit future decisions.

There is no known failing local automated check at handoff. Device-specific keyboard/image-picker/share/screen-reader behavior and iOS compilation remain unverified. Android install/UI inspection is blocked as recorded above. No Phase 4 customer lookup/availability/saved-bakery workflow was started.

## Local checkpoint

A separate conventional local commit follows Phase 2; use `git log -1 --oneline` for its hash. Phase 1/2 history is retained. `git remote -v` is empty: **no remote backup or GitHub publishing has occurred**. Do not infer remote safety from a local commit.

## Phase 3A architecture and NFR baseline (2026-10-26)

Phase 3A preserves Phase 3 features and history. The verified starting checkpoint was clean `7c6b03c`; preceding commits `f5c5986` and `7a0e150` remain in history. Architecture responsibilities and remaining debt are in [architecture contract](architecture.md); stable NFR acceptance criteria are in [NFR register](non-functional-requirements.md); Phase 1-3 source/evidence gaps are in [audit](architecture-nfr-audit.md). Repository contracts now live in feature domains, the auth provider is composed from the application layer, and image signature/size validation is shared from core. No Phase 4 workflow was started.

| Phase 3A verification | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | Passed after formatting `test/auth_test.dart`; final check is recorded in the checkpoint commit. |
| `flutter analyze --no-pub` | Passed: no issues. |
| `flutter test --no-pub` | Passed: all 49 tests. |
| `npm.cmd ci --prefix scripts/sql-test` and `node scripts/sql-test/verify.mjs` | Passed: all four migrations applied in PGlite 0.5.11 and 41 local PostgreSQL/grant/RLS/function checks passed. These are modeled SQL checks, not Supabase service checks. |
| `flutter build apk --debug --no-pub` | Passed; APK at `build/app/outputs/flutter-apk/app-debug.apk`. |
| Android emulator | `adb devices -l` listed `emulator-5554`; installing this APK failed with streamed install and blank ADB failure detail. No UI/device acceptance is claimed. Prior Phase 3 alternate non-streamed install also timed out. |
| Live Supabase | `config/local.json` absent; `supabase status` reports Docker unavailable (Podman also absent), with no linked project. No live Auth, database, Storage or email checks were available. |
| iOS | Not built or device-tested. Xcode project target is iOS 13.0; Windows host has no usable Xcode/macOS environment. |

Configured Android minimum resolved from the generated manifest is API 24 with Flutter 3.41.1; iOS deployment target is 13.0. This records configuration, not tested platform support. Performance/device targets in the NFR register are proposals awaiting owner review; no performance measurements, availability, RPO or RTO commitments were made. Owner decisions for dual-role enrollment remain open. No Git remote is configured; the new local checkpoint is not remote backup. Stop before Phase 4.
