# ENKE POS feature-architecture migration checklist

This is the practical continuation guide for the numbered feature migration.
It records what is complete, why each boundary exists, which checks are
required, and a prompt that can be reused for the next module.

## Current checkpoint

- Total planned modules: **28**, numbered `00` through `27`.
- Completed and evidence-recorded: **Modules 00–27**.
- Module 20 (Reports) is complete on
  `codex/feature-architecture-20-reports`: implementation
  `fd6c33003ad931c222abcc0b177e079b69b300c9`, evidence
  `e529344305f5928c759fff3e21ebec54c9172cd7`.
- Module 21 (Printing and Documents) is complete on
  `codex/feature-architecture-21-printing`: implementation `12504f1e`,
  evidence `d63de987`.
- Module 22 (Communications) is complete on
  `codex/feature-architecture-22-communications`: implementation `4b9f960d`,
  evidence `6f6022220cb25fd3e40c7b7784d7bf9d2706a1b4`.
- Module 23 (Restaurant and KOT) is complete on
  `codex/feature-architecture-23-restaurant`: implementation `45c519ed`,
  evidence `895ec417`.
- Module 24 (Billing) is complete on
  `codex/feature-architecture-24-billing`: implementation
  `7e11d20e2c0b368ff0866f630c307b805fe14a5c`, evidence
  `e99f588683464858be3804af9a8dde40be644d7e`.
- Module 25 (Kiosk) is complete on
  `codex/feature-architecture-25-kiosk`: implementation
  `c0b2f2af8c7579e486228dc6f6efe0ac1b3e6740`, evidence
  `fbf5d46fe1dfdadf989a78dc61c3670937f94f78`.
- Module 26 (Dashboard) is complete on
  `codex/feature-architecture-26-dashboard`: implementation
  `6a4b514ce8653da5649ed3b96ce8f93c395edabc`, evidence
  `f35fc5c6f4f34301e3712f60c880d19ad572cc15`.
- Module 27 (Offline and realtime sync) is complete on
  `codex/feature-architecture-27-sync`: implementation
  `fe3fb38fa522125c1df152a3ca8e3bb558040ebf`, evidence
  `3ff4257dc3232134a23949672e8a374c31fdcea9`.
