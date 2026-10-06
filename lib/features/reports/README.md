# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report** and **Stock Report**. The other reports
still live in `lib/screens/reports/` and move here one at a time.

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
