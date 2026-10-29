# Implementation plan

Current owner scope (2026-10-29): English-only; **offline functionality is excluded**. Preserve ordinary session persistence, unsent-input recovery, network-failure handling and idempotent online retries without claiming offline operation. The original Phase 5–10 labels and their actual implementation/acceptance status are reconciled in [the phase completion matrix](phase-completion-matrix.md). Mandatory Decorating is an unresolved deviation from the original lifecycle; do not silently change existing records or claim owner approval.

## Current scope: Phase 5 implementation delivered (2026-10-29)

The owner authorized Phase 5 after `ea5966f`. Four-step request builder, account/bakery drafts, server review/revalidation, atomic idempotent Pending submission, private references and customer/baker list/detail are implemented in migration 007 and the request feature. Seven migrations now match development; no reset. See [Phase 5 handoff](phase-5-handoff.md) for local, limited-live and blocked acceptance. The positive three-account workflow remains blocked; no native test is inferred from Chrome. **Stop before Phase 6.** All earlier current-scope/stop-before-5 wording below is historical.

Phase 6 must evolve Pending-only constraints into authoritative quotation/agreement/confirmation/lifecycle transactions, link capacity allocations to real orders, recheck current quote/business/date/capacity/allowance, and run true concurrent last-slot/idempotency tests. Phase 5 does not reserve capacity or implement these actions. Preserve immutable initial snapshots and private attachment membership when extending the schema.

Phase 4 implementation update: availability configuration/calendar, server date/status contract, blocking/conflict handling, customer public availability, saved/recent access and browser link-through-login routing are now implemented. Positive cross-account/live Chrome acceptance requires dedicated baker accounts; local/model checks are separately recorded. Phase 5 must integrate real order occupancy transactionally; no order workflow was introduced here. See [handoff](phase-4-handoff.md). Scheduling semantics are provisional decisions 39–43, not previously approved policy.

Current override (2026-10-28): owner authorized laptop verification followed by Phase 4 once exact blockers are documented, and deferred native installation/acceptance. Customer discovery is implemented and deployed; availability semantics and full Phase 4 completion remain pending. See [Phase 4 continuation](phase-4-handoff.md). Earlier phase-stop statements below describe historical gates and are superseded by this instruction. Do not begin Phase 5.

## Architectural boundaries

Flutter is the Android/iOS product. The generated web target exists solely to make the same Flutter foundation easy to inspect. Riverpod owns state/repository injection; go_router owns navigation. Feature layout is domain/application/data/presentation as features are introduced (avoid empty boilerplate folders). Current preview repository and providers remain separate from future authenticated data. Theme/English copy/config are shared core facilities. No TypeScript runtime or WebView.

Backend target: Supabase Auth, PostgreSQL with RLS, Storage, Realtime and transactional RPCs. Planned entities: profiles, businesses/memberships, products/options/flavours/finishes/extras, delivery zones, availability rules/blocked days, saved businesses, app/manual orders, immutable configuration snapshots, quote versions/lines/agreements, public order events, separate baker-only notes/events, cancellation/reschedule requests, external payment records, conversations/messages/read cursors, reviews/reports/blocks, preferences and operation idempotency records.

Public catalog exposure must use explicit safe projections; raw business data must not leak private contact fields. Ownership policies join auth.uid() through membership or customer_id; customer order/message queries must never select baker-only tables. Manual orders have nullable customer identity and no conversation. Establish unique constraints for one active quote version, one agreement per actor/version, one customer review per order and scoped operation keys. Draft/device caches are untrusted and never authoritative.

Use atomic PostgreSQL functions for request submission (catalog lookup and snapshots), quote revision (new immutable version and invalidation), agreement (current version check), confirmation and production changes. Confirmation must lock a stable business/day availability row, recheck capacity, blocked dates, version and ownership in one transaction, then reserve and log an event. All code paths including manual orders and reschedules use the same lock protocol, deterministic lock ordering and idempotency keys; test simultaneous confirmations on the last slot. Pending requests do not reserve. Keep business timezone/date separate from UTC event timestamps. No client-calculated total can authorize a charge or update a persisted quote.

Storage: owner-scoped business/product image paths with explicit publication; private attachment bucket scoped to order participants, short-lived signed URLs and validated metadata/type/size. Attachment verification and privileged account deletion/external notification integrations use Edge Functions as needed; service-role secrets stay server-side. Realtime subscriptions are authorized and scoped to order participants, invalidating repository state after committed updates. Realtime is not the source of truth.

## Phase gates

