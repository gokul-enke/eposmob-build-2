# CHANGES.md — Session Changes (2026-07-11)

All changes made in this session across the eposmob codebase. Total: **9 files modified**, **1,850 insertions**, **907 deletions**.

---

## sales_provider.dart
**Path:** `lib/providers/sales_provider.dart`
**Reason for change:** The Day Close Pending flow from the login screen was closing today's date instead of the actual pending day. The provider API methods needed optional parameters to target the correct business date and transaction IDs.

### Changes:
1. **What changed:** `fetchDailySalesCloseSummary()` method (line ~973)
   **Why:** To allow filtering the summary API call by a specific business date (the pending date) rather than always defaulting to today.
   **Before:** Method accepted only `accessToken` and `storeId` parameters.
   **After:** Added optional `String? businessDate` parameter. When provided and non-empty, adds `business_date` to the API query parameters.

2. **What changed:** `createDailySalesClose()` method (line ~1040)
   **Why:** To allow explicitly targeting the correct opening/closing transaction when closing a pending day (not the current day's transactions).
   **Before:** Method had no way to specify which transactions to close.
   **After:** Added optional `int? openingTransactionId` and `int? closingTransactionId` parameters. When provided, they are included in the request body JSON.

**Business logic impact:** Yes — this change adds new optional parameters to the provider methods. Existing callers that don't pass these parameters behave identically to before (backwards compatible).

---

## store_selection_screen.dart
**Path:** `lib/screens/login/store_selection_screen.dart`
**Reason for change:** The "Day Close Pending" dialog's "Yes" callback was not forwarding the pending business date and transaction IDs to the `DayCloseModal`, causing it to close today's date instead of the actual pending day.

### Changes:
1. **What changed:** Day Close Pending `AlertDialog` content (line ~431)
   **Why:** To display the message and confirmation message more clearly as separate lines.
   **Before:** Single `Text` widget with combined message/confirmation message.
   **After:** `Column` with `mainAxisSize: MainAxisSize.min` containing the main message `Text` and (if present) a bold `confirmationMessage` `Text` below it.

2. **What changed:** `DayCloseModal` constructor call inside the "Yes" button callback (line ~459)
   **Why:** To forward the pending status data (business date, opening/closing transaction IDs) to the modal so it closes the correct day.
   **Before:** `DayCloseModal(openDraft: pendingStatus?.openDraft, onSuccess: ...)`.
   **After:** Added `pendingBusinessDate: pendingStatus?.businessDate`, `pendingOpeningTransactionId: pendingStatus?.openingTransactionId`, and `pendingClosingTransactionId: pendingStatus?.closingTransactionId`.

**Business logic impact:** Yes — this correctly routes the pending day's identifiers to the Day Close modal. Desktop layout: N/A.

---

## transaction_list.dart
**Path:** `lib/screens/transactions/transaction_list.dart`
**Reason for change:** The Customer Transactions screen showed a squished/overflowing table layout on mobile (e.g., "RIGHT OVERFLOWED BY 43 PIXELS"). Replaced with clean mobile cards.

### Changes:
1. **What changed:** `build()` method — added `isMobile` check (line ~build)
   **Why:** To split the layout between mobile (<700px) and desktop.
   **Before:** Single layout path using `isSmallScreen = size.width < 600` for minor adjustments, but still rendering the same table on all widths.
   **After:** Added `final bool isMobile = size.width < 700;`. When `isMobile` is true, returns a completely different mobile layout. Desktop layout is returned for wider screens.

2. **What changed:** New method `_buildMobileFilters(Size size)` (added)
   **Why:** Desktop filter row overflows on mobile. Needed vertically stacked collapsible filters.
   **Before:** Did not exist.
   **After:** Renders an `ExpansionTile` with filter inputs (Status dropdown, Customer name field, Reference field, Date picker, Reset button) stacked vertically inside an accordion.

3. **What changed:** New method `_buildEmptyState()` (added)
   **Why:** Shared empty state widget for mobile when no transactions found.
   **Before:** Did not exist.
   **After:** Renders a centered column with a receipt icon, "No transactions found" title, and "Try adjusting your search criteria" subtitle.

4. **What changed:** New method `_buildMobileList()` (added)
   **Why:** To render transactions as cards instead of a table on mobile.
   **Before:** Did not exist.
   **After:** Renders a `ListView.separated` of compact cards. Each card contains:
   - **Top row:** Customer name (bold, 13px) + optional Reference ID (muted, 10px) on the left, status chip on the right
   - **Bottom row:** Currency + Amount (accent color, 13px) on the left, calendar icon + Date on the right
   - Card tap calls `_showTransactionDetails(tx)`
   - Pagination control below the list

5. **What changed:** New method `_buildStatusChip(String status)` (added)
   **Why:** Color-coded status badge for mobile cards.
   **Before:** Did not exist.
   **After:** Returns a styled `Container` with colored background and text based on status value (SUCCESS/green, FAILED/red, PENDING/orange, default/grey).

**Desktop layout preserved:** Yes — the entire original `build()` return for wider screens is unchanged.
**Business logic untouched:** Yes — only UI/layout changes.

---

## stock.dart
**Path:** `lib/screens/product/stock.dart`
**Reason for change:** (1) Mobile card layout needed optimization — buttons too large, too many fields, wasted space. (2) Vertical overflow when filter section expanded. (3) Duplicate filter toggle buttons on mobile.

### Changes:
1. **What changed:** `_buildMobileStockCard()` — Product name + metadata section (line ~1210 area)
   **Why:** Category and Store name were on separate lines, wasting vertical space.
   **Before:** Product name, then Category on its own line, then Store name on its own line.
   **After:** Product name (bold, accent color, 14px) on the first line. Category and Store name combined into a single line: `"Category · Store NAME"` (11px, muted grey).

2. **What changed:** `_buildMobileStockCard()` — Action buttons position
   **Why:** Action buttons row at the bottom of the card wasted vertical space and separated them from context.
   **Before:** Buttons (Edit, View, More) were in a `Row` at the very bottom of the card with 44x44px sizing.
   **After:** Buttons moved to top-right of the card alongside the product name, sized at 30x30px with 14px icons. The separate bottom action row was **removed**.

3. **What changed:** `_buildMobileStockCard()` — Fields grid
   **Why:** The 8-field `StockInfoChip` grid (Retail, MRP, Purchase, Qty, Unit, Rack, Barcode, Order Date) was too tall and showed unnecessary detail.
   **Before:** 4 rows × 2 columns using `StockInfoChip` widgets with 8px gaps.
   **After:** Compact 2×2 grid showing only Retail, Qty, Barcode, Order Date using `_buildCompactFieldBox()` with 6px gaps, 6px/8px padding, 10px labels, 12px values.

4. **What changed:** New method `_buildCompactFieldBox()` (added)
   **Why:** Reusable compact field display widget for mobile cards.
   **Before:** Did not exist.
   **After:** Returns a `Container` with light grey background, rounded border, label (10px, muted) and value (12px, bold).

5. **What changed:** New method `_buildMobileStockActionButtons()` (added)
   **Why:** Compact 30×30px action buttons for mobile top-right placement.
   **Before:** Used shared `_buildStockActionButtons()` with 44×44px buttons.
   **After:** Returns `List<Widget>` of Edit, View, and More (PopupMenu) buttons at 30×30px with 14px icons.

6. **What changed:** Old `_buildStockActionButtons()` method (removed)
   **Why:** Replaced by the new compact `_buildMobileStockActionButtons()` for mobile and `_buildDesktopStockActionButtons()` for desktop (which already existed).
   **Before:** Single method used by mobile cards.
   **After:** Removed entirely — mobile uses `_buildMobileStockActionButtons()`, desktop uses `_buildDesktopStockActionButtons()`.

7. **What changed:** Mobile layout page wrap — `SingleChildScrollView` (around line 448 area)
   **Why:** The mobile Column overflowed by 36px vertically when the filter section expanded.
   **Before:** Mobile layout was a plain `Column` with no scroll capability.
   **After:** Wrapped the mobile Column in a `SingleChildScrollView`. Set the stock list's `ListView` to `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()` to avoid nested scroll conflicts.

8. **What changed:** `_buildMobileFiltersSection()` — Removed duplicate "Filters" toggle bar (line ~624–676)
   **Why:** Two filter toggles appeared on mobile — one in the header (funnel icon) and one horizontal "Filters" bar widget.
   **Before:** When `_showFilters` was false, a horizontal `Container` with "Filters" text and `filter_list` icon was shown as a second toggle.
   **After:** Removed the horizontal "Filters" bar entirely. Only the header funnel `IconButton` remains as the single toggle.

**Desktop layout preserved:** Yes — all desktop-path code is untouched.
**Business logic untouched:** Yes — only UI/layout changes.

---

## product_barcode.dart
**Path:** `lib/screens/product/product_barcode.dart`
**Reason for change:** Mobile card layout was too tall with unnecessary fields and large action buttons at the bottom.

### Changes:
1. **What changed:** `_buildMobileProductCard()` — Top row restructured (line ~640 area)
   **Why:** Checkbox was separate, category and serial number were on separate lines.
   **Before:** Product name and category stacked vertically on the left. Serial number (`#123`) as standalone text on the right. Checkbox in a separate area.
   **After:** Top row has: Checkbox (32×32) + Product name (bold, accent, 14px) with `"Category · #SerialNumber"` below (11px, muted) on the left side. View (eye) and Print buttons (30×30px, compact icons) on the right side.

2. **What changed:** `_buildMobileProductCard()` — Fields section
   **Why:** 5 fields (Barcode, Qty, Price, MRP, SKU) across multiple rows was too tall.
   **Before:** Two rows of `ProductBarcodeTwoColumnLayout` (Barcode+Qty, Price+MRP) plus optional SKU field.
   **After:** Single horizontal row with 3 fields only: Barcode, Qty, Price. Each uses `_buildCompactFieldBox()` with `flex: 1` for equal width, 6px gaps.

3. **What changed:** `_buildMobileProductCard()` — Action buttons row removed
   **Why:** Buttons moved to top-right of card.
   **Before:** Bottom row with `ProductBarcodeIconAction` widgets for View and Print.
   **After:** Removed entirely. Actions are now 30×30px `BuildBoxShadowContainer` buttons in the top-right.

4. **What changed:** New method `_buildCompactFieldBox()` (added)
   **Why:** Reusable compact field display for mobile cards.
   **Before:** Did not exist.
   **After:** Same pattern as stock.dart — Container with label (10px) and value (12px bold), 6px/8px padding.

5. **What changed:** MRP and SKU fields — removed from mobile card
   **Why:** Too many fields made the card tall. These are still visible via the View (eye) popup.
   **Before:** MRP row and optional SKU row shown on the card.
   **After:** Not shown on the card. Still accessible through `_showProductDetails()` dialog (untouched).

6. **What changed:** Import of `build_container_box.dart` (added)
   **Why:** `BuildBoxShadowContainer` widget used for the new compact action buttons needed this import.
   **Before:** Not imported.
   **After:** Added `import '../../../components/build_container_box.dart';` (or equivalent path).

7. **What changed:** Unused `sideBarController` variable removed (line ~1065)
   **Why:** Static analysis warning — variable was declared but never used.
   **Before:** `final SideBarController sideBarController = Get.put(SideBarController());`
   **After:** Line removed.

**Desktop layout preserved:** Yes — `_buildDesktopProductCard()` is untouched.
**Business logic untouched:** Yes — `_showProductDetails()` and `_handlePrintSingle()` are untouched.

---

## purchase_orders.dart
**Path:** `lib/screens/purchase/purchase_orders.dart`
**Reason for change:** Mobile card layout was too tall with action buttons at the bottom and fields using full-width `PurchaseOrdersTwoColumnLayout` widgets.

### Changes:
1. **What changed:** `_buildMobilePurchaseCard()` — Top row restructured (line ~659)
   **Why:** Supplier and serial number were separate, action buttons at bottom.
   **Before:** Purchase date (bold) and Supplier (below) on the left. Serial number `#123` as standalone text on the right. View and Receive buttons in a separate bottom row.
   **After:** Purchase date (bold, 14px) and `"Supplier · #SerialNumber"` (11px, muted) on the left. View button (30×30px, accent bg) and Receive button (30×30px, green bg, conditional) on the right. `mainAxisAlignment: MainAxisAlignment.spaceBetween` added to the top Row.

2. **What changed:** `_buildMobilePurchaseCard()` — Fields section
   **Why:** `PurchaseOrdersTwoColumnLayout` + `PurchaseOrdersInfoChip` widgets were too padded.
   **Before:** Used `PurchaseOrdersTwoColumnLayout(start: PurchaseOrdersInfoChip(...), end: PurchaseOrdersInfoChip(...))`.
   **After:** Standard `Row` with two `Expanded` children, each containing `_buildCompactFieldBox()` for Store and Total Price. 6px gap between them.

3. **What changed:** `_buildMobilePurchaseCard()` — Bottom action buttons row removed
   **Why:** Buttons moved to top-right.
   **Before:** `Row` at the bottom with `PurchaseOrdersIconAction` for View and conditional Receive.
   **After:** Removed entirely.

4. **What changed:** New method `_buildCompactFieldBox()` (added, line ~595)
   **Why:** Reusable compact field display for mobile cards.
   **Before:** Did not exist.
   **After:** Same pattern — Container with label (10px muted) and value (12px bold), 6px/8px padding, light grey bg with border.

5. **What changed:** Badge position adjusted
   **Why:** Visual flow improvement.
   **Before:** Badge was between the fields and the action buttons.
   **After:** Badge is the last element, left-aligned below the fields row.

**Desktop layout preserved:** Yes — desktop card and table paths are untouched.
**Business logic untouched:** Yes — `_handleOrderAction()` calls are unchanged.

---

## proforma_invoice_list.dart
**Path:** `lib/screens/transactions/proforma_invoice_list.dart`
**Reason for change:** The screen showed a squished horizontal table on mobile that was unreadable. Needed a complete mobile card layout, mobile filters, and mobile header.

### Changes:
1. **What changed:** `build()` method — added `isMobile` check (line ~build)
   **Why:** To switch between mobile card view and desktop table view.
   **Before:** Single layout path rendering the same table on all screen widths.
   **After:** Added `final bool isMobile = size.width < 700;`. Returns a `SingleChildScrollView`-wrapped mobile layout when true, or the original desktop layout when false.

2. **What changed:** `_buildHeader()` — now accepts `bool isMobile` parameter
   **Why:** Mobile header needs a funnel toggle button; desktop just shows the title.
   **Before:** `_buildHeader()` with no parameters, returned a simple `Text` widget.
   **After:** `_buildHeader(bool isMobile)`. When `isMobile` is true, returns a `Row` with the title on the left and a filter toggle `IconButton` (funnel icon) on the right.

3. **What changed:** New state variable `_showFilters` (added)
   **Why:** Controls visibility of mobile filter section.
   **Before:** Did not exist.
   **After:** `bool _showFilters = false;` — toggled by the mobile header funnel button.

4. **What changed:** New method `_buildMobileFilters()` (added)
   **Why:** Desktop filter row is too wide for mobile. Needed vertical stack with collapsible behavior.
   **Before:** Did not exist.
   **After:** When `_showFilters` is true, renders a `Container` with vertically stacked filter fields (Status dropdown, Customer name, Invoice number, Date picker) and a Reset button. Hidden when `_showFilters` is false.

5. **What changed:** New method `_buildMobileList()` (added)
   **Why:** To render proforma invoices as cards instead of a table on mobile.
   **Before:** Did not exist.
   **After:** Renders a `ListView.separated` with `shrinkWrap: true` and `NeverScrollableScrollPhysics()` (since parent is `SingleChildScrollView`). Each item calls `_buildMobileCard()`.

6. **What changed:** New method `_buildMobileCard()` (added)
   **Why:** Individual card widget for each proforma invoice on mobile.
   **Before:** Did not exist.
   **After:** Card contains:
   - **Top row:** Invoice number (bold, accent, 14px) + `"Customer · Quotation #"` below (11px, muted) on the left. View (eye) button (30×30px) on the right.
   - **Fields row:** Amount and Due Date in two equal `Expanded` columns using `_buildCompactFieldBox()`, 6px gap.
   - **Status badge:** Color-coded chip (green/orange/red/grey) left-aligned below the fields.
   - Card tap calls `_showDetails(invoice)`.

7. **What changed:** New method `_buildCompactFieldBox()` (added)
   **Why:** Reusable compact field display for mobile cards.
   **Before:** Did not exist.
   **After:** Same pattern as other screens — Container with label and value, compact padding.

8. **What changed:** Unused `_detailTile()` method (removed, line ~211)
   **Why:** Static analysis warning — method was declared but never referenced.
   **Before:** `Widget _detailTile(String label, String value)` returning a 160px-wide `SizedBox` with label and value.
   **After:** Removed entirely.

9. **What changed:** Mobile `build()` layout uses `SingleChildScrollView` wrapper
   **Why:** The mobile content (header + filters + card list + pagination) is rendered as a scrollable page rather than using `Expanded` + internal scrolling, since `shrinkWrap` lists inside `Column` require a scrollable parent.
   **Before:** N/A (mobile path didn't exist).
   **After:** `SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), child: ...)` wraps the mobile layout.

**Desktop layout preserved:** Yes — the entire desktop `BuildBoxShadowContainer` with table, header, filters, and pagination is unchanged.
**Business logic untouched:** Yes — `_showDetails()`, `_fetchInvoices()`, and all data fetching logic are unchanged.

---

## daily_sales_close_list.dart
**Path:** `lib/screens/sales/daily_sales_close_list.dart`
**Reason for change:** (1) The header row (title + Open Shift + Day Close + Filter buttons) overflowed on mobile. (2) The `DayCloseModal` widget needed to accept pending business date and transaction ID parameters for the Day Close Pending fix.

### Changes:
1. **What changed:** Header section — mobile layout (line ~770 area)
   **Why:** On narrow screens, the single `Row` with title text and all action buttons overflowed horizontally.
   **Before:** Single `Row` with title `Text` widget and action buttons (`ElevatedButton` for Open Shift, Day Close, and `IconButton` for filter toggle) all on one horizontal line.
   **After:** On mobile viewports (`_isMobile(context) == true`), uses a `Column` layout: title text on the first line, then a `Row` of action buttons (Open Shift, Day Close, Filter toggle) on the second line. Desktop retains the single horizontal `Row`.

2. **What changed:** `DayCloseModal` class — new constructor parameters (line ~873)
   **Why:** To receive and forward the pending day's business date and transaction IDs from the login flow.
   **Before:** Constructor had `onSuccess` and `openDraft` only.
   **After:** Added `String? pendingBusinessDate`, `int? pendingOpeningTransactionId`, and `int? pendingClosingTransactionId`.

3. **What changed:** `_DayCloseModalState._loadSummary()` — business date parameter (line ~1078)
   **Why:** When opened from the login pending flow, the modal should fetch the summary for the pending date, not today.
   **Before:** Called `fetchDailySalesCloseSummary(accessToken: ..., storeId: ...)`.
   **After:** Added `businessDate: widget.pendingBusinessDate` to the call. Also sets `_businessDateController.text` to `widget.pendingBusinessDate ?? result?.businessDate ?? ''`.

4. **What changed:** `_DayCloseModalState._handleSubmit()` — transaction ID parameters (line ~1260)
   **Why:** When closing a pending day, the API needs the specific opening/closing transaction IDs.
   **Before:** Called `createDailySalesClose(...)` without transaction IDs.
   **After:** Added `openingTransactionId: widget.pendingOpeningTransactionId` and `closingTransactionId: widget.pendingClosingTransactionId`.

**Desktop layout preserved:** Yes — desktop header row is unchanged.
**Business logic impact:** Yes — the DayCloseModal now correctly targets the pending day's transactions when opened from the login flow.

---

## user_switcher.dart
**Path:** `lib/widgets/user_switcher.dart`
**Reason for change:** (1) Switch User dropdown list overflowed vertically (BOTTOM OVERFLOWED BY 17 PIXELS). (2) Password confirmation dialog overflowed vertically (BOTTOM OVERFLOWED BY 46 PIXELS) and horizontally (RIGHT OVERFLOWED BY 18 PIXELS on Cancel/Switch buttons).

### Changes:
1. **What changed:** Import of `store_selection_screen.dart` — commented out (line 15)
   **Why:** The import was flagged as unused by `flutter analyze`. Commented out instead of deleted in case it's needed later.
   **Before:** `import 'package:pos_machine/screens/login/store_selection_screen.dart';`
   **After:** `// import 'package:pos_machine/screens/login/store_selection_screen.dart';`

2. **What changed:** `initState()` — removed redundant null check (line ~47)
   **Why:** `context` inside a `State` object is never null — the null comparison always evaluated to true, generating a warning.
   **Before:** `"🔧 UserSwitcher: Context is: ${context != null ? 'valid' : 'null'}"`
   **After:** `"🔧 UserSwitcher: Context is valid"`

3. **What changed:** `_showPasswordConfirmationDialog()` — Dialog content wrapped in `SingleChildScrollView` (line ~89)
   **Why:** On small screens, the dialog content (title, subtitle, email, password field, buttons) exceeded the `maxHeight: 0.4 * screenHeight` constraint, causing 46px bottom overflow.
   **Before:** `child: Column(mainAxisSize: MainAxisSize.min, ...)` directly inside the `Container`.
   **After:** `child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, ...))`.

4. **What changed:** `_showPasswordConfirmationDialog()` — Cancel/Switch buttons wrapped in `Expanded` (line ~152 area)
   **Why:** Two `CustomRoundButton` widgets with fixed `width: 120` each plus `SizedBox(width: 10)` spacing overflowed on narrow dialog widths.
   **Before:**
   ```dart
   Row(children: [
     CustomRoundButton(title: "Cancel", width: 120, ...),
     const SizedBox(width: 10),
     CustomRoundButton(title: "Switch", width: 120, ...),
   ])
   ```
   **After:**
   ```dart
   Row(children: [
     Expanded(child: CustomRoundButton(title: "Cancel", width: 120, ...)),
     const SizedBox(width: 10),
     Expanded(child: CustomRoundButton(title: "Switch", width: 120, ...)),
   ])
   ```
   The `width: 120` inside each button acts as a preferred/minimum width but `Expanded` constrains them to share available space equally.

5. **What changed:** `build()` method — `switcherBody` moved inside `LayoutBuilder` scope (line ~337)
   **Why:** The `switcherBody` needed access to `constraints` from `LayoutBuilder` to set dynamic max height on the dropdown.
   **Before:** `switcherBody` was defined outside `LayoutBuilder`, then passed in. `LayoutBuilder` wrapped it in `SingleChildScrollView` when bounded.
   **After:** `switcherBody` is defined inside `LayoutBuilder`'s builder. When bounded, returns `SizedBox(height: constraints.maxHeight, child: switcherBody)` instead of `SingleChildScrollView`.

6. **What changed:** Dropdown container — wrapped in `Flexible` with dynamic constraints (line ~430 area)
   **Why:** When the user list was long, the dropdown container grew taller than the available space, causing 17px bottom overflow.
   **Before:** `Container(margin: ..., decoration: ..., child: Column(children: [...users...]))`.
   **After:** `Flexible(child: Container(constraints: BoxConstraints(maxHeight: constraints.hasBoundedHeight ? double.infinity : 250), ...))`. The `Flexible` allows the container to shrink, and the `BoxConstraints` caps height to 250px in unbounded contexts (like sidebar drawers).

7. **What changed:** User list items — wrapped in `Flexible` + `SingleChildScrollView` (line ~460 area)
   **Why:** To make the list of users scrollable when it exceeds the available dropdown height.
   **Before:** `...salesExecutiveProvider.salesExecutives.map((executive) { ... }).toList()` spread directly into the Column's children.
   **After:**
   ```dart
   Flexible(
     child: SingleChildScrollView(
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: salesExecutiveProvider.salesExecutives.map((...) { ... }).toList(),
       ),
     ),
   )
   ```
   The "Switch User" title and `Divider` remain fixed above the scrollable list.

**Desktop layout preserved:** Yes — the widget is used identically on desktop side menu; the `LayoutBuilder` logic adapts based on constraints.
**Business logic untouched:** Yes — all authentication, password verification, store access checks, and executive switching logic are completely unchanged.

---

## Summary Table

| File | Lines Changed | Type of Change |
|------|-------------|----------------|
| `sales_provider.dart` | +12 | Business logic (API params) |
| `store_selection_screen.dart` | +14 / -11 | Business logic (param forwarding) |
| `transaction_list.dart` | +310 / -22 | Mobile UI (new card layout) |
| `stock.dart` | +278 / -262 | Mobile UI (compact cards, scroll fix, filter fix) |
| `product_barcode.dart` | +134 / -98 | Mobile UI (compact cards) |
| `purchase_orders.dart` | +95 / -54 | Mobile UI (compact cards) |
| `proforma_invoice_list.dart` | +368 / -46 | Mobile UI (new card layout) |
| `daily_sales_close_list.dart` | +206 / -110 | Mobile UI (header fix) + Business logic (params) |
| `user_switcher.dart` | +433 / -304 | Mobile UI (scroll overflow fixes) |
