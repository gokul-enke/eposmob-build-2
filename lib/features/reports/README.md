# features/reports

Report screens built on the shared listing kit (`core/ui`). So far:
**My Sales Report**, **Customer Transactions Report** and **Product Sales Report**. The other reports
still live in `lib/screens/reports/` and move here one at a time.

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
