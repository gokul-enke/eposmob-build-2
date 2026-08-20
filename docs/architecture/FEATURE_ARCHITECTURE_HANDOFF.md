# Feature architecture migration handoff

> Stop point: complete and verify Module 09 (Products), write this handoff, and
> stop. Modules 10–27 are intentionally left for a future task.

This document is the operational handoff for continuing the POS Flutter feature
architecture migration. The authoritative module order and commit evidence live
in [MIGRATION_LEDGER.md](MIGRATION_LEDGER.md); this file explains how to use that
evidence, what Modules 00–09 established, and how to prompt and supervise a
future coding agent safely.

## 1. Snapshot at handoff

The branch chain is linear. Every module has its own branch, created from the
verified evidence commit of the preceding module. Never combine two numbered
modules in one branch.

There are 28 modules in total (`00`–`27`). At this stop point, Modules `00`–`09`
are complete (10 modules) and Modules `10`–`27` remain (18 modules). No Module 10
branch or implementation has been started.

| # | Module | Branch | Implementation/evidence tip | Full Flutter suite | Guard after module |
|---:|---|---|---|---:|---|
| 00 | Shared platform | `codex/feature-architecture-00-shared-platform` | evidence `2cdac4c1df56aa5cb9221f7d6618ac40cd36dbc3` | 896 | 575 legacy / 5 exceptions / 0 strict |
| 01 | App shell | `codex/feature-architecture-01-app-shell` | evidence `5887b929abbcd1d475d774a750495f01dfb9c7bd` | 926 | 575 / 5 / 1 |
| 02 | Identity and session | `codex/feature-architecture-02-identity-session` | evidence `db29d57ea710c59e99e7012ab02419e14e10f66f` | 958 | 574 / 5 / 2 |
| 03 | Organization and settings | `codex/feature-architecture-03-organization-settings` | evidence `9f03b396d16fa27edd2624951293439d99943e15` | 1,005 | 568 / 5 / 3 |
| 04 | Subscription | `codex/feature-architecture-04-subscription` | evidence `939ae8e33eaa3a3554139e8d18c66b1863885698` | 1,040 | 568 / 4 / 4 |
| 05 | Support | `codex/feature-architecture-05-support` | evidence `fa3a7fec529d84a81ed2110056703e209459ef64` | 1,065 | 564 / 4 / 5 |
| 06 | Notifications | `codex/feature-architecture-06-notifications` | evidence `66b4a673f5e3941e0ffec35f4ce0db0a54905419` | 1,069 | 562 / 4 / 6 |
| 07 | Loyalty | `codex/feature-architecture-07-loyalty` | implementation `e3532292276dd9314332658ec0c463ae0787c7f2`; evidence `b13268cb924726e0d233488dd2b9ab0fea538bba` | 1,073 | 561 / 4 / 7 |
| 08 | Categories | `codex/feature-architecture-08-categories` | implementation `acc385d838bb22506d84a2de1fd51d323e28cd7b`; evidence `f06dbf591103c00ea1698cb02212785e45737023` | 1,128 | 551 / 4 / 8 |
| 09 | Products | `codex/feature-architecture-09-products` | implementation `1469e802211a0c831470e1ec03841e3b3a257172`; evidence: this documentation commit / completed branch `HEAD` | 1,212 | 528 / 0 / 9 |

Do not infer a module's base from its implementation commit. Use the evidence
tip shown here and in the ledger; evidence commits contain the finalized ledger
and verification record for the next branch.

## 2. What “complete” means

A feature is not complete merely because files were moved. Every numbered
module must satisfy all of these checks:

- [ ] The ownership boundary and explicit exclusions were audited before edits.
- [ ] The feature has one public root: `lib/features/<feature>/<feature>.dart`.
- [ ] Domain code is pure Dart and owns no Flutter/HTTP/Hive/preferences/app
      dependency.
- [ ] Infrastructure implements feature-owned ports and is injected by app
      composition.
