# Sales Returns architecture

Sales Returns owns the return history list, item-return form, details modal,
refund calculations, return DTOs and return-specific API/state. The existing UI
is retained; shared-kit styling is separate work.

## Layers and public surface

- `domain/`: return list/items/refund DTOs, draft/order ID validation, item reason
  resolution and refund calculations. No Flutter, HTTP or storage dependencies.
- `data/`: `SalesReturnApi` injects GET/POST and `TenantSession`; typed reads and
  mutation responses retain existing URLs, headers, payloads and error handling.
  `SalesReturnRepository` supplies request-local list/item snapshots. No cache is
  added because this workflow has no existing offline return cache.
- `presentation/state/`: `SalesReturnProvider` owns compatible shared return
  state. List, form, details and item-dialog controllers own page state and inputs.
  Request generations reject stale detail/list completions, Reset supersedes an
  item lookup, and completion guards prevent duplicate and late UI callbacks.
- `presentation/pages/`: captured provider/auth dependencies, dialogs and print
  navigation. `presentation/widgets/`: original rendering supplied with state,
  currency and callbacks; no auth/provider/HTTP lookups.
- `presentation/navigation/`: `SalesReturnNavigation` wraps named sidebar slots.
- `presentation/printing/`: `sales_return_print_items.dart` is the public adapter
  between return DTOs and the shared Sales print DTOs.

Other modules may use return domain DTOs/helpers, `SalesReturnApi`,
`SalesReturnRepository`, `SalesReturnProvider`, `SalesReturnNavigation`,
`SalesReturnDetailModal` and the print-item adapter. The pages are shell entry
points; controller/widget internals are not a cross-feature API.

## SalesProvider compatibility

`SalesProvider` remains registered in `main.dart` and retains its existing return
methods, getters and writable pagination properties. It delegates return work to
one owned `SalesReturnProvider`, forwards notifications once and disposes the
bridge with its facade. Its existing post-request constructor argument and Sales
workflows remain compatible. The return repository can be injected for tests.
The missing-tenant vs HTTP-error list clearing boundary is preserved.

The form still depends on SalesProvider's public order search and order-details
lookups. Sales order/print/customer/store DTOs keep their existing shared ownership;
they are not duplicated into this feature. Return item snapshots and refund/draft
state are local, so opening a details modal does not replace form items. Refund
breakdowns, fractional quantity rules, session baselines, payment validation,
partial item returns and return-order completion payloads remain covered.

## Return list

`SalesReturnListPage` (sidebar index 50) uses the shared list UI
(`ListPageScaffold`) with an Excel export. It reads pages through
`SalesReturnListRepository` (`data/sales_return_list_repository.dart`) rather
than `SalesReturnProvider`; `SalesReturnRepository.fetchPage` remains for the
`SalesProvider` facade. Row actions open the existing details modal and print
page with the same transaction and print identity.

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

## Navigation

- `SideBarController.createSalesReturnScreenIndex`: 49, CreateSalesReturnPage.
- `SideBarController.salesReturnListScreenIndex`: 50, SalesReturnListPage.

The positional screen array is unchanged. Menus and Sales entry points use the
named constants/navigation adapter. The modal remains a public dialog entry.
Backend contract notes were moved from the old screen directory into
`docs/sales_returns/`; no backend contract change is included here.

## Verification

Run `flutter test --no-pub test/features/sales_returns test/quotation_and_sales_return_model_test.dart`
and `flutter analyze --no-pub`.

The original focused baseline passed 22 tests. New coverage checks transport
headers/store/query scope, JSON payload types, missing draft IDs, payment omission,
error boundaries, notification forwarding, snapshot isolation, stale response,
Reset during lookup, disposal, session baseline retention, completion validation,
duplicate completion and dialog field ownership. Page tests use 375 x 812 and
1440 x 900.

Original/refactored screenshots at widths 375 and 1280 were pixel-identical for
the list, selected-order form and details modal with deterministic fixtures.
Captured Flutter errors also matched. These checks do not verify production
fonts, live tenant API submission, native sharing/printing or a Windows build.
The full suite completed with 2298 passing tests, 2 skipped and the existing
`standard_pdf_layout_contract_test.dart` active-store-address failure. Full
analysis reported 3623 issues with no errors or new feature warnings. All 51 focused regressions passed after the final stale-selection guards.
Final module analysis reported 52 informational lints, with no warnings or errors.

## Step 0-7 checklist

- [x] Map screens, shared SalesProvider consumers, helpers, models and indices.
- [x] Move owned DTOs/pure helpers with Git moves; update all imports.
- [x] Extract injectable return API/repository with TenantSession.
- [x] Separate return state while preserving the public SalesProvider facade.
- [x] Split pages, controllers, dialogs, passive view sections and printing adapter.
- [x] Name/wrap navigation; preserve shell positions.
- [x] Mirror legacy tests and add API/controller/page workflow regressions.
- [x] Document ownership/public surface and remove old screen/temporary fixture paths.

Formatting is applied after pub get to all callers as well as the feature. No
core UI changes are included. Unrelated pubspec.lock modifications are preserved.
Senior review, manual live acceptance and merge remain separate from local work.