- Remaining numbered modules: **none**. The migration contains exactly 28
  modules, `00` through `27`; future work must use the owner TODO/debt paths,
  not a new Module 28.
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
| 19 | Accounting — transaction/document values, invoices, receipts, vouchers, expenses, company accounts, dynamic context, controller lifecycle, and app-owned complete presentation. | `codex/feature-architecture-19-accounting` / `fdd2a382` | Base `628d3e14`; implementation `09c77dca`; evidence `fdd2a382`; Accounting/composition/registry gate 15; widget smoke 1; architecture guard 14; full 1,338; guard 486 / 0 / 19; 51 export-only shims. |
| 20 | Reports — read-only report context/query/pagination, DTO projections, per-kind controller/runtime, and thirteen destination wrappers; source-feature state and Printing output remain excluded. | `codex/feature-architecture-20-reports` / `e5293443` | Base `fdd2a382`; implementation `fd6c3300`; evidence `e5293443`; Reports strict gate 8; composition 1; architecture guard 13; full 1,346; guard 486 / 0 / 20; 22 export-only shims and 6 Printing-owned printer exclusions. |
| 21 | Printing and Documents — typed device/document/output values, barcode-layout settings, PrinterSettings runtime bridge, and behavior-compatible print/PDF/thermal/barcode/document/report-printer implementations. | `codex/feature-architecture-21-printing` / `d63de987` | Base `e5293443`; implementation `12504f1e`; evidence `d63de987`; Printing/document gate 138; architecture guard test 13; full 1,350; guard 486 / 0 / 21; exactly 99 export-only shims and 9 retained demo assets. |
| 22 | Communications — typed WhatsApp gateway/provider/runtime, app-owned local plugin adapter, settings destination, and transaction delivery seam. | `codex/feature-architecture-22-communications` / `6f602222` | Base `d63de987`; implementation `4b9f960d`; evidence `6f602222`; strict/app gate 7; registry/App Destination/PDF gate 13; full 1,357; guard 486 / 0 / 22; exactly 3 export-only shims and no deleted legacy paths. |
| 23 | Restaurant and KOT — table/menu/order-selection values, table transport/provider state, typed Restaurant order context, and app-owned complete Restaurant/Kitchen/modifier workflows. | `codex/feature-architecture-23-restaurant` / `895ec417` | Base `6f602222`; implementation `45c519ed`; evidence `895ec417`; focused Restaurant/registry/app-smoke gate 13; full 1,362; guard 486 / 0 / 23; exactly 9 export-only shims and no deleted legacy paths. |
| 24 | Billing — strict cart/context/totals/checkout contracts and runtime shells, with the complete 93-file Billing implementation relocated behind an app-owned compatibility bridge. | `codex/feature-architecture-24-billing` / `e99f5886` | Base `895ec417`; implementation `7e11d20e`; evidence `e99f5886`; strict contract 4; Billing compatibility 108; Product downstream 30; registry/guard 21; full 1,367; guard 486 / 0 / 24; app legacy tree and typed-port debt recorded in Billing docs. |
| 25 | Kiosk — strict runtime-backed page wrappers for the Kiosk landing/order/checkout/legal surfaces, with the complete seven-file implementation relocated behind an app-owned bridge. | `codex/feature-architecture-25-kiosk` / `fbf5d46f` | Base `e99f5886`; implementation `c0b2f2af`; evidence `fbf5d46f`; Kiosk/composition contract 3; combined Kiosk/widget/guard gate 17; full 1,370; guard 479 / 0 / 25; zero shims, seven obsolete paths removed, no new navigation/backend contract. |
| 26 | Dashboard — strict public destination/DTO/runtime boundary with app-owned role-specific screens and provider bridge; source analytics and Sync remain outside. | `codex/feature-architecture-26-dashboard` / `f35fc5c6` | Base `fbf5d46f`; implementation `6a4b514c`; evidence `f35fc5c6`; Dashboard strict/composition 4; registry/App Destination 8; full 1,374; guard 471 / 0 / 26; 3 export-only shims, 8 legacy screen/widget relocations, slot 1 preserved. |
| 27 | Offline and Realtime Sync — strict session/change/status, transport, cursor, socket, lifecycle, manual-sync, and app projection boundary; source-feature caches and CRUD remain with their owners. | `codex/feature-architecture-27-sync` / `3ff4257d` | Base `f35fc5c6`; implementation `fe3fb38f`; evidence `3ff4257d`; focused Sync 17; registry/widget 9; Product source-compatibility 22; full 1,379; guard 471 / 0 / 27; six export-only shims, no deleted paths. |

For each completed module, read its feature `README.md`, `FEATURE_SPEC.md`,
`TODO.md`, and `CHANGELOG.md`; those files contain the exact compatibility
paths, exclusions, behavior quirks, and later-module debt. Short SHAs above are
for navigation only; the architecture ledger contains full SHAs.

## Active and remaining modules

| # | Module | Ownership focus | Important boundary |
|---:|---|---|---|
| 20 | Reports | Report pages/provider/DTO projections. | Complete; Reports are read-only consumers and do not own source state. |
| 21 | Printing and Documents | Printer settings, document configuration, print/PDF/barcode output. | Complete; output behavior is app-owned behind the strict Printing root; source business state remains with its owning modules. |
| 22 | Communications | WhatsApp/settings/transaction-sharing adapter. | Complete; keep messaging transport separate from Support, Printing, and Sync; no unverified backend API was invented. |
| 23 | Restaurant and KOT | Restaurant billing UI, tables/menu/order/KOT state. | Complete; Billing consumes the typed Restaurant order-context seam; generic checkout/cart remains Billing-owned. |
| 24 | Billing | Billing screens, cart, checkout, non-restaurant flows, cart/local compatibility. | Complete; strict contracts and app-owned compatibility bridge are recorded in the Module 24 evidence. |
| 25 | Kiosk | Kiosk screens and actions. | Complete; app-owned legacy behavior is behind strict wrappers, with no new destination or backend contract. |
| 26 | Dashboard | Dashboard pages/provider/models. | Complete; read projections remain app-owned until source features publish typed contracts. |
| 27 | Offline and Realtime Sync | Sync/realtime providers, offline controls, scheduling/cursors. | Complete; strict Sync owns scheduling/transport/cursors, while app adapters project into Product/Customers/Inventory/Sales and six compatibility shims remain until typed source commands replace them. |

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

