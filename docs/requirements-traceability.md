# Requirements traceability

Current audit: first-time onboarding now requires an explicit Customer or Baker selection before saving; existing profiles and dual-role policy are unchanged. Local widget regression covers missing selection and choosing Baker; live onboarding and returning-user acceptance remain outstanding. See [phase completion matrix](phase-completion-matrix.md) for all phase statuses and unresolved work.

Owner decision 54 restores the approved Confirmed → Baking → Ready → Delivered path. Migration 008 preserves existing Decorating rows/history, keeps their capacity allocated and allows Decorating → Ready. New transitions into Decorating are denied. Flutter domain/UI and modeled SQL regression tests cover both paths; real multi-account acceptance remains blocked. English-only and offline exclusion continue.

Current scope and evidence are in [the Phase 5–10 completion matrix](phase-completion-matrix.md). English-only supersedes bilingual requirements; offline functionality is excluded. Existing draft/session persistence and connection-error recovery remain required, but do not establish or promise offline operation. Phases 5 and 6 are not accepted: positive multi-account hosted workflow, last-capacity race and lifecycle acceptance are outstanding.

## Phase 5 current evidence (2026-10-29)

| ID | Requirement | Implementation/evidence | Remaining acceptance |
| --- | --- | --- | --- |
| P5-01 | Four-step builder/customization/contact/fulfilment | Request presentation/controller/domain; Back and narrow 200% text test | Positive live Chrome journey requires active baker fixture |
| P5-02 | Persistent isolated drafts and restoration | Server draft revision + per-project/account/bakery local cache; restart/isolation tests | Native storage/device restart deferred |
| P5-03 | Authoritative estimate/current availability | Review+submit RPC, integer paisa, changed-price/date rejection; SQL PKR 4,100 fixture | Real two-party catalog/date-change acceptance blocked |
| P5-04 | Atomic/idempotent Pending creation | Migration 007; duplicate token/different token, injected late failure/rollback, immutable snapshots tested | True concurrent hosted transactions untested |
| P5-05 | Private reference images | Registered paths/member Storage policies, ownership/count/retirement checks; failure/retry UI tests | Positive live upload/reload and unrelated actual baker access blocked |
| P5-06 | Customer/baker request views | RLS list/detail/quote/event; 20-row pages; no Phase 6 actions | Limited live customer endpoint/Chrome empty state only |
| P5-07 | Uncertain outcome/session/network recovery | Persist uncertain marker, freeze input, status check/exact retry; duplicate/late-account tests | Real interrupted submission with owned bakery blocked |
| P5-08 | Deployment and handoff | Seven migration versions match; 67 Flutter, 10 setup, 114 modeled SQL, 20 limited live checks | See final Chrome/build matrix; native and full cross-account explicitly deferred/blocked |

The [Phase 5 handoff](phase-5-handoff.md) and [integration table](integration-verification.md) supersede older planned/missing-environment statements below. Feature implementation is separate from complete acceptance. Phase 6 has not started.

Phase 4 latest: baker calendar/settings/blocking and customer bakery/menu/pricing/fulfilment/availability/saved/recent/link navigation are implemented. Evidence: 57 Flutter tests, 81 modeled SQL checks, nine limited new live endpoints; real two-baker Chrome/permissions acceptance remains blocked. Availability uses date-only business-timezone semantics and an inaccessible future allocation contract; no live orders or fake occupancy. Earlier availability-planned statements below are superseded by [Phase 4 handoff](phase-4-handoff.md).

Latest evidence (2026-10-28): see [integration verification](integration-verification.md) and [Phase 4 continuation](phase-4-handoff.md). Older unconfigured/unlinked environment notes below are historical. Native acceptance is explicitly deferred. C01 public profiles/menus and saved bakeries now have implementation and modeled tests; full availability and native shared-link acceptance remain pending.

Statuses: Foundation = Phase 1 code; Implemented/pending integration = Phase 2 source and local tests, with live backend acceptance unverified; Planned = later work. See the Phase 2 evidence matrix below.

