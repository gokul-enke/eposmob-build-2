# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report**,
**Supplier Transactions Report**, **Product Sales Report** and **Stock Report**. The other reports
still live in `lib/screens/reports/` and move here one at a time.

**Supplier Transactions Report listing** uses the same header, filter panel,
table/cards, loading/empty states and pagination. Its View details now lives in
this feature with a compatibility export at the legacy path; print pages stay
at their legacy paths.

The supplier listing uses `domain/supplier_report.dart`,
`data/supplier_report_source.dart`, `data/supplier_report_snapshot.dart`,
`SupplierTransactionsReportController`,
`SupplierTransactionsReportPage` and widgets under `widgets/supplier_report/`.
The source reuses the public SupplierRepository and its injectable, tenant-aware
API. Directory reads are local snapshots and do not replace the shared supplier
list or selection. Only View sets the supplier name/ID for the existing details
page. ReportNavigation knows slots 67 (listing) and 68 (details).

Requests retain supplier ID, date-only bounds, `list_all=false`, server paging,
tenant/store scope and grouped/legacy-list parsing. Filter changes and Reset
start at page one; Reset clears visible calendar state as well as request bounds.
Request generations ignore stale responses and disposal continuations. A failed
refresh keeps the previous rows and shows an error banner with Retry and a toast.
Directory options load independently of the table. Their failure shows a separate
translated banner with an options-only Retry; successful report results, Export
and pagination remain usable while directory options are unavailable or pending.
After a report failure, pagination is disabled until Retry succeeds. A failed
filter change retains the displayed rows/page but keeps page one as its retry
target; Reset also clears that target even on an unfiltered later page.
Filters keep date-only bounds and use the existing auto-dismiss calendar.
Export rereads every matching summary page without changing visible/shared state,
reports progress, and rejects duplicate IDs, invalid amounts, changing pagination,
incomplete results, or filter changes/disposal during export. The loaded report's
token, tenant, store and endpoint must still match before and after every export
page and after workbook creation; otherwise file delivery is cancelled. A refresh
is required before exporting a changed scope. Amounts remain numeric
in the workbook. The pagination safety guard accepts up to 1,000 declared pages;
it fails rather than truncating an export. There is no new date-period limit.
The caller may inject ExportController; only a page-owned controller is disposed.
Windows uses the shared Save As service; other platforms use its share sheet.

## Supplier Transactions Report View

`SupplierTransactionDetailsScreen` (sidebar slot 68) now delegates to
`SupplierReportDetailsController`, a query, repository-backed source, snapshot
reader and stateless filters/results under `widgets/supplier_report/details/`.
The public class/import, Back to Report (slot 67), selected supplier ID/name,
seven displayed columns, two-decimal display, default previous-month/today dates,
Reset defaults, choices and local filter predicates remain compatible.
The main summary listing already has the feature architecture, shared layout
and export; its implementation is unchanged by this View extraction.

View uses `ListPageScaffold`, `PageHeader`, `FilterPanel`, shared inputs,
table/cards, badges, loading/empty/error states and Filters/Export/Refresh.
The same date-only auto-dismiss calendar keeps bounds 2000–2101. No pagination
controls or date-period limit are added to View.

Two client state defects are addressed during extraction: local filters use
View's fetched rows instead of the independently paged supplier directory;
changing date bounds reloads the same endpoint so widening the range can recover
rows outside the previous server-filtered subset. ID selection does not fall
back to a different supplier with the same name. Request generations and session
checks prevent stale results replacing the latest selection.

Requests still use the existing SupplierRepository/API, bearer/tenant/store
scope, supplier ID, date-only `from_date`/`to_date` and `list_all=true`.
Excel export reads its own complete snapshot without publishing shared state,
follows declared outer supplier pages, validates optional nested counts,
rejects overlapping IDs, invalid dates/amounts and incomplete/changing metadata,
and rechecks filters, selection, session and lifecycle before file delivery.
If pagination or nested counts are omitted, completeness relies on the existing
`list_all=true` contract returning full supplier transaction arrays.
The workbook includes the displayed fields, currency, supplier ID/name and date
bounds; amounts retain their numeric precision. Native Save As/share and busy
states use the existing shared export services.

