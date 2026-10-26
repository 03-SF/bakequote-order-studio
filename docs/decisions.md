# Decisions and open questions

## Adopted development decisions

1. Flutter project is isolated in `mobile`; reference remains a sibling Git clone at the audited commit. No new GitHub repository/remote was invented.
2. Project package is `bakequote_mobile`, display name BakeQuote, Android development ID `dev.bakequote.bakequote_mobile` and iOS development ID `dev.bakequote.bakequoteMobile`. Owner must provide final identifiers before store registration and auth/app-link configuration.
3. Phase 1 has explicit preview role routes rather than simulated production sign-in. There are no accounts, persistence promises or backend writes. Locale and navigation state reset after restart.
4. Core visual tokens follow reference hex annotations. Native Material controls, directional spacing, safe areas and an adaptive rail replace web primitives. Dark mode is not designed in Phase 1.
5. All currently authored foundation copy is centralized in an English/Urdu dictionary; Material delegates supply RTL and system labels. Fixture names/code are proper-name data. A native Urdu language review and future full-workflow localization remain required.
6. Bundle Manrope, Fraunces, Noto Nastaliq Urdu and their OFL licenses. Use supplied project photographs for development; confirm redistribution rights before release.
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
| Minimum OS/device support, accessibility acceptance and Urdu editorial approval | Release matrix |

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
