# Database and storage

Current deployment: the seven prior migration versions match the linked
development project (2026-10-29). The Phase 5 progression migration is local
and parsed but not yet deployed. Limited live checks pass; full
cross-account acceptance remains blocked by dedicated baker credentials. See
[current evidence](integration-verification.md).

Phase 6 operations are defined in the local
`20261029000300_baker_operations.sql` migration. It keeps contacts, notes and
advances out of customer DTOs, preserves manual orders without customer
accounts or conversations, and performs manual confirmation, usage and
capacity writes atomically. It is parsed and locally wired but not deployed
or concurrency-tested against the hosted database.

## Phase 7 communication and moderation: 20261029000400_communication_moderation.sql

The local Phase 7 migration adds participant-scoped `order_conversations` and
`order_messages` for app orders only. Message writes go through a
security-definer command that verifies the customer/baker relationship,
rejects manual orders, blocked participants, closed orders, oversized text,
and more than three attachments, while preserving duplicate
`client_message_id` retries and server-assigned sequence numbers.
`order_message_cursors` supports durable unread state and `notifications`
stores recipient-scoped message notifications. Reviews are limited to the
owning customer after delivery and are one per order. Participants may submit
bounded reports and block the other participant; all communication and
moderation tables have RLS and default client writes are revoked.

The private `conversation-attachments` bucket is readable only when an
authenticated participant is referenced by a registered message path. Upload
paths are order/message UUID-shaped and limited to image types; the Flutter
panel validates and uploads up to three images before sending, while the
server verifies every referenced object. Hosted deployment,
database-boundary concurrency tests, and live two-account acceptance are
still required.

## Phase 8 synchronization: 20261029000500_synchronization.sql

The synchronization migration adds a monotonic identity-backed
`feed_sequence` to append-only `order_events` and exposes the authenticated
`sync_order_changes(after_sequence, limit)` endpoint. The endpoint returns a
bounded ordered change page, the latest participant-visible order version and
status for each event, and a cursor. It applies participant authorization
inside the security-definer function, so unrelated orders are not returned.
The client advances its cursor only after a successful response and reloads
the authoritative order/detail state after synchronization.

Mutating commands remain online-only and continue to require optimistic
versions. Confirmation and lifecycle commands now use UUID operation IDs
retained for retry after a lost response, preventing duplicate effects while
stale versions surface an explicit conflict instead of silently overwriting
another update. No offline queue or client-authoritative cache was added.

## Phase 9 billing and lifecycle: 20261029000600_billing_lifecycle.sql

`store_transactions` and `account_entitlements` are server-owned records.
Their execution grants are revoked from all client roles; only a trusted
provider-verification integration may apply a verified Apple/Google event.
Provider, environment, transaction ID, product, payload digest, state and
expiry are persisted, with a unique provider transaction key for duplicate
callback reconciliation. The client can read only its own current entitlement,
and usage data is never reset by reinstall, restore, downgrade or cancellation.

`account_export_snapshot()` returns a bounded identity-scoped JSON snapshot
for the account export foundation. It intentionally does not claim to be an
encrypted archive or include arbitrary storage bytes. Encrypted maintained
library backup/restore requires a release-approved cryptography adapter and
key/passphrase handling; plaintext import is not implemented.

`request_account_deletion('DELETE')` requires a recent authenticated session,
blocks pending and active production orders, creates idempotent media/account
cleanup jobs, and records status for support visibility. The migration does
not pretend that a client can delete `auth.users`: a trusted cleanup worker
must process jobs, remove private media and shared-history references under
the approved retention policy, then complete Auth deletion. Subscription
cancellation remains separate from account deletion.

## Phase 5 requests: 20261029000100_customer_requests.sql

| Table | Ownership and write contract |
| --- | --- |
| request_drafts | Auth customer UUID + bakery; self SELECT, no direct client writes. One open draft/customer/bakery; revision-checked save, reviewed snapshot/token and submitted-order link. |
| order_requests | Customer + business ownership; customer/owning baker SELECT only. Unique source draft, UUID reference, lifecycle status, immutable snapshot, quote version, agreement, due time and optimistic version. |
| request_quotes | Participant-only SELECT; initial estimate plus immutable baker revisions with reason, actor and timestamp. |
| request_events | Participant-only SELECT; initial requested event. No private baker note/event data mixed in. |
| request_uploads | Self SELECT through draft ownership; generated immutable path, retired tombstone. Registration/retirement require owner and draft lock. |
| request_attachments | Participant-only SELECT; path/draft ownership validated before linking to order atomically. |