Print preparation/navigation is extracted separately with the same inputs,
total calculation, date bounds and destination. Its existing name-based lookup
in the shared supplier directory is retained: unavailable directory rows can
omit contact details, and same-name suppliers can supply the wrong contact.
These pre-existing Print P2 cases are not introduced by View/export changes.

Focused tests cover request compatibility, all-page snapshot validation,
filters/date widening/Reset/Retry, stale requests and export cancellation,
numeric workbook delivery, Print route inputs and English/Arabic/Malayalam
desktop/tablet/phone/short-window layouts. Live backend, Windows Save As and a
physical printer still require manual QA; passing tests cover exercised cases.

Customer and supplier report search menus reuse `AppSearchDropdownPopup` from
the shared UI kit for white surfaces, blue selected/hover states and input text
styles. Their picker keys stay stable across selection and Reset, preventing
the dropdown package from popping the report route during popup disposal.
Customer From/To fields reuse the translated Select Date placeholder; date/time
filter and View selection contracts are unchanged.

Built the same way as `features/customers` (the reference implementation);
see its README for the full set of layer and UI rules.

## Customer Transaction Report View/details

`presentation/pages/customer_report_details_page.dart` owns the existing
`SimpleTransactionDetailsScreen` used by sidebar slot 66. The old
`screens/reports/customer_transactions_reports/customer_transaction_details_screen.dart`
path re-exports it, so existing View callers and the constructor remain compatible.
Back still opens the report listing at slot 65.

This moves the details screen into the report feature and applies the shared
listing UI approved for this screen:

- `presentation/state/customer_report_details_state.dart` owns initialization,
  controllers, response mapping, local filters, Reset and disposal.
- `presentation/state/customer_report_details_print.dart` owns the existing
  customer lookup, totals and navigation to `TransactionReportPrintPage`.
- Value-and-callback widgets under `presentation/widgets/customer_report/details/`
  own the filter panel, date-only adapters, desktop columns and phone cards.
- The page composes `ListPageScaffold`, `PageHeader`, shared buttons, `FilterPanel`,
  `AppDataTable`/`AppListCard`, badges, loading and empty states. Narrow headers
  fold Filters/Export/Refresh into the shared menu. The details display still
  has no pagination controls.
- `presentation/state/customer_report_details_export_state.dart` composes the
  existing `ExportController`, `FileExportService` and Excel builder; it owns
  busy state, progress, selection/session checks and error feedback.
- `domain/customer_report_details_query.dart` freezes the selected customer and
  current local filters. `data/customer_report_details_snapshot.dart` reads all
  declared pages without modifying provider state, validates grouped/flat
  pagination, IDs, financial values and available transaction counts, then
  applies those same contains/inclusive-date filters to the complete snapshot.
- `presentation/export/customer_report_details_export.dart` uses
  `ListExcelExportService` for the visible transaction fields, customer ID/name
  and selected dates. Amounts are numeric cells without display rounding.
  Windows uses the shared Save As flow; other platforms use shared delivery.

State, print and export parts share one Dart library and the original state
instance. Print's executable implementation remains unchanged; display state
only gains export readiness, session capture and invalidation hooks. Existing
translations, request arguments, grouped response parsing and print arguments
are retained. Date-only
controls reuse the auto-dismiss calendar with the same 2000–2101 bounds. Reset
clears the visible dates and dropdowns as well as their existing filter values.
In particular, this legacy details request still uses
`InvoiceProvider.listAllTransaction` with its default `updateState: true`; the
listing controller's isolated-request rules below are not newly applied to the
display loader. Export uses the same endpoint with explicit page numbers and
`updateState: false`. It is disabled for loading, empty or failed loads; a
filter change, refresh, customer/session change or disposal prevents an in-flight
snapshot from reaching Save As. Reset keeps the stable selected customer name
for export, independently of the legacy print controller.
The print pages, provider/API implementations, main report listing and shared
`lib/core` components remain unchanged.

### Verification and existing issues

