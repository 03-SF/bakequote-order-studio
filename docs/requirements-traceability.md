# Requirements traceability

Statuses: Foundation = Phase 1 code; Implemented/pending integration = Phase 2 source and local tests, with live backend acceptance unverified; Planned = later work. See the Phase 2 evidence matrix below.

| ID | Requirement | Current evidence / status | Delivery phase |
| --- | --- | --- | --- |
| F01 | Separate native Flutter product and Git history | Android/iOS generated hosts, Dart app, separate local repository | 1 |
| F02 | Reference preservation and implemented/planned audit | reference-audit.md, sibling checkout | 1 |
| F03 | Theme/assets/shared controls | core/theme, shared/widgets, bundled fonts/images | 1 |
| F04 | Riverpod/go_router/feature separation | app/app.dart, preview repository/providers, domain modules | 1 |
| F05 | Both role navigation foundations | Customer four destinations, baker five, adaptive rail/tabs | 1 |
| F06 | English/Urdu + RTL | core/l10n, Material localization delegates, bundled Urdu font; foundation copy translated, fixture names remain data | 1; complete product 9 |
| F07 | Safe config without credentials | BackendConfig plus explicit preview/live modes; empty public example; SDK initialized only in live mode | 1,2 |
| A01 | Register/verify/login/reset/session | Supabase repository, auth controller/screens, guards and SDK HTTP-mock tests; real email/native restoration pending | 2 implemented/pending integration |
| A02 | Profiles/ownership/RLS/storage privacy | Versioned migrations, pgTAP/HTTP tests prepared; no live database/storage execution | 2 implemented/pending integration |
| B01 | Business onboarding and account preferences | Phase 2 identity/profile editing and owned private draft; full business setup and notification preferences remain planned | 2 foundation; 3,8 |
| B02 | Products/size/quantity/flavour/finish/extras/images/prices | Read-only sample menu, advisory price objects; planned catalog repositories | 3 |
| B03 | Delivery zones/fees, minimum, lead time/capacity/blocked dates | Planned transactional availability model | 3,4 |
| C01 | Bakery code/shared link/profile/menu/availability/saved bakeries | Sample code/profile only; no lookup or saved mutation | 4 |
| O01 | Customize, date/pickup/delivery/contact/design/images/drafts | Planned request workflow | 5 |
| O02 | Estimate and submission Pending; no pending capacity reservation | Pure estimate and reservesCapacity tests; planned authoritative RPC/idempotency | 1 foundation; 5 backend |
| O03 | Review versioned quote, agreement, revision invalidation | Pure Dart tests + illustrative quote sheet; no workflow calls | 1 foundation; 6 workflow |
| O04 | Explicit confirmation, simultaneous requests/capacity | Advisory preconditions only; planned shared day lock/transaction | 6 |
| O05 | Confirmed -> Baking -> Ready -> Delivered | Pure tested transitions, no persistence/UI controls | 1 foundation; 6 backend |
| O06 | Duplicate prevention/retries | Duplicate agreement/confirmation rejected on same updated value; persistent operation keys planned | 5,6 |
| O07 | Cancellation request distinct from approval, withdrawal/decline/reschedule | Pure cancellation distinction tested; other workflows planned | 6 |
| O08 | Events/history/configuration/price snapshots | Immutable quote lines/history foundation; authoritative snapshot/events planned | 5,6 |
| O09 | Private notes/events inaccessible to customers | No private fixture data exposed; separate RLS tables planned (no client filtering as security) | 2,7 |
| O10 | Customer tracking and baker search/filter/order detail | Static sample card/quote only; real tracking planned | 5,6,7 |
| B04 | Today, Calendar, due times | Placeholder/preview; no editable calendar or live operations | 4,7 |
| B05 | Manual orders, contacts, no account/chat creation | Manual exclusions in rules; manual creation planned | 7 |
| B06 | External advances, remaining balances, private notes | Clearly labeled illustrative 1500/3000 amounts; persistence planned | 7 |
| M01 | Order messages/images/unread/Realtime | Explicit empty placeholder; participant repositories planned | 8 |
| M02 | Chat never confirms or changes prices | UI notice; no chat mutator; backend authority planned | 6,8 |
| R01 | Own delivered app order review only | Pure ownership/manual/reviewed eligibility tests; backend unique constraint/RLS planned | 8 |
| X01 | Notifications/report/block | Planned, no false delivery/moderation claims | 8 |
| X02 | Offline drafts/cache, blocked authoritative operations | Pure confirm offline precondition; device caching/reconnect planned | 5,9 |
| X03 | Accessibility and complete localization | SafeArea/scrolling/48px buttons/RTL foundation tests; full device/screen-reader review planned | 1,9 |
| X04 | Account deletion/legal/retention | Owner decisions open; secure deletion workflow planned | 9 |
| X05 | Plans/export/backup/restore | No invented pricing/allowance; owner applicability unresolved | 9 |
| V01 | Setup/verification/docs/local checkpoint | README, project-status.md, Git checkpoint | 1 |
| V02 | Release/Android+iOS device verification | Android build attempt recorded; iOS requires macOS/Xcode | 10 |

Domain port scope is explicit: web date parsing, catalog conflict checking, private projection and localStorage export/reset tests are not represented as migrated functionality. Their real equivalents belong to availability, ownership and offline/restore phases. Do not infer backend enforcement from these advisory Dart tests.

## Phase 2 evidence matrix

| ID | Requirement | Source / local evidence | Live acceptance |
| --- | --- | --- | --- |
| P2-01 | Verify Phase 1 and corrected commands | Baseline clean at 7a0e150, analysis and 8 tests rerun; README and phase-1-handoff.md contain exact commands | Local complete |
| P2-02 | Supabase setup/configuration | Explicit modes; public-key validation; async client/repository startup; pinned CLI/local config | Project discovery and local stack blocked |
| P2-03 | Profile initialization and safe identity | Auth trigger ignores privilege metadata; verified RPC creates child identity/owned business draft | SQL syntax parsed, pgTAP/real signup not executed |
| P2-04 | Auth journeys | Registration/verify-resend/login/forgot/reset/logout; controller, forms and SDK PKCE mock tests | Real email delivery/callbacks/reset not executed |
| P2-05 | Restoration, invalid/expired sessions | Server getUser/refresh check, loading/error gate, persistent recovery marker; controller/SDK mock tests | Native authenticated restart pending |
| P2-06 | RLS and grants | Own profiles; column grants; business ownership; no admin/operator entitlement | Backend requests prepared, not executed |
| P2-07 | Demo isolation and cache clearing | Preview never initializes SDK; guarded live role routes; stale read/write/logout tests | Local tests pass; live two-account device switching pending |
| P2-08 | Profile/business images | Owner-scoped uploads, bucket limits, pointer update/cleanup, private signed previews | Real upload/download/unauthorized requests pending |
| P2-09 | Future private files | Restrictive denial for order/conversation/product buckets | SQL test and HTTP cases prepared, not executed |
| P2-10 | English/Urdu, visual architecture | Existing tokens/domain rules retained; localized auth/profile screens and narrow 160% RTL form tests | Native Urdu editorial/device acceptance pending |
| P2-11 | Handoff/checkpoint | Backend setup, DB/storage, decisions/status and phase-2-handoff.md; separate local checkpoint | No remote configured; no remote backup |

The one-time initial experience is a provisional UI contract. Whether one account may act in both roles, own multiple businesses or invite a team remains unresolved. Full business setup, publication/catalog, orders and communications remain their original later phases.
