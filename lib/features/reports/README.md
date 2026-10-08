# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report**,
**Supplier Transactions Report** and **Stock Report**. The other reports
still live in `lib/screens/reports/` and move here one at a time.

**Supplier Transactions Report listing** uses the same header, filter panel,
table/cards, loading/empty states and pagination. Its details and print pages
stay at their legacy paths.

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

Customer and supplier report search menus reuse `AppSearchDropdownPopup` from
the shared UI kit for white surfaces, blue selected/hover states and input text
styles. Their picker keys stay stable across selection and Reset, preventing
the dropdown package from popping the report route during popup disposal.
Customer From/To fields reuse the translated Select Date placeholder; date/time
filter and View selection contracts are unchanged.

Built the same way as `features/customers` (the reference implementation);
see its README for the full set of layer and UI rules.

## Layers

```text
features/reports/
├── domain/                          pure Dart
│   ├── report_date_range.dart       From/To moments, API format, inverted check
│   ├── customer_report.dart         CustomerReportRow + strict page parsing
│   └── my_sales_report.dart         parseMySalesReport (rejects bad amounts)
├── data/
│   └── customer_report_snapshot.dart  all-pages read for the export
└── presentation/
    ├── state/
    │   ├── customer_transactions_report_controller.dart  filters, paging, export rows
    │   ├── my_sales_report_controller.dart               filters, local paging
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
- **A failed reload keeps the rows on screen**, shows `ReportErrorBar` with
  Retry, and disables Export.
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