The original extraction tests were first exercised against the original screen.
The final focused run passes 96 checks across details, snapshots, report
listing/controller, provider, localization, toast guards and shared Excel/file
delivery. They cover selected ID versus duplicate names, the existing name
fallback, numeric response fields,
combined filters, inclusive dates, Reset/reload, errors/retry, empty selection,
Back and disposal during loading. Shared layout checks exercise desktop, phone,
tablet, short windows, Arabic and Malayalam, actual calendar selection/cancel,
the All dropdown choice, hide/show/refresh, visible Reset, pending loading and
long source values in a narrow desktop panel with larger text. The old phone
header/card overflow no longer occurs in the tested layouts. Local English and
Arabic renders were inspected with loaded fonts. Focused static analysis has no
issues.

Review compared the extracted display/print bodies and request/route contracts,
inspected callbacks, field/status/value rendering and lifecycle behavior, and
exercised regression and responsive render checks. No new P0/P1/P2/P3 finding
was identified in the reviewed changes. Export tests additionally exercise
grouped/flat all-page reads, duplicate names/IDs, invalid amounts/dates,
truncated counts, changing pagination, Reset, numeric workbooks, phone actions,
busy/repeated clicks, errors and session/filter/disposal cancellation. Shared
file delivery tests cover Save As, cancellation and extension/overwrite handling.
Missing pagination metadata or inconsistent rows fail visibly instead of
producing a partial workbook. Nested completeness is checked against the count
when the API supplies one; otherwise it relies on the endpoint returning the
full group's transaction array. The following original print issues are
retained under the instruction to preserve logic:

- **P2:** Reset clears `_customerController`; Print then omits the selected
  customer's name and skips the contact lookup, although the rows remain.
- **P2:** Print looks up a name and takes the first result rather than matching
  the selected ID. Same-name customers can therefore get another customer's
  contact/address on the report.
- **P2:** Print resumes after its asynchronous lookup without a mounted check
  before `setState` and navigation. Leaving while it waits can cause an update
  after disposal.

These print findings are confirmed by unchanged source paths, not by a live
backend/printer test. Actual API responses, printer output and the complete
running-app navigation still require manual verification. Concurrent reloads
also retain their original ordering behavior; no request generation is added.

Manual check after loading the new code: open Reports > Customer Transaction
Report > View; compare the selected customer and rows; combine transaction type,
status, Credit/Debit and From/To dates; Reset and refresh; toggle phone filters;
check Print rows, totals and dates; export with combined filters and after Reset,
open the saved workbook and compare customer, dates, rows and numeric amounts;
cancel Save As and verify Export becomes available; return to the report listing.

Run the details tests with:

```powershell
flutter test --no-pub test/features/reports/presentation/pages/customer_report_details_page_test.dart
```

The optional `CUSTOMER_REPORT_DETAILS_CAPTURE=shared` mode stores local PNGs in
the Windows temporary `customer-report-details-shared` directory. The behavioral
and layout checks run without that variable; there is no image-parity assertion
against the superseded UI.

## Layers

```text
features/reports/
├── domain/                          pure Dart
│   ├── report_date_range.dart       From/To moments, API format, inverted check
│   ├── customer_report.dart         CustomerReportRow + strict page parsing
│   ├── my_sales_report.dart         parseMySalesReport (rejects bad amounts)
│   ├── models/product_sales_report.dart  existing report response model
│   └── product_sales_query.dart     filter snapshot, options and session scope
├── data/
│   ├── customer_report_snapshot.dart  all-pages read for the export
│   ├── product_sales_api.dart       injected Product Sales HTTP operation
│   └── product_sales_snapshot.dart  complete filtered export read
└── presentation/
    ├── state/
    │   ├── customer_transactions_report_controller.dart  filters, paging, export rows
    │   ├── my_sales_report_controller.dart               filters, local paging
    │   ├── product_sales_report_controller.dart          filters, requests, paging
    │   └── report_load_error.dart
    ├── export/        one workbook builder per report
    ├── navigation/report_navigation.dart   the only code that knows sidebar indices
    ├── pages/         customer_transactions_report_page.dart, my_sales_report_page.dart
    └── widgets/       report_error_bar.dart, customer_report/, my_sales/
```

## Rules these reports follow

- **The controller owns the logic.** Pages only read providers, build the
  controller with a `fetch` closure, and render it. Controllers are tested
  without widgets.