### Module 19 — Accounting

- Base: Module 18 evidence `628d3e14`.
- Implementation: `09c77dca1e1141e0b4f1ce0d3a4b399362e4f9c2`; evidence:
  `fdd2a3821abb1897d99d98e6adb25f76cc590ea5` (`docs: record accounting
  migration evidence`).
- Boundary: strict Accounting owns typed transaction/document/account-book
  values, dynamic saved-`app_url` transport, tenant/company/store context,
  generation-safe controller state, and stable destination wrappers. Billing,
  Sales, Purchasing, Customers, Suppliers, Reports, Printing,
  Communications, Restaurant, and Sync behavior stays outside the boundary.
- Presentation: complete transaction/invoice/receipt/expense/voucher/company-
  account/location-management implementations live under
  `lib/app/accounting/` behind the Accounting bridge. Six providers and 45
  screen/widget paths remain export-only shims; the invoice PDF remains
  Printing-owned.
- Verification: Accounting/controller/HTTP/composition/registry/App
  Destination gate 15/15; widget smoke 1/1; architecture guard test 14/14;
  full Flutter suite 1,338/1,338; guard 486 legacy / 0 exceptions / 19
  strict; strict analyzer clean; formatter and diff checks clean except
  expected line-ending notices.
- Known debt: backend authorization/tenant relationship/store scoping,
  posting atomicity, idempotency/reversal, deployed endpoint verification,
  Reports/Printing projections, Communications delivery, Sync scheduling, and
  final removal of the 51 compatibility exports. Full details are in
  `docs/features/accounting/` and the ledger evidence record.

### Module 20 — Reports

- Base: Module 19 Accounting evidence
  `fdd2a3821abb1897d99d98e6adb25f76cc590ea5`.
- Implementation: `fd6c33003ad931c222abcc0b177e079b69b300c9`; evidence:
  `e529344305f5928c759fff3e21ebec54c9172cd7` (`docs: record Reports
  migration evidence`).
- Boundary: strict Reports owns read-only context/query/pagination values,
  report DTO/projection models, dynamic transport, per-kind controller/runtime
  state, and thirteen destination-compatible wrappers. It consumes source
  feature projections and does not own Sales, Accounting, Purchasing,
  Inventory, Customers, Suppliers, Products, Billing, Payments, Fulfillment,
  Restaurant, Communications, or Sync behavior.
- Transport/lifecycle: saved `app_url` resolves per request; JSON, Bearer,
  X-Tenant, active-store, query, and 15-second timeout behavior is preserved.
  Context identity includes normalized backend/tenant/store and a non-secret
  principal fingerprint. Same-kind loads are single-flight; forced loads are
  latest-wins; logout, store change, clear, and dispose invalidate generations.
- Presentation/compatibility: full behavior-compatible implementations live
  under `lib/app/reports/`, registry imports only the Reports root, and exactly
  22 old model/provider/screen paths are export-only shims. The six transaction
  printer paths are now Printing-owned export-only compatibility paths;
  mixed `lib/models/pagination.dart` remains outside strict Reports.
- Verification: Reports strict contract/controller gate 8/8; composition 1/1;
  architecture guard test 13/13; strict analyzer no issues; complete Flutter
  suite 1,346/1,346; guard 486 legacy / 0 exceptions / 20 strict. Formatter
  and diff checks are clean except normal Windows line-ending notices.
- Known debt: deployed endpoint authorization/tenant/store/pagination/
  aggregation verification, typed replacement of the app-owned provider and
  screens, inherited logging/responsive/localization work, and final shim
  removal. Printing migration is recorded in Module 21. Full details are in
  `docs/features/reports/` and the ledger evidence record.

### Module 21 — Printing and Documents

- Base: Module 20 Reports evidence
  `e529344305f5928c759fff3e21ebec54c9172cd7`.
