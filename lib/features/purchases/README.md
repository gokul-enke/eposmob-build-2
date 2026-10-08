# Purchases architecture

The Purchases module owns the existing order and legacy purchase workflows. This
migration preserves their UI, request payloads and public provider compatibility.
The UI redesign is a separate review.

## Ownership and public surface

- `domain/models/`: purchase orders, legacy purchases, vouchers and item DTOs.
  `domain/purchase_order_*`: pure totals, filters, item rules and error recognition.
- `data/`: injected HTTP and TenantSession, URL/header construction, response
  parsing, repository commands and request-local list snapshots. Draft storage
  uses the existing shared Hive box and key, with an injected opening boundary.
- `presentation/state/`: the public `PurchaseProvider` facade and private state
  operations; callback-driven order list/form and legacy list/form controllers.
  Controllers own their inputs, timers and listeners and ignore late completions.
- `presentation/pages/`: captured provider/auth dependencies and route/dialog
  ownership. `presentation/widgets/`: supplied data and callbacks, retaining the
  original screen trees. `presentation/navigation/`: named sidebar routes.

Consumers use `PurchaseProvider`, `PurchaseRepository`, `PurchaseApi`,
`PurchaseNavigation`, purchase DTOs and pure helpers. Public provider signatures,
fields, notification behavior and override support remain compatible. Purchase
Returns delegation and listener disposal remain. Shared store/supplier/pagination
DTOs retain their shared locations. There are no old-path re-export shims.

Read response parsing belongs to the data layer. Request preparation remains
separate from sending to preserve missing-tenant error handling boundaries.
Snapshot fetching does not replace the shared visible provider list. Order and
legacy creation retain supplier/store selection, permissions, units, payment
validation, partial receipt, draft restoration and API encoding.

## Navigation

| Workflow | Sidebar index |
| --- | --- |
| Legacy purchase list / add | 19 / 20 |
| Legacy voucher list / details / entry | 26 / 29 / 37 |
| Purchase details | 36 |
| Order list / create or receive | 81 / 82 |

Indices are named on `SideBarController` and wrapped by `PurchaseNavigation`.
The screen array order remains unchanged.

## Verification

Run `flutter test --no-pub test/features/purchases test/purchase_filter_screens_test.dart`
and `flutter analyze --no-pub`. Tests mirror the module's data, domain,
controller and page ownership. Coverage includes tenant/store scope, payloads,
422 handling, snapshot isolation, draft persistence, partial receipt, duplicate
commands, disposal, stale responses and Reset while directory lookups are pending.

Final focused regressions: 54 passed.

Full-suite checkpoint: 2,278 passed, 2 skipped and the same pre-existing failure
in `standard_pdf_layout_contract_test.dart` (all six standard themes resolve the
active-store address centrally). Baseline: 2,249 passed with the same skips and
failure. Full analysis: 3,636 diagnostics, zero errors and no new warnings versus
the baseline of 3,643 diagnostics.

Before/after Flutter test screenshots at widths 375 and 1280 were pixel-identical
for the order list, create/receive form, details and four legacy screens. Existing
narrow-layout overflow diagnostics matched the original screens; they are not
resolved by this architecture change. Phone page tests also exercise 375 x 812.
Live tenant requests, production fonts and a Windows application build have not
been verified by these tests.

## Architecture checklist (steps 0-7)

- [x] Map screens, provider callers, DTOs, draft ownership and route indices.
- [x] Move owned models and pure logic into domain using Git moves.
- [x] Extract injected transport, response parsing and repositories into data.
- [x] Move the compatible provider facade and update every caller.
- [x] Split active and legacy pages into wiring, controllers and passive widgets.
- [x] Name and wrap navigation without changing sidebar positions.
- [x] Mirror tests and compare original/refactored rendering.
- [x] Document public surface, remove old paths and temporary comparison fixtures.
- [x] Domain has no Flutter/HTTP/storage imports; data has no widget/provider/context imports.
- [x] Owned Dart files are under approximately 400 lines; format after pub get.
- [x] No core changes, new analysis errors/warnings or new full-suite failures.

Lifecycle guards prevent late draft/dialog/command callbacks from touching a
removed page. Directory lookups use their own generation so Reset does not
cancel option loading. These extraction safeguards do not change API contracts.
Unrelated pre-existing `pubspec.lock` changes are excluded from the migration.
Senior review and live application acceptance remain external to local checks.

## Purchase Orders list UI and export

The order list uses the shared `ListPageScaffold`, `PageHeader`, `FilterPanel`,
table/card, badge and pagination components. Its supplier/store filters remain
searchable and its date fields retain the date-only calendar and yyyy-MM-dd API
values. Header Refresh and pull-to-refresh retain the existing Reset behavior.
The total-price strip is explicitly the sum of the visible page. View, Receive
and Create keep the existing navigation and provider preparation callbacks;
inner pages, repositories, models and list/form controllers are unchanged.

The two purchase lists share the public purchase-list adapters
`PurchaseListPicker` / `PurchaseListDateField`, the request-local
`PurchaseExportPage` / `collectPurchaseExport` collector and export-only
`PurchaseListExportGuard`. Purchase Returns consumes these helpers without
depending on order page or controller internals. Other modules need not use them.

Export uses `ExportController` and the shared Excel/file delivery services:
Save As on Windows, sharing on other platforms. It captures the filters, starts
at page 1 and reads every declared page without changing the visible list.
Missing/inconsistent page metadata, empty batches or duplicate/missing IDs fail
the export. A filter, Reset, token, tenant, active-store, endpoint, currency,
permission or page-disposal change aborts before delivery. The endpoint provides
no snapshot token or total row count: these checks detect pagination defects,
but cannot guarantee an atomic snapshot during concurrent backend edits.

Verification: 135 focused purchase/return/filter/export tests pass; touched files
analyze cleanly. Fixtures cover populated phone/tablet/desktop lists, hidden
mobile filters, supplier/store choices, date values, Reset including unselected
search text, filtered all-pages workbooks from page 2, duplicate IDs, request and
session failures, disposal and the existing inner-page regressions. Screenshots
for both lists at 375, 768 and 1280 are in `docs/screenshots/purchase-lists`.
Full suite: 2,339 passed, two skipped and the existing failure in
`standard_pdf_layout_contract_test.dart` (all six standard themes resolve the
active-store address centrally, line 391). No print sources are changed here.
Live APIs and native Windows Save As remain manual acceptance checks.
