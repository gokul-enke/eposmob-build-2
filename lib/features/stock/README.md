# Stock list

This migration owns **only the Stock listing screen** (sidebar slot 15).
The existing UI, filter rules, 20-row pagination, quantity colours, clipboard
buttons and row action menus are retained. UI redesign is a separate change.

## Layout

```text
domain/stock_list_query.dart                 listing inputs passed to the legacy provider
presentation/state/stock_list_controller.dart owned inputs, options, initialization and disposal
presentation/navigation/stock_navigation.dart list/add entry points
presentation/pages/stock_list_page.dart      cached services and existing dialog entry points
presentation/widgets/list/                  header, frame, fields, filters, rows, states and actions
```

## Existing shared boundary

`StockProvider` and `models/list_stock.dart` remain at their original paths.
They also support pending stock entries, stock mutations, details, billing,
reports and realtime synchronization. Moving their model/API/provider ownership
would broaden this listing-only task, so those layers are deliberately deferred.
The listing controller accepts fetch/read/filter callbacks rather than storing
providers. The page caches its services before asynchronous work.

The existing provider still owns shared stock data, local filtering and paging;
provider notifications after editing or realtime updates still rebuild this list.
There is no new API or request contract. Initialization retains category → stock
→ store order, and search/reset/page use the original provider methods.

Add stock, stock details, edit, adjust, move and withdraw implementations are
unchanged. The list's embedded read-only details dialog also retains its content.
`stock_responsive.dart` remains shared legacy presentation code because inner
screens also use it. There is no new export button in this architecture change.

## Public surface

- `StockListPage`: the sidebar list entry point.
- `StockNavigation`: list/add routing, slots 15 and 18.
- Existing `StockProvider` and stock models remain the shared public contract.

The controller owns all nine text inputs, including the status dropdown search
input, and disposes them. Fetch continuations do not notify after disposal;
failed initialization releases the list's loading state for retry.

## Verification

```powershell
flutter test test/features/stock test/list_stock_variant_test.dart test/product_filter_screens_test.dart
flutter analyze
```

Tests cover every filter, reset, request order, option sorting, loading failure,
disposal, 20-row paging, realtime row replacement, and row callbacks carrying the
original stock object. Populated layouts run at 375×812, 1280×900 and 1440×900.

Optional screenshot capture writes outside the repository:

```powershell
$env:STOCK_CAPTURE_TAG = 'after'
flutter test test/features/stock/presentation/pages/stock_list_page_test.dart
```

No live stock mutation is submitted and physical printing is outside this scope.
Inner-page architecture and the later listing UI PR are not part of this change.
