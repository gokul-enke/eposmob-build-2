# ENKE POS feature-architecture migration checklist

This is the practical continuation guide for the numbered feature migration.
It records what is complete, why each boundary exists, which checks are
required, and a prompt that can be reused for the next module.

## Current checkpoint

- Total planned modules: **28**, numbered `00` through `27`.
- Completed and evidence-recorded: **Modules 00–18**.
- Module 19 (Accounting) is the next branch to start from the verified Module
  18 evidence commit.
- Remaining after Module 18: Modules `19–27`.
- The canonical branch is `gokul-dev`; numbered migration branches are stacked
  work branches and can be merged/cherry-picked into `gokul-dev` later.
- The detailed branch/SHA ledger remains
  [`MIGRATION_LEDGER.md`](MIGRATION_LEDGER.md). The operational handoff remains
  [`FEATURE_ARCHITECTURE_HANDOFF.md`](FEATURE_ARCHITECTURE_HANDOFF.md).

## What “complete” means

Use every item below for every module. A module is not complete because files
were merely moved or because a focused widget test happens to pass.

- [ ] Audit ownership, consumers, backend/API assumptions, cache/session
      behavior, and explicit exclusions before editing.
- [ ] Define one public root: `lib/features/<feature>/<feature>.dart`.
- [ ] Keep domain values and ports free of Flutter, HTTP, Hive, preferences,
      `APPUrl`, and legacy provider imports.
- [ ] Put HTTP/preferences/Hive implementations in the feature data layer and
      inject them from app composition.
- [ ] Make app and feature consumers import the public root, not internals.
- [ ] Keep cross-feature workflows in `lib/app/...` adapters or typed ports;
      do not move another feature's behavior into the current module.
- [ ] Replace old implementations with deletions or export-only shims. A shim
      must not contain a second implementation.
- [ ] Scope state/cache by backend, tenant, principal, and store where the
      feature has persisted or asynchronous state.
- [ ] Invalidate generations on logout, API-key reset, store switch, clear, and
      dispose; add tests for late results and in-flight races.
- [ ] Preserve public names, runtime widget types, destination indices, payload
      shapes, parser quirks, and fallback behavior unless the module documents
      an intentional change.
- [ ] Add focused domain/data/application/presentation tests appropriate to the
      feature, including malformed responses, failures, cache behavior, and
      concurrency.
- [ ] Run formatting, scoped analysis, focused tests, architecture guard,
      `git diff --check`, and the complete `flutter test --no-pub` suite.
- [ ] Commit implementation first; record the exact implementation SHA and
      verification; then make a separate evidence/docs commit.
- [ ] Stage and audit untracked files as well as tracked diffs. Do not include
      generated plugin registrant churn from `flutter pub get` unless it is
      intentionally part of the module.
- [ ] Create the next branch only from the verified evidence commit.

## Completed modules