Authenticated roles may execute the owner/participant-checked public RPCs; anonymous execution and default PUBLIC execution are revoked. Internal `request_snapshot`/`request_choice` have no client execution grant. All privileged functions use empty search paths. Review and submit lock the same business row used by catalog/availability changes; `source_draft_id` and token implement exact retry. A mismatched token fails, including after successful submission. The current date/catalog/fulfilment/minimum/attachments are revalidated before insertion; no client total or customer ID is trusted. Pending requests do not reserve capacity. The local Phase 5 migration adds business locking, atomic allocation/usage/confirmation, idempotent operation keys and single-step lifecycle commands; it still requires hosted and concurrent verification.

Private `order-references` is now membership-enabled only through registered `<customer>/<draft>/<UUID>.(jpg|png|webp)` paths. Existing 5 MiB/type bucket limits remain; max three registered nonretired images is a proposed default. No UPDATE policy exists. Read permits draft owner or submitted order participants; insert requires owned unsubmitted nonretired registration. Delete checks submission membership under the draft lock. Tombstoning uncertain registration prevents delayed retries reviving abandoned paths. Client cleanup reconciles server status and cannot delete successful attachments. Signed URLs expire after 300 seconds; they remain bearer links until expiry, so never log/share them. Conversation attachments remain restrictive-denied.

Frozen request snapshots expose exact pickup address only to participants, not through public discovery; owner IDs/private business contact fields are omitted. Submitted objects and snapshots have no Phase 5 deletion/retention API. Cleanup is best effort for abandoned objects; a lost local queue needs a future authorized server cleanup policy. File signature validation is client-side plus Storage declared MIME/size enforcement, not server malware scanning. See [full contract](phase-5-handoff.md).

## Identity migration: 20261026000100_identity.sql

| Table | Ownership/data | App grants and RLS |
| --- | --- | --- |
| profiles | Auth user ID; name, phone, locale, initial experience, optional image path | SELECT own row; UPDATE only name/phone/locale/image_path on own row. No INSERT, DELETE, ID/experience/created_at edits |
| customer_profiles | Profile ID; identity completion | SELECT own row only; written by verified onboarding function |
| baker_profiles | Profile ID; identity completion | SELECT own row only; written by verified onboarding function |
| businesses | UUID, owner baker ID, name/image, full-onboarding flag, creation time | SELECT own business; UPDATE name/image only on own row. Ownership/ID/completion flags cannot be assigned by client |

Private profiles are not a public customer directory. Draft businesses are private; no public business table/view is exposed in Phase 2. Later public catalog access must use a deliberate safe projection. All four tables enable RLS, revoke PUBLIC/anon/authenticated default privileges, then grant only necessary SELECT and column UPDATE access. Unauthenticated table reads are rejected by grants. RLS filters unrelated users even if they know a UUID. There is no operator/admin role or client-writable privileged flag.

`initialize_profile` is an Auth after-insert trigger, SECURITY DEFINER with empty search_path, owned by the migration role. It copies only a bounded display name, never role/admin/ownership metadata. It also backfills existing Auth identities as incomplete profiles. Clients cannot call the trigger function or insert arbitrary profile rows.

`complete_identity` is the only exposed identity mutation RPC. It requires auth.uid(), checks server-side email confirmation, validates a customer/baker value and bounded names/phone, locks the own profile, and atomically creates the appropriate identity plus one owned business draft for a baker. Same-choice retries do not create duplicate rows/businesses; changing a chosen experience is rejected. Authenticated users have EXECUTE; anonymous/PUBLIC do not. It never creates customer accounts or conversations as a side effect of baker/manual orders.

