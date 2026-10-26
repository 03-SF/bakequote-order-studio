# Implementation plan

## Architectural boundaries

Flutter is the Android/iOS product. The generated web target exists solely to make the same Flutter foundation easy to inspect. Riverpod owns state/repository injection; go_router owns navigation. Feature layout is domain/application/data/presentation as features are introduced (avoid empty boilerplate folders). Current preview repository and providers remain separate from future authenticated data. Theme/localization/config are shared core facilities. No TypeScript runtime or WebView.

Backend target: Supabase Auth, PostgreSQL with RLS, Storage, Realtime and transactional RPCs. Planned entities: profiles, businesses/memberships, products/options/flavours/finishes/extras, delivery zones, availability rules/blocked days, saved businesses, app/manual orders, immutable configuration snapshots, quote versions/lines/agreements, public order events, separate baker-only notes/events, cancellation/reschedule requests, external payment records, conversations/messages/read cursors, reviews/reports/blocks, preferences and operation idempotency records.

Public catalog exposure must use explicit safe projections; raw business data must not leak private contact fields. Ownership policies join auth.uid() through membership or customer_id; customer order/message queries must never select baker-only tables. Manual orders have nullable customer identity and no conversation. Establish unique constraints for one active quote version, one agreement per actor/version, one customer review per order and scoped operation keys. Draft/device caches are untrusted and never authoritative.

Use atomic PostgreSQL functions for request submission (catalog lookup and snapshots), quote revision (new immutable version and invalidation), agreement (current version check), confirmation and production changes. Confirmation must lock a stable business/day availability row, recheck capacity, blocked dates, version and ownership in one transaction, then reserve and log an event. All code paths including manual orders and reschedules use the same lock protocol, deterministic lock ordering and idempotency keys; test simultaneous confirmations on the last slot. Pending requests do not reserve. Keep business timezone/date separate from UTC event timestamps. No client-calculated total can authorize a charge or update a persisted quote.

Storage: owner-scoped business/product image paths with explicit publication; private attachment bucket scoped to order participants, short-lived signed URLs and validated metadata/type/size. Attachment verification and privileged account deletion/external notification integrations use Edge Functions as needed; service-role secrets stay server-side. Realtime subscriptions are authorized and scoped to order participants, invalidating repository state after committed updates. Realtime is not the source of truth.

## Phase gates

| Phase | Deliverables | Acceptance gate |
| --- | --- | --- |
| 1 Foundation | Reference audit, native theme/shells, Riverpod/router, localized preview, config boundary, pure rule tests, handoff/checkpoint | Format/analyze/tests, attempted Android build; explicitly separate iOS status |
| 2 Accounts/backend | Migrations, Auth sign-up/verification/reset/session lifecycle, profiles, ownership, RLS/storage policies and redirect setup | Two-user/anonymous access tests; real email links and secure session recovery |
| 3 Baker catalog | Identity/onboarding, product/options/images, catalog pricing and delivery settings | Persisted CRUD with ownership/validation, upload failures and availability settings |
| 4 Availability/customer | Lead times/minimums/capacity/blocked dates, code/shared links, menu/profile/saved bakeries | Timezone boundaries, inaccessible business states and valid dates tested |
| 5 Requests | Customization/date/fulfilment/contact/design/images, drafts, authoritative estimates and immutable snapshots, submit/list/detail | Duplicate/retry operations create one Pending request; catalog changes handled |
| 6 Quotes/lifecycle | Quote versions/agreement, explicit baker confirmation, production, cancellation/withdrawal/decline, reschedule | Database race/role/idempotency tests; stale agreements rejected; valid transitions only |
| 7 Baker operations | Today/calendar/search/filter, manual orders/contacts, private notes, advances/balances | No customer note/event leakage; manual orders create no account/chat; payments explicitly external |
| 8 Communication | Order messages/images/retry/read state, Realtime, notifications, reviews/report/block | Participant-only access, manual exclusion, eligibility/abuse/failure tests; no chat authority |
| 9 Cross-cutting | Offline cache/drafts/reconnect, complete localization/accessibility, deletion, approved plan/export/restore | No offline authoritative writes; deletion/retention and restore access verified against owner decisions |
| 10 Release | Acceptance suite, device matrix, performance/security, signing/beta builds and operations docs | Android and iOS physical devices, backup drills, migrations/monitoring/runbooks and store approval |

Stop after Phase 1. Each later phase updates traceability and status, and introduces migrations only with tests for authoritative invariants. Never infer completed features from a screen or helper.

## Quality strategy

Pure tests cover price precision, quote history and state rules. Widget tests cover both navigation systems, narrow Urdu RTL, text scaling and quotation sheet. Later repository tests cover loading/error/offline states; database tests cover RLS/storage ownership, transactions, races and retries; integration/device tests cover end-to-end customer/baker journeys, app links, keyboards, uploads, screen readers and restoration. Neither in-memory tests nor an APK build substitute for device acceptance.
