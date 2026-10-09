# Receipt listing

Owns the Receipt List only. The existing route delegates to the feature page, which uses the shared ListPageScaffold, FilterPanel, rows/cards and ExportController.

- Domain: immutable input query, existing receipt matching rules and payment type label keys.
- Data: provider compatibility repository and complete request-local API page snapshot. Existing date parameters, tenant/store headers, page sizes, timeout and duplicate/count validation are preserved.
- Controller: page inputs, status/method, search debounce, reset, pagination and frozen export query. Pending searches still win over page changes.
- Presentation: filters, rows/cards, workbook and page integration. Create, details and sharing retain their existing adapters and behavior.

The shared InvoiceProvider keeps the receipt cache, current page, options and latest-request publication guards because existing consumers use these methods. Export uses a separate snapshot and never changes the visible cache. Invoice state and receipt creation/details APIs are unchanged. The details dialog body was moved verbatim to the legacy row action adapter; no inner-page behavior was refactored.

Manual validation: search/status/method/date filters, Reset, pagination, Refresh, responsive layout, all matching rows in Export, and the existing View/Share navigation. Native Save As and live backend responses require manual verification. Do not create a receipt to validate this listing refactor.

Automated validation: `flutter test --no-pub test/features/receipts test/screens/transactions/receipt_list_test.dart test/screens/transactions/invoice_list_test.dart test/providers/invoice_provider_customer_report_test.dart test/invoice_provider_zatca_failed_count_test.dart`. Covers complete fetches beyond 1000 rows, request races, failed later pages, reset after date filtering, matching and payment-method compatibility, pending search/pagination/export sequences, disposal, missing authentication and responsive layouts. Invoice and receipt provider consumers are included.
