# Sales feature

Owns the sales and online-sales lists, order details and actions, the local
confirmed-sales attention queue, shift opening, and daily closing (operator
and administrator lists and details). Quotations are a separate module.

## Layers

- `domain/`: order and daily-close models, list and order query parameters,
  payment-code rules and action errors. Pure Dart; no Flutter, HTTP,
  preferences or GetX.
- `data/`: injectable order/action/daily-close HTTP clients, the repository and
  the tenant-scoped `SalesListRepository` used by the listing and its export.
  Tenant headers and active-store lookup use `TenantSession`. Cash-breakdown
  serialization preserves denomination strings and integer counts.
- `presentation/state/`: the public provider plus order/filter/closing/return
  capabilities, and disposable list, detail and form controllers.
- `presentation/navigation/`: Sales sidebar mutations through `SalesNavigation`.
- `presentation/pages/`: provider capture, controller lifetime, and screen
  orchestration.
- `presentation/widgets/`: passive list/detail/form sections, with public
  dialog and detail roots capturing their own dependencies.
- `presentation/commands/` and `sharing/`: user actions, printing and platform
  sharing, using services captured before asynchronous work begins.
- `presentation/export/`: the Sales/Online Orders Excel workbook.

## Public surface

Other modules may use:

- `SalesProvider`: existing order/filter/return/closing methods and properties.
  It remains registered in `main.dart`. Its legacy `listOrderDetails` context
  argument is retained for callers; the data layer does not use a context.
- `SalesRepository` and the three API clients for injected one-off requests.
- Domain order and daily-close models and `SalesOrderQuery`.
- `SalesNavigation` and the public page classes.
- Public order detail/return widgets, cancellation/status/payment dialogs,
  confirmed-order details, `DayCloseModal` and `OpenShiftModal`.

The shared `lib/models/order_details.dart`, fulfillment provider, print
services, local-product provider and durable local-sale sync service remain
shared infrastructure. This feature consumes them; it does not recreate
their caches, retry queues or fulfillment transport.

## Sales listing

`SalesListPage` serves both Sales → Sales and Online Orders, using
`isOnlineSales` for the existing `filter_online_sales=true` parameter.

- `domain/SalesListQuery` preserves order/receipt lookup, customer, phone,
  price, status, date/time and exact business-date parameters.
- `data/SalesListRepository` reads tenant-scoped pages without mutating
  `SalesProvider`. Export freezes that scope and reads every matching page;
  duplicate IDs, malformed financial rows, changing pagination, missing rows
  and later-page errors abort the workbook. Export is bounded to 1,000 pages.
- `presentation/state/SalesListController` owns inputs, debounce, pagination,
  requested retry page and stale-response protection. Session changes clear
  old rows. Refresh keeps filters; Reset clears them and loads page one.
- Header, filters, table, cards, badges, pagination, scrollbar and file delivery
  use shared components. Excel includes order and receipt numbers as text,
  customer, date, item count, numeric amount and status.

Row actions (`widgets/orders/SalesOrderRowActions`) reuse the order commands
(share, return, cancel, status, payment) and refresh the list's own query after
mutations. The online scope survives Reset, pagination, refresh and all export
pages. `SalesProvider` forwards realtime refreshes to the mounted list, with
owner-aware detach; other consumers retain the legacy provider behavior.

The current API returns full pagination (10 rows per page), and its established
`500 / failed / No Orders Found` envelope means an empty result. Other failures
show Retry and retain prior rows, with export/navigation disabled until recovery.
Export transport failures report the failed page and abort delivery; no partial
workbook is saved.

## Navigation

Named constants live together on `SideBarController`:

| Screen | Index |
|---|---:|
| Sales | 2 |
| Order details | 11 |
| Confirmed-sales attention queue | 54 |
| Daily close list | 78 |
| Daily close details | 79 |
| Admin daily close list | 84 |
| Online sales | 92 |

The adapter uses the registered controller, creating it only when necessary.
Daily-close detail returns to the invoking screen through the adapter.

## Preserved contracts and review boundaries

Request paths, filter names, pagination, cancellation/refund field types,
closing bodies and existing response policies are preserved. Overlapping
list/detail requests and realtime updates cannot overwrite a newer result.
Controllers suppress callbacks after disposal and forms prevent duplicate
submissions while a request is in progress.

## Verification

```powershell
flutter test test/features/sales test/features/sales_returns
flutter test test/features/customers/presentation/state/customer_orders_controller_test.dart test/features/customers/presentation/widgets/profile/customer_orders_tab_test.dart
flutter test test/order_details_variant_test.dart test/order_details_method_labels_test.dart test/order_packing_test.dart test/local_sale_sync_service_test.dart
flutter analyze
```

Tests cover model parsing, tenant/query/action contracts, error preservation,
request ordering, filter reset, disposal, closing submission, listing export
and offline sync. Daily-close lists/details, order-detail error state, and
closing-form widgets are exercised at phone and desktop sizes. These tests do
not establish live backend correctness or native printer/share behavior.
