# Sales Return Orders list

This feature owns only the listing at sidebar index 50. The compatibility
`SalesReturnPage` delegates to the shared list page. Detail, creation, refund and
print screens remain unchanged; row actions pass the same transaction and print
identity to those existing screens.

The source requests `APPUrl.listSalesReturn` with `page`, the persisted
`active_store_id` as `store_id`, and the existing Bearer and X-Tenant headers.
There are no new filters or mutation requests. Listing data is request-local,
so paging and exporting do not overwrite the shared provider's return details.
Failed loads retain the previous page with Retry and block Export. Request
generations and scope checks discard stale responses after navigation/session
changes. If a refreshed catalogue removes the current page, the list reloads
the last available page.

Excel includes every matching return transaction, preserving bill/order numbers
as text and amounts/quantities as numbers. Each export freezes authentication,
tenant and store; page totals, page size, counts and unique positive return IDs
must remain consistent. A failed page, incomplete financial row, duplicate ID,
changed scope, or more than 1000 pages aborts delivery. Return IDs are distinct
from order IDs: multiple returns against the same original order are valid.

Fractional quantities are summed without the old per-item integer truncation.
The list displays a dash for missing transaction dates instead of a fabricated
current date; export rejects missing dates. Desktop tables have a horizontal
scrollbar, and mobile layouts use shared cards and header actions.
The shared desktop layout fits short tables to their rows and places pagination
directly below; long tables remain bounded and scroll vertically.
