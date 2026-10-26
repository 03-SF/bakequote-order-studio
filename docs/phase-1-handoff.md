# Project status — Phase 1

Date: 2026-10-26. Scope: Phase 1 only. Phase 2 has not started.

## Completed

- Retrieved and audited the Lovable reference at `28a346ce0a4b011658f848a1d8564a8d29208783`; preserved its source and separate Git history.
- Ran the reference in Vite; inspected welcome/customer order details/baker workspace. Existing reference test suite passed 25 tests in two files.
- Created separate Flutter Android/iOS hosts and optional Flutter web preview, with BakeQuote development identity.
- Added Riverpod repository/config/locale providers and go_router customer/baker route shells, adaptive tabs/rail, safe areas and scrolling.
- Recreated cream/rose/cocoa theme, cards, buttons, wordmark, menu imagery and illustrative quotation sheet.
- Bundled the three reference photographs and Manrope/Fraunces/Noto Nastaliq Urdu fonts with OFL licenses.
- Localized foundation UI into English/Urdu with automatic RTL; sample proper names/references remain data. Language choice is in memory, not persisted.
- Added public Supabase configuration boundary/example; no credentials required and no client initialized. No backend claims, writes or real auth.
- Added pure advisory Dart estimate and order-rule foundation with immutable quote history; tests cover versioning, production sequence, offline/availability checks, duplicate operations on updated values, pending capacity semantics, cancellation distinction and delivered-order review eligibility.
- Added requested agent instructions, phase plan, requirements traceability, audit and open decisions. Local checkpoint is on main; use `git log -1 --oneline` for its exact identifier.

## Actual verification

| Check | Result |
| --- | --- |
| Flutter environment | Flutter 3.41.1 stable / Dart 3.11.0, Windows, Android SDK 36.1.0, JDK 21 |
| `dart format --output=none --set-exit-if-changed lib test` | Passed: 12 files, 0 changed |
| `flutter analyze --no-pub` | Passed: no issues found |
| `flutter test --no-pub` | Passed: 8 tests (6 domain, 2 widget) |
| Narrow RTL/text scaling | Widget tests exercise 390×844 at 160% scale, Urdu direction and customer tabs; both role navigation tested at wider width |
| `flutter build apk --debug` | Succeeded; first build 505.4 seconds, APK generated |
| `flutter run -d emulator-5554 --no-resident --no-pub` | Final corrected source rebuilt successfully (107.3 seconds), APK installed and Flutter startup completed on Android 16/API 36 x64 emulator |
| Android visual smoke check | Welcome rendered with supplied imagery, wordmark and preview label. Emulator showed an unrelated Pixel Launcher not-responding dialog; this is not full device acceptance |
| iOS | Host generated only. Not built/signed/run: requires macOS, Xcode and appropriate signing environment |
| Reference `npm test` | Passed: 25 tests; no tracked reference source changes after restoring Vite-generated route line endings |

The first test run found a narrow wordmark overflow, corrected by scaling only the brand mark to available width. A subsequent broad edit temporarily affected money rows; corrected before final passing tests/build. Initial analysis style notices were fixed with Dart tooling. The first Android build logged Kotlin incremental-cache errors involving C: pub cache versus D: project paths, then Gradle's fallback succeeded. The final rebuild succeeded. If this recurs on another machine, inspect the cache/drive configuration before changing global settings. Flutter Doctor reports some Android licenses unaccepted; build nevertheless completed with installed components. Review and accept required SDK licenses via `flutter doctor --android-licenses` when provisioning missing components.

## Remaining work and blockers

This foundation has sample/placeholder screens, not production workflows. No real authentication, profiles, migrations, RLS/storage permissions, catalog editing, bakery lookup, request creation, actual quote agreement/confirmation, concurrent capacity enforcement, operations editing/manual orders, communication/Realtime, notifications/moderation, durable drafts/offline storage, deletion or plans/backup restore exist. Follow the phase plan rather than treating previews as completed features.

No Supabase project or public configuration supplied: live Phase 2 setup requires project details, auth redirect/email configuration and verified ownership policies. No mobile GitHub repository supplied: local Git is initialized with no remote; README includes connection steps. Final app identifiers, imagery rights, legal/retention/plan policies and release credentials remain owner decisions. Default generated launcher icons remain development assets; branded store assets belong to release preparation. iOS and physical Android acceptance require suitable environments/devices.

## Handoff

Follow README commands to run. Start at welcome, select either preview role, navigate tabs, inspect the sample quotation, and switch language. Stop here: Phase 2 requires a new request. The local checkpoint includes source, lockfile, generated platform hosts and documentation, excluding build outputs and local configuration.
## Canonical Phase 1 run commands

The earlier chat run-command block may have appeared blank. From the workspace root these are the exact commands for the archived baseline:

```powershell
cd mobile
flutter pub get
flutter run -d emulator-5554
```

For the current application use the explicit preview/live commands in [setup instructions](../README.md). This file preserves Phase 1 verification; it does not claim Phase 2 live integration.