- [ ] App and other features import only the public feature root.
- [ ] Earlier strict features do not import later feature implementations.
- [ ] Cross-feature workflows use app-owned adapters/bridges.
- [ ] Legacy paths are either deleted or implementation-free exports; no second
      implementation remains in a shim.
- [ ] Cache/session/store/tenant state is provenance-scoped and stale async work
      cannot restore old state after reset.
- [ ] Runtime widget names and immutable App Shell destination slots remain
      compatible unless a separately approved product change says otherwise.
- [ ] Exact transport/parser/cache/UI behavior is characterized with focused
      tests, including failure and concurrency paths.
- [ ] Formatting, scoped analysis, focused tests, architecture guard, staged
      diff audit, and the complete Flutter test suite pass.
- [ ] The implementation commit is created, then the ledger/docs evidence is
      finalized in a separate evidence commit.
- [ ] No uncommitted migration-owned changes remain before the next numbered
      branch is created; documented unrelated user-owned files are preserved
      and explicitly excluded.

## 3. Completed module details

### Module 00 — Shared platform

Established Core/Shared primitives for networking, preferences, errors,
localization, theme, and reusable presentation. It moved reusable legacy
components behind stable public paths while keeping export-only compatibility
for widespread consumers. Feature-specific behavior must not be added to
Core/Shared merely to avoid a dependency decision.

Primary docs: `docs/features/shared_platform/`.

### Module 01 — App shell

Established typed `AppDestination`, App Shell state/presentation, responsive
composition, store switcher shell, and the app-owned legacy numeric destination
registry. Numeric indices remain an adapter detail. Features publish screens;
the app maps them to destinations. Features must not import App Shell internals
or mutate a sidebar index directly.

Primary docs: `docs/features/app_shell/`.

### Module 02 — Identity and session

Established authentication, tenant discovery, roles/capabilities, session
state, profile projection, runtime bridges, and app-owned login/store/session
handoffs. Later modules consume the Identity root or receive a narrow session
reader; they do not read authentication providers or preferences directly.

Primary docs: `docs/features/identity/`.

### Module 03 — Organization and settings

Established organization/store value models, app/general/admin settings,
branding, language/translation, geographic reference data, master-data catalog,
company information presentation, and app-owned mixed settings adapters. The
cross-feature Settings hub and store bootstrap remain app coordination, not
Organization domain behavior.

Primary docs: `docs/features/organization/`.

### Module 04 — Subscription

Established subscription status/domain ports, trusted refresh/cache semantics,
process-wide access gating, lifecycle refresh, UI runtime, Organization
fallback adapter, login handoff, and logout reset. A stale in-flight refresh is
generation-guarded and cannot re-enable access after logout.

Primary docs: `docs/features/subscription/`.

### Module 05 — Support

Established FAQ domain/repository/controller/presentation and the app-owned
Identity-token handoff. It removed four dead legacy paths. The deployed Flutter
FAQ route and bundled backend route still disagree; that is documented debt,
not permission to silently invent an endpoint.

Primary docs: `docs/features/support/`.

### Module 06 — Notifications

Established a deliberately presentation-only feature for the existing static,
currently unreachable five-card prototype. It did not invent a feed API,
provider, read/unread state, or push contract. Never expose the fabricated feed
as real notifications until its P0 product/backend work is complete.

Primary docs: `docs/features/notifications/`.

### Module 07 — Loyalty

Established a deliberately presentation-only boundary for the standalone
slot-6 static form/list prototype. Customer profile loyalty data, earning,
redemption, receipts, and backend loyalty persistence remain with Customers,
Sales, Printing, and backend work. Do not treat the prototype as a working
loyalty system.

Primary docs: `docs/features/loyalty/`.

### Module 08 — Categories

Established the category catalog, three list scopes, tenant/store-aware HTTP
and Hive provenance, scoped loading/errors, CRUD/detail/reference state, strict
management/quick-create UI, Product-media/form app adapters, and stable Hive IDs
8/9. It fixed stale-context and cache-clear races. Bundled-backend purchasable
filter, detail route, authorization, relationship scoping, and media persistence
remain explicit debt.

