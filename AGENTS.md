# Agent instructions

This repository is the new native Flutter app. The sibling Lovable web checkout is a design reference; preserve it. Do not embed it in a WebView or put mobile code in its source tree.

## Structure

- `lib/app`: application composition and go_router configuration.
- `lib/core`: theme, English copy and backend configuration.
- `lib/features/<feature>/domain`: pure Dart value objects and rules, no Flutter/network imports.
- `lib/features/<feature>/data`: repository implementations and DTO mapping.
- Feature application state belongs in Riverpod providers/controllers, and presentation in widgets.
- `lib/features/preview`: isolated fixtures, explicitly labeled. Preview roles are not authentication.
- `lib/shared/widgets`: shared controls. Use directional layout and readable English copy.

## Invariants

Use integer minor currency units. Mobile estimates are advisory. Server functions must authorize and calculate prices, version quotations, enforce idempotency and transact confirmation/capacity checks. Pending does not reserve capacity. Chat never changes price or confirms an order. Revision invalidates prior agreement. Manual orders never create accounts or conversations. Keep private notes/events in separate protected storage; never rely only on client projections. Do not port the prototype's demo allowance into production.

No service-role keys or privileged secrets in clients, fixtures or commits. Add database RLS and storage ownership tests before enabling live services. Do not invent legal policy, prices, retention or plan limits.

## Verification and scope

Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` and an Android debug build for relevant changes. Record actual results and blockers in `docs/project-status.md`; distinguish iOS checks. Do not claim device acceptance from widget tests. Test version agreement and capacity races at the database boundary when implemented. Keep English layouts accessible at narrow widths and large text sizes.

Current authorization (2026-10-28): Phase 4 availability and customer bakery experience implementation plus laptop verification. Native APK installation/device acceptance is explicitly deferred: do not retry emulator installation. Follow `docs/architecture.md` and `docs/non-functional-requirements.md`. Six migrations are deployed. Phase 4 availability, discovery and saved/recent workflows are implemented under the explicit provisional scheduling defaults in decisions 39–43. Two-baker/email/device acceptance gaps remain in `docs/integration-verification.md`; do not claim full live acceptance. Dual-role is unresolved. Stop before Phase 5. Commit the requested local checkpoint without rewriting history or claiming remote backup.

## Phase 2 access boundaries

Explicit APP_MODE selects preview or live at startup. Preview never initializes Supabase and cannot access live routes. Keep authenticated data out of fixture repositories. Auth callbacks are handled once through AppLinks and PKCE exchange; recovery is checked against the SDK exchange result, not a URL type flag. Preserve same-installation recovery state across restarts. Guard initialization, errors and account switches; clear private state and image cache on identity changes.

Apply only versioned Supabase migrations. Keep profile/identity/ownership fields under column grants plus RLS. Privileged functions must validate auth.uid(), use a fixed empty search_path and revoke default PUBLIC EXECUTE. Initial experience is not an admin entitlement; dual-role behavior remains an owner decision. Private order/conversation uploads stay denied until real membership tables exist. Never make them permissive just for UI tests.

Report fake/HTTP-mocked Flutter tests separately from pgTAP and real Auth/PostgREST/Storage verification. SQL parsing is syntax validation only. Do not call live integration complete while real email, permissions and native restart/callback tests are blocked. Do not publish or imply remote backup; no GitHub remote is configured.