| # | Module and boundary | Branch / evidence | Verification snapshot |
|---:|---|---|---|
| 00 | Shared platform — Core/Shared networking, preferences, errors, localization, theme, and reusable UI primitives. | `codex/feature-architecture-00-shared-platform` / `2cdac4c1` | Full 896; guard 575 / 5 / 0. |
| 01 | App Shell — typed destinations, registry, responsive shell, store/session composition. | `codex/feature-architecture-01-app-shell` / `5887b929` | Full 926; guard 575 / 5 / 1. |
| 02 | Identity — authentication, tenant/session credentials, roles, login/profile bridges. | `codex/feature-architecture-02-identity-session` / `db29d57e` | Full 958; guard 574 / 5 / 2. |
| 03 | Organization — settings, branding, language/location/reference data, store context, company info. | `codex/feature-architecture-03-organization-settings` / `9f03b396` | Full 1,005; guard 568 / 5 / 3. |
| 04 | Subscription — status repository/provider, cache trust, access registry, lifecycle and UI bridge. | `codex/feature-architecture-04-subscription` / `939ae8e3` | Full 1,040; guard 568 / 4 / 4. |
| 05 | Support — FAQ/support presentation and strict request/parser/controller boundary. | `codex/feature-architecture-05-support` / `fa3a7fec` | Full 1,065; guard 564 / 4 / 5. |
| 06 | Notifications — presentation-only static prototype; no invented backend contract. | `codex/feature-architecture-06-notifications` / `66b4a673` | Full 1,069; guard 562 / 4 / 6. |
| 07 | Loyalty — standalone legacy loyalty-card prototype only; Customer profile loyalty remains Customer-owned. | `codex/feature-architecture-07-loyalty` / `b13268cb` | Full 1,073; guard 561 / 4 / 7. |
| 08 | Categories — catalog values, repository/cache/provider/forms; Product/Inventory/Billing rails excluded. | `codex/feature-architecture-08-categories` / `f06dbf59` | Full 1,128; guard 551 / 4 / 8. |
| 09 | Products — catalog, CRUD/search/barcode/property state and presentation; stock/cart/printing/tax transport excluded. | `codex/feature-architecture-09-products` / `8fe4eb82` | Full 1,212; guard 528 / 0 / 9. |
| 10 | Inventory — stock operations, stock cache/provider, adjustments and inventory UI; Purchasing/Billing/Sync scheduling excluded. | `codex/feature-architecture-10-inventory` / `68eb3031` | Full 1,237; guard 520 / 0 / 10. |
| 11 | Customers — customer directory/value/profile/cache/provider; Billing selection, vouchers, reports, printing, and sync scheduling excluded. | `codex/feature-architecture-11-customers` / `0a931a19` | Full 1,257; guard 505 / 0 / 11. |
| 12 | Suppliers — supplier directory/value/profile/cache/provider; Purchasing workflows, accounting, reports, printing, and sync excluded. | `codex/feature-architecture-12-suppliers` / `16566045` | Full 1,278; guard 494 / 0 / 12. |
| 13 | Sales Workforce — sales-executive directory/provider; Reports/Sales/Billing behavior remains with consumers. | `codex/feature-architecture-13-sales-workforce` / `13500223` | Full 1,288; guard 494 / 0 / 13. |
| 14 | Promotions — discount directory, validity, dynamic transport/cache; cart application remains Billing-owned. | `codex/feature-architecture-14-promotions` / `8ebd2b15` | Full 1,298; guard 494 / 0 / 14. |
| 15 | Fulfillment — delivery-method values, context, repository/cache/provider; Billing still owns selection/charge/checkout/order behavior. | `codex/feature-architecture-15-fulfillment` / `a20568ca` | Focused 82; full 1,305; guard 494 / 0 / 15; 2 export-only shims, 0 deletions. |
| 16 | Payments — bank and gateway directories plus Pine Labs terminal lifecycle; Billing owns checkout/payment validation and Accounting owns persisted outcomes. | `codex/feature-architecture-16-payments` / `888df54b` | Focused 9; selected downstream 26; architecture guard 13; full 1,314; guard 494 / 0 / 16; 7 export-only shims, 0 deletions. |
| 17 | Purchasing — purchase/order/item/voucher values, repository/controller state, app-owned complete workflow presentation, and reset/store lifecycle. | `codex/feature-architecture-17-purchasing` / `9fea3efc` | Focused 9 + composition 1; selected gate 32; architecture guard 13; full 1,324; guard 486 / 0 / 17; 2 export-only shims, 8 relocated screen implementations. |
| 18 | Sales — sales orders, returns, quotations, edit-order, confirmed orders, daily close, typed resources, and lifecycle-safe controller; complete screens/providers remain app-owned behind a bridge. | `codex/feature-architecture-18-sales` / `628d3e14` | Implementation `cf75f742`; combined Sales/composition/registry/App Destination gate 15; architecture guard 13; full 1,331; guard 486 / 0 / 18; 29 export-only shims. |

For each completed module, read its feature `README.md`, `FEATURE_SPEC.md`,
`TODO.md`, and `CHANGELOG.md`; those files contain the exact compatibility
paths, exclusions, behavior quirks, and later-module debt. Short SHAs above are
for navigation only; the architecture ledger contains full SHAs.

## Active and remaining modules

