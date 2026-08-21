# ENKE POS feature-architecture migration checklist

This is the practical continuation guide for the numbered feature migration.
It records what is complete, why each boundary exists, which checks are
required, and a prompt that can be reused for the next module.

## Current checkpoint

- Total planned modules: **28**, numbered `00` through `27`.
- Completed and evidence-recorded: **Modules 00–14**.
- Module 15 (Fulfillment) is the active branch in progress at the time this
  checklist was written.
- Remaining after Module 15: Modules `16–27`.
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

For each completed module, read its feature `README.md`, `FEATURE_SPEC.md`,
`TODO.md`, and `CHANGELOG.md`; those files contain the exact compatibility
paths, exclusions, behavior quirks, and later-module debt. Short SHAs above are
for navigation only; the architecture ledger contains full SHAs.

## Active and remaining modules

| # | Module | Ownership focus | Important boundary |
|---:|---|---|---|
| 15 | Fulfillment | Delivery-method values, context, repository/cache/provider. | Billing owns selection/charge/checkout/order behavior; Sync owns later scheduling. |
| 16 | Payments | Bank, payment-gateway, Pine Labs state/services. | Billing owns payment validation/totals; Printing owns output; backend credentials stay behind ports. |
| 17 | Purchasing | Purchase screens/provider/order/item/voucher values. | Inventory owns stock; Suppliers/Payments/Accounting remain public dependencies. |
| 18 | Sales | Sales, returns, edit-order, quotation/order/daily-close state. | Billing creates checkout inputs; Accounting/Printing/Reports consume projections. |
| 19 | Accounting | Transactions, invoices, receipts, vouchers, expenses, company accounts. | Do not absorb Sales checkout or Printing templates. |
| 20 | Reports | Report pages/provider/DTO projections. | Reports are read-only consumers; do not become owners of source state. |
| 21 | Printing and Documents | Printer settings, document configuration, print/PDF/barcode output. | Keep source business state in owning modules; preserve user-owned printer changes. |
| 22 | Communications | WhatsApp/settings/transaction-sharing adapter. | Keep messaging transport separate from Support and Sync. |
| 23 | Restaurant and KOT | Restaurant billing UI, tables/menu/order/KOT state. | Do not absorb generic Billing checkout or Fulfillment directory state. |
| 24 | Billing | Billing screens, cart, checkout, non-restaurant flows, cart/local compatibility. | Consume Products/Categories/Promotions/Fulfillment/Payments through roots; own checkout policy. |
| 25 | Kiosk | Kiosk screens and actions. | Consume public roots; keep legal/static pages and support boundaries explicit. |
| 26 | Dashboard | Dashboard pages/provider/models. | Read projections from owning features; do not duplicate repositories. |
| 27 | Offline and Realtime Sync | Sync/realtime providers, offline controls, scheduling/cursors. | Publish typed deltas or app adapters; never bypass strict feature cache/session authority. |

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

## Stop/merge instruction

If the goal is intentionally paused after a selected module, stop after its
separate evidence commit and leave later modules untouched. Merge or cherry-pick
the verified evidence commits into `gokul-dev` only when desired; do not merge an
implementation commit without its evidence/docs commit. This checklist itself
is intentionally written on `gokul-dev` so it remains available while numbered
branches are merged later.
