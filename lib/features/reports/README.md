# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report** and
**Supplier Transactions Report**. The other reports
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

## Tests

`test/features/reports/` mirrors these folders. The provider HTTP contracts
are in `test/providers/invoice_provider_customer_report_test.dart` and
`test/providers/sales_executive_provider_report_test.dart`.
