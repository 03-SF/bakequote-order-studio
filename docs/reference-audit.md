# Reference audit

## Source and method

Source: https://github.com/03-SF/bakequote-order-studio

Inspected commit: `28a346ce0a4b011658f848a1d8564a8d29208783`.
Local checkout: `../../reference/bakequote-order-studio` relative to this document. Read the root AGENTS.md (preserve Lovable history), README, package configuration, every route, shared BakeQuote shell/UI/order components, styles, seed/catalog, pricing, state machine, selectors, dates, localStorage store, media helper and both test files. The checkout is preserved as a separate repository. Dependency installation used `npm install --no-package-lock`; no frontend feature edits were made.

The repository is TanStack Start / React 19 / TypeScript / Tailwind 4 with Vite 8, not Flutter. README explicitly separates the current build-repair baseline from its original aspirational prototype brief. Ten route tests only establish route matching, not complete user workflows.

## Findings

| Area | Observed implementation | Classification |
| --- | --- | --- |
| Welcome and entry | Hero photograph, wordmark, customer/baker entry; `/auth` sets local demo session without password | Implemented UI, simulated authentication |
| Customer shell | `/home`, `/orders`, `/messages`, `/account`; responsive sidebar/bottom navigation | Implemented navigation |
| Baker shell | `/baker/today`, `/baker/calendar`, `/baker/orders`, `/messages`, `/baker/account` | Implemented navigation |
| Home and Today | Shared FoundationPage displays bakery text and sorted seeded orders; Today is not a due-time operational dashboard | Partial |
| Orders | Seeded records, status, date/amount; modal configuration, quote/history, progress, event list | Implemented read-only demo presentation |
| Conversation | Role-filtered app-order conversations; local text/data-URL images, unread timestamps, simulated failure/retry | Simulated local functionality |
| Calendar | Agenda text, blocked dates and order list; no month grid or date editing | Partial |
| Account | Sample identity and explanatory text; no editing, verification/reset or deletion | Partial |
| Language | Key-label dictionary and document RTL; most content remains English | Partial |
| Persistence | One browser localStorage document shared across demo roles; export/import/reset and shallow validation | Simulated; not production storage/backup |
| Rules | Pure pricing, agreement/revision, confirmation/availability, transitions, cancellation, rescheduling, advances, review eligibility and customer projection helpers | Implemented local helpers; most have no complete UI workflow |
| Bakery access, saved bakery editing | Code and saved values seeded; no working lookup/share/menu workflow | Missing workflow |
| Catalog and baker setup | Seed structures only; no CRUD/setup screens | Missing |
| Request wizard, drafts and submit | Types/default draft exist; request creation not implemented | Missing |
| Confirmation and operations | Helpers exist; no production transaction/RLS/idempotency, operational editing/manual-order workflow | Missing backend/workflow |
| Notifications, moderation, plans | Demo controls/acknowledgements and fixture allowance of eight; no external service or legitimate commercial plan | Simulated or planned |
| Supabase | No Supabase dependency, migrations, Auth, Storage or Realtime | Missing |

## Runtime inspection

Installed dependencies and started `npm run dev -- --host 127.0.0.1 --port 5173`; Vite served successfully. Browser inspection covered the welcome hero, customer order list/detail (BQ-1037, itemization, advances, event history), baker demo entry and baker workspace. Source inspection covers all ten routes; runtime inspection is not a full acceptance test. npm reported two high-severity dependency advisories; no forced dependency changes were applied to this reference.

## Visual system and reuse

| Token | Reference / Flutter choice |
| --- | --- |
| Background | Ivory `#FFF9F5` |
| Brand | Muted rose `#B65F75`; darker `#93465D` for readable filled controls |
| Secondary surface | Blush `#F5E4E8` |
| Text | Cocoa `#35292D`; secondary `#75666B` |
| Border | `#EADDE0` |
| Geometry | 12px controls, 16px cards, restrained borders/shadow; 16/20/24px spacing |
| Fonts | Manrope body, Fraunces headings/wordmark, Noto Nastaliq Urdu for Urdu |
| Navigation | Customer four tabs, baker five; bottom tabs on phones and rail at wider widths |

Reference CSS uses OKLCH values with the above hex comments. Flutter intentionally follows documented hex brand tokens; this is a native adaptation, not exact CSS rendering. Built-in Material cake icon adapts the reference inline SVG cake mark. Reference numbers and order IDs remain isolated LTR in the Flutter preview.

Copied `src/assets/bakery-hero.jpg`, `cake-chocolate.jpg`, `cupcakes.jpg` into `assets/images`. No standalone image license/source attribution was found; owner must confirm rights before release. The photos are supplied project assets, used here for development. Fonts are bundled from Google Fonts with corresponding SIL OFL licenses in `assets/fonts`, avoiding runtime font requests. Font source paths: `ofl/manrope`, `ofl/fraunces`, `ofl/notonastaliqurdu` in https://github.com/google/fonts.

## Porting decisions

The reference's canonical 2 lb cake fixture is 3000 + 500 + 300 + 300 delivery = 4100 PKR; custom design +400 = 4500, recorded advance 1500 leaves 3000. Actual starting menu prices are 1800 for chocolate cake and 1500 for cupcakes. The reference does not seed BQ-1042: it is the next sequence number. Flutter uses BQ-1042 as an explicitly labeled illustrative quotation.

Dart ports the applicable estimate, versioned agreement, revision invalidation, sequential production, availability/online preconditions, pending capacity semantics, distinct cancellation request and review ownership checks. Tests add real time bounds, integer paisa and immutable quote lists. The reference's demo allowance, browser persistence, seed date mutation and projection-only security are deliberately not adopted as production architecture. Dart domain tests do not prove server concurrency or permissions. Catalog lookup/conflict validation, full date rules, private projections and persistent operation idempotency remain later work and are tracked explicitly.

## Phase 2 boundary

The reference findings above remain historical and unchanged. Native authentication and Supabase migrations are new Flutter/backend work; none are inferred from the Lovable demo. The reference checkout is still separate and was not modified for Phase 2. Preserve its published Lovable history.

## Phase 3 note

The language/font findings above describe the preserved React reference. Current Flutter requirements are English-only; Urdu assets and language controls have been removed. The reference pricing configuration confirms one flavour, one finish and distinct extra IDs per selection. Native catalog options are scoped per product to make applicability explicit. The reference checkout was not changed.
