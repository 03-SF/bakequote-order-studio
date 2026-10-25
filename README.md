# BakeQuote Order Studio

## Current status

The build-repair baseline provides welcome/demo entry, customer and baker navigation,
readable seeded orders and quotations, conversations, a read-only agenda and demo controls.
It is not the completed application. Real authentication, backend persistence, order
creation, editing and the remaining business workflows still need implementation.
The product goal is the full app; the screen list below is coverage guidance, not a cap.

## Local checks

Use Node.js 22.12+ (or a supported newer version). After installing dependencies:

```sh
npm run build
npm run typecheck
npm test
npm run dev
```

The build regenerates TanStack route types. Do not edit `src/routeTree.gen.ts` by hand.
Open the URL printed by Vite. Select a demo role; no password is needed.

The following section records the original prototype brief, not completed features.


Build BakeQuote, a polished fully interactive mobile-first responsive web prototype for customers and home bakers. Build now, not a plan or marketing landing page. React/TypeScript, Tailwind, reusable components. Use seeded demo data and shared localStorage persistence with separate customer/baker demo sessions and a discreet role switcher and reset-data action. No production backend, real authentication, payments or push integrations required. Do not publish externally.

Visual: warm ivory #FFF9F5, white surfaces, muted rose #B65F75, blush #F5E4E8, cocoa text #35292D, secondary #75666B, borders #EADDE0. Refined bakery identity, consistent BakeQuote wordmark, attractive cake photography, restrained rounded cards/shadows, clear typography. Information-rich functional layouts, not repeated generic cards. Mobile bottom nav at 390–430px, responsive desktop sidebar/two columns, accessible labels/contrast/focus/touch sizes. Customer nav Home/Orders/Messages/Account. Baker Today/Calendar/Orders/Messages/Account.

Planned feature coverage (not a fixed screen limit), with supporting states as tabs/steps/dialogs/sheets:
1 Welcome and role selection with customer/baker demo entry.
2 Auth internal sign-in/register/reset/verification states, explicitly simulated, no real passwords.
3 Customer Home: known baker code SWEETCRUMB, saved/recent bakers, active order summary (no unrestricted marketplace).
4 Baker Profile/Menu: photo, business details, ratings, location, pickup/delivery, lead time, cake/cupcake menu, starting prices/options, availability, reviews, save and create-request CTA.
5 Create Order: internal steps product/customization; date/fulfilment; contact/design; review/submit. Cake/cupcake, weight/quantity, flavour, finish, extras, instructions, local reference image preview/removal, available dates, pickup/delivery zone/address, contact, itemized estimate. Preserve draft on back, validate.
6 Customer Orders active/past with status/date/reference/amount.
7 Customer Order Detail: configuration, images, estimate/current quote/history, timeline, agreement, withdrawal/cancellation requests, conversation and eligible review. Never private notes.
8 Shared Conversations Inbox filtered by demo role with search/unread/previews.
9 Order Conversation: text and image messages, timestamps, retry state, order header/link. Persistent across role switches. Chat never confirms orders.
10 Customer Account: profile/contact/saved bakers/language/notification preferences/help/privacy/demo deletion/sign out.
11 Baker Setup internal identity/catalog/pricing/fulfilment/availability/review-activate steps.
12 Baker Today: compact pending/today/upcoming/overdue operational view, stages, due times, quick manual order.
13 Baker Calendar usable month grid/day agenda, today shortcut, order markers, FULL/BLOCKED, block/unblock sheets affecting customer date picker.
14 Baker Orders filters Pending/Confirmed/Baking/Ready/Delivered/Declined-Cancelled and search.
15 Baker Order Detail: full request, customer/images, revise quote/history/agreement, confirm with due time, production updates, recorded advance/balance, PRIVATE notes, chat/reschedule/cancellation decisions/event history.
16 Quick Manual Order: customer name/phone, description/date/time/total/advance/balance/private notes; label Manual, never create customer account or conversation.
17 Baker Business/Catalog Settings: business, cakes/cupcakes, flavours/weights/extras/prices, zones/fees, minimums, lead time, availability, code/share. Changes reflected customer-side.
18 Baker Account/App Settings: account/language/notifications, Free/Pro plan panel, demo allowance, backup/restore info, help/privacy/deletion/signout. No invented commercial prices: pricing to be confirmed.

Coherent sample journey: Sweet Crumb by Ayesha, baker Ayesha, F-10 Islamabad, customer Sara Ahmed, PKR, order BQ-1042, 2lb chocolate birthday cake. Demo fixture base 3000+buttercream 500+topper 300=3800 product; delivery 300=4100 estimate. Later custom design adjustment 400 gives 4500 revised quote. Recorded advance 1500 leaves 3000. Itemize fees; use consistent dates relative to initial demo date and persist them. Seed several additional distinct-stage orders.

Rules: request Pending; quote version/agreement separate from confirmation; revision invalidates prior agreement; baker explicitly confirms after current-version agreement, availability and demo allowance checks. Pending does not reserve date. Confirmed>Baking>Ready>Delivered; reject invalid transitions and duplicate clicks/submission. Decline, pending withdrawal, cancellation REQUEST vs approval distinct; reschedule logged. Delivered app order eligible for one customer review. Keep private notes inaccessible in customer selectors/components. Manual orders no chat. Allowance reached leaves request pending and existing orders accessible; clearly demo fixture not actual commercial plan.

Complete working journey: customer opens bakery/configures/uploads image/requests; switch baker sees same pending request/revises quote; switch customer agrees; switch baker confirms with due time; appears in calendar/today; both exchange messages; advance stages through delivered; customer reviews. Every primary action functional, persists refresh. Shared state no separate disconnected mock views.

Supporting sheets/dialogs for edits, blocking, quote, confirmation, decline/withdraw, cancellation/reschedule/advance/notes/review/report/block/plans/deletion. Demo controls simulate offline/upload-message failure and allowance reached. Cached viewing/drafts allowed offline simulation; authoritative submission/confirmation blocked. Useful empty/loading/error/success states, unsaved changes, date conflict, catalog changes. Image upload is local demo only.

English/Urdu key labels/navigation with RTL and suitable Urdu font; don't claim complete localization unless complete. Keep references/numbers readable. Clearly label simulated auth/payment/notification/deletion actions. Advance is recorded, not processed payment. Optional JSON demo export/restore must validate and never claim encrypted production backup. Report/block demo acknowledgement only, no real moderation claim.

Separate mock services, pricing and state machine from UI. Verify pricing, transitions, quote-version agreement invalidation, shared-role journey, persistence/reset, mobile no-overflow, working links/dialogs and no hidden-by-sticky content. Add meaningful tests if supported. Finish full scope then report features, actual checks, limitations and demo exploration steps.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/add934d4-0575-4f2a-9f18-e413504ce7ae).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