Primary docs: `docs/features/categories/`.

### Module 09 — Products

Module 09 owns Product catalog/read models, search, variants, properties, sale
units, Product media projections, CRUD, barcode generation/selection, read-only
stock projections, tenant/store cache/checkpoint semantics, and Product
management/editor/detail presentation. It does not claim a Product media
request route. Inventory stock operations, Billing cart/reservations/effective
pricing, Printing output, Purchasing, Reports, Kiosk, and Sync scheduling
remain later modules and cross through public ports or app adapters.

The implemented authority split is intentional:

- `ProductCatalogController.products` is the canonical full/sellable catalog.
  Only that state writes Product Hive/checkpoints or publishes a complete
  catalog replacement. Filtered management results live in the ephemeral
  `viewProducts` state loaded by `ensureView`/`refreshView` and never persist or
  replace downstream catalogs.
- In the configured app, `ProductCache` is the sole durable Product catalog
  writer. App composition implements both the complete-catalog sink and the
  typed mutation upsert/remove sink as memory-only, reservation-safe
  `LocalProductProvider` projections. An accepted mutation before catalog
  hydration cannot create a one-row cache.
- Configured startup disables unscoped Product-Hive hydration and guards legacy
  Product-box writes both when queued and when executed. Cache clearing resets
  strict rows/metadata before the memory projection while preserving Billing
  cart/saved-order persistence.
- A provenance-valid cache is projected into Billing before transport. An
  offline failure keeps the cached baseline visible and truthful, and a later
  ordinary ensure retries the network. Checkpoint invalidation preserves rows,
  clears only the cursor, and forces a full non-delta reload until accepted.
- Strict rows are deeply detached before Billing projection, including nested
  stock and variant collections. Configured manual and realtime sync both route
  through strict catalog refresh, so Billing reservations and Sync callbacks
  cannot mutate strict controller/cache objects or become alternate writers.
- Configured `LocalProductProvider` catalog fetches, editor-facing
  `GridSelectionProvider` barcode/create calls, `ProductProvider`
  property/edit calls, and the three app-owned complete editors delegate those
  Product operations to `ProductRuntime`. Their direct legacy callbacks are
  isolated/pre-composition fallbacks only. Later-module Grid catalog/filter
  reads still using direct HTTP remain explicit consumer-migration debt and do
  not own Product Hive/checkpoints.
- `lib/app/products/legacy_complete_product_editor_authority.dart` preserves
  complete legacy payload/response behavior while applying strict context and
  stale-result rules. Server edit snapshots preserve meaningful empty stock,
  attachment, property, variant, and sale-unit collections. Typed stale results
  are silently discarded, and Billing-owned cart/saved-order price
  reconciliation runs only after an accepted, current edit.
- The three behavior-complete editor sources and their presentation bridge stay
  app-owned until Inventory, Printing, and Billing publish the later typed
  ports. Product presentation imports none of those later implementations.
- Module 09 removed the global invalid-certificate override, wraps Flutter
  `debugPrint` with `product_log_redactor.dart` before `runApp`, and continuously
  guards Product sources against raw credential/header/response-body
  diagnostics across `debugPrint`, `print`, and `log`.

The compatibility inventory is exact: eight implementation-free export shims,
one mixed `lib/models/local_models.dart` facade, 23 deleted obsolete paths, and
eight excluded similarly named screens (seven Inventory stock paths and the
Printing confirmation modal). The path-by-path inventories are recorded in the
Module 09 ledger evidence record and `docs/features/products/TODO.md`.
Registry slots 14, 17, 28, 35, and 83 retain their historical runtime widget
classes through the Product public root.

