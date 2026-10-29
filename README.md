# BakeQuote Mobile

English-only Flutter/Dart app for Android/iOS. Phases 1–5 now include authentication, baker setup/catalog/pricing, availability, customer bakery access and Pending order requests with private references. Development Supabase has seven migrations; full multi-account acceptance remains blocked by dedicated verified baker credentials. See [Phase 5 handoff](docs/phase-5-handoff.md) and [actual evidence](docs/integration-verification.md). Chrome is a development host; native acceptance remains deferred. Stop before Phase 6.

Validated baseline SDK: Flutter 3.41.1 stable / Dart 3.11.0. Development identifiers: Android `dev.bakequote.bakequote_mobile`, iOS `dev.bakequote.bakequoteMobile`; callback scheme `dev.bakequote.mobile`. These are development defaults, not final store identities.

## Preview mode (no backend or credentials)

From the workspace root:

```powershell
cd mobile
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/preview.json
```

Start an emulator first, or substitute a listed device ID. `flutter run -d chrome --dart-define-from-file=config/preview.json` previews the same native Flutter widgets in a browser. Preview is the default when APP_MODE is omitted. It uses explicitly labeled fixtures, never initializes Supabase, and cannot enter live routes. Selecting a preview role never grants backend access. The earlier blank-looking run-command section is replaced by the explicit commands above; the [Phase 1 handoff](docs/phase-1-handoff.md) preserves baseline results.

## Live mode (development backend)

1. Follow [backend setup](docs/backend-setup.md) to create/migrate a disposable local stack or link an existing hosted development project. Do not use a production project for integration fixtures.
2. Copy the example into an ignored local file:

```powershell
Copy-Item config/example.json config/local.json
```

3. Edit `config/local.json` locally. Set APP_MODE to `live`, SUPABASE_URL to the actual API URL and SUPABASE_PUBLISHABLE_KEY to the public publishable key (legacy anon JWT also supported). Keep AUTH_CALLBACK_BASE as `dev.bakequote.mobile://auth` for Android/iOS. No service-role/secret key, database password or access token belongs in Flutter or this file. Runtime values are compiled into the app; public keys are not a substitute for RLS.
4. Run:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config/local.json
```

Changing compile-time settings requires restarting the run/build, not hot reload. Live mode never falls back to sample identity if configuration, sessions or profile reads fail. It shows a retryable unavailable state. Email/password registration, verification/resend, login, recovery/password update, session restoration and logout use the Supabase SDK. First verified sign-in completes an initial customer/baker identity. Bakers receive an owned private business draft; business setup, catalog and pricing are under Open baker setup. Profile/name/phone and owned image uploads are available under Account. Real orders/messages remain later-phase placeholders and show no demo records in live mode.

Android debug local HTTP is allowed only for localhost/127.0.0.1/10.0.2.2. Hosted configuration requires HTTPS. Native email callbacks use PKCE and must open on the installation that requested them. A completed verification can also be followed by ordinary password sign-in. Reset and verification callbacks are classified by both exact URI and SDK exchange result; changing a URL type parameter cannot turn verification into recovery.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Current local tests include fake-repository/controller and HTTP-mocked SDK checks; they do not prove live permissions. Backend checks and separate-account scenarios are documented in [backend setup](docs/backend-setup.md) and [handoff](docs/phase-2-handoff.md).

On macOS with Xcode/CocoaPods, run `flutter build ios --simulator`, then `flutter run -d <ios-device-id> --dart-define-from-file=config/local.json`. iOS building/signing/device flows were not executed on this Windows host. Generated development launcher icons remain placeholders.

## Documents and source control

- [Database and storage](docs/database-and-storage.md): migrations, grants, policies, paths and test boundaries.
- [Implementation plan](docs/implementation-plan.md), [traceability](docs/requirements-traceability.md), [decisions](docs/decisions.md).
- [Architecture contract](docs/architecture.md), [NFR register](docs/non-functional-requirements.md) and [Phase 1-3 audit](docs/architecture-nfr-audit.md).
- [Reference audit](docs/reference-audit.md): the separate Lovable implementation remains a reference.
- [Current status](docs/project-status.md) and [Phase 3 verification/handoff](docs/phase-3-handoff.md).

Phase 1 checkpoint: `7a0e150`. Phase 2 is a separate local commit; inspect `git log -1 --oneline`. No GitHub remote is configured, and this work has **not** been backed up remotely. After you create an empty mobile repository, connect it explicitly:

```powershell
git remote add origin https://github.com/<owner>/<new-mobile-repository>.git
git push -u origin main
```

Phase 3A establishes architecture and non-functional acceptance criteria only. Do not start Phase 4 until authorized. Backend credentials, final role/membership product decisions, proposed NFR targets and live acceptance remain tracked rather than assumed.

## Phase 3 demonstration and local database checks

BakeQuote is English-only. Legacy stored locale values fall back to English. The remaining fonts are Manrope and Fraunces. There is no language switch.

Open baker preview, then **Open baker setup**. Use Setup, Catalog, Fulfilment, Pricing and Review. Save draft changes explicitly; reopening the app restores the preview workspace on this device. Live mode uses the same controls with Supabase persistence and ownership checks. No sample catalog is installed for real accounts. See the complete [demonstration path](docs/phase-3-handoff.md#demonstration).

For a reproducible isolated PostgreSQL/WASM test of all migrations (Node.js required):

```powershell
npm.cmd ci --prefix scripts/sql-test
node scripts/sql-test/verify.mjs
```

This executes PostgreSQL grants/RLS/functions against modeled Auth/Storage schemas. It does not start or verify Supabase Auth, PostgREST, email, Storage HTTP, bucket MIME limits or native callbacks. The real stack checks remain separate:

```powershell
npx.cmd --yes supabase@2.122.0 test db
python scripts/verify_backend.py --config config/local.json
python scripts/verify_phase3.py --config config/local.json --confirm-development
```

The HTTP tests require dedicated accounts configured through the secure local prompts in [backend setup](docs/backend-setup.md). The Phase 3 script intentionally replaces the fixture business's catalog/zone availability; use disposable development businesses only.

On this workstation, if Flutter/ADB are not on PATH, prepend their existing installation directories for this PowerShell process:

```powershell
$env:Path = "D:\flutter\flutter\bin;D:\SDK\platform-tools;" + $env:Path
```