Initial experience is a navigation/onboarding intent, not an authorization claim for arbitrary data. Role selection does not bypass RLS: business operations require actual ownership. Whether an account can operate in both experiences remains an unresolved product choice. The Phase 2 UI offers one initial experience and no live role switch. One draft business per owner is an explicit provisional idempotency constraint, not a finalized multi-business/team product policy.

Full business onboarding remains false and cannot be completed through a direct client update. Phase 3 will add actual business/catalog validation before completion. Schema constraints protect safe lengths, locale, known experience values, nonempty completed names and ownership-scoped image paths. No commercial limits, payment processing, legal retention or deletion policy is introduced.

## Storage migration: 20261026000200_storage.sql

All bucket limits are development engineering limits: 5 MiB/object, allowed MIME types image/jpeg, image/png and image/webp. Flutter preflights bytes/size; Supabase enforces bucket limits and RLS independently. Clients never have service-role access. Object names are generated UUIDs and uploads use `upsert:false` so replacements are distinct immutable objects.

| Bucket | Visibility | Path / current policy |
| --- | --- | --- |
| profile-images | Private | `<auth-user-uuid>/<file-uuid>.jpg|png|webp`; own profile required for INSERT, own prefix SELECT/DELETE. No UPDATE policy |
| business-images | Public image bytes | `<business-uuid>/profile/<file-uuid>.jpg|png|webp`; INSERT/metadata SELECT/DELETE only actual owner. No UPDATE policy. Public URLs intentionally require no account |
| product-images | Public-designated reserved bucket | No client upload/read-metadata policy; restrictive denial until products exist in Phase 3 |
| order-references | Private | All client operations denied until order membership/ownership tables exist |
| conversation-attachments | Private | All client operations denied until participant membership exists |

Public bucket download endpoints intentionally bypass object SELECT RLS for bytes; no private image belongs in these buckets. Owner-only metadata listing is not a promise of private public-bucket downloads. The future-bucket restrictive policy blocks client operations on reserved buckets even if a permissive policy is accidentally introduced. Later migrations must deliberately replace it with tested membership rules. No placeholder `authenticated USING(true)` policy is used for private attachments.

Phase 2 Account supports private profile images for both experiences and public bakery-profile images for a baker with an owned draft. It uploads first, then updates the own record pointer; failed pointer updates attempt to remove only that newly uploaded object. Old replaced objects are not automatically purged; retention/orphan cleanup is unresolved rather than an invented deletion schedule. Private previews use signed URLs valid for 300 seconds; they are not stored in profiles. Backend tests must verify unrelated signing/downloads are denied. The client clears account state across logout/switch and does not expose old signed URLs in the next account UI.

Allowed MIME metadata does not replace future image-processing/moderation requirements. Order/conversation attachment APIs and product image uploads remain intentionally closed.

## Verification layers

1. [SQL parser](../scripts/validate_sql.py): PostgreSQL/PLpgSQL syntax only; no schema/policy execution.
2. [pgTAP tests](../supabase/tests/identity_rls.test.sql): real database trigger/grant/RLS statements as separate JWT identities, with rollback. Requires local Supabase and was not executable on the current host.
3. [HTTP tests](../scripts/verify_backend.py): real Auth/PostgREST/Storage calls using three verified fixture accounts. Requires migrated live/local services and credentials; not executed here.
4. Flutter tests: fake repository, SDK HTTP mocks, route guards, state clearing and validation. These never substitute for backend permission checks.

No policy is described as live-verified until the corresponding backend tests run against the selected project. Apply migrations using [setup instructions](backend-setup.md), retain migration history, and add reviewed migrations rather than editing an applied schema silently.

## Phase 3 current schema: 20261026000300_baker_catalog.sql

`profiles.locale` is normalized to English before its constraint is narrowed to `en`. The original migrations are preserved. Existing Auth/customer/baker and provisional unique-owner business model remain intact; no new exclusive-role or admin assignment exists.

`businesses` gains bounded description, private owner/contact name and phone, public location, private exact pickup address, cover path, unique server-generated 32-character business code, pickup/delivery flags, bigint minimum_paisa and revision. Existing name/logo/completion fields remain. Identity onboarding creates one owned private draft atomically; workspace editing does not create another business.