- Implementation: `12504f1e`; evidence: `d63de987` (`docs: record Printing
  migration evidence`).
- Boundary: strict `features/printing` owns pure device/document/output values,
  barcode-layout settings, and the typed PrinterSettings runtime. Complete
  receipt, return-bill, KOT, daily-close, invoice-PDF, standard-PDF, thermal,
  barcode, logo, document-config, printer-service, and six Reports
  transaction-printer implementations are app-owned under
  `lib/app/printing/legacy/`.
- Preserved elsewhere: Sales, Billing, Accounting, Purchasing, Inventory,
  Product, Reports query/source state, Restaurant/KOT source workflows,
  Communications delivery, and Sync scheduling/cursors. Product still owns
  barcode identity/selection; Printing renders supplied output projections.
- Compatibility: exactly 99 old Dart paths remain export-only shims — 83
  `lib/screens/print/**`, six report-printer paths, invoice PDF, three models,
  the document-config provider, and five printer services. Nine historical
  demo assets moved with the app implementation. No baseline reduction is
  claimed while those shims remain consumed.
- Verification: Printing/document/barcode/composition gate 138/138;
  architecture guard test 13/13; strict Printing analyzer no issues; complete
  Flutter suite 1,350/1,350; guard 486 legacy / 0 exceptions / 21 strict;
  `git diff --check` clean apart from Windows line-ending notices.
- Known debt: typed hardware discovery/permission ports, deployed
  document-config and printer authorization verification, typed source
  projections from later workflows, queue/retry/offline policy, platform/UI
  modernization, and final shim removal. Full details are in
  `docs/features/printing/` and the ledger evidence record.

### Module 22 — Communications

- Base: Module 21 Printing evidence `d63de987`.
- Implementation: `4b9f960d`; evidence: `6f602222` (`docs: record
  Communications migration evidence`).
- Boundary: strict `features/communications` owns the pure `WhatsappGateway`
  port, session snapshot, typed provider facade, runtime/presentation bridge,
  slot-63 settings destination, and message/PDF delivery orchestration.
  Sales/Accounting source records and transaction-sharing assembly remain with
  their owners; Printing owns PDF generation/layout; Support owns FAQ/chat;
  Sync owns offline/realtime scheduling.
- Composition: `lib/app/communications/` adapts the complete local
  WhatsApp Bot/Chromium implementation and configures it before `runApp`.
  Sales, Accounting, and the share helper consume the Communications public
  root. The current integration is a local plugin/platform client; no verified
  HTTP/backend WhatsApp contract was invented.
- Compatibility: exactly three old paths remain export-only shims:
  `lib/controllers/whatsapp_controller.dart`,
  `lib/providers/whatsapp_provider.dart`, and
  `lib/screens/settings/whatsapp_settings.dart`. No legacy path was deleted.
- Verification: strict/app gate 7/7; registry/App Destination/PDF gate 13/13;
  complete Flutter suite 1,357/1,357; guard 486 legacy / 0 exceptions / 22
  strict; scoped analyzer has no errors or warnings; formatter and diff check
  are clean apart from normal Windows line-ending notices.
- Known debt: deployed plugin/device/permission verification, session and
  tenant/store policy, delivery status/retry/idempotency, platform integration
  tests, typed transaction source projections, and final shim removal. Details
  are in `docs/features/communications/` and the ledger evidence record.

### Module 23 — Restaurant and KOT

- Base: Module 22 Communications evidence `6f602222`.
- Implementation: `45c519ed`; evidence: `895ec417` (`docs: record Restaurant
  migration evidence`).
- Boundary: strict Restaurant owns pure menu/table/order-selection values,
  context-safe table transport/provider state, local menu/order state, runtime
  wrappers, and a typed Restaurant order-context seam for Billing.
- Presentation: complete Restaurant page, Kitchen Master, and modifier modal
  implementations live under `lib/app/restaurant/legacy/`; registry slots 55,
  56, 89, and 97 retain their runtime names and constructor flags.
- Preserved elsewhere: Billing/cart/checkout policy, Product catalog/cache,
  Inventory stock, Customer directory, CartProvider order/KOT operations,
  Printing output, and Sync scheduling/realtime transport. No menu backend or
  separate KOT endpoint was invented.
