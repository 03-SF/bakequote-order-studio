# Decisions and open questions

## Adopted development decisions

1. Flutter project is isolated in `mobile`; reference remains a sibling Git clone at the audited commit. No new GitHub repository/remote was invented.
2. Project package is `bakequote_mobile`, display name BakeQuote, Android development ID `dev.bakequote.bakequote_mobile` and iOS development ID `dev.bakequote.bakequoteMobile`. Owner must provide final identifiers before store registration and auth/app-link configuration.
3. Phase 1 has explicit preview role routes rather than simulated production sign-in. There are no accounts, persistence promises or backend writes. Locale and navigation state reset after restart.
4. Core visual tokens follow reference hex annotations. Native Material controls, directional spacing, safe areas and an adaptive rail replace web primitives. Dark mode is not designed in Phase 1.
5. **Superseded by decision 22:** historical bilingual foundation. Current application and future acceptance are English-only.
6. **Superseded in Phase 3:** bundle Manrope and Fraunces with OFL licenses. Urdu font assets are removed. Supplied photographs remain development assets pending rights confirmation.
7. Use integer paisa in pure domain objects; UI samples currently show whole PKR. Database must choose a corresponding exact integer/numeric contract. The canonical 4100/4500 quotation is test data, not a commercial product policy.
8. Do not copy the web demo limit of eight confirmations into a production plan. No plan limits, prices or entitlements exist in this phase.
9. Historical Phase 1 decision: client/provider boundary existed with initialization deferred. Phase 2 now initializes the SDK only in explicit live mode; public settings never make preview accounts real.
10. Rule helpers are advisory client calculations. Server permissions, transactions, event writing, deduplication and capacity checks remain authoritative. The client cannot safely confirm simultaneous requests.
11. Manual-order flow must be separate from app quotation agreement and conversation creation. Current rules reject manual agreement/confirmation; actual manual creation is Phase 7.
12. Generated web host is for inspecting the Flutter UI, not a continuation of React or a separate website product.

## Owner decisions still required

| Decision | Needed before |
| --- | --- |
| New GitHub remote, ownership/team, final bundle IDs and signing identities | Remote publishing/store setup |
| Supabase project/region, public client settings, auth email sender and approved callback domains | Phase 2 live accounts |
| Business membership model (single baker vs teams), business timezone and supported locations | Schema/availability finalization |
| Cancellation/reschedule/lead-time override policies and quote validity rules | Phase 6 |
| Image source rights and final brand/store icon assets | Release |
| Applicable plans/limits, pricing, export/restore scope and backup responsibility | Phase 9 |
| Terms/privacy, retention, deletion handling for order records and message attachments | Phase 9 |
| Notification channels, delivery provider, moderation/report/block behavior | Phase 8 |
| Minimum OS/device support, accessibility acceptance | Release matrix |

No commercial prices, legal policies or retention periods have been invented. Advances are records of payments received outside the app; real payment processing is out of scope unless separately authorized.

## Phase 2 decisions (2026-10-26)

13. APP_MODE defaults to `preview`; `live` is explicit. Public keys do not select a mode implicitly. Preview and live have separate route sets/repositories and no shared identity/data store. Misconfigured live mode shows an error instead of using sample data.
14. Supabase owns token persistence/refresh through the installed Flutter SDK. Our controller checks the server before exposing a restored identity, handles async errors and clears account-specific state across identity changes. Signed private image URLs are ephemeral; decoded image caches are cleared on identity change.
15. Use PKCE with `dev.bakequote.mobile://auth/verify` and `/reset`, AppLinks-owned dispatch and disabled duplicate Flutter/SDK URI handlers. The SDK code-exchange result must agree with the exact callback path. Recovery is kept per project/user across restart and completed password changes require a new password sign-in. Same-installation email flow is a development constraint; cross-device reset bridging is not implemented.
16. **Unresolved product decision: can one account be both customer and baker?** Phase 1 did not decide this. Phase 2 records one initial experience after verification and does not expose live role switching. It does not use role metadata as an authorization claim. Separate identity tables avoid an exclusive database enum entitlement; a later explicit product decision can add dual-role enrollment and navigation with new policies/UI. No privileged operator/admin account feature exists.
17. For Phase 2 idempotent identity initialization, one private draft business per initial baker is enforced by a unique owner. Multi-business ownership and team memberships remain unresolved, not silently enabled. Full bakery onboarding remains incomplete and belongs to Phase 3.
18. All private profile data and draft business records are self/owner-only. No public business projection is added before the catalog phase. Public bakery image bytes are explicitly public; personal profile images are private. Images are optional; no rights over customer order/conversation data are invented.
19. Image limits are development engineering defaults (5 MiB, JPEG/PNG/WebP); no commercial storage plan or retention schedule is defined. Old image-object cleanup, data retention and account deletion remain owner decisions/later work. Future product uploads and private order/conversation attachments are restrictive-denied until their ownership models exist.
20. CLI discovery used Supabase 2.122.0 via npx. No local config/project was available. Hosted project discovery returned AccessTokenRequiredError; Docker/Podman were absent; database tests could not connect to 127.0.0.1:54322. Migrations have not been applied or RLS live-verified here. Public configuration goes in ignored local JSON; CLI access tokens/database passwords stay in local prompts/secret environments, never chat or Flutter.
21. No remote has been configured. Local commits preserve work on this machine only. Final bundle identifiers, verified universal links, iOS signing, auth email sender and owner-approved domains remain unresolved.

