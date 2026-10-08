# Shared Listing Page Layout — Work Guide

## Goal

The **Customers listing page** is the reference design. Every other listing page in the app (suppliers, purchases, sales, vouchers, expenses, reports, ...) must look and behave the same way.

The shared layout **already exists** in `lib/core/ui/` and the Customers page is built on it. Your job is to move the other listing pages onto it. Each page only provides its own data, columns, card and filters; the layout, spacing, colours, responsiveness, loading/empty states and pagination come from the shared layout.

> **Do not copy the customers page and edit it for each page.** Every page goes through `ListPageScaffold`.

> This guide is only about how list pages **look**. Moving a module's code into `lib/features/<module>/` is a separate PR — see [`FEATURE_ARCHITECTURE_GUIDE.md`](FEATURE_ARCHITECTURE_GUIDE.md). For a module, do the architecture PR first, then this UI PR.

---

## 1. Reference: the Customers page

| File | What to look at |
|---|---|
| `lib/features/customers/presentation/pages/customers_list_page.dart` | The whole page: one `ListPageScaffold` call |
| `lib/features/customers/presentation/widgets/list/customer_table_columns.dart` | Table columns (`TableColumnDef`) |
| `lib/features/customers/presentation/widgets/list/customer_list_card.dart` | Card for narrow screens (`AppListCard`) |
| `lib/features/customers/presentation/widgets/list/customer_filter_fields.dart` | Filter fields (`FilterPanel`) + mobile tile texts |
| `lib/features/customers/presentation/state/customer_list_controller.dart` | Search inputs: text controllers, 300 ms debounce, Reset |
| `test/features/customers/presentation/pages/customers_list_page_test.dart` | How the page is tested at phone and desktop sizes |

The page is made of five slots:

```
┌ Page header ─ icon · title · subtitle ─ [Filters] [Export] [Refresh] [+ Add] ┐
├ Filter panel ─ fields in a 1 / 2 / 4 column grid · Reset ───────────┤
├ List ─ table on wide screens / cards on narrow screens ─────────────┤
│        + loading state, empty state, pull-to-refresh                │
└ Pagination bar ─ "N on this page" ······· ‹  Page x of y  › ────────┘
```

On phones (< 700 px) the list is always cards, and the filters are either:

- **a collapsible "Search and filters" tile** — pass `mobileFilterTexts` and keep `showFilters` true (Customers), or
- **hidden behind the Filters button** — no `mobileFilterTexts`, `showFilters` starts false on phones (Suppliers, the transaction lists, the reports).

A wide screen whose list area is narrower than 720 px also shows cards. When the header is narrower than 640 px, two or more secondary buttons fold into one "more" (⋮) menu; below 560 px the subtitle hides and Add uses its short label. These numbers live in `ListLayoutBreakpoints` and `PageHeader` — never repeat them in a page.

---

## 2. The shared layout — what you use

Import one file: `import 'package:pos_machine/core/ui/ui.dart';`