Implementation commit `1469e802211a0c831470e1ec03841e3b3a257172`
contains 118 audited paths with 23,358 insertions and 23,175 deletions. The guard
passes at 528 legacy paths / 0 cross-feature exceptions / 9 strict features; the
scoped analyzer reports no issues; formatter checks 90 changed Dart files with
0 changes; the expanded migration/downstream gate passes 198/198; and the full
Flutter suite passes 1,212/1,212. This file and the ledger form the separate
documentation evidence commit; resolve its literal SHA with `git rev-parse HEAD`
on the completed branch.

Primary docs: `docs/features/products/`.

## 4. Remaining ordered modules

Continue in exactly this order unless the ledger is deliberately amended and
the dependency reasoning is documented first.

| # | Module | Primary ownership | Critical seam / warning |
|---:|---|---|---|
| 10 | Inventory | stock provider/models; add/adjust/move/withdraw/detail stock UI | Consume Product read projections; do not move Product catalog/cart policy into Inventory. |
| 11 | Customers | existing Customers feature, customer list/forms/profile/provider/API/cache | Preserve the existing reference feature contract; fix tenant/store/user cache provenance and profile boundaries. |
| 12 | Suppliers | supplier list/profile/provider/models | Purchasing consumes supplier contracts; vouchers remain Accounting. |
| 13 | Sales workforce | sales-executive provider/models | Organization/Identity consume narrow actor/employee projections; avoid cycles. |
| 14 | Promotions | discount provider/models | Product stores base configuration; Billing applies effective cart discounts. |
| 15 | Fulfillment | delivery method provider/models | Sales/Billing consume public options; keep checkout orchestration outside. |
| 16 | Payments | bank/gateway/Pine Labs providers/models/services | Accounting records outcomes; Billing coordinates checkout; never expose secrets in logs. |
| 17 | Purchasing | purchase screens/provider/order/item/voucher models | Consume Product/Supplier/Inventory roots; stock application crosses an app workflow. |
| 18 | Sales | sales, returns, quotations, edit order, daily close | Publish order contracts; Billing creates carts, Accounting owns financial records. |
| 19 | Accounting | transactions, invoice, receipt, expense, voucher, company accounts | Split internally by accounting concepts; customer/supplier vouchers belong here. |
| 20 | Reports | report screens/provider/DTOs | Read projections only; do not make Reports own source feature models/state. |
| 21 | Printing and documents | printer settings, layouts, PDF/barcode/document rendering/output | Consume public snapshots; keep devices/rendering outside Products/Billing/Sales. |
| 22 | Communications | WhatsApp provider/controller/settings/share adapters | Message transport and permissions; consume Accounting/Sales document projections. |
| 23 | Restaurant and KOT | restaurant/KOT/table/menu/order workflow | Publish restaurant order context to Billing; do not absorb general Billing. |
| 24 | Billing | cart, checkout, saved orders, non-restaurant billing, remaining `LocalProductProvider` mix | Largest decomposition tail; consume Products/Inventory/Customers/Promotions/Payments. |
| 25 | Kiosk | Kiosk screens and Kiosk-specific product/cart presentation | Consume public catalog/Billing contracts; keep legal/static Kiosk pages here. |
| 26 | Dashboard | dashboard screen/provider/models | Read projections from sources; no ownership of operational state. |
| 27 | Offline and realtime sync | realtime/offline transport, cursors, scheduling, settings/control UI | Coordinate feature-owned sync sinks; never make features import Sync. |

## 5. Standard branch workflow

Use PowerShell commands from the repository root.

### 5.1 Start from verified evidence

```powershell
git status --short
git switch --detach <previous-module-evidence-sha>
git switch -c codex/feature-architecture-XX-feature-name
git rev-parse HEAD
```

The first command must show no migration-owned changes. A documented unrelated
user-owned file may remain only if it is preserved and excluded from every
stage/commit. Never use `git reset --hard` or overwrite a dirty user worktree.

### 5.2 Audit before editing

- Enumerate every candidate file and every importer with `rg --files` and `rg`.
- Inspect runtime routes, provider registration, session/store reset, Hive type
  IDs/box names, preferences, request contracts, and backend routes.
