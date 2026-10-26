# BakeQuote Mobile

Native Flutter/Dart app for customers and home bakers. Phase 2 adds Supabase authentication, private persistent profiles and explicit business ownership. **Live integration acceptance is blocked pending a development backend; see [Phase 2 handoff](docs/phase-2-handoff.md).** Later ordering/catalog workflows are not implemented.

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

Changing compile-time settings requires restarting the run/build, not hot reload. Live mode never falls back to sample identity if configuration, sessions or profile reads fail. It shows a retryable unavailable state. Email/password registration, verification/resend, login, recovery/password update, session restoration and logout use the Supabase SDK. First verified sign-in completes an initial customer/baker identity. Bakers receive an owned private business draft; full business onboarding remains Phase 3. Profile/name/phone and owned image uploads are available under Account. Real orders/messages remain later-phase placeholders and show no demo records in live mode.

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
- [Reference audit](docs/reference-audit.md): the separate Lovable implementation remains a reference.
- [Current status](docs/project-status.md) and [Phase 2 verification/handoff](docs/phase-2-handoff.md).

Phase 1 checkpoint: `7a0e150`. Phase 2 is a separate local commit; inspect `git log -1 --oneline`. No GitHub remote is configured, and this work has **not** been backed up remotely. After you create an empty mobile repository, connect it explicitly:

```powershell
git remote add origin https://github.com/<owner>/<new-mobile-repository>.git
git push -u origin main
```

Stop before Phase 3. Backend credentials, final role/membership product decisions and live acceptance remain tracked rather than assumed.