- **Never touch shared provider state.** Reports call the provider with
  `updateState: false` and keep their own rows.
- **A newer request always wins.** Every load gets a request number; a
  response that comes back after a newer request is dropped.
- **A failed reload shows `ReportErrorBar` with Retry and disables Export.**
  Customer Transactions and My Sales retain their previous rows. Product Sales
  clears results, preserving that report's existing failure behavior.
- **Export only what matches the filters.** `canExport` is false while
  loading, after an error, or when the filters changed since the last load.
  The customer export reads every page again and fails rather than saving
  partial data.
- **From after To never reaches the API.**
- Header actions are Filters → Export → Refresh (`HeaderAction`); filters
  start hidden on phones.

## Stock Report public surface

- `domain/models/stock_report.dart`: moved response, rows and summary. Its
  local `StockReportPagination` retains current/per/last page metadata and
  additionally reads `total` for export completeness checks. No storage/UI imports.
- `domain/stock_report_query.dart`: local store/category/product selections,
  date-only values, stock/expiry enums and the session scope record. The API's
  product parameter remains a **name**, not an ID.
- `data/stock_report_api.dart`: injectable GET transport and `TenantSession`;
  the same stock endpoint, headers, 15-second timeout and active-store fallback.
- `data/stock_report_snapshot.dart`: all-page export reads, rejecting failed,
  missing or changing pagination and declared total-count mismatches.
- `StockReportController`: owns filters, reset revision, serialized loading,
  requested retry page, visible rows and guarded export snapshots.
- `ReportsProvider.fetchStockReport`: existing named parameters and shared
  getter/notifications remain. `fetchStockReportSnapshot` is the new local read
  used by this page and export. Other reports in this shared provider stay put.
- `StockReportPage`: caches provider dependencies once; renders shared header,
  filter panel, metrics, table/cards, error banner and pagination. Directories
  come from existing store/category/local-product providers, with no new loads.
- `ReportNavigation.openStockReport`: sole setter of sidebar slot
  `SideBarController.stockReportScreenIndex` (98), used by desktop/mobile menus.

Purchase-price and stock-cost fields, including the summary and Excel columns,
use the existing `menu.purchase.orders.access` permission. Export fetches every
filtered page without changing visible/shared rows and checks query, token,
tenant, active store and cost permission before/after asynchronous work. No
period or record cap is introduced. Windows uses the shared Save As flow;
other platforms use its existing share flow.

Stock export rejects repeated product IDs within or across pages instead of
deduplicating a possibly incomplete snapshot. Keyboard-opened product menus
scroll their highlight after layout, with close/disposal guards.

Stock-specific leaf widgets live under `widgets/stock_report/` and receive only
data and callbacks. Small directories use the shared native searchable picker.
The large product directory uses a bounded MenuAnchor/ListView.builder adapter
with the same shared input, text, spacing and white surface tokens; all products
remain searchable without building the entire catalog as menu buttons. Reset
keys clear unselected searches. Dates use the existing auto-dismiss date
picker with explicit placeholders and clear actions. Inner stock workflows are
outside this report listing migration.

## Tests

`test/features/reports/` mirrors these folders. The provider HTTP contracts
are in `test/providers/invoice_provider_customer_report_test.dart` and
`test/providers/sales_executive_provider_report_test.dart`.


## Product Sales Report public surface

`ProductSalesReportPage`, `ProductSalesApi`, the existing public
`ReportsProvider.fetchProductSalesReport` adapter and `ReportNavigation` own the
listing at slot 40. Models live in `domain/models/product_sales_report.dart`;
`ProductSalesQuery` and directory options are pure Dart. The injected API keeps
existing URL, filters, headers and timeout. Other ReportsProvider endpoints are
outside this migration and retain their existing provider.

`ProductSalesReportController` owns local selection, date-only inputs, directory
snapshots, server paging and the serialized latest-request-wins queue. Pages read
providers once and pass closures; widgets under `widgets/product_sales/` receive
only values and callbacks. Filtering uses 25-row pages. Directory failures do not
block usable rows and retry options independently. Report failures clear old
results as before; Retry preserves the intended page and Reset starts at page one.