| ID | Requirement | Current evidence / status | Delivery phase |
| --- | --- | --- | --- |
| F01 | Separate native Flutter product and Git history | Android/iOS generated hosts, Dart app, separate local repository | 1 |
| F02 | Reference preservation and implemented/planned audit | reference-audit.md, sibling checkout | 1 |
| F03 | Theme/assets/shared controls | core/theme, shared/widgets, bundled fonts/images | 1 |
| F04 | Riverpod/go_router/feature separation | app/app.dart, preview repository/providers, domain modules | 1 |
| F05 | Both role navigation foundations | Customer four destinations, baker five, adaptive rail/tabs | 1 |
| F06 | English-only (supersedes bilingual requirement) | English locale and fonts only; old stored preferences ignored; large-text English tests | 3 |
| F07 | Safe config without credentials | BackendConfig plus explicit preview/live modes; empty public example; SDK initialized only in live mode | 1,2 |
| A01 | Register/verify/login/reset/session | Supabase repository, auth controller/screens, guards and SDK HTTP-mock tests; real email/native restoration pending | 2 implemented/pending integration |
| A02 | Profiles/ownership/RLS/storage privacy | Versioned migrations, pgTAP/HTTP tests prepared; no live database/storage execution | 2 implemented/pending integration |
| B01 | Business onboarding and profiles | Setup/draft/review/activation/editing/code/share implemented; notification preferences remain Phase 8 | 3 implemented; live pending |
| B02 | Products/size/quantity/flavour/finish/extras/images/prices | Product/variant/flavour/finish/extra editors, active flags and owned images; SQL/Dart/repository/widget tests | 3 |
| B03 | Delivery zones/fees, minimum, lead time/capacity/blocked dates | Delivery settings/zones/fees, product quantity minimum and subtotal minimum implemented; lead time/capacity/blocked dates remain Phase 4 | 3,4 |
| C01 | Bakery code/shared link/profile/menu/availability/saved bakeries | Live code/pasted-link lookup, safe profiles/menus, paginated saved mutation implemented; availability and native link launch deferred/pending | 4 partial |
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
| X02 | Safe network-error recovery, session restoration, and no unsafe duplicate online writes | Local draft/session recovery and explicit retry; hosted lost-response and native lifecycle checks outstanding. Offline functionality excluded. | 5,9 |
| X03 | Accessibility and readable English | SafeArea/scrolling/48px buttons/large-text tests; full device/screen-reader review planned | 1,9 |
| X04 | Account deletion/legal/retention | Owner decisions open; secure deletion workflow planned | 9 |
| X05 | Plans/export/backup/restore | No invented pricing/allowance; owner applicability unresolved | 9 |
| V01 | Setup/verification/docs/local checkpoint | README, project-status.md, Git checkpoint | 1 |
| V02 | Release/Android+iOS device verification | Android build attempt recorded; iOS requires macOS/Xcode | 10 |
| ARC-01 | Document and enforce feature architecture boundaries | `docs/architecture.md`; Phase 3A contracts moved to domain, image validation moved to core, auth repository provider moved to application | 3A |
| NFR-01 | Stable acceptance criteria for security, reliability, performance, accessibility, compatibility and operations | `docs/non-functional-requirements.md`; proposed targets explicitly unapproved | 3A |
| AUD-01 | Evidence/gap/correction audit of Phases 1-3 | `docs/architecture-nfr-audit.md`; live and device evidence distinguished | 3A |
| NFR-02 | Typed persistence errors and conflict mapping | Baker application still maps selected SQL failures by error text; follow-up required | 3A follow-up |
| NFR-03 | Performance benchmarks and supported-device matrix | Proposed measurable tests recorded; no results claimed; configured iOS 13.0, Android uses Flutter minSdk | 10 |
| NFR-04 | Cross-account, private storage, email and native lifecycle verification | Local/model evidence is not live evidence; see current status and handoff | 2,3,10 |

Domain port scope is explicit: web date parsing, catalog conflict checking, private projection and localStorage export/reset tests are not represented as migrated functionality. Appropriate availability, ownership and authorized restore behavior require independent implementation and verification. Offline functionality is excluded. Do not infer backend enforcement from these advisory Dart tests.

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
| P2-10 | Historical bilingual acceptance (superseded) | Phase 3 English-only cleanup replaces language/RTL-specific criteria; tokens/domain rules retained | English-only acceptance below |
| P2-11 | Handoff/checkpoint | Backend setup, DB/storage, decisions/status and phase-2-handoff.md; separate local checkpoint | No remote configured; no remote backup |

The one-time initial experience is a provisional UI contract. Whether one account may act in both roles, own multiple businesses or invite a team remains unresolved. Full business setup, publication/catalog, orders and communications remain their original later phases.

## Phase 3 evidence matrix

| Requirement | Implementation/local verification | Live acceptance |
| --- | --- | --- |
| English-only and old preference | Dictionary/control/font/dependency removal; normalized profile locale; migration and English large-text tests | Old remote locale migration pending deployment |
| Business draft/setup/activation | Workspace UI, existing idempotent owned business creation, server required-field checks and revision guards; SQL/widget tests | Supabase save/restart/activation unexecuted |
| Owner-only writes/public fields | RLS, RPC ownership, private raw tables and approved-field public RPC; two-identity local SQL checks | Real PostgREST two-baker checks prepared, unexecuted |
| Catalog and applicable options | Cakes/cupcakes, names/descriptions/images, size/pack, product-owned flavour/finish/extras, activation/edit/deactivation; local tests | Real catalog persistence pending |
| Pricing/fulfilment | Exact integer paisa, quantity/subtotal minima, pickup, named delivery zones/fees, backend estimate and matching preview; PKR 4100 SQL/Dart/widget regression | Live estimate RPC pending |
| Images/failures/cleanup | Public logo/cover/product controls and owner policies; SDK HTTP-mocked upload/pointer/cleanup tests; SQL referenced-image protection | Actual bucket type/size/upload/download behavior pending |
| Preview isolation/restart/account switching | Separate device namespace, account-scoped providers, session guard, stale repository rejection and cache clearing | Native two-live-account switching/restart pending |
| Platform/handoff/checkpoint | See Phase 3 handoff for executed commands and device/build results | iOS requires macOS/Xcode; no remote backup |

No Phase 4 customer discovery/availability workflow is claimed. Dual-role policy remains unresolved; ownership is independent of that decision.
