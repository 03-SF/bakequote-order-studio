# Current project status — Phase 2

Date: 2026-10-26. Phase 1 baseline is archived at 7a0e150 and in [phase-1-handoff.md](phase-1-handoff.md). Current scope stops before Phase 3.

**Phase 2 source is implemented and locally tested. Live Supabase integration and permission acceptance remain blocked and are not claimed complete.**

## Implemented

- Supabase configuration/client lifecycle, explicit preview/live isolation and public-key validation. No secrets or local credential files are committed.
- Real SDK calls for registration, verification/resend, login, forgot/reset/password update, logout, restoration and invalid sessions; loading/error gates and duplicate-action protection.
- Exact Android/iOS development callbacks using AppLinks/PKCE; SDK-typed recovery enforcement and a per-project/user recovery marker across restarts. Password update requires fresh sign-in.
- Persistent own profile name/phone/locale and image APIs; verified first-identity onboarding; baker ownership plus a private draft business. Full bakery setup remains Phase 3.
- Two versioned migrations for schema/grants/RLS/functions and storage. Safe initialization ignores privilege metadata; no client admin/operator role. Future product/order/conversation uploads remain denied.
- Authenticated role-aware navigation preserves theme/Riverpod/go_router/English-Urdu RTL and existing domain rules. Account changes clear profile/provider/form/image state; stale reads/writes cannot repopulate a logged-out identity.
- Backend setup, database/storage policies, traceability, decisions and detailed [Phase 2 handoff](phase-2-handoff.md), including separate-account acceptance scenarios.

## Checks actually executed

| Check | Result |
| --- | --- |
| Phase 1 baseline | Clean working tree at 7a0e150; analyze clean and 8 tests passed |
| Flutter tests | 29 passed: existing domain/navigation tests plus auth-controller, live-form/RTL and SDK HTTP-mock callback tests |
| Formatting | Passed: 22 Dart files, 0 changes in the final format check |
| Static analysis | Passed: no issues found in final analysis |
| SQL/PLpgSQL parser | Both migrations and transactional pgTAP suite parsed successfully; syntax only |
| Python HTTP test script | Compiled successfully; real backend requests not run without configuration/accounts |
| iOS plist | Parsed successfully and callback keys checked; this is not an iOS build/runtime test |
| Android debug build | Succeeded (221.1 seconds) with Kotlin fallback after the known C:/D: incremental-cache issue |
| Android live-mode build/startup | Rebuilt/installed on Android 16 emulator; missing-configuration smoke test exposed provider retries keeping loading visible. Fixed with explicit initialization retry behavior, bounded wait and regression test; corrected run rebuilt successfully (58.2 seconds), installed (14.7 seconds) and produced normal Flutter startup logs. Final visual confirmation was blocked when ADB became offline/still authorizing; the configuration error is verified by the real-provider widget regression test |
| Final-source Android APK | `flutter build apk --debug --no-pub --dart-define=APP_MODE=live` succeeded (102.6 seconds); no credentials embedded |
| Android callback registration | ADB query resolves dev.bakequote.mobile://auth/verify to the BakeQuote activity |
| Hosted Supabase discovery | Failed with AccessTokenRequiredError: no CLI login/access token |
| Local Supabase discovery | Failed with StatusDbInspectError: Docker/Podman not found; no linked project |
| pgTAP database tests | Attempted, blocked by DbConnectError / ECONNREFUSED 127.0.0.1:54322 |
| Live Auth/email/RLS/Storage | Not executed; no available migrated project/public config or verified test-account credentials |
| iOS build/sign/device | Not executed; Windows host lacks macOS/Xcode environment |

Local tests use repository fakes and mocked HTTP where stated. They do not verify real email delivery, native authenticated restart, RLS/storage requests or live image uploads. The SQL parser proves syntax, not grants or policies at runtime. No database migration has been applied here. Focused authentication-widget tests were also rerun: all 3 passed.

## Blockers and owner decisions

To complete live acceptance, make a migrated local Supabase stack available or complete local CLI login/link for an existing hosted development project. Put the actual public URL/key in ignored `config/local.json`, configure exact email redirects/sender, and use dedicated verified customer/Baker A/Baker B accounts via secure local prompts. [Backend setup](backend-setup.md) has exact commands and no service-role requirement in Flutter.

Dual-role enrollment, multiple-business/team behavior, final app identifiers/universal links, legal/retention/deletion, cleanup of replaced image objects, production backup responsibilities and image rights remain unresolved. Current initial-experience UI and one draft per baker are explicitly provisional, not silent final product decisions. No Phase 3 catalog/order/communication workflows were added.

## Source control and handoff

Phase 2 is saved as a separate local commit on main; inspect `git log -1 --oneline` for its exact hash. Phase 1 history is preserved. There is still no GitHub remote and no remote backup. Run using [README commands](../README.md), and follow the [Phase 2 handoff](phase-2-handoff.md) to finish infrastructure-dependent acceptance. Stop before Phase 3.