| # | Module | Ownership focus | Important boundary |
|---:|---|---|---|
| 19 | Accounting | Transactions, invoices, receipts, vouchers, expenses, company accounts. | Do not absorb Sales checkout or Printing templates. |
| 20 | Reports | Report pages/provider/DTO projections. | Reports are read-only consumers; do not become owners of source state. |
| 21 | Printing and Documents | Printer settings, document configuration, print/PDF/barcode output. | Keep source business state in owning modules; preserve user-owned printer changes. |
| 22 | Communications | WhatsApp/settings/transaction-sharing adapter. | Keep messaging transport separate from Support and Sync. |
| 23 | Restaurant and KOT | Restaurant billing UI, tables/menu/order/KOT state. | Do not absorb generic Billing checkout or Fulfillment directory state. |
| 24 | Billing | Billing screens, cart, checkout, non-restaurant flows, cart/local compatibility. | Consume Products/Categories/Promotions/Fulfillment/Payments through roots; own checkout policy. |
| 25 | Kiosk | Kiosk screens and actions. | Consume public roots; keep legal/static pages and support boundaries explicit. |
| 26 | Dashboard | Dashboard pages/provider/models. | Read projections from owning features; do not duplicate repositories. |
| 27 | Offline and Realtime Sync | Sync/realtime providers, offline controls, scheduling/cursors. | Publish typed deltas or app adapters; never bypass strict feature cache/session authority. |

## Recent completion details

### Module 15 — Fulfillment

- Base: Module 14 evidence `8ebd2b15`.
- Implementation: `b9b5f9f7`; evidence: `a20568ca`.
- Boundary: delivery-method directory values, dynamic context-bound transport,
  Preferences cache, provider state, reset/store/session lifecycle.
- Preserved elsewhere: Billing selection/fees/checkout/cart/order mutation,
  Sales/Printing projections, and Module 27 scheduling.
- Verification: focused Fulfillment/Billing gate 82/82; full Flutter suite
  1,305/1,305; guard 494 legacy / 0 exceptions / 15 strict; strict analyzer
  clean; architecture guard tests 13/13.
- Compatibility: `lib/models/delivery_method.dart` and
  `lib/providers/delivery_methods_provider.dart` remain export-only shims;
  no old path was deleted.

### Module 16 — Payments

- Base: Module 15 evidence `a20568ca`.
- Implementation: `34bcd1638fe2a85238f24732c0cce45146a9c806`; evidence:
  `888df54b44488bf8bb24439013e073f93e92afae`.
- Boundary: bank/payment-gateway directories, context-safe repository/cache
  state, Pine Labs MethodChannel lifecycle, and app-owned composition.
- Preserved elsewhere: Billing payment-method selection, validation, totals,
  checkout orchestration and terminal-result interpretation; Accounting
  persisted financial outcomes; Printing/Reports output projections.
- Verification: Payments focused suite 9/9; selected downstream Billing,
  session-reset, and widget gate 26/26; architecture guard test 13/13; full
  Flutter suite 1,314/1,314; guard 494 legacy / 0 exceptions / 16 strict;
  strict Payments analyzer clean; formatter and diff checks clean except
  expected line-ending notices.
- Compatibility: seven old payment paths remain implementation-free shims:
  `lib/config/pine_labs_config.dart`, `lib/models/bank.dart`,
  `lib/models/payment_gateway.dart`, `lib/providers/bank_provider.dart`,
  `lib/providers/payment_gateways_provider.dart`,
  `lib/providers/pine_labs_terminal_provider.dart`, and
  `lib/services/pine_labs_terminal_service.dart`. No payment path was deleted.
- Known debt: Pine Labs deployment identifiers, backend authorization/contract
  verification, downstream Printing/Reports consumers, Billing orchestration,
  and final shim removal remain with their scheduled owners.

### Module 17 — Purchasing

- Base: Module 16 evidence `888df54b`.
- Implementation: `5cf6f86a911ab9bc2fb7eb529ebeff5a30548582`; evidence:
  `9fea3efc`.
- Boundary: purchase/order/item/voucher values, dynamic repository transport,
  generation-safe controller/runtime, and public workflow page wrappers.
  Product, Suppliers, Inventory, and Payments are public dependencies; Billing
  checkout/cart, Accounting outcomes, Printing/Reports, and Sync scheduling
  remain outside Purchasing.
