# Database and storage access-control foundation

Migrations are versioned source, not proof of an applied database. Current live execution is blocked; see [handoff](phase-2-handoff.md).

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
