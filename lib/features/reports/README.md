# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report** and **Customer Transactions Report**. The other reports
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