## Phase 3 requirement change (2026-10-26)

22. BakeQuote is English-only by explicit owner instruction. This supersedes decisions 5/6 and every earlier bilingual/Urdu acceptance criterion. Urdu dictionaries, locale controls/preferences and font assets are removed; old stored locale values fall back to English. Direction-aware Flutter APIs and large-text accessibility remain. Historical handoffs record what was tested then, not current requirements.

23. Preserve the Phase 2 initial-experience model and provisional one-business-per-owner onboarding constraint. Phase 3 authorization uses business ownership, never preview roles or a new exclusive-role entitlement. Dual-role enrollment/navigation and teams/multiple businesses remain unresolved; none is required to edit the existing owned business. The exact future question is whether a customer may enroll as a baker on the same identity, and which role-switch/navigation/membership workflow should expose that enrollment.
24. Business activation requires name, description, owner/contact name, contact phone, public area, at least one fulfilment method, pickup address when pickup is enabled, and an active zone when delivery is enabled. Images and catalog publication are optional at activation. The same server checks apply to subsequent active-business edits. Public projection excludes owner ID, owner/contact information and exact pickup address. Customer lookup/screens remain Phase 4.
25. Catalog variants and customization options are product-owned JSON arrays with stable UUIDs, validated within a transactional RPC. This explicitly models applicability without imposing shared-option behavior. Cake size quantities use positive grams and descriptive labels; cupcake variants use positive counts per pack. At most one flavour and finish plus distinct extras follow the reference configuration. Option charges apply per ordered cake/pack; quantity scales the item subtotal. Per-extra arbitrary quantities/multi-flavour mixes are not in confirmed scope and require an explicit extension. Deactivate products/options/zones instead of deleting; future orders must capture immutable labels, units, prices, selected image references and business revision. Catalog edits must never recompute historical orders.
26. Currency is PKR, stored/calculated as bigint integer paisa (100 paisa = PKR 1). The minimum product subtotal excludes delivery. Quantity minimum is per product, measured in cakes/packs; pack units are separate. Zones are explicitly named/selectable with nonnegative flat fees, without invented radius/geocoding rules. The server ignores client totals and derives prices from saved active product/variant/options/zone records. No automatic custom-design price is invented: the existing manual quote adjustment belongs to Phase 6. The PKR 4,100 example is an explicit preview/test fixture only.
27. Workspace saves lock the owned business and compare a revision. Stable client-created product/zone UUIDs plus transaction/upsert and stale-revision rejection prevent duplicated repeated saves. New business creation remains the existing verified/idempotent identity RPC. Stale edits require reload and review; there is no silent last-writer overwrite.
28. Public business/product image upload validates byte signatures/5 MiB before immutable UUID-path uploads. Bucket limits remain independently configured. Upload UI reports checking/uploading/saving stages with indeterminate progress, not invented byte percentages. Referenced images cannot be deleted through Storage RLS. A per-project/per-account local cleanup queue records upload intent before upload, retries abandoned/replaced objects after loading or on request, and checks referenced paths after uncertain commits. Cleanup is best effort while offline; losing device storage can leave unreferenced server objects requiring an owner-authorized future server cleanup job. This is engineering cleanup of unreferenced public uploads, not a retention policy for order/chat records. Private order/conversation permissions stay restrictive-denied.
29. Local PostgreSQL/WASM verification uses pinned PGlite 0.5.11 with modeled Supabase schemas/roles. It executes actual SQL, grants, RLS and PL/pgSQL, but does not verify Supabase services or hosted/local deployment. Real Auth/email/PostgREST/Storage and native authenticated restoration remain external acceptance blockers. Migration 004 corrects ambiguous/unqualified storage object-name references discovered by runtime execution; earlier versioned migrations are preserved.

30. Estimate responses must remain within the exact integer range shared by native Dart and optional web preview (2^53 - 1 paisa). Backend/client reject larger totals before returning/displaying a rounded number. This is a numeric representation boundary, not a commercial business price policy. Null revisions are rejected by every workspace/activation/image RPC.