The shared listing scaffold renders the header, FilterPanel, totals, table/cards
and pagination. Export uses the shared ExportController and Windows Save As/mobile
sharing service, reading all filtered pages with per_page 250. It keeps numeric
Excel values and cancels if filters, page lifecycle or session scope change during
fetching or workbook creation. Incomplete/changing pagination fails rather than
saving partial data. No date-range limit is added. Report inner pages are unchanged.

Tests mirror the feature under test/features/reports. The migration checklist,
baseline and verification boundaries are in docs/migrations/product_sales_report_listing.md.

## Non-Stock Report listing

`NonStockReportPage` owns only the Non-Stock Report list (sidebar slot 77).
No product detail, stock-write, purchase, return or billing workflow is moved.

- `domain/models/non_stock_report.dart` and `non_stock_report_pagination.dart`
  contain the endpoint model and pagination. `domain/non_stock_report_query.dart`
  records the name filters and session scope without UI/storage dependencies.
- `data/non_stock_report_api.dart` preserves the URL, bearer/tenant headers,
  active `store_id`, name-valued `store`/`category`/`product`, barcode and page.
  Transport and `TenantSession` are injectable; the timeout remains 15 seconds.
- `data/non_stock_report_snapshot.dart` reads all filtered export pages and
  rejects overlaps, changing metadata and incomplete results. Row identity is
  product ID plus store, since a product may occur in several stores. Live-data
  moves (`NonStockReportSnapshotChanged`) are reread up to 3 times by the
  controller; malformed data and filter/session/permission changes are not.
- `presentation/state/non_stock_report_controller.dart` owns inputs, 300 ms
  barcode debounce, local rows, retry target, pagination and request generations.
  Errors retain the displayed rows; retry uses the newly requested filter page.
- `presentation/widgets/non_stock_report/` receives values and callbacks.
  All three searchable pickers use a bounded native menu and lazy list with the
  shared input, menu surface and text tokens. This avoids creating thousands of
  native menu buttons. Searches cover the whole cached directory and make no API
  requests. Reset clears typed search even without an option selection.
- `presentation/export/non_stock_report_export.dart` delegates XLSX creation to
  `ListExcelExportService`; the page uses the shared `ExportController` (Save As
  on Windows, share on other platforms). Barcodes stay text; quantities and
  reorder levels are numeric. Applied filters are included in the workbook.
- `ReportNavigation.openNonStockReport()` owns navigation. Desktop/mobile menu
  permissions are unchanged. Export additionally rechecks report permission,
  filters, token, tenant and active store before creating/delivering a snapshot.

**Public compatibility:** `ReportsProvider.fetchNonStockReport` retains its void
signature, updates `nonStockReport` and notifies once. The listing and export use
`fetchNonStockReportSnapshot`, which never replaces shared provider rows.
`ReportsProvider` remains globally registered; other report methods stay there.

The model/page were moved from `models/get_non_stock_report_model.dart` and
`screens/reports/non_stock_report/non_stock_report.dart`; no compatibility shims
remain. Architecture and shared listing UI are delivered together following the
requested report workflow. No shared `lib/core` component is changed.

Run the module regression tests:

```powershell
flutter test test/features/reports/data/non_stock_report_api_test.dart test/features/reports/data/non_stock_report_snapshot_test.dart test/features/reports/presentation/state/non_stock_report_controller_test.dart test/features/reports/presentation/widgets/non_stock_report_picker_test.dart test/features/reports/presentation/pages/non_stock_report_page_test.dart test/report_filter_screens_test.dart
```

The populated page tests cover phone (375), tablet (768) and desktop (1280), full
export, failures/reset, permissions and stock status/quantity display. Picker tests
cover a 10,000-product catalog, keyboard opening/selection, closing and disposal.
Native Windows repainting/Save As and live backend data still need device QA.

## Consumed Stocks Report listing

Owns only the read-only listing at sidebar slot 80. No withdrawal creation,
stock updates, billing, purchases, returns or inner screens move in this change.
Architecture and shared listing UI are implemented together following the
requested report workflow; the shared `lib/core` kit is unchanged.