| Widget | Use it for |
|---|---|
| `ListPageScaffold<T>` | The whole page. Takes `header`, `filters`, `showFilters` (the Filters button), `mobileFilterTexts`, `toolbar` (e.g. an error bar with Retry), `isLoading`, `items`, `columns`, `cardBuilder`, `emptyState`, `pagination`, `onRowTap`, `onRefresh`, `minTableWidth` (wide tables scroll sideways). |
| `PageHeader` + `HeaderAction` | Icon, title, subtitle, `actions:` (a list of `HeaderAction` — Filters, Export, Refresh, Print …) and the primary Add button (`onAdd`, `addLabel`, `addShortLabel`). `HeaderAction` has `active` (Filters shown), `badge` (filters applied while hidden), `busy` (export running) and a `key` for tests. |
| `FilterPanel` | The filter block. `fields:` is a list of `TextFilterField`, `DropdownFilterField<T>`, `DateRangeFilterField`, `DateTimeFilterField` (one date + time, e.g. a report's From / To), `CustomFilterField` (any other picker). `onSearch` runs on every keystroke (debounce it), `onSubmit` on Enter. `embeddedResetLabel` is the full-width Reset text on phones. |
| `CollapsedFilterTexts` | Title + subtitles of the phone filter tile. |
| `TableColumnDef<T>` + `TableCells` | Table columns. `TableCells.number` (the muted row number), `.text`, `.amount` (green/red, 2 decimals), `.avatarName`, `.widget` (badges), `.action` (View button). |
| `AppListCard`, `AppMetricStrip`, `AppMetric`, `AppAvatar`, `AppBadge` | Building blocks for the phone card. |
| `ListPagination` | Current/total pages, items per page, `onPageChanged`, count text. Also numbers the rows across pages. |
| `AppEmptyState` | Icon + title + subtitle (+ optional action, e.g. Reset filters) when the list is empty. |
| `AppToast` | Every message to the user: `AppToast.success / error / warning / info(context, text)`. Never `ScaffoldMessenger` / `SnackBar` — a test fails if one is added. |
| `ExportController` + `FileExportService` | Export button state (busy, progress text) and saving the file (Save As on Windows, share sheet elsewhere). |
| `AppAdaptiveList<T>` | Table/cards + pagination **without** header and filters — for lists inside tabs and dialogs. |
| `AppColors`, `AppSpacing`, `AppRadius`, `AppTextStyles` | All colours, gaps, radii and text styles. |

A new page is: columns + card + filter fields + one `ListPageScaffold` call. Simplified from `suppliers_list_page.dart` (which keeps the filter/export state in `SupplierListController`):

```dart
ListPageScaffold<Supplier>(
  header: PageHeader(
    icon: Icons.local_shipping_rounded,
    title: 'suppliers.title'.tr,
    subtitle: 'suppliers.subtitle'.tr,
    actions: [
      HeaderAction.filters(
        key: SuppliersListPage.filterToggleKey,
        showFilters: _showFilters,
        showLabel: 'list.filters'.tr,
        hideLabel: 'list.hide_filters'.tr,
        onPressed: () => setState(() => _showFilters = !_showFilters),
        badge: !_showFilters && _hasActiveFilters,
      ),
      HeaderAction(
        key: SuppliersListPage.exportKey,
        icon: Icons.ios_share_rounded,
        label: _export.busy ? 'list.exporting'.tr : 'list.export'.tr,
        onPressed: suppliers.isEmpty ? null : _runExport,
        busy: _export.busy,
      ),
      HeaderAction(
        icon: Icons.refresh_rounded,
        label: 'list.refresh'.tr,
        onPressed: _refresh,
      ),
    ],
    addLabel: 'suppliers.add'.tr,
    addShortLabel: 'supplier_list_mobile.btn_add_new'.tr,
    onAdd: _addSupplier,
  ),
  showFilters: _showFilters, // starts false on phones
  filters: supplierFilterPanel(_controller),
  isLoading: provider.isLoading,
  items: suppliers, // provider.supplierList
  columns: supplierTableColumns(onView: _openProfile),
  cardBuilder: (supplier, rowNumber) => SupplierListCard(
    supplier: supplier,
    rowNumber: rowNumber,
    onView: () => _openProfile(supplier),
  ),
  onRowTap: _openProfile,
  emptyState: AppEmptyState(
    icon: Icons.local_shipping_outlined,
    title: 'supplier_list.no_suppliers_desktop'.tr,
    subtitle: 'supplier_list.try_adjusting_search'.tr,
  ),
  pagination: ListPagination(
    currentPage: provider.currentPage,
    totalPages: provider.totalPages,
    itemsPerPage: provider.itemsPerPage,
    onPageChanged: provider.goToPage,
    countLabel: SupplierLabels.countOnPage(suppliers.length),
  ),
  onRefresh: _refresh,
)
```

---

## 3. Order of work

Already on the shared layout (use them as more examples):

- Customers — `lib/features/customers/presentation/pages/customers_list_page.dart`
- Suppliers — `lib/features/suppliers/presentation/pages/suppliers_list_page.dart`
- Expenses — `lib/features/expenses/presentation/pages/expense_list_page.dart`
- Invoices, proforma invoices, receipts, customer vouchers, supplier vouchers,
  customer transactions, supplier transactions —
  `lib/screens/transactions/`
- My Sales Report, Customer Transactions Report —
  `lib/features/reports/presentation/pages/` (date + time filters, error bar
  with Retry, all-pages export with progress)

Still to move — one page per PR:

1. **Weigh machine colours** — replace `WeighUiColors` / `WeighSurface` in `lib/features/weigh_machine/presentation/widgets/weigh_ui.dart` with `AppColors` / `AppSurface`, then delete `WeighUiColors`.
2. `lib/screens/purchase/purchase.dart`, `purchase_orders.dart`, `purchase_voucher.dart`
3. `lib/screens/purchase_return/purchase_return_list.dart`
4. `lib/screens/sales/sales.dart`, `daily_sales_close_list.dart`, `admin_daily_sales_close_list.dart`
5. `lib/screens/sales_return/sales_return_list.dart`
6. `lib/screens/product/stock.dart`
7. The other reports in `lib/screens/reports/` (use `DateRangeFilterField` or `DateTimeFilterField`; see `lib/features/reports/`)

Export: use `ExportController` + a header `HeaderAction` (see the suppliers page). Never call the share sheet directly — `FileExportService` saves with Save As on Windows, where the native share UI can close the app. Disable the Export button while loading, after a failed load, or when the list is empty. Accept an optional `ExportController` in the page constructor so tests can capture the file, and dispose it only if the page created it.

If a page needs something the shared layout can't do (an extra header button, a new filter type), **add it to `lib/core/ui/` with a parameter** and a test in `test/core/ui/`. Never special-case it inside the page. Changes to `lib/core/ui/` (widgets, tokens, toast colours) affect every screen, so they go in their **own small PR** with before/after screenshots — not hidden inside a page PR. Don't branch on one case inside a shared widget (`this == success ? … : …`); add or change a token instead.

---

## 4. Rules

- **Only the UI changes.** Don't change providers, API calls, models, or how data is loaded/filtered/paginated. The page passes what its provider already gives it into `ListPageScaffold`.
- **No page names inside `lib/core/ui/`.** If a shared widget needs something page-specific, add a parameter.
- **No new colours, radii, font sizes or breakpoint numbers in page files.** Use the tokens; if one is missing, add it to `lib/core/ui/tokens/`.
- **Debounce typing** (300 ms, `SearchDebouncer` in `lib/core/utils/`); search immediately on Enter and on dropdown changes.
- **Header buttons in this order:** Filters → Export → Refresh → + Add. Filters start open on wide screens; on phones use the collapsible tile or start them hidden (see section 1).
- **Messages through `AppToast`** only.
- **All visible text through `.tr`**, with keys in `en.json`, `ar.json` and `ml.json`.
- **Don't change the look of the Customers page.** It is the reference.
- Each PR has before/after screenshots at 375, 768 and 1280 px widths.

---

## 5. Checklist for every page you move

- [ ] Page uses `ListPageScaffold` — no hand-built header / filter / table / pagination layout left in the page file
- [ ] Header: correct icon, title, subtitle; Filters / Export / Refresh / Add in that order and wired up; on a phone they fold into the ⋮ menu without overflow
- [ ] Filters: all old filters still work; typing is debounced; Reset clears every field and the list
- [ ] Wide screen shows the table; narrow screen shows cards; on a phone the filters are the collapsible tile or hidden until Filters is tapped
- [ ] Row numbers continue across pages (page 2 starts at 21 with 20 per page)
- [ ] Tapping a row / card / View opens the same screen as before
- [ ] Loading spinner, empty state and pull-to-refresh all work
- [ ] Pagination: previous/next disabled at the ends; count text correct
- [ ] No hard-coded English, colours or breakpoint numbers in the page file
- [ ] Old page-specific widgets that are no longer used are deleted
- [ ] A page test like `customers_list_page_test.dart` (phone + desktop sizes). Helpers in `test/test_support/`: `tapFilterToggle` / `hasFilterToggle` (works when the button is in the ⋮ menu), `CapturingExport` + `useTempExportDirectory` (check the exported workbook), `EnglishTranslations` (real strings from `en.json`)
- [ ] `flutter analyze` is clean for the touched files and `flutter test` passes (a fresh checkout needs your local `.env` in the project root)
- [ ] Every touched `.dart` file formatted after `flutter pub get` — callers like `side_menu.dart` included; new imports in order
- [ ] `git status` shows only this page's files — no `tmp/`, PDFs, `.env` or generated plugin files
- [ ] Before/after screenshots at 375 / 768 / 1280 attached to the PR

---

## 6. Definition of done

- Every page in section 3 uses `ListPageScaffold` and the Customers page looks unchanged.
- `WeighUiColors` no longer exists.
- A new listing page can be built by writing only its columns, its card, its filter fields and one `ListPageScaffold` call.
