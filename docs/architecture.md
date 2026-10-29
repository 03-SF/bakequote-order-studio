# BakeQuote architecture contract

Current reconciliation: English-only, offline functionality excluded. Session restoration and safe recovery of unsent user input remain supported without promising offline workflows. Phase 5–10 implementation and live acceptance are not complete; [the completion matrix](phase-completion-matrix.md) supersedes older phase-status statements below. The owner approved Confirmed → Baking → Ready → Delivered; existing Decorating orders remain readable/capacity-consuming and may advance to Ready. Order-reference access is participant-gated, while conversation uploads and account deletion remain disabled.

## Phase 5 extension (2026-10-29)

The [request feature](../lib/features/requests/) uses pure typed domain models/contracts, Supabase/SharedPreferences mapping in data, Riverpod workflow coordination in application, and forms/list/detail widgets in presentation. Its public entry point is `requests.dart`; discovery opens the composed router route rather than importing private request data. Widgets pick input/files but do not coordinate database writes. Application providers own pagination, private signed-image URLs and identity-scoped repository injection. Captured-session checks and operation epochs prevent stale results/caches after navigation or account changes.

`open/save/review/submit_request` are invariant-sensitive server transactions, not widget write sequences. Submit locks draft/business and atomically freezes the request, estimate version 1, event and attachments. No Edge Function is needed because Phase 5 introduces no external integration or privileged secret. Ordinary bounded list/detail reads use RLS. Errors map SQLSTATE to sanitized recovery instructions. No automatic write retries; user retry reuses the draft/review token. SharedPreferences partitions draft and cleanup intent by project/user/business and is not claimed encrypted. See [handoff](phase-5-handoff.md) and [schema](database-and-storage.md).

Earlier baseline descriptions below remain architectural history. The authorized scope is now completed Phase 5 implementation, stopping before Phase 6; multi-account/native acceptance gates remain open.

Status: Phase 3A baseline, 2026-10-26. This describes the present Flutter implementation and the boundaries required for later features. A passing build does not prove that every boundary is satisfied; the audit records the remaining work.

## Runtime and composition

`lib/main.dart` reads compile-time configuration and initializes Flutter. `lib/app/app.dart` composes the `MaterialApp.router`, theme, English strings and `go_router` routes. `routerProvider` is the navigation composition root. The authentication state begins in `initializing`; route redirection waits for restoration before selecting signed-out, verification, recovery, onboarding or signed-in routes. Preview and live route sets are selected explicitly by `BackendConfig`; preview uses fixtures/device storage and does not initialize Supabase.

Riverpod providers construct repositories and scope their lifetime to configuration and identity. Auth session events feed `AuthController`. Identity changes invalidate account-scoped providers and clear Flutter image caches. Repository operations check the captured identity before writes. An expired session therefore fails the operation and must not report success. Error mapping returns stable user-safe copy; raw backend messages, SQL, URLs and credentials must not reach UI or routine logs.

## Feature layers

Each feature may use these folders where they add a real boundary:

| Layer | Responsibility | BakeQuote examples |
| --- | --- | --- |
| Presentation | Widgets, input, accessibility, display state and navigation intent. Calls application providers/controllers; no SQL or multi-step backend coordination. | `auth/presentation/auth_pages.dart`, `auth/presentation/live_pages.dart`, `baker/presentation/baker_pages.dart`, `preview/presentation/preview_pages.dart` |
| Application | Riverpod controllers/providers, session-aware dependency injection and workflow coordination. Owns loading/success/failure state and prevents duplicate submissions. | `auth/application/auth_controller.dart`, `baker/application/baker_providers.dart` |
| Domain | Plain Dart models, validations/calculations and repository contracts. No Flutter, widgets, Supabase client or transport DTOs. | `auth/domain/auth_models.dart`, `auth/domain/auth_repository.dart`, `baker/domain/baker_workspace.dart`, `baker/domain/baker_repository.dart`, `catalog/domain/pricing.dart`, `orders/domain/order_rules.dart` |
| Data | Supabase/Auth/Storage calls, local preview persistence, SQL-shaped serialization and concrete repository implementations. | `auth/data/supabase_auth_repository.dart`, `baker/data/baker_repository.dart`, `preview/data/preview_repository.dart` |

`core/config/backend_config.dart`, `core/theme/app_theme.dart` and `core/l10n/app_strings.dart` are app-wide facilities. `core/media/image_validation.dart` contains byte-only image validation shared by auth and baker features. `shared/widgets/controls.dart` is for controls with a real cross-feature use. Do not move feature rules into `core` merely to make an import convenient. Keep Preview's fixture persistence isolated from live repositories.

