# Sales listing

`SalesListPage` serves both Sales → Sales and Online Orders, using
`isOnlineSales` for the existing `filter_online_sales=true` parameter.
`SalesScreen` remains a compatibility wrapper around that same page.
Order details, returns, printing and mutation endpoints retain their existing
implementations.

- `domain/SalesListQuery` preserves order/receipt lookup, customer, phone,
  price, status, date/time and exact business-date parameters.
- `data/SalesListRepository` reads tenant-scoped pages without mutating
  `SalesProvider`. Export freezes that scope and reads every matching page;
  duplicate IDs, malformed financial rows, changing pagination, missing rows
  and later-page errors abort the workbook. Export is bounded to 1,000 pages.
- `presentation/SalesListController` owns inputs, debounce, pagination,
  requested retry page and stale-response protection. Session changes clear
  old rows. Refresh keeps filters; Reset clears them and loads page one.
- Header, filters, table, cards, badges, pagination, scrollbar and file delivery
  use shared components. Excel includes order and receipt numbers as text,
  customer, date, item count, numeric amount and status.

The existing row workflows were moved from `screens/sales/sales.dart` into
`screens/sales/widgets/sales_order_actions.dart` and reused by both lists.
Both modes use shared action styling and refresh their own query after mutations.
The online scope survives Reset, pagination, refresh and all export pages.
Typing then abandoning a search keeps an in-flight same-query refresh alive;
an in-flight search for different inputs is replaced after debounce.
`SalesProvider` forwards realtime refreshes to the mounted list, with
owner-aware detach; other consumers retain the legacy provider behavior.

The current API returns full pagination (10 rows per page), and its established
`500 / failed / No Orders Found` envelope means an empty result. Other failures
show Retry and retain prior rows, with export/navigation disabled until recovery.
Export transport failures report the failed page and abort delivery; no partial
workbook is saved. A repeatable HTTP 500 HTML response on a particular page
requires a backend correction rather than dropping orders from the export.

Regression coverage: `test/features/sales/`, existing Sales parsing/lifecycle/
cancel/filter tests, shared listing/header/pagination and localization tests.
