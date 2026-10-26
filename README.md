# BakeQuote Mobile

Native Flutter/Dart Phase 1 foundation for Android and iOS. This is a clearly labeled development preview, not a production ordering app. No real account is signed in, and no data is sent to Supabase.

## Run

Validated SDK: Flutter 3.41.1 stable / Dart 3.11.0. Install Flutter and the Android SDK, then from this directory:

```powershell
flutter doctor -v
flutter pub get
flutter run -d emulator-5554
```

Select another available device using `flutter devices`. An emulator must be started first. For a browser preview of the same Flutter widgets:

```powershell
flutter run -d chrome
```

Choose customer or baker preview. Use the top language button for Urdu/English; the role-switch button returns to welcome. Explore Orders and open the sample quotation. Sample bakery/products/prices are fixtures. Calendar, messages, accounts and bakery access explain their planned phases.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Android APK: `build/app/outputs/flutter-apk/app-debug.apk`. On macOS with Xcode and CocoaPods, run `flutter build ios --simulator`, then `flutter run -d <ios-device-id>`. Signing, physical iOS verification and release builds have not been completed on this Windows host. Review the actual results in [project status](docs/project-status.md).

## Configuration

No credentials are needed. [Example configuration](config/example.json) supplies only empty public client settings. Copy to ignored `config/local.json`, and later use:

```powershell
flutter run --dart-define-from-file=config/local.json
```

Only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` belong in client configuration. These compile-time values are recoverable from app binaries. Never put service-role keys, database passwords or privileged integration secrets here. Phase 1 deliberately does not initialize Supabase even if settings are supplied. Phase 2 adds initialization, auth lifecycle/error handling, redirect registration and verified RLS before using a live project.

## Project identity and source control

Package: `bakequote_mobile`; display name: BakeQuote; Android application ID: `dev.bakequote.bakequote_mobile`; iOS bundle ID: `dev.bakequote.bakequoteMobile` (generated development defaults). Choose owned reverse-domain identifiers before store registration. This is a separate Git repository; the web reference lives outside it at `../reference/bakequote-order-studio`.

No mobile GitHub remote was supplied and none was created. After creating an empty repository, connect this local checkpoint:

```powershell
git remote add origin https://github.com/<owner>/<new-mobile-repository>.git
git push -u origin main
```

## Architecture and handoff

- [Reference audit](docs/reference-audit.md): implemented versus planned evidence, visual tokens and provenance.
- [Implementation plan](docs/implementation-plan.md): feature boundaries, backend transaction design and phase gates.
- [Requirements traceability](docs/requirements-traceability.md): requirements mapped to evidence or a future phase.
- [Decisions](docs/decisions.md): assumptions and unresolved owner choices.
- [Project status](docs/project-status.md): verification and remaining blockers.

Only Phase 1 is implemented. Stop before applying migrations, creating accounts or connecting a production service.
