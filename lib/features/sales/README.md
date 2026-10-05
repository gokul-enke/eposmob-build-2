# Sales feature

Owns the sales and online-sales lists, order details and actions, the local
confirmed-sales attention queue, shift opening, and daily closing (operator
and administrator lists and details). Quotations are a separate module;
their existing files under `lib/screens/sales/` remain there.

## Layers

- `domain/`: order and daily-close models, query parameters, payment-code
  rules and action errors. Pure Dart; no Flutter, HTTP, preferences or GetX.
- `data/`: injectable order/action/daily-close HTTP clients and the repository.
  Tenant headers and active-store lookup use `TenantSession`. Cash-breakdown
  serialization preserves denomination strings and integer counts.
- `presentation/state/`: the public provider plus order/filter/closing/return
  capabilities, and disposable list, detail and form controllers.
- `presentation/navigation/`: Sales sidebar mutations through `SalesNavigation`.
- `presentation/pages/`: provider capture, controller lifetime, and screen
  orchestration. The existing UI is retained rather than adopting the listing
  UI kit during this architecture change.
- `presentation/widgets/`: passive list/detail/form sections, with public
  dialog and detail roots capturing their own dependencies.
- `presentation/commands/` and `sharing/`: user actions, printing and platform
  sharing, using services captured before asynchronous work begins.

## Public surface

Other modules may use:

- `SalesProvider`: existing order/filter/return/closing methods and properties.
  It remains registered in `main.dart`. Its legacy `listOrderDetails` context
  argument is retained for callers; the data layer does not use a context.
- `SalesRepository` and the three API clients for injected one-off requests.
- Domain order and daily-close models and `SalesOrderQuery`.
- `SalesNavigation` and the six public page classes.
- Public order detail/return widgets, cancellation/status/payment dialogs,
  confirmed-order details, `DayCloseModal` and `OpenShiftModal`.

The shared `lib/models/order_details.dart`, fulfillment provider, print
services, local-product provider and durable local-sale sync service remain
shared infrastructure. This feature consumes them; it does not recreate
their caches, retry queues or fulfillment transport.

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
closing bodies and existing response policies are preserved. In particular,
the existing orders endpoint's HTTP 500 `No Orders Found` response remains an
empty result; other failures retain their backend message and previous rows.
Overlapping list/detail requests and realtime updates cannot overwrite a
newer result. Controllers suppress callbacks after disposal and forms prevent
duplicate submissions while a request is in progress.

The existing pagination, dropdowns, layout and actions are retained. No list
redesign or export behavior change is included.

## Verification

```powershell
flutter test test/features/sales test/features/sales_returns
flutter test test/features/customers/presentation/state/customer_orders_controller_test.dart test/features/customers/presentation/widgets/profile/customer_orders_tab_test.dart
flutter test test/order_details_variant_test.dart test/order_details_method_labels_test.dart test/order_packing_test.dart test/local_sale_sync_service_test.dart
flutter analyze
```

Tests cover model parsing, tenant/query/action contracts, error preservation,
request ordering, filter reset, disposal, closing submission and offline sync.
Sales, daily-close lists/details, order-detail error state, and closing-form
widgets are exercised at phone and desktop sizes;
populated Sales rows are checked at 375 and 1280 pixels. Set
`SALES_CAPTURE_PREVIEWS=1` to write geometry previews into the system temporary
directory. These tests do not establish pixel-for-pixel equality to the
original screen, live backend correctness, or native printer/share behavior.

## Architecture checklist

- Models/provider/pages moved; callers import feature paths without legacy
  compatibility re-exports.
- Domain and transport layers have no UI dependencies; HTTP is injectable.
- Controllers own and dispose their fields/timers; dialogs capture dependencies
  at their boundary; extracted sections accept inputs and callbacks.
- Named navigation constants and the adapter retain existing screen slots.
- Existing Sales tests move into the matching feature tree.
- Shared infrastructure and unrelated lockfile changes are preserved.
- Architecture and UI changes remain distinct. The user requested continuing
  on the existing branch; PR creation, commit and push require their next
  instruction.