- Compatibility: exactly nine old Restaurant model/provider/screen paths remain
  export-only shims; no old Restaurant path was deleted. The complete app
  copies are not shims and are listed in the feature README/TODO.
- Verification: focused Restaurant/registry/app-smoke gate 13/13; complete
  Flutter suite 1,362/1,362; guard 486 legacy / 0 exceptions / 23 strict;
  strict analysis clean; formatter and diff check clean apart from normal
  Windows line-ending notices.
- Known debt: menu remains a local fixture pending a verified backend contract;
  table master-data pagination/mutation/permission semantics need backend
  verification; Billing decomposition and typed Cart/KOT status ports belong to
  Modules 24/27. Full details are in `docs/features/restaurant/` and the
  ledger evidence record.

### Module 24 — Billing

- Base: Module 23 Restaurant evidence `895ec417`.
- Implementation: `7e11d20e2c0b368ff0866f630c307b805fe14a5c`; evidence:
  `e99f588683464858be3804af9a8dde40be644d7e` (`docs: record Billing
  migration evidence`).
- Boundary: strict Billing owns context identity, detached cart/line/totals,
  checkout result contracts, generation-aware controller state, runtime page
  shells, and the public Billing composition seam.
- Presentation: the existing 93-file desktop/mobile/quotation Billing tree is
  app-owned under `lib/app/billing/legacy/` and is configured through
  `LegacyBillingPresentationBridge`; runtime names and behavior are preserved.
- Preserved elsewhere: Product catalog/cache authority, Inventory stock,
  Restaurant table/menu/KOT, Customers directory, Payments gateway state,
  Printing output, Communications delivery, and Sync scheduling. Cart,
  saved/confirmed-order persistence, CheckoutService, and mixed
  LocalProductProvider behavior remain explicit compatibility seams.
- Verification: strict contract 4/4; Billing composition/widget/strict smoke
  6/6; Billing compatibility/downstream 108/108; Product downstream 30/30;
  registry/App Destination/architecture 21/21; complete Flutter suite
  1,367/1,367; guard 486 legacy / 0 exceptions / 24 strict; scoped analyzer
  clean and formatter/diff checks clean apart from normal Windows line-ending
  notices.
- Known debt: typed CartProvider/BillingProvider/CheckoutService ports,
  saved-order provenance/reset barriers, verified backend order/payment
  envelopes, and final app legacy-tree removal remain for later compatibility
  work. Full details are in `docs/features/billing/` and the ledger evidence.

### Module 25 — Kiosk

- Base: Module 24 Billing evidence `e99f5886`.
- Implementation: `c0b2f2af8c7579e486228dc6f6efe0ac1b3e6740`; evidence:
  `fbf5d46fe1dfdadf989a78dc61c3670937f94f78` (`docs: record Kiosk migration
  evidence`).
- Boundary: strict Kiosk publishes runtime-backed `KioskScreen`,
  `KioskOrderPage`, `KioskBillingPage`, `PrivacyPage`, and `TermsPage`
  wrappers. The seven behavior-complete page/card files are app-owned under
  `lib/app/kiosk/legacy/`.
- Preserved elsewhere: Product catalog/cache, Categories, Billing cart and
  checkout persistence, Customer directory, Identity, Subscription, Support,
  Printing output, Inventory stock, Restaurant table/menu/KOT, and Sync
  scheduling. No App Shell destination or production caller currently exposes
  Kiosk.
- Compatibility: no Kiosk shim remains; the seven old screen/widget paths were
  relocated/deleted from the horizontal legacy baseline. No Kiosk backend/API
  contract was invented.
- Verification: Kiosk strict/composition contract 3/3; combined
  Kiosk/widget/architecture gate 17/17; complete Flutter suite 1,370/1,370;
  guard 479 legacy / 0 exceptions / 25 strict; scoped analysis has no errors
  or warnings and formatter/diff checks are clean apart from normal Windows
  line-ending notices.
