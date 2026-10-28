# Phase 4 handoff: availability and customer bakery experience

## Current implementation (2026-10-28)

The Phase 4 feature implementation now includes baker timezone/whole-day lead-time/capacity settings, monthly service-date browsing, Today, selected-day status, block/unblock, conflict detection, explicit refresh and unsaved-edit protection. Customer discovery reuses the existing code lookup/profile/menu/saved flow, adds starting prices, public delivery zone fees, availability and a bounded server-persisted recent list. Reviews have an honest unavailable state. No order submission, fabricated success, live fixture bookings or marketplace search was added.

Availability has domain/application/data/presentation layers and public UI entry points. Widgets never call SQL/Supabase directly. Controller epochs reject stale results after identity or bakery changes. Settings revisions are not refreshed beneath unsaved input; month/Today/block actions wait until the edit is saved/discarded. Conflicts preserve text and require explicit reload/review. Customer refresh is deliberate; no private table is exposed through Realtime.

Migration `20261028000200_availability_recents.sql` was dry-run reviewed as the sole pending version and applied without reset to the linked development project. It adds availability_settings, blocked_dates, inaccessible capacity_allocations and self-RLS recent_businesses. Restricted RPCs validate ownership, revision, timezone and date ranges. Public calendar responses omit order identities, occupied counts and internal capacity. Active delivery zones expose only name/fee. All new functions revoke default PUBLIC execution and use an empty search path.

### Scheduling contract and policy review

Whole calendar-day lead time and one order per capacity unit are provisional implementation semantics under the latest instruction to implement and record missing decisions. The baker must explicitly choose a timezone. These are not claimed as owner-approved policy. Confirmed/baking/ready/delivered consume capacity; pending/declined/withdrawn/cancelled do not. A cancellation request alone has no effect. The allocation table has no client writer or real order population yet. SQL fixtures are isolated locally; hosted data has no invented bookings.

Later confirmation/manual/rescheduling must lock the business row, recheck available date, and update order/allocation/event atomically with idempotency and an order foreign key. Blocking an occupied date fails; it never cancels/reschedules. Changing timezone with allocations and lowering capacity below future occupancy fail. Override/reschedule rules and the dual-role policy remain unresolved. Recent history defaults to 20 distinct bakeries; it is not a promised retention period.

### Verification and acceptance limits

- 57 Flutter tests passed, including month/year/leap rollover, conflict input retention at 200% text, duplicate-save prevention, block refresh, shared-link authentication destination and account-state clearing. Formatting and analysis passed before final handoff.
- 81 modeled PostgreSQL runtime checks passed: ownership plus unchanged denied-write target, blocked/past/full/lead-time states, timezone year rollover, consuming statuses, cancellation release, bounded recent deduplication/ownership and unpublished availability.
- Nine new live customer-session/anonymous endpoint checks passed. Earlier 15 single-account, six discovery and six Chrome checks remain separately recorded historical evidence.
- Final Chrome regression was rerun against the updated Web bundle: all six cases passed after restarting the stopped loopback host. Ten Python setup checks passed. Android debug APK compiled in 83.4 seconds; it was not installed and no emulator was retried. All six migration versions match remotely.
- Cross-account preflight remains BLOCKED: no dedicated Baker A/B credentials are locally configured. Prepared `verify_cross_account.py` compares owner snapshots/bytes after denied mutations in both directions. It has not executed live. Positive owner settings/blocking, customer refresh of that bakery, save/reopen, images and real account-switch Chrome acceptance remain blocked by those identities.
- Android installation/native auth/link/storage/permissions/background/device acceptance and iOS build/device acceptance remain deferred. Push is a future feature. No native acceptance claim follows from Chrome.

See [integration verification](integration-verification.md) for the latest observed build/Chrome results and exact blockers. Feature implementation is delivered, but full Phase 4 live acceptance is not signed off. Stop before Phase 5.

### Browser demonstration and setup

