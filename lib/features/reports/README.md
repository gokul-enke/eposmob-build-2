# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report**,
**Supplier Transactions Report** and **Product Sales Report**. The other reports
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