- Presentation: eight complete legacy purchase screens moved under
  `lib/app/purchasing/` behind `LegacyPurchasingPresentationBridge`; registry
  slots 19, 20, 26, 36, 81, 82, and 83 preserve historical runtime classes.
- Verification: Purchasing feature gate 9/9; composition 1/1; selected
  Purchasing/registry/model/widget gate 32/32; architecture guard test 13/13;
  full Flutter suite 1,324/1,324; guard 486 legacy / 0 exceptions / 17 strict;
  strict analyzer clean and 33 formatted files unchanged.
- Compatibility: exactly two export-only paths remain —
  `lib/providers/purchase_provider.dart` and
  `lib/screens/purchase/helpers/purchase_order_totals.dart`. The eight old
  screen implementations were relocated without old implementations left in
  place; purchase model files remain mixed-owner compatibility surfaces.
- Known debt: decompose mixed models/provider through typed Product, Supplier,
  Inventory, Billing, and Accounting ports; define backend tenant/supplier/
  store authorization, pagination, receiving/idempotency/reversal/atomicity,
  Accounting/Printing/Reports projections, and Module 27 scheduling before
  removing the two exports. Detailed behavior and path inventories are in
  `docs/features/purchasing/` and the ledger evidence record.

### Module 18 — Sales

- Base: Module 17 evidence `9fea3efc`.
- Implementation: `cf75f7428edde0f4c1529d342828eb6f7137801a`; evidence:
  `628d3e14` (`docs: record sales migration evidence`).
- Boundary: strict `features/sales` owns typed Sales context/query/resource
  values, dynamic endpoint resolution, injected repository transport,
  per-resource controller state, and typed destination wrappers. Billing owns
  checkout/cart policy; Accounting owns posted financial outcomes; Printing,
  Reports, Communications, and Sync remain later consumers/coordinators.
- Presentation: complete Sales, Sales Return, Edit Order, quotation, and
  daily-close implementations moved under `lib/app/` behind
  `LegacySalesPresentationBridge`; runtime classes and slots 2, 11, 49, 50,
  51, 54, 78, 79, 84, 87, 88, and 92 remain unchanged.
- Verification: combined Sales/controller/composition/registry/App
  Destination gate 15/15; architecture guard test 13/13; full Flutter suite
  1,331/1,331; guard 486 legacy / 0 exceptions / 18 strict; scoped strict/app
  analyzer clean; formatter and diff checks clean except expected line-ending
  notices.
- Compatibility: exactly 29 old Sales/Sales Return/Edit Order screen/widget
  and provider locations remain export-only shims. Behavior-complete sources
  live under `lib/app/`; mixed Sales models remain transitional.
- Known debt: backend authorization and tenant/store relationship scoping,
  order/return idempotency and reversal, quotation conversion atomicity,
  daily-close accounting outcomes, Billing cart ports, Accounting persistence,
  Printing/Reports projections, and Module 27 scheduling. Details and exact
  paths are in `docs/features/sales/` and the ledger evidence record.

## How to continue on a future module

1. Read this checklist, the latest handoff, and the latest ledger row.
2. Verify the exact evidence commit with `git show <sha>` and create a new
   worktree/branch from that commit. Do not branch from an implementation-only
   commit or from an uncommitted `gokul-dev` tree.
3. Inventory all legacy paths, imports, registrations, consumers, tests, URL
   getters, preferences/Hive keys, and backend routes before moving anything.
4. Write the ownership/exclusion decision down in the feature docs before
   implementing. If a contract is uncertain, preserve the current behavior and
   record the uncertainty as debt instead of inventing a backend/API.
5. Implement strict domain ports first, then data adapters, application state,
   app composition, and consumer rewrites. Keep compatibility shims thin.
6. Add characterization tests for success, malformed/non-200/network failure,
   cache hits/fallbacks, context changes, logout/store reset, and late async
   completions. Add widget/route tests only for UI the module actually owns.
7. Run the gates, inspect the staged diff including untracked files, commit the
   implementation, then update the ledger/handoff/docs in a separate evidence
   commit.