1. Follow [browser setup](backend-setup.md#laptop-only-flutter-web-verification). Sign in with a confirmed dedicated baker; open Calendar. Enter an IANA timezone, lead days and daily capacity; save. Select a future date, block it, reload, then unblock it. Concurrent stale saves must ask for reload.
2. As that baker, activate a complete bakery/catalog using existing setup. Copy its business code.
3. In a separate customer browser session, open Find a bakery, enter the code, inspect profile/menu/delivery fees and availability. Save it and reopen from Saved or Recently opened after browser reload.
4. Change a date as the baker; select Reload / retry as the customer and check the new status. No request/order is submitted.
5. Development link: `http://localhost:7357/#/bakery/<32-hex-code>`. The route preserves the code through login and onboarding. Native `dev.bakequote.mobile://bakery/<code>` parsing remains supported; installed native dispatch, Android App Links/iOS Universal Links and a production domain remain unverified/deferred.
6. Use accessible, separately verified Baker A/B inboxes. Default sender limitations may require custom SMTP; do not disable confirmation or grant organization access just for test mail. Keep passwords in secure local terminal prompts. Run the existing Phase 3 fixture suite only on dedicated disposable businesses, then the new cross-account runner. No service credential is used to prove permissions.

## Historical partial handoff (superseded above)

Owner authorization on 2026-10-28 supersedes earlier stop-before-Phase-4 instructions once laptop checks pass or their exact blockers are recorded. Android/iOS remain the final product platforms; Flutter Web is a development/test host only. No emulator install or native acceptance retry was made in this continuation. Phase 5 has not started.

## Implemented customer discovery

- Live customer home supports a normalized bakery code or `dev.bakequote.mobile://bakery/CODE` pasted link, safe public bakery profile, menu, active size/pack/flavour/finish/extra prices, public image loading/error states and saved bakeries.
- New feature layers: pure domain models/repository contract, Supabase data mapping, Riverpod workflow controller and presentation. No preview role is used for live permissions. Account change/disposal invalidates pending results.
- Menu and saved lists use UUID keyset pagination, 20 rows requested and a server-enforced maximum of 30. Variant/option data is explicitly projected rather than returning arbitrary owner JSON keys. Inactive products/options/variants and unpublished businesses are excluded.
- Saves use an authenticated server function with an idempotent composite key. An unavailable saved bakery returns a null public profile and can still be removed. Raw saved records are visible only to their account. Failed writes never announce success; lookup input remains available after recoverable errors.
- `set_business_publication` is an owner/revision-checked database primitive for publication changes; its owner UI is not added yet. Existing baker activation UI remains in use.
- Shared links can be copied/pasted for lookup. Native link dispatch, installed-app launch and production universal links remain deferred; do not claim that copied links are a verified native deep-link flow.

## Migration and checks

Migration [20261028000100_customer_discovery.sql](../supabase/migrations/20261028000100_customer_discovery.sql) adds `saved_businesses`, RLS/grants, `public_menu`, `saved_bakeries`, `set_saved_business`, `set_business_publication`, an index and case-normalized `public_business`. All privileged functions use an empty search path and restricted execution. Deployment initially failed establishing a temporary database connection; remote history confirmed the migration absent. One retry applied it successfully without resetting data.

The modeled PostgreSQL suite passed 56 checks, including new cross-account saves, duplicate saves, page limits, cursors and unpublished-business privacy. These are modeled identities, not real two-baker HTTP sessions. Flutter tests cover invalid/shared codes, integer display, failed-save state, unavailable results, preserved input and narrow large-text layout. See [integration verification](integration-verification.md) for actual live and browser evidence.

## Remaining Phase 4 work and decisions

Phase 4 is **partial, not complete**. Lead-time/capacity units, business timezone policy, blocked-date management and authoritative available-date lookup are not implemented. The owner was asked to confirm whole calendar-day lead time in a baker-selected timezone and capacity measured in confirmed orders per business date. No reply has approved those proposals. Existing minimum quantity/subtotal rules stay unchanged. Pending orders must not reserve capacity; later confirmation needs an atomic shared lock protocol, not client-side counting.

The one-customer/two-baker live suite remains blocked by two additional verified test accounts and email delivery to their inboxes. Default SMTP only permits organization-member addresses; do not grant administrative membership merely to test inbox delivery, bypass confirmation, or present admin-created confirmed users as email-flow verification. No dual-role policy was decided.

Native auth callbacks, native session/storage lifecycle, device permissions, push notifications and physical-device acceptance are explicitly deferred. Push implementation remains Phase 8. Source Git has no configured remote; a local checkout/commit is not remote backup.

## Laptop demonstration

1. Build/serve Flutter using [backend setup](backend-setup.md#laptop-only-flutter-web-verification).
2. Sign in as a verified customer and complete initial customer onboarding. Customer home displays Find a bakery.
3. Enter the code of an activated bakery created by its own baker account. Unknown/draft/unpublished codes show unavailable. Public details exclude owner identity, contact phone and exact pickup address.
4. View active menu choices, save the bakery, refresh saved bakeries, reload the browser and reopen the menu. Remove it from saved when finished.
5. A real positive demo requires an activated baker fixture; it has not been performed with two real baker accounts yet. Do not automatically seed identical catalogs into real businesses.