Domain value objects must not become thin wrappers around Flutter or Supabase types. Repository contracts belong in the consuming feature's domain (or application layer if they express orchestration rather than domain capability); data implements them. Domain may depend on core pure-Dart utilities. A feature may use another feature only through an intentionally public, stable application/domain API; never import its private `data/` or `presentation/` implementation. Widgets do not contain SQL, call Supabase directly, or coordinate multi-step writes. Avoid adapters that only rename an SDK method without adding policy, validation or testability.

## Backend responsibility and authority

- Direct Supabase reads and a single invariant-safe write are acceptable in a repository when grants/RLS enforce the caller's access, the result is bounded, and no cross-row invariant must be updated atomically. Phase 3 owner's catalog reads are bounded by the owned business ID and RLS; public business details use an explicit approved projection.
- Database functions/RPCs and transactions own invariant-sensitive database operations: business activation, revision-checked workspace save, image-pointer update, authoritative catalog estimates, and future quote agreement, confirmation/capacity, allowances and order transitions. Validate `auth.uid()` and ownership inside the operation. Future operations spanning records must commit all changes or none.
- Edge Functions are for external services, provider secrets, privileged administrative work and workflows that do not belong in a database transaction. Keep service-role secrets server-side; do not create a privileged function as a shortcut around RLS.
- Every schema/policy/function change is a new versioned migration. Do not edit a migration already applied to an environment. Rehearse forward migration and recovery/rollback implications against a disposable development database.
- Revoke default `PUBLIC` execution on privileged database functions. Set a fixed safe `search_path`, schema-qualify referenced objects, validate the authenticated actor and grant `EXECUTE` only to the required roles. Never trust caller-supplied owner IDs, totals, role claims or projections.
- Retryable creation and confirmation operations require a caller-scoped idempotency key backed by a unique database constraint and a stored result. A client must not automatically retry a non-idempotent write without such protection. Existing Phase 3 workspace writes use stable IDs, a lock and revision comparison; conflict is returned for user review. Do not label this as a general operation-key facility.
- Use row revisions or equivalent compare-and-set for concurrently edited state. A stale edit returns a conflict and preserves input for reload/review; do not silently overwrite a newer edit.
- Persist money as integer paisa (`100 paisa = PKR 1`); server functions load applicable saved prices and calculate totals. Client estimates are display-only. Future orders save immutable labels, units, selected options, prices, currency and business/catalog revision; later catalog edits cannot change history.

## Security and data exposure

PostgreSQL grants and RLS are the access-control boundary. UI visibility and route guards improve usability but never authorize backend access. Auth identities do not carry client-writable operator privileges. Business ownership is verified from database relationships. Customer-facing business reads are allow-listed projections; raw business rows include private contact and exact pickup data and are owner-only. Public image buckets are intentionally public for image bytes and must contain no personal profile or attachment content. Profile images are private. Order-reference and conversation attachment access remains denied until membership tables and policies exist.

Auth SDK owns session persistence and token refresh. The app waits for `getUser`/restoration and profile loading before exposing protected routes. Supabase PKCE callback handling is centralized in `AuthController`, classifies exact callback paths, and checks the SDK exchange result. Recovery state is associated with the user/project so a reset link cannot route a verification flow into password recovery. Account changes clear the prior profile, scoped providers and decoded image cache. Current local preferences include non-secret preview drafts and image-cleanup intent; they are not trusted access grants. No source or test result in this repository certifies the host platform's on-disk token encryption; assess the selected Supabase Flutter SDK and platform storage before release.

## Known boundary status

The Phase 3A correction moved AuthRepository and BakerRepository contracts into feature domain folders, moved auth repository provider composition to the application layer, and extracted shared byte validation from auth data into core. Remaining debt is listed in [architecture NFR audit](architecture-nfr-audit.md): `BakerWorkspace` is a JSON-shaped mutable persistence model in the domain, `bakerError` still classifies some database failures by text, and the auth controller's provider constructs the Supabase SDK implementation. These are contained and do not grant access, but should be separated into pure workspace rules/data DTO mapping, typed safe repository failures, and a composition boundary as the features grow. Do not use a broad rewrite to address them.

The unresolved dual-role policy remains open. The current first-experience navigation and one-draft-per-owner model are provisional. Future customer-to-baker enrollment, switching, membership and account deletion behavior require an owner decision; business ownership and RLS remain authoritative regardless.

## Phase 4 boundary update

Availability uses pure date/status/repository contracts in features/availability/domain, session-scoped Riverpod coordination in application, RPC/error mapping in data, and keyboard-safe presentation. Features expose deliberate public UI entry points through availability.dart and discovery.dart; consumers do not import private data adapters. Shared-link destination routing is app composition. Settings/blocking lock the business and compare a revision; customer calendar reads return statuses only. Recent-history writes serialize on the caller profile and prune to 20 records. No private Realtime subscription is exposed; clients explicitly refresh and later confirmation must recheck authoritative state atomically. No Phase 5 order writes are implemented.
