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
9. Supabase client/provider boundary exists but initialization is intentionally deferred. A supplied public key does not make preview accounts real. Backend credentials are not needed for Phase 1.
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
