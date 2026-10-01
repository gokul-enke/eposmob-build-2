# Shared Listing Page Layout — Work Guide

## Goal

The **Customers listing page** is the reference design. Every other listing page in the app (suppliers, purchases, sales, vouchers, expenses, reports, ...) must look and behave the same way.

The shared layout **already exists** in `lib/core/ui/` and the Customers page is built on it. Your job is to move the other listing pages onto it. Each page only provides its own data, columns, card and filters; the layout, spacing, colours, responsiveness, loading/empty states and pagination come from the shared layout.

> **Do not copy the customers page and edit it for each page.** Every page goes through `ListPageScaffold`.

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
┌ Page header ─ icon · title · subtitle ─────────── [Refresh] [+ Add] ┐
├ Filter panel ─ fields in a 1 / 2 / 4 column grid · Reset ───────────┤
├ List ─ table on wide screens / cards on narrow screens ─────────────┤
│        + loading state, empty state, pull-to-refresh                │
└ Pagination bar ─ "N on this page" ······· ‹  Page x of y  › ────────┘
```

On phones (< 700 px) the filter panel collapses into an expandable "Search and filters" tile and the list is always cards. A wide screen whose list area is narrower than 720 px also shows cards.

---

## 2. The shared layout — what you use

Import one file: `import 'package:pos_machine/core/ui/ui.dart';`

| Widget | Use it for |
|---|---|
| `ListPageScaffold<T>` | The whole page. Takes `header`, `filters`, `mobileFilterTexts`, `isLoading`, `items`, `columns`, `cardBuilder`, `emptyState`, `pagination`, `onRowTap`, `onRefresh`. |
| `PageHeader` | Icon, title, subtitle, Refresh, Add (+ `extraActions` such as Export/Print). Shortens itself on phones. |
| `FilterPanel` | The filter block. `fields:` is a list of `TextFilterField`, `DropdownFilterField<T>`, `DateRangeFilterField`. `onSearch` runs on every keystroke (debounce it), `onSubmit` on Enter. `embeddedResetLabel` is the full-width Reset text on phones. |
| `CollapsedFilterTexts` | Title + subtitles of the phone filter tile. |
| `TableColumnDef<T>` + `TableCells` | Table columns. `TableCells.number`, `.text`, `.amount` (green/red, 2 decimals), `.avatarName`, `.widget` (badges), `.action` (View button). |
| `AppListCard`, `AppMetricStrip`, `AppMetric`, `AppAvatar`, `AppBadge` | Building blocks for the phone card. |
| `ListPagination` | Current/total pages, items per page, `onPageChanged`, count text. Also numbers the rows across pages. |
| `AppEmptyState` | Icon + title + subtitle when the list is empty. |
| `AppAdaptiveList<T>` | Table/cards + pagination **without** header and filters — for lists inside tabs and dialogs. |
| `AppColors`, `AppSpacing`, `AppRadius`, `AppTextStyles` | All colours, gaps, radii and text styles. |

A new page is: columns + card + filter fields + one `ListPageScaffold` call.

```dart
ListPageScaffold<Supplier>(
  header: PageHeader(
    icon: Icons.local_shipping_rounded,
    title: 'suppliers.title'.tr,
    subtitle: 'suppliers.subtitle'.tr,
    refreshTooltip: 'suppliers.refresh'.tr,
    onRefresh: _refresh,
    addLabel: 'suppliers.add'.tr,
    addShortLabel: 'suppliers.add_short'.tr,
    onAdd: _openAddSupplier,
  ),
  filters: supplierFilterPanel(_controller),
  mobileFilterTexts: supplierMobileFilterTexts(),
  isLoading: provider.isLoading,
  items: provider.pageItems,
  columns: supplierTableColumns(onView: _openSupplier),
  cardBuilder: (supplier, rowNumber) => SupplierListCard(...),
  onRowTap: _openSupplier,
  emptyState: AppEmptyState(
    icon: Icons.search_off_rounded,
    title: 'suppliers.empty_title'.tr,
    subtitle: 'suppliers.empty_subtitle'.tr,
  ),
  pagination: ListPagination(
    currentPage: provider.currentPage,
    totalPages: provider.totalPages,
    itemsPerPage: provider.itemsPerPage,
    onPageChanged: provider.goToPage,
    countLabel: ...,
  ),
  onRefresh: _refresh,
)
```

---

## 3. Order of work

One page per PR. Get the first one (Suppliers) reviewed before starting the rest.

1. **Suppliers** — `lib/screens/suppliers/supplier_list.dart` + `supplier_list_mobile.dart` (same desktop/mobile split Customers had, so it maps 1:1).
2. **Weigh machine colours** — replace `WeighUiColors` / `WeighSurface` in `lib/features/weigh_machine/presentation/widgets/weigh_ui.dart` with `AppColors` / `AppSurface`, then delete `WeighUiColors`.
3. `lib/screens/transactions/customer_voucher_list.dart` (+ `_mobile`)
4. `lib/screens/transactions/expense_list_screen.dart`
5. `lib/screens/purchase/purchase.dart`, `purchase_orders.dart`, `purchase_voucher.dart`
6. `lib/screens/purchase_return/purchase_return_list.dart`
7. `lib/screens/sales/sales.dart`, `daily_sales_close_list.dart`, `admin_daily_sales_close_list.dart`
8. `lib/screens/sales_return/sales_return_list.dart`
9. `lib/screens/product/stock.dart`
10. Reports in `lib/screens/reports/` (use `DateRangeFilterField`)

If a page needs something the shared layout can't do (an extra header button, a new filter type), **add it to `lib/core/ui/` with a parameter** and a test in `test/core/ui/`. Never special-case it inside the page.

---

## 4. Rules

- **Only the UI changes.** Don't change providers, API calls, models, or how data is loaded/filtered/paginated. The page passes what its provider already gives it into `ListPageScaffold`.
- **No page names inside `lib/core/ui/`.** If a shared widget needs something page-specific, add a parameter.
- **No new colours, radii, font sizes or breakpoint numbers in page files.** Use the tokens; if one is missing, add it to `lib/core/ui/tokens/`.
- **Debounce typing** (300 ms, like `CustomerListController`); search immediately on Enter and on dropdown changes.
- **All visible text through `.tr`**, with keys in `en.json`, `ar.json` and `ml.json`.
- **Don't change the look of the Customers page.** It is the reference.
- Each PR has before/after screenshots at 375, 768 and 1280 px widths.

---

## 5. Checklist for every page you move

- [ ] Page uses `ListPageScaffold` — no hand-built header / filter / table / pagination layout left in the page file
- [ ] Header: correct icon, title, subtitle; Add and Refresh wired up
- [ ] Filters: all old filters still work; typing is debounced; Reset clears every field and the list
- [ ] Wide screen shows the table; narrow screen shows cards; phone shows the collapsible filter tile
- [ ] Row numbers continue across pages (page 2 starts at 21 with 20 per page)
- [ ] Tapping a row / card / View opens the same screen as before
- [ ] Loading spinner, empty state and pull-to-refresh all work
- [ ] Pagination: previous/next disabled at the ends; count text correct
- [ ] No hard-coded English, colours or breakpoint numbers in the page file
- [ ] Old page-specific widgets that are no longer used are deleted
- [ ] A page test like `customers_list_page_test.dart` (phone + desktop sizes)
- [ ] `flutter analyze` is clean for the touched files and `flutter test` passes
- [ ] Before/after screenshots at 375 / 768 / 1280 attached to the PR

---

## 6. Definition of done

- Every page in section 3 uses `ListPageScaffold` and the Customers page looks unchanged.
- `WeighUiColors` no longer exists.
- A new listing page can be built by writing only its columns, its card, its filter fields and one `ListPageScaffold` call.