`products` contains stable UUID, owning business FK, cake/cupcakes kind, name/description, active flag, minimum cakes/packs per order, image pointer, JSON variants/options and creation time. Each variant has UUID, label, positive grams (cake) or cupcakes-per-pack, integer price_paisa and active flag. Each customization has UUID, label, flavour/finish/extra kind, integer surcharge and active flag. Applicability is containment within that product. The RPC validates types, positive quantities, bounded labels, unique IDs, nonnegative exact money and at least one active variant for an active product. Engineering arrays are bounded at 200 entries each. There are no direct client table mutations.

`delivery_zones` contains stable UUID, owning business FK, bounded name, nonnegative bigint fee_paisa and active flag. Authenticated owners can SELECT their own products/zones through RLS; anon/raw-table access and other owners' reads/writes are denied. No product, option or zone delete API is exposed. Omitted product/zone IDs are deactivated rather than deleted.

| RPC | Access and authority |
| --- | --- |
| save_baker_workspace | Authenticated actual owner; locks business; compares revision; transactionally validates/upserts catalog and zones, edits allowed business details and increments revision; rejects cross-business IDs. Ignores injected owner/code/image/completion values |
| activate_business | Actual owner and matching revision; server requires complete name/description/contact/location/fulfilment details; publishes by setting completion and increments revision |
| check_business_setup | Internal only; revoked from PUBLIC/anon/authenticated; rechecks subsequent active-business edits as well as activation |
| validate_catalog | Internal validation helper, no client execute |
| public_business | Explicit active-only JSON projection for anon/authenticated. Only id/code/name/description/location/public image paths/pickup-delivery flags/minimum. No owner ID/name/contact or exact address |
| catalog_estimate | Owner may preview a draft; others may estimate only an activated business. Checks product/variant/options/zone applicability and availability, quantity/subtotal minimum, pickup/delivery enabled. Server calculates saved prices and returns integer subtotal/delivery/total, PKR and revision; no client-total argument |

All privileged functions use empty search_path, explicit schema qualification, explicit ownership checks and revoked default execution. Safe public RPCs receive deliberate grants. Business code is an identifier, not a private credential. Draft business rows are not publicly discoverable. Customer lookup/public catalog screens remain Phase 4; only the backend safe business projection is established here.

Prices are integer paisa throughout: PKR 3,000 = 300000. Item quantity scales base plus selected charges, then a single named-zone fee is added. Minimum value excludes delivery. Example: 300000 + 50000 + 30000 = 380000; delivery 30000 gives 410000 (PKR 4,100). No sample catalog is inserted by migrations or normal real-user onboarding. Custom design charges remain explicit quote adjustments in Phase 6.

Future order implementation MUST create immutable snapshots with labels/units/selected options/prices/currency/business revision and pinned image references. Historical orders must not join mutable catalog prices to reconstruct totals. No historical order table exists yet, so current public orphan cleanup does not pretend to implement order-image retention.

## Phase 3 storage: 20261026000400_catalog_storage.sql

All image bucket limits remain 5 MiB/object, JPEG/PNG/WebP. No service key. No UPDATE/upsert policy; every replacement has a new UUID filename.

| Bucket | Current path and permissions |
| --- | --- |
| profile-images | Private, unchanged user-ID prefix ownership. Personal account photos never enter public business buckets |
| business-images | Public bytes; `<business-id>/profile/<file-id>.jpg|png|webp` logo and `<business-id>/cover/<file-id>...` cover. Metadata SELECT/INSERT/DELETE require actual owner |
| product-images | Public bytes; `<business-id>/<product-id>/<file-id>.jpg|png|webp`. Product must already exist in that owned business. Metadata SELECT/INSERT/DELETE require matching product/business owner |
| order-references | Private; restrictive denial remains until actual order membership exists |
| conversation-attachments | Private; restrictive denial remains until participant membership exists |

`set_baker_image` requires the owner, current revision, known slot, owned product where applicable, matching canonical path and existing uploaded storage object. It attaches/removes a pointer and increments revision. A restrictive DELETE policy protects referenced business/product images. This protects uncertain commits during network failure; a client cannot delete the new image while the database points to it.

