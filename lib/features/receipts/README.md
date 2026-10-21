# Receipts

Owns Receipt List, Create and Details. Existing routes and modal entry points remain compatibility exports. The list uses the shared ListPageScaffold, FilterPanel, rows/cards and ExportController.

- Domain: immutable input query, existing receipt matching rules and payment type label keys.
- Data: provider compatibility repository and complete request-local API page snapshot. Existing date parameters, tenant/store headers, page sizes, timeout and duplicate/count validation are preserved.
- Controller: page inputs, status/method, search debounce, reset, pagination and frozen export query. Pending searches still win over page changes.
- Presentation: filters, rows/cards, workbook and page integration. Sharing retains its existing adapter and behavior.

The shared InvoiceProvider keeps the receipt cache, current page, options and latest-request publication guards because existing consumers use these methods. Export uses a separate snapshot and never changes the visible cache. Invoice state and receipt creation/details APIs are unchanged.

## Create and Details architecture

- `receipt_editor_repository.dart` forwards the existing customer-directory, master-data, independent invoice snapshot and receipt submission calls. It does not introduce another HTTP implementation or change the tenant/store contract.
- `receipt_form_item.dart` maps saved row snapshots to the existing payload, including string invoice IDs, numeric amounts, nullable payment method IDs, paid status and description defaults.
- `receipt_create_controller.dart` owns loading, form state, totals, row operations, validation and submission. It is a private Dart part of the create widget library; the view can bind to state without exposing mutable form internals publicly.
- `receipt_item_card.dart` owns each row's text controllers and focus nodes. The controller retains row/editor resources until the dialog is unmounted, detaches removed-row listeners and disposes all owned resources once. Late lookup/focus callbacks check mounting.
- `receipt_create_dialog.dart` retains the existing widgets, dimensions, labels, styles and callbacks. `receipt_details_dialog.dart` retains the existing read-only content and `receipt_details_action.dart` opens it using the receipt supplied by the list. Details adds no network request.

Business validation, payment defaults, invoice filtering, dates, saved-row totals, customer-change confirmation and success/error navigation are preserved. Draft amounts are still excluded until Add. See [inner-page review](INNER_PAGES_REVIEW.md) for unchanged issues and manual checks.

Manual list validation: search/status/method/date filters, Reset, pagination, Refresh, responsive layout, all matching rows in Export, and View/Share navigation. Native Save As and live backend responses require manual verification. Inner-page manual checks are in the review document.

Automated validation: `flutter test --no-pub test/features/receipts test/screens/transactions/receipt_list_test.dart test/screens/transactions/invoice_list_test.dart test/providers/invoice_provider_customer_report_test.dart test/invoice_provider_zatca_failed_count_test.dart`. Covers complete fetches beyond 1000 rows, request races, failed later pages, reset after date filtering, matching and payment-method compatibility, pending search/pagination/export sequences, disposal, missing authentication and responsive layouts. Invoice and receipt provider consumers are included.
