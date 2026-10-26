# Agent instructions

This repository is the new native Flutter app. The sibling Lovable web checkout is a design reference; preserve it. Do not embed it in a WebView or put mobile code in its source tree.

## Structure

- `lib/app`: application composition and go_router configuration.
- `lib/core`: theme, localization and backend configuration.
- `lib/features/<feature>/domain`: pure Dart value objects and rules, no Flutter/network imports.
- `lib/features/<feature>/data`: repository implementations and DTO mapping.
- Feature application state belongs in Riverpod providers/controllers, and presentation in widgets.
- `lib/features/preview`: isolated fixtures, explicitly labeled. Preview roles are not authentication.
- `lib/shared/widgets`: shared controls. Use directional layout and localized copy.

## Invariants

Use integer minor currency units. Mobile estimates are advisory. Server functions must authorize and calculate prices, version quotations, enforce idempotency and transact confirmation/capacity checks. Pending does not reserve capacity. Chat never changes price or confirms an order. Revision invalidates prior agreement. Manual orders never create accounts or conversations. Keep private notes/events in separate protected storage; never rely only on client projections. Do not port the prototype's demo allowance into production.

No service-role keys or privileged secrets in clients, fixtures or commits. Add database RLS and storage ownership tests before enabling live services. Do not invent legal policy, prices, retention or plan limits.

## Verification and scope

Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` and an Android debug build for relevant changes. Record actual results and blockers in `docs/project-status.md`; distinguish iOS checks. Do not claim device acceptance from widget tests. Test version agreement and capacity races at the database boundary when implemented. Keep both languages and narrow RTL layouts usable.

Current authorized scope: Phase 1 only. Do not start Phase 2 until requested. Maintain all handoff documents. Commit local checkpoints when requested; never rewrite published reference history.
