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
  product ID plus store, since a product may occur in several stores.
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