- Known debt: decide whether to expose or retire the currently unreachable
  workflow; verify deployed product/category/cart/coupon/customer/order APIs;
  publish typed Product/Billing/Customer ports; add real session/store,
  platform/accessibility, responsive, and legal-copy coverage. Full details are
  in `docs/features/kiosk/` and the ledger evidence.

### Module 26 — Dashboard

- Base: Module 25 Kiosk evidence `fbf5d46fe1dfdadf989a78dc61c3670937f94f78`.
- Implementation: `6a4b514ce8653da5649ed3b96ce8f93c395edabc`; evidence:
  `f35fc5c6f4f34301e3712f60c880d19ad572cc15` (`docs: record dashboard
  migration evidence`).
- Boundary: strict Dashboard publishes the public destination, DTO/parser
  models, runtime bridge, and `DashboardScreen` wrapper. Role-specific screens,
  responsive helpers, and the current provider are app-owned under
  `lib/app/dashboard/legacy/`.
- Preserved elsewhere: Product, Inventory, Customers, Suppliers, Sales,
  Accounting, Reports, Billing, Subscription, Organization, Identity, and Sync
  remain the owners of their records, operational repositories, caches, and
  schedulers. Dashboard does not invent a backend analytics contract.
- Compatibility: exactly three implementation-free shims remain at
  `lib/models/dashboard.dart`, `lib/models/dashboard_api.dart`, and
  `lib/providers/dashboard_provider.dart`; eight old Dashboard screen/widget
  paths were relocated to the app-owned tree and removed from the legacy
  baseline. Registry slot `1` and the `DashboardScreen` runtime type are
  unchanged.
- Verification: Dashboard strict/composition contract 4/4; registry/App
  Destination gate 8/8; complete Flutter suite 1,374/1,374; guard 471 legacy /
  0 exceptions / 26 strict; strict Dashboard analyzer clean; app-owned
  relocated UI retains inherited info/warning lint debt.
- Known debt: verify deployed endpoint/envelope/auth/tenant/store/permission
  semantics; replace dynamic maps with typed source projections; remove
  inherited response logging; add role/session/store lifecycle and responsive/
  accessibility coverage; then remove the three shims. Full details are in
  `docs/features/dashboard/` and the ledger evidence.

### Module 27 — Offline and Realtime Sync

- Base: Module 26 Dashboard evidence
  `f35fc5c6f4f34301e3712f60c880d19ad572cc15`.
- Implementation: `fe3fb38fa522125c1df152a3ca8e3bb558040ebf`; evidence:
  `3ff4257dc3232134a23949672e8a374c31fdcea9`.
- Boundary: strict Sync owns session/change/status values, pull/auth/entity
  transport, provenance-scoped cursors, socket lifecycle, manual-sync gating,
  reconnect policy, and app/runtime lifecycle. Product, Customers, Inventory,
  Sales, Billing/cart, Organization, Identity, and Dashboard remain the
  source-feature authorities; an app-owned entity sink is the projection seam.
- App compatibility: six complete legacy implementations now live under
  `lib/app/realtime_sync/`; the six original provider/settings/button paths are
  implementation-free export shims. No source-feature repository, cache, CRUD,
  stock reservation, cart, or presentation implementation moved into Sync.
- Verification: strict realtime-sync tests 17/17; registry/App Destination/
  widget smoke 9/9; Product source-compatibility regression 22/22; complete
  `flutter test --no-pub --reporter compact` 1,379/1,379; guard 471 legacy /
  0 exceptions / 27 strict; strict analyzer and formatter clean; diff check
  clean apart from normal Windows line-ending notices.
- Known debt: verify deployed sync and Reverb contracts, move opaque sink rows
  to typed source-feature commands, move full offline orchestration to source
  owners, configure deployment-owned Reverb credentials, add cancellation/
  backoff/observability/idempotency, and remove the six shims after consumers
  migrate. Full details are in `docs/features/realtime_sync/` and the ledger.

## How to continue after the numbered migration

1. Read this checklist, the latest handoff, the ledger, and the owning feature's
   `README.md`, `FEATURE_SPEC.md`, `TODO.md`, and `CHANGELOG.md`.
2. Select one explicit open debt and its owning module. Do not create Module 28
   or reopen a completed boundary without a written evidence amendment.