8. Report exact branch, base/evidence/implementation SHAs, changed/deleted/
   shim paths, focused/full counts, analyzer result, guard counts, known infos,
   and remaining debt. Only then start the next module.

## Reusable future-agent prompt

```text
Continue the ENKE POS feature-architecture migration with Module <NN> — <NAME>.

Work only in a new worktree/branch created from the verified evidence commit
<PREVIOUS_EVIDENCE_SHA>. Read docs/architecture/MODULE_MIGRATION_CHECKLIST.md,
docs/architecture/FEATURE_ARCHITECTURE_HANDOFF.md, the ledger, and the target
feature docs first.

Audit ownership, consumers, routes, preferences/Hive keys, async/session/store
behavior, and explicit exclusions before editing. Move only the target feature
behind lib/features/<feature>/<feature>.dart. Keep domain pure, inject data
adapters from lib/app, import other features only through public roots, and use
export-only shims or deletions for old paths. Preserve public names, payloads,
parser quirks, runtime destination slots, and UI behavior unless the docs record
an intentional change. Do not move Billing, Inventory, Purchasing, Sales,
Accounting, Printing, Reports, Restaurant, Kiosk, Dashboard, Communications,
or Sync behavior merely because it mentions this feature.

Add focused tests for contracts, failures, cache provenance, concurrency,
logout/store reset, and owned UI. Run:
  dart format ...
  dart analyze <strict/app/tests>
  flutter test --no-pub <focused tests>
  flutter test --no-pub --reporter compact
  dart run tool/architecture_guard.dart --base-ref <PREVIOUS_EVIDENCE_SHA>
  flutter test --no-pub test/architecture_guard_test.dart
  git diff --check

Commit production implementation separately from docs/evidence. Before
reporting completion, stage/audit untracked files, preserve generated plugin
registrant changes as unrelated when applicable, update the ledger/handoff and
feature docs with exact SHAs/counts, and create no later-module branch.
```

### Next concrete prompt (Module 19)

```text
Continue the ENKE POS feature-architecture migration in D:\Projects\ENKE\eposmob.

Work on exactly Module 19 — Accounting, in a new worktree/branch:
  codex/feature-architecture-19-accounting
Base it on the verified Module 18 evidence commit:
  628d3e14 (full SHA: resolve `git rev-parse
  codex/feature-architecture-18-sales`).
Verify that the base contains implementation cf75f742 and the Sales evidence
docs before editing.

Read the checklist, FEATURE_ARCHITECTURE_HANDOFF.md, MIGRATION_LEDGER.md,
FEATURE_ARCHITECTURE.md, the Module 18 Sales docs, and the Accounting source
tree first. Audit ownership, consumers, backend routes, parser/payload shapes,
tenant/company/store scoping, financial mutation/idempotency behavior,
cache/session/reset races, registry slots, and tests before changing code.

Accounting owns transactions, invoices, receipts, vouchers, expenses, and
company-account state. Consume Sales, Purchasing, Customers, Suppliers,
Payments, Promotions, Fulfillment, and Organization only through public roots
or app-owned bridges. Do not absorb Billing cart/checkout policy, Printing
output, Reports projections, Communications sharing, Restaurant/KOT workflow,
or Sync scheduling. Preserve runtime widget names and numeric destination
slots. Add strict seams only where an actual contract exists; do not invent a
backend API.

Run focused/downstream tests, strict analyzer, formatter, architecture guard
against 628d3e14, diff check, and the complete `flutter test --no-pub` suite.
Create one implementation commit and one evidence/docs commit. Update the
ledger, handoff, and docs/features/accounting files with exact SHAs/counts and
leave no migration-owned changes uncommitted. Do not start Module 20.
```

## Stop/merge instruction

If the goal is intentionally paused after a selected module, stop after its
separate evidence commit and leave later modules untouched. Merge or cherry-pick
the verified evidence commits into `gokul-dev` only when desired; do not merge an
implementation commit without its evidence/docs commit. This checklist itself
is intentionally written on `gokul-dev` so it remains available while numbered
branches are merged later.
