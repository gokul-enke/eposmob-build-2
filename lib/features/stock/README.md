# Stock list

This migration owns **only the Stock listing screen** (sidebar slot 15).
The listing uses the shared UI layout, filters, cards/table, action buttons,
quantity badges and pagination. The provider's filter rules and 20-row paging
remain unchanged. Inner pages and stock mutations remain outside this scope.

## Layout

```text
domain/stock_list_query.dart                 listing inputs passed to the legacy provider
data/stock_list_snapshot.dart                immutable filtered export of loaded entries
presentation/state/stock_list_controller.dart owned inputs, options, initialization and disposal
presentation/navigation/stock_navigation.dart list/add entry points
presentation/pages/stock_list_page.dart      cached services and existing dialog entry points
presentation/widgets/list/                  shared header/scaffold composition, filters, rows and actions
presentation/export/stock_list_excel.dart    Excel columns with purchase-price/variant permissions
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
→ store order, and search/reset/page use the original provider methods. Text
filters debounce for 300 ms; Enter and dropdown selections apply immediately.
Reset cancels pending searches and clears popup queries. Refresh reapplies the
visible filters after the existing loader completes. Export flushes pending text
before taking its snapshot; pagination stays at page 1 when it flushes new filters.
After a mutation reload clears provider filters, the list restores its last
applied query without committing pending text edits. Realtime updates and failed
reloads with unchanged filters retain the current page. Export uses the
controller's applied query rather than reconstructing it from shared cache state.

Add stock, stock details, edit, adjust, move and withdraw implementations are
unchanged. The list's embedded read-only details dialog also retains its content.
`stock_responsive.dart` remains shared legacy presentation code because inner
screens also use it.

## Shared UI and export

The page supplies stock columns/cards to `ListPageScaffold`, with `PageHeader`,
`FilterPanel` and `ListPagination`. The wide table has a visible horizontal
scrollbar. On phones, secondary actions use the shared header menu and filters
use the shared collapsible tile. Dropdown searches are transient popup inputs;
abandoning a search never changes the displayed selection or applied filter.

The shared Export button uses `ExportController` and `ListExcelExportService`:
Save As on Windows, the shared delivery mechanism on other platforms. It exports
all **loaded stock entries matching the applied filters**, across local pages,
without fetching another endpoint or changing the visible page. The provider's
existing loading/cache completeness is unchanged; this is not a new server-wide
stock fetch. Entries are identified by stock ID, not product name (the same
product can legitimately have several stock entries). Barcodes remain text and
quantities retain precision. Purchase price is omitted without the existing
purchase permission, and variant columns follow the existing feature flag.

Export is disabled during loading, after a failed refresh and for an empty list.
Rows, filter values and column permissions are frozen at the click, so realtime
updates while the workbook is being created cannot alter that export. An injected
export controller remains caller-owned; the page disposes only its own instance.

## Public surface

- `StockListPage`: the sidebar list entry point.
- `StockNavigation`: list/add routing, slots 15 and 18.
- Existing `StockProvider` and stock models remain the shared public contract.

The controller owns and disposes the three text filters and three selected-value
controllers. Popup routes own their temporary search inputs. Fetch continuations do not notify after disposal;
failed initialization releases the list's loading state for retry.

## Verification

```powershell
flutter test test/features/stock test/list_stock_variant_test.dart test/product_filter_screens_test.dart
flutter analyze
```

Tests cover every filter, reset, request order, option sorting, loading failure,
disposal, 20-row paging, realtime row replacement, and all five row callbacks
carrying the original stock object. Snapshot parity checks compare all provider
pages, including variant/secondary filters. Excel checks cover all loaded rows,
leading zeroes, numeric precision, missing/invalid values and cost/variant columns.
Page tests cover pending searches with Export/Next, refresh failure/retry,
mutation reload followed by paging/export/reset, pending edits during reload,
abandoned popup searches and phone actions. Populated layouts run at 375×812,
768×900, 1280×900 and 1440×900.

Optional screenshot capture writes outside the repository:

```powershell
$env:STOCK_CAPTURE_TAG = 'after'
flutter test test/features/stock/presentation/pages/stock_list_page_test.dart
```

No live stock mutation is submitted and physical printing is outside this scope.
Inner-page architecture remains outside this change.