- `domain/models/consumed_stocks_report.dart` retains the public response/row
  classes and nested `data.data` / `data.pagination` envelope, with pure Dart
  parsing. Quantity text remains unchanged for display; numeric-string IDs and
  pagination are normalized. `consumed_stocks_report_query.dart` owns product
  and store IDs, open date-only bounds and the inverted-range check.
- `data/consumed_stocks_report_api.dart` injects HTTP and `TenantSession`, keeps
  the 15-second timeout, bearer/tenant headers, `product_id`, `store_id`, `from`,
  `until` and `page`. Selected store overrides active-store fallback, as before.
- `data/consumed_stocks_store_directory.dart` reads the same login-cached store
  directory from SharedPreferences (`store_id`, with legacy `id` fallback).
  Missing/malformed stores do not block the
  report. The controller reuses an in-flight directory load.
- `data/consumed_stocks_report_snapshot.dart` loads every matching page with no
  arbitrary row/page limit. It verifies record IDs, finite quantities, stable
  metadata and final row count. Repeated product names are valid withdrawals;
  overlapping withdrawal IDs are rejected rather than silently deduplicated.
- `presentation/state/consumed_stocks_report_controller.dart` owns filters,
  Reset revision, rows, pagination, retry target and stale-request protection.
  A failed filter change retains displayed rows but retries page 1 for the new
  filters. An inverted date range never reaches the endpoint.
- `presentation/widgets/consumed_stocks_report/` gets values and callbacks.
  Bounded native menus lazily render cached products/stores with shared input,
  surface and text tokens. Controlled date-only fields reuse the existing
  auto-dismiss calendar; clear/Reset update their display and placeholders.
- `presentation/pages/consumed_stocks_report_page.dart` reads providers once,
  owns its controller, and uses `ListPageScaffold` for headers, filters,
  table/cards, loading, empty/error states and pagination.
- `presentation/export/consumed_stocks_report_export.dart` delegates XLSX and
  native Save As/share delivery to the shared export services. It includes all
  seven displayed columns plus applied IDs/dates, with numeric quantities.
  Export captures its own query and pages; paging/refresh does not cancel it.
  Filter/reset/session/permission changes stop delivery with a cancellation
  message rather than the generic export failure.
- `ReportNavigation.openConsumedStocksReport()` owns desktop/mobile navigation.
  The named index is `SideBarController.consumedStocksReportScreenIndex`.

Public compatibility: `ReportsProvider.fetchConsumedStocksReport` still returns
`Future<void>`, updates `consumedStocksReport` and notifies once. The new listing
and export use `fetchConsumedStocksReportSnapshot`, which does not publish shared
rows, and `consumedStocksReportScope` to validate the session. ReportsProvider
remains globally registered because it still owns other report APIs. The moved
model's `GetConsumedStocksReportResponse`, `Data`, `ConsumedStockData` and
`Pagination` remain its public data types. No shims remain at the old paths.

Tests mirror API, directory, snapshot, controller, pickers and populated page
layouts at 375/768/1280 pixels. They cover repeated product withdrawals,
overlapping IDs, date Reset/clear, page-2 export, retry/failure retention,
permissions/session changes, native-menu keyboard visibility and 10k products.
Native Windows repainting/Save As and live backend data still need device QA.

## Admin Sales Executive Report listing

The admin listing now has a scoped repository, controller, shared desktop table
and mobile cards, and shared Excel export. Its existing details dialog remains
in the compatibility screen without changes. The API returns all executive
rows at once: no pagination or name parameter is invented. Name search remains
local, and export uses all matching loaded rows.

Requests retain the scalar active store, tenant and bearer headers, today default,
custom date-time bounds (including open bounds), and sales-executive redirection.
Reset clears both dates and name and reloads today. Failed refreshes retain rows
with a retry/error state and disable export; empty success remains distinct.
Generation and session checks discard late responses and cancel stale exports.
Missing financial values remain blank and incomplete core rows disable export.
Workbook amounts are numeric, phone numbers are text, and currency, applied
bounds, date mode and load time describe the captured report.

Focused contract and widget tests cover filter/reset/reload sequences, failures,
late responses, account changes, workbook contents, shared controls, and
English/Arabic/Malayalam layouts. Live backend and native save/share need manual
QA; these tests do not guarantee absence of every possible defect.