3. Confirm the current branch and clean/dirty state. Preserve unrelated user
   files; do not reset, discard, overwrite, or stage them.
4. Audit current consumers, backend/API assumptions, cache/session/store
   behavior, and cross-feature ownership before implementing. If a contract is
   uncertain, preserve behavior and record the uncertainty as debt.
5. Keep changes inside the owner feature or an app adapter. Use public roots,
   typed ports, context-safe state, generation invalidation, and thin shims;
   never create a second repository/cache authority.
6. Add characterization tests for success, malformed/non-200/network failure,
   cache provenance, context changes, logout/store reset, and late completions
   proportional to the debt. Add widget/route tests only for owned UI.
7. Run formatter, scoped analyzer, focused/downstream tests, architecture guard
   from the current verified tip, `git diff --check`, and the full Flutter suite.
8. Stage/audit tracked and untracked files, commit implementation separately
   from docs/evidence, and report exact branch/SHA/counts/guard/analyzer/debt.

## Reusable post-migration prompt

The following prompt is for future debt work after all numbered modules are
complete. Copy it, replace the owner/debt placeholders, and keep the work on a
descriptive branch. Do not create Module 28.

### Copy-paste prompt for remaining debt

```text
Continue ENKE POS architecture follow-up work in D:\Projects\ENKE\eposmob.

The numbered migration is complete (Modules 00–27). Do not create Module 28.
Work on one explicit debt only:
- Owner feature/module: [OWNER FEATURE / MODULE]
- Debt: [ONE TODO ITEM OR CONTRACT GAP]
- Branch: [DESCRIPTIVE fix/refactor BRANCH]
- Base: [CURRENT VERIFIED TIP]

Read first:
- docs/architecture/MODULE_MIGRATION_CHECKLIST.md
- docs/architecture/MIGRATION_LEDGER.md
- docs/architecture/FEATURE_ARCHITECTURE_HANDOFF.md
- docs/features/[owner]/README.md
- docs/features/[owner]/FEATURE_SPEC.md
- docs/features/[owner]/TODO.md
- docs/features/[owner]/CHANGELOG.md

Before editing, audit consumers, backend/API assumptions, auth/tenant/store/
session boundaries, preferences/Hive/cache provenance, async reset races,
navigation, and existing tests. Preserve behavior when the contract is
uncertain; record uncertainty as debt rather than inventing an endpoint.

Keep the change in the owning feature or a narrow lib/app adapter. Import
features only through public roots, keep domain code framework-free, preserve
runtime names/payload/parser quirks, and do not create a second repository or
cache writer. Do not move Product, Inventory, Billing/cart, Purchasing, Sales,
Accounting, Printing, Reports, Restaurant, Kiosk, Communications, Dashboard,
Organization, Identity, or Sync behavior across ownership boundaries.

Add focused tests for success/failure/malformed responses, cache provenance,
context changes, logout/store reset, and late async completion proportional to
the debt. Run formatter, scoped analyzer, focused/downstream tests, the
architecture guard from the base tip, git diff --check, and the full
flutter test --no-pub suite. Stage and audit tracked plus untracked files;
commit implementation separately from docs/evidence. Report exact branch,
base/implementation/evidence SHAs, changed/deleted/shim paths, test counts,
analyzer/guard results, and remaining debt. Do not start another numbered
module.
```

### Historical prompt (Module 27 — completed)

