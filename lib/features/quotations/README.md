# Quotation List

This feature owns only the Quotation List (sidebar slot 87): request-local
listing data, filter inputs, pagination, shared presentation and Excel export.
Creation, quotation details, billing checkout, status updates and printing APIs
remain at their existing paths. Their provider/model ownership is deliberately
outside this listing-only migration.

## Layers and public surface

- `domain/quotation_list_query.dart`: immutable filter snapshot and the existing
  exact-day quotation/expiry request parameters; pure Dart.
- `data/quotation_list_repository.dart`: injectable HTTP and `TenantSession`,
  page parsing and validated all-page exports. It never changes shared state.
- `presentation/state/quotation_list_controller.dart`: inputs, debounce,
  successful query/page, retry target, stale-response guards and disposal.
- `presentation/navigation/quotation_list_navigation.dart`: existing slots
  86 (new), 88 (details/selected ID) and 90 (quotation billing draft).
- `presentation/pages/quotation_list_page.dart`: `QuotationsListScreen`, the
  public sidebar entry point, using `ListPageScaffold` and cached services.
- `presentation/pages/quotation_list_actions.dart`: the retained row conversion
  and print handlers. Item quantity, sale-unit conversion, price/MRP, stock,
  customer, address, discount, tax and delivery mapping are unchanged.
- `presentation/widgets/list/`: shared filter, card/table, badge/action composition.
- `presentation/export/quotation_list_excel.dart`: displayed columns in Excel.

`QuotationsProvider` and `quotation_model.dart` remain the existing shared public
contracts used by inner pages and billing. No detail/form page is migrated here.
External callers use `QuotationsListScreen` and the existing shared contracts.

## Behavior

The list GET retains its URL, bearer/tenant headers, active-store fallback,
customer/store IDs and status spelling. Quotation Date and Expiry Date each map
to the same day's from/to API parameters, not a date-range interpretation.
Typing debounces for 300 ms; Enter/dropdown/date changes load page one. Reset
clears every input and the transient dropdown searches. Failed requests retain
prior rows, show Retry and block export. Retry retains the requested page, even
after a failed filter change. Old responses cannot overwrite a newer query or
restore data after disposal/session change. Unchanged/undone typing does not
reset an existing page during export. Pagination comes from the server.
The live endpoint supplies a simple paginator (`next_page_url` / `per_page`),
without `last_page` or `total`. The shared pagination bar therefore shows only
the current page while Next follows the server's continuation. Full pagination
metadata remains supported. Only the endpoint's exact HTTP 500 `failed` /
`No quotations found` / empty `data` envelope is treated as a zero-result page;
other failures retain Retry and block export.

All presentation uses the existing shared kit, including the filter toggle,
Export/Refresh/New header actions, date decoration, table scrollbar, cards,
status badges, row actions and toasts. Customer/store popup searches are separate
from the selected value. Inner print and billing draft services are retained.

Export freezes the applied filters and token, then reads all matching pages
with one tenant/fallback-store snapshot. It never moves the visible page or
mutates `QuotationsProvider`. Duplicate/missing IDs, inconsistent totals/pages,
missing records, page offsets and later-page failures abort the export rather
than create a partial workbook. Exactly 1000 pages are supported; larger
declared exports stop before page two. Simple pagination uses the same bounded
traversal, following continuation until the final page without mistaking the
first 15 rows for the complete report. The shared `ExportController` performs
Windows Save As or the existing delivery mechanism on other platforms. Injected
export controllers remain caller-owned. Leaving/changing session cancels the
pending snapshot before delivery.

## Verification

Tests under `test/features/quotations/` cover the transport contract, export
integrity/boundary, filter/reset/page/export/retry sequences, stale responses,
pending and undone typing, popup dismissal, exact dates/placeholders,
navigation/action identity, disposal, Excel values and populated en/ar/ml
layouts at 375/768/1280 pixels. Existing quotation checkout/model/print tests
remain applicable. Physical printing and live mutation/network operations need
manual application verification; they are not submitted by the automated tests.