The repository stores cleanup intent before upload, then attaches the new pointer and acknowledges it locally, queues the previous image and retries removal. Pointer failures/abandoned uploads stay retryable. On an uncertain commit, cleanup reads current pointers before deletion and the database independently protects references. Failed cleanup survives app restart in a per-project/per-user queue; loading the workspace attempts it, and Review offers Retry image cleanup. Queue data never authorizes access; RLS still applies. Loss of local application storage can leave server orphans; no privileged scheduled server cleanup or retention schedule is invented. Personal Phase 2 profile-photo replacement retention is unchanged.

Migration 004 also fixes unqualified storage object-name references: names are explicitly `storage.objects.name`, avoiding a business `name` binding or ambiguous product/business joins. The local runtime test found this defect; it was not detectable by syntax parsing alone.

## Current verification boundaries

- PGlite 0.5.11: actual PostgreSQL execution with modeled Auth/Storage schemas and roles; ownership/grants/RLS/functions/activation/pricing/storage-object checks. This does not execute Supabase services, enforce actual bucket HTTP type/size limits, deliver email or test native restart.
- Supabase pgTAP: identity_rls.test.sql plus catalog_rls.test.sql, prepared for `supabase test db`; blocked without a running stack.
- Real HTTP: verify_backend.py and verify_phase3.py use dedicated accounts/public key, never a service key; unexecuted without development configuration.
- Flutter: pure rules, preview device persistence, HTTP-mocked SDK image failures and widget flows. No claim of live persistence derives from these checks.

Future database functions for quotes, agreements, capacity, allowances and lifecycle changes must use explicit execute grants, authenticated ownership checks, a fixed search path and transactional atomic writes. Retryable mutations require unique scoped idempotency keys; stale revisions must conflict instead of silently overwriting. See [architecture contract](architecture.md) and [NFR acceptance criteria](non-functional-requirements.md). None of these future order workflows is implemented by the Phase 3 catalog RPCs.

Primary policy/function guidance: [Supabase functions](https://supabase.com/docs/guides/database/functions), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).


## Customer discovery migration (20261028000100)

Adds account-private `saved_businesses` with composite key and self-read RLS. Only `set_saved_business` mutates it, enforcing auth.uid(), active business lookup and duplicate-safe insert/remove. `saved_bakeries` exposes only approved public profiles; inactive saved businesses return null profiles and remain removable. `public_menu` exposes active products/options/variants using explicit JSON projections, UUID keyset pagination, default page 20, hard maximum 30. `public_business` normalizes case/whitespace. `set_business_publication` locks the owned business, compares revision and validates setup before publication. No private profile/business table grants or storage policies are loosened. Every new privileged function fixes search_path and restricts EXECUTE. This migration is deployed to development; live multi-account acceptance remains pending. See phase-4-handoff.md.

## Phase 4 availability and recent history

Migration 20261028000200_availability_recents adds availability_settings, blocked_dates, capacity_allocations and recent_businesses. All have RLS; the first three have no direct client grants, recent history has self-only SELECT. Functions revoke PUBLIC execution and use empty search paths. owner_availability/save_availability/set_blocked_date require ownership; mutations lock the business and compare settings revision. bakery_availability exposes configured/timezone/lead_days/today/date-state only, for active bakeries or their owner. Date ranges max 62 days; invalid date casts are rejected by PostgreSQL. No object policies were loosened. public_business additionally exposes active delivery zone name/fee only.

capacity_allocations is an inaccessible integration contract with no client writer, no real-order population and no fixture live data. Confirmed/baking/ready/delivered count; pending/declined/withdrawn/cancelled do not. Future confirmation/reschedule/manual transactions must use the business lock, recheck availability and write order/allocation/event atomically. Add real order FK and idempotency/concurrency tests then. Blocking occupied dates and conflicting timezone/capacity changes fail. No existing booking is cancelled. Service dates are SQL date; recent timestamps are timestamptz. Caller device timezone never determines business today.

record_bakery_open locks the caller profile, verifies published business, upserts last-open timestamp and prunes to 20. recent_bakeries returns safe public profiles or null for unavailable businesses. History is not shared between identities. All limits/lead-day units are implementation defaults as documented in decisions, not commercial entitlements or approved retention commitments.