- Run focused baseline tests and record their exact count.
- Assign each neighboring behavior to its scheduled owner. A file location is
  evidence, not proof of ownership.
- Decide which legacy paths can be deleted and which require export-only shims.
- Write/update `README.md`, `FEATURE_SPEC.md`, `TODO.md`, and `CHANGELOG.md` for
  the module.

### 5.3 Implement in safe slices

1. Pure domain values and ports.
2. Data adapters and exact parser/transport/cache tests.
3. Application state with concurrency/reset tests.
4. App composition and cross-feature adapters.
5. Presentation move and widget tests.
6. Consumer rewrites to the public root.
7. Legacy deletion/shims and architecture inventories.

Do not add the feature to `strict_features.txt` until the strict boundary and
all required root rewrites pass. `cross_feature_exceptions.txt` may only shrink.

### 5.4 Verification commands

Adapt focused paths to the module, then run all gates:

```powershell
dart format --output=none --set-exit-if-changed <changed-dart-paths>
dart analyze lib/features/<feature> lib/app/<feature> test/features/<feature> test/app/<feature>
flutter test --no-pub test/features/<feature> test/app/<feature>
flutter test --no-pub test/architecture_guard_test.dart
dart run tool/architecture_guard.dart --base-ref <previous-evidence-sha>
git diff --check
git status --short
```

Also run downstream regression tests discovered during the importer audit. Then:

```powershell
flutter test --no-pub --reporter compact
```

Record exact passed counts. Never write “all tests pass” without the command,
count, and commit being evidenced.

### 5.5 Commit and evidence

1. Stage only audited module paths.
2. Review `git diff --cached --name-status` and `--stat`.
3. Commit implementation: `refactor: migrate <feature> to feature architecture`.
4. Run guard/full suite against that commit.
5. Fill the ledger and feature docs with actual SHA/counts/findings.
6. Commit evidence: `docs: record <feature> migration evidence`.
7. Confirm no migration-owned path remains uncommitted; preserve and report any
   explicitly documented unrelated user-owned path.
8. Create the next branch from the evidence commit, not the implementation
   commit.

## 6. Copy-paste prompt for a future agent

For the immediate next task use Module 10 / Inventory and resolve the exact
completed Module 09 evidence tip before creating the branch.