| Phase | Deliverables | Acceptance gate |
| --- | --- | --- |
| 1 Foundation | Reference audit, native theme/shells, Riverpod/router, English preview, config boundary, pure rule tests, handoff/checkpoint | Format/analyze/tests, attempted Android build; explicitly separate iOS status |
| 2 Accounts/backend | Migrations, Auth sign-up/verification/reset/session lifecycle, profiles, ownership, RLS/storage policies and redirect setup | Two-user/anonymous access tests; real email links and secure session recovery |
| 3 Baker catalog | Identity/onboarding, product/options/images, catalog pricing and delivery settings | Persisted CRUD with ownership/validation, upload failures and availability settings |
| 4 Availability/customer | Lead times/minimums/capacity/blocked dates, code/shared links, menu/profile/saved bakeries | Timezone boundaries, inaccessible business states and valid dates tested |
| 5 Requests | Customization/date/fulfilment/contact/design/images, drafts, authoritative estimates and immutable snapshots, submit/list/detail | Duplicate/retry operations create one Pending request; catalog changes handled |
| 6 Quotes/lifecycle | Quote versions/agreement, explicit baker confirmation, production, cancellation/withdrawal/decline, reschedule | Database race/role/idempotency tests; stale agreements rejected; valid transitions only |
| 7 Baker operations | Today/calendar/search/filter, manual orders/contacts, private notes, advances/balances | No customer note/event leakage; manual orders create no account/chat; payments explicitly external |
| 8 Communication | Order messages/images/retry/read state, Realtime, notifications, reviews/report/block | Participant-only access, manual exclusion, eligibility/abuse/failure tests; no chat authority |
| 9 Cross-cutting | English accessibility, account deletion, applicable plan/billing recovery and encrypted export/restore | Owner decisions, working implementations, retention and recovery acceptance; offline functionality excluded |
| 10 Release | Acceptance suite, device matrix, performance/security, signing/beta builds and operations docs | Android and iOS physical devices, backup drills, migrations/monitoring/runbooks and store approval |

Phase 1 is archived at 7a0e150. Current scope is Phase 3; stop before Phase 4. Each later phase updates traceability and status, and introduces migrations only with tests for authoritative invariants. Never infer completed features from a screen or helper.

## Quality strategy

Pure tests cover price precision, quote history and state rules. Widget tests cover navigation, narrow English layouts, text scaling and quotations. Repository tests cover loading, connection failures and safe recovery; database tests cover RLS/storage ownership, transactions, races and retries; integration/device tests cover customer/baker journeys, app links, keyboards, uploads, screen readers and restoration. Neither in-memory tests nor an APK build substitute for device acceptance.

## Phase 3A architecture and non-functional baseline

Phase 3A establishes [the architecture contract](architecture.md), [NFR acceptance register](non-functional-requirements.md) and [Phase 1-3 audit](architecture-nfr-audit.md). Its source corrections move repository contracts to feature domains, shared byte-only image validation to core, and auth provider composition to the application layer. It does not add Phase 4 workflows. Proposed performance/platform targets remain unapproved proposals. Live Supabase, Android device and iOS verification gates remain open.

Before Phase 4, resolve owner decisions required by a concrete workflow; preserve server authorization and atomicity requirements. Phase 4 discovery/availability must use bounded/paginated queries and approved public projections. Phase 5 requests need immutable price/configuration snapshots, server pricing and idempotent atomic submission. Phase 6 agreement/confirmation needs version checks, operation keys, explicit transaction boundaries and capacity-race tests. Phase 8 private attachments require actual conversation/order membership authorization. Phase 9/10 require owner-approved deletion/export, backup, device support and release operations decisions.

## Phase 2 implementation and remaining gate

Identity/profile/business ownership migrations and bucket policies now have versioned source. Flutter auth, profile editing and profile/business image APIs use a dedicated repository/controller rather than the fixture store. Initial experience is one-time onboarding navigation; actual business ownership is checked by RLS. Email callbacks use exact development URIs and PKCE exchange typing. Logout/session changes discard profile state and private image providers; pending reads/writes cannot repopulate an expired identity.

The implementation is locally tested but the Phase 2 live gate is not met: no logged-in/linked hosted development project, local container engine or supplied public configuration. Apply migrations, run the pgTAP and HTTP checks, and verify real email/native session journeys per [Phase 2 handoff](phase-2-handoff.md) before certifying live access control. Phase 3 source work is authorized while this external integration gate remains explicitly unverified. Phase 3 now adds catalog/business source; the external Phase 2 gate remains unverified.

## Phase 3 implementation and boundary

English-only cleanup is complete before new feature UI. Baker workspace has Setup/Catalog/Fulfilment/Pricing/Review, explicit draft saves, activation, editing and native code sharing. Business/product image selection, previews, replacement/removal and retry use owned immutable paths. Riverpod providers scope repositories to the authenticated account; preview has a separate device-only namespace. There are no generated real-user fixtures.

Migrations 003/004 add business details/code/revision, products with validated product-specific variants/options, delivery zones, owner-only raw reads, locked RPC writes, safe active-business projection, backend activation/estimate and product/cover storage policies. Both live repository calls and local preview calculations use integer paisa. Existing order/version/capacity rules remain untouched.

Phase 3 local source verification and live acceptance are separate. Execute the PGlite runtime suite, Flutter tests and Android build; run pgTAP/HTTP acceptance and native email/restart/upload journeys when a development stack is available. No live backend verification is inferred from local SQL or mocks. Stop before Phase 4: customer code lookup, saved bakeries, date/lead-time/capacity/blocked-day availability remain future work.