```text
Continue the ENKE POS feature-architecture migration in D:\Projects\ENKE\eposmob.

Work on exactly one module:
- Module 27 — Offline and Realtime Sync
- Branch: codex/feature-architecture-27-sync
- Base: f35fc5c6f4f34301e3712f60c880d19ad572cc15 (the verified Module 26 evidence commit)

Before editing, verify the branch/base and read:
- docs/architecture/MODULE_MIGRATION_CHECKLIST.md
- docs/architecture/MIGRATION_LEDGER.md
- docs/architecture/FEATURE_ARCHITECTURE_HANDOFF.md
- docs/architecture/FEATURE_ARCHITECTURE.md
- tool/architecture/strict_features.txt
- tool/architecture/legacy_paths.txt
- tool/architecture/cross_feature_exceptions.txt
- docs/features/dashboard/{README,FEATURE_SPEC,TODO,CHANGELOG}.md

Audit every offline/realtime provider, sync endpoint, preference/Hive key,
bootstrap/store-switch/logout path, scheduler, timer, queue, subscription,
retry/conflict rule, cache cursor, auth/tenant/store boundary, and current
consumer/test. Identify which state is a Sync-owned transport concern and
which remains with Product, Categories, Inventory, Customers, Suppliers,
Sales, Purchasing, Accounting, Restaurant, Billing, Communications, Dashboard,
Organization, or Identity. Do not invent a sync/backend contract when the
deployed route or envelope is unverified.

Consume public roots or narrow app-owned bridges. Keep operational source state,
mutation/cache authority, Product/Inventory/Billing repositories, source
models, and Dashboard projections with their owners. Sync may coordinate
transport and invalidation, but must not become a second repository or cache
writer for another feature.

Implement one public `features/realtime_sync` (or the audited feature name)
root only when the audit proves a Sync-owned boundary. Keep domain pure, inject
transport/scheduler state from app composition, preserve preference/Hive keys
and reset ordering, delete only zero-consumer paths, and use implementation-
free shims for remaining consumers. Record uncertain backend/security/platform
behavior as explicit debt rather than silently changing it.

Add focused success/failure/malformed/session/store-reset/store-switch,
late-completion, queue/retry/conflict, and scheduler tests proportional to the
audited surface. Run formatter, scoped analyzer, focused and downstream tests,
architecture guard plus guard tests, `git diff --check`, and the full
`flutter test --no-pub` suite. Stage and audit tracked and untracked files,
commit implementation first, then a separate docs/evidence commit. Update the
ledger/handoff/checklist with full SHAs and exact counts. Module 27 is the final
numbered module; do not broaden scope into post-migration cleanup.
```

### Generic owner-module template (historical)

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

### Historical prompt (Module 21)

```text
Continue the ENKE POS feature-architecture migration in D:\Projects\ENKE\eposmob.

Work on exactly Module 21 — Printing and Documents, in a new worktree/branch:
  codex/feature-architecture-21-printing
Base it on the verified Module 20 evidence commit:
  e5293443 (full SHA: `e529344305f5928c759fff3e21ebec54c9172cd7`).
Verify that the base contains implementation fd6c3300 and the Reports evidence
docs before editing.

Read the checklist, FEATURE_ARCHITECTURE_HANDOFF.md, MIGRATION_LEDGER.md,
FEATURE_ARCHITECTURE.md, the Module 20 Reports docs, and the Printing source
tree first. Audit ownership, consumers, printer/document configuration,
platform/device APIs, PDF/thermal/barcode output, report export seams,
tenant/company/store/session scoping, reset races, registry slots, exports, and
tests before changing code.

Printing and Documents owns printer settings, document configuration,
print/PDF/barcode rendering/output, and printer-facing services. Start with
the six transaction-printer implementations still under
`lib/screens/reports/**`, printer settings/configuration surfaces, and existing
report export/print seams. Consume Reports, Sales, Accounting, Products,
Inventory, Purchasing, Billing, and Organization only through public roots or
app-owned bridges. Do not move report query/source state, Product barcode
generation/selection, Billing checkout/cart policy, Communications delivery,
Restaurant/KOT workflow, or Sync scheduling into Printing. Preserve runtime
widget names and destination slots; do not invent a backend print contract.

Run focused/downstream tests, strict analyzer, formatter, architecture guard
against e5293443, diff check, and the complete `flutter test --no-pub` suite.
Create one implementation commit and one evidence/docs commit. Update the
ledger, handoff, and docs/features/printing files with exact SHAs/counts and
leave no migration-owned changes uncommitted. Do not start Module 22.
```

## Stop/merge instruction

If the goal is intentionally paused after a selected module, stop after its
separate evidence commit and leave later modules untouched. Merge or cherry-pick
the verified evidence commits into `gokul-dev` only when desired; do not merge an
implementation commit without its evidence/docs commit. This checklist itself
is intentionally written on `gokul-dev` so it remains available while numbered
branches are merged later.