```text
Continue the feature-architecture migration in D:\Projects\ENKE\eposmob.

Work on exactly one module only:
- Module: [10 — Inventory]
- New branch: [codex/feature-architecture-10-inventory]
- Base: the verified evidence tip of
  `codex/feature-architecture-09-products` (`git rev-parse
  codex/feature-architecture-09-products`); verify it contains implementation
  `1469e802211a0c831470e1ec03841e3b3a257172` and the Module 09 evidence docs.

Read these files first:
- docs/architecture/MIGRATION_LEDGER.md
- docs/architecture/FEATURE_ARCHITECTURE_HANDOFF.md
- docs/architecture/FEATURE_ARCHITECTURE.md
- tool/architecture/strict_features.txt
- tool/architecture/legacy_paths.txt
- tool/architecture/cross_feature_exceptions.txt
- docs/features/[previous feature]/README.md, FEATURE_SPEC.md, TODO.md, CHANGELOG.md

Requirements:
1. Confirm there are no uncommitted migration-owned changes and create only the
   requested branch from the exact evidence SHA. Preserve documented unrelated
   user-owned files; do not reset, discard, overwrite, or stage them.
2. Before editing, perform a read-only ownership/behavior/backend/import/cache/
   session/navigation/test audit. Report owned files, exclusions, public ports,
   cycles, compatibility shims, deletion candidates, guard target, and focused
   regression matrix.
3. Implement one strict public feature root with pure domain, injected data
   adapters, application state, app-owned cross-feature adapters, and strict
   presentation. Small features may omit unused layers; do not invent contracts.
4. Other features and app code may import only the public feature root. Earlier
   strict features must never import this module's internals. This module must
   not import later feature implementations.
5. Preserve behavior unless a correctness/security fix is explicitly audited,
   tested, documented, and listed in the changelog. Preserve Hive type IDs/box
   formats, preference/request contracts, runtime widget names, and App Shell
   destination slots unless an approved contract change says otherwise.
6. Make caches/requests context-safe across backend, tenant, company, store,
   user/session, reset, and stale async completion. Never log credentials. Keep
   TLS certificate validation enabled.
7. Delete obsolete zero-consumer legacy paths. Keep only implementation-free
   export shims or documented mixed-owner facades, with removal owners in TODO.
8. Add/update docs/features/[feature]/{README,FEATURE_SPEC,TODO,CHANGELOG}.md and
   the migration ledger. Add focused domain/data/application/presentation/app/
   lifecycle/concurrency tests proportional to risk.
9. Run formatter, scoped analyzer, focused and downstream tests, architecture
   guard/tests, git diff check, and the complete `flutter test --no-pub` suite.
   Record exact commands and counts.
10. Audit the staged diff, create an implementation commit, then a separate
    evidence commit. Leave no migration-owned change uncommitted and report any
    preserved unrelated user file. Do not start the next module.
11. Preserve the Product handoff contracts: import only
    `features/products/products.dart`; never write the Product Hive box or
    cursor outside Product application/data; use Product read projections for
    stock; remove a Product shim only after every consumer has moved; and do not
    move the mixed `LocalProductProvider`/`local_models.dart` state wholesale
    into one feature.

For Module 10 specifically: Inventory owns stock mutation, adjustment,
movement, withdrawal, operational availability, and stock screens/provider/
models. Products keeps only immutable read projections embedded in catalog
responses. Inventory consumes Products through its public root and must not pull
Product catalog CRUD, Billing cart/reservation policy, Purchasing workflows,
Printing, Reports, or Sync orchestration into its strict boundary.
```

The prompt deliberately starts Module 10 only. For each later task, advance one
row at a time through Modules 11–27 and replace the module/branch/base values
with the immediately preceding evidence commit. Across that sequence:

- Module 10 takes the seven stock exclusions, but consumes Product identity and
  read-only stock projections from the Product root.
- Modules 11–20 consume Product contracts where needed without adopting its
  cache, editor, mutation, or synchronization authority.
- Module 21 replaces barcode render/device/output bridge behavior, not Product
  barcode generation or selection.
- Module 24 decomposes Billing/cart/reservation state from
  `LocalProductProvider` and `local_models.dart` and replaces the temporary
  Billing helper exports used by the app-owned complete editors.
- Module 25 moves Kiosk consumers to public Product search/index contracts.
- Module 27 owns scheduling/realtime/offline transport and consumes Product
  sinks; Products must not import Sync.
- At every module, delete only zero-consumer Product shims, preserve the full
  app-owned editor behavior until equivalent typed ports exist, and rerun the
  Product regression seams affected by the consumer rewrite.

## 7. Handoff acceptance checklist

Before trusting this stop point, verify:

- [x] Module 09 has an implementation commit and a separate documentation
      evidence commit recorded in the ledger.
- [x] The Module 09 row above contains its implementation SHA and final
      test/guard counts; the evidence SHA is the completed branch `HEAD`.
- [x] `products` is strict and cross-feature exceptions are zero.
- [x] The complete Flutter suite passes at the Product implementation commit.
- [x] Product docs mark only finished Module 09 tasks complete and retain real
      backend/security/later-module debt.
- [x] Evidence records the exact 8 shims, 23 deletions, 1 mixed facade, and 8
      exclusions without treating an app compatibility editor as strict code.
- [x] No migration-owned path remains uncommitted; the unrelated user-owned
      `docs/ENKE_PROJECT_HUB_COMPLETE_HANDOFF.md` is preserved and excluded.
- [x] No Module 10 branch or implementation was started.
- [x] The next agent is told to resolve and branch from the Module 09 evidence
      tip.

If any box is unchecked, the migration has not reached its requested stop
condition yet.
