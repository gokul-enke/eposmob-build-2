# CloudPOS — Debug Console Error Audit

**App:** CloudPOS (`pos_machine`)  
**Platform:** Windows desktop (debug)  
**VM Service:** `ws://127.0.0.1:63701/JTrtmoRLY9k=/ws`  
**Demo server:** `https://eposdemo.yougoit.in`  
**Test account:** `salesexecutive2@funzcart.in` / store **متجر النجمة Store** (Store ID: 2)  
**Audit date:** 2026-09-10  
**Method:** Marionette MCP — login, store bootstrap, **full `SideBarController` index sweep (0–101)**, prior sidebar text tour, billing sale flow (kitkat → confirm)

---

## Executive Summary

| Severity | Count | Can hang / block production? |
|----------|-------|------------------------------|
| **Critical (backend 500/404)** | 4 distinct API failures | Yes — invoice/transactions, dashboard stats, order details |
| **High (logic / wrong store ID)** | 2 | Yes — Sales list fetch uses wrong store on every menu tap |
| **Medium (UX / data mismatch / lifecycle)** | 5 | Can confuse users; day-close dialog blocks every session; widget dispose warnings |
| **Low (debug noise)** | 2 | No — handled gracefully |
| **Flutter red exceptions (`══╡ EXCEPTION`)** | **0 observed** | No framework crash banners during this run |
| **Screens visited (`SideBarController` indices)** | **102 / 102** | Full app page map covered |

No unhandled Flutter framework exceptions or render overflow errors were observed during full navigation. The red console noise is almost entirely **backend API failures**, **provider-level debug errors**, and **lifecycle warnings when hot-swapping screens** that can leave features empty or stuck in production if the demo API is deployed as-is.

---

## Test Coverage

### Coverage status (authoritative: `lib/controllers/sidebar_controller.dart`)

| Metric | Result |
|--------|--------|
| Sidebar screen indices defined | **0–101** (102 widgets) |
| Indices visited via Marionette extension `cloudposAudit.navigate` | **102 / 102** |
| Navigation failures | **0** |
| Sidebar text-tap tour (prior pass) | ~40 top-level / expandable items |
| Billing checkout exercised | Yes (kitkat SAR 3.00 confirmed) |

**Automation:** Debug-only VM extension `ext.flutter.cloudposAudit.navigate` (registered in `lib/main.dart` under `kDebugMode`) sets `SideBarController.index` directly. Audit runner: `dart run tool/sidebar_index_audit.dart ws://127.0.0.1:63701/<token>/ws`.

### Full index coverage matrix

| Idx | Screen widget | Nav | Notable console errors |
|-----|---------------|-----|------------------------|
| 0 | BillingPageResponsive | OK | ERR-001/002 bootstrap, ERR-005 |
| 1 | DashboardScreen | OK | ERR-003 sales-stats 500, ERR-005 |
| 2 | SalesScreen | OK | ERR-004/009 (list-orders), ERR-005 |
| 3 | CartScreen | OK | cumulative bootstrap noise |
| 4 | TransactionScreen | OK | bootstrap noise |
| 5 | CustomersScreen | OK | bootstrap noise |
| 6 | LoyalityCardScreen | OK | bootstrap noise |
| 7 | NotificationScreen | OK | bootstrap noise |
| 8 | SupportScreen | OK | bootstrap noise |
| 9 | AddCustomersScreen | OK | bootstrap noise |
| 10 | OpenProfileScreen | OK | bootstrap noise |
| 11 | SalesOrderDetailsScreen | OK | bootstrap noise |
| 12 | AddCategoryScreen | OK | bootstrap noise |
| 13 | AddCategoryPropertiesScreen | OK | bootstrap noise |
| 14 | AddProductScreen | OK | bootstrap noise |
| 15 | AddStockScreen | OK | bootstrap noise |
| 16 | AddCategoryPageScreen | OK | bootstrap noise |
| 17 | TabBarForAddNewProduct | OK | bootstrap noise |
| 18 | AddProductStockScreen | OK | bootstrap noise |
| 19 | PurchaseScreen | OK | bootstrap noise |
| 20 | AddPurchaseScreen | OK | bootstrap noise |
| 21 | InvoiceListScreen | OK | **ERR-010** dispose listener warning |
| 22 | VoucherListScreen | OK | bootstrap noise |
| 23 | CustomerTransactionListScreen | OK | bootstrap noise |
| 24 | CreateNewInvoiceScreen | OK | ERR-001 blocks account types |
| 25 | CreateNewVoucherScreen | OK | bootstrap noise |
| 26 | PurchaseVoucherScreen | OK | bootstrap noise |
| 27 | ViewCategoryWidget | OK | detail screen (no list context) |
| 28 | ViewProductWidget | OK | detail screen |
| 29 | ViewVoucherWidget | OK | detail screen |
| 30 | ViewTransactionDetailsWidget | OK | detail screen |
| 31 | ViewInvoiceDetailsWidget | OK | detail screen |
| 32 | ViewVoucherDetailsWidget | OK | detail screen |
| 33 | StockDetailsWidget | OK | detail screen |
| 34 | EditCategoryPageScreen | OK | detail screen |
| 35 | TabBarForEditProduct | OK | detail screen |
| 36 | ViewPurchaseWidget | OK | detail screen |
| 37 | AddVoucherDetailsWidget | OK | detail screen |
| 38 | OpenCustomerProfileScreen | OK | detail screen |
| 39 | AccountBookScreen | OK | bootstrap noise |
| 40 | ProductSalesReportScreen | OK | report APIs mostly 200 |
| 41 | SalesReportScreen | OK | report APIs mostly 200 |
| 42 | SupplierSalesReportScreen | OK | report APIs mostly 200 |
| 43 | LocationManagementScreen | OK | bootstrap noise |
| 44 | LocationManagementScreen (alias) | OK | bootstrap noise |
| 45 | CategoryList (legacy home) | OK | bootstrap noise |
| 46 | HomeNew | OK | bootstrap noise |
| 47 | ReceiptListScreen | OK | bootstrap noise |
| 48 | ViewReceiptDetailsWidget | OK | detail screen |
| 49 | SalesReturnScreen | OK | bootstrap noise |
| 50 | SalesReturnPage | OK | bootstrap noise |
| 51 | EditOrder | OK | bootstrap noise |
| 52 | SupplierListScreen | OK | bootstrap noise |
| 53 | PrinterSettings | OK | bootstrap noise |
| 54 | ConfirmedOrdersScreen | OK | bootstrap noise |
| 55 | RestaurantPage (Attender) | OK | bootstrap noise |
| 56 | KitchenMaster | OK | bootstrap noise |
| 57 | SupplierDetailsScreen | OK | detail screen |
| 58 | SalesExecutiveReportScreen | OK | **ERR-011** order details 404 |
| 59 | CompanyAccountsScreen | OK | bootstrap noise |
| 60 | AddCompanyAccountScreen | OK | bootstrap noise |
| 61 | AccountDetailsScreen | OK | detail screen |
| 62 | SettingsScreen | OK | bootstrap noise |
| 63 | WhatsappSettingsScreen | OK | bootstrap noise |
| 64 | CompanyInfoScreen | OK | bootstrap noise |
| 65 | CustomerTransactionsReportScreen | OK | clean tail (executives loaded) |
| 66 | SimpleTransactionDetailsScreen | OK | detail screen |
| 67 | SupplierTransactionReportScreen | OK | clean tail |
| 68 | SupplierTransactionDetailsScreen | OK | detail screen |
| 69 | OpenSupplierProfileScreen | OK | detail screen |
| 70 | CustomerVoucherListScreen | OK | bootstrap noise |
| 71 | CreateCustomerVoucherScreen | OK | bootstrap noise |
| 72 | SupplierVoucherListScreen | OK | bootstrap noise |
| 73 | CreateSupplierVoucherScreen | OK | bootstrap noise |
| 74 | TransactionScreen (supplier alias) | OK | bootstrap noise |
| 75 | SupplierVoucherListScreen (alias) | OK | bootstrap noise |
| 76 | CreateSupplierVoucherScreen (alias) | OK | bootstrap noise |
| 77 | NonStockReportScreen | OK | **ERR-012** Obx build-phase update |
| 78 | DailySalesCloseListScreen | OK | bootstrap noise |
| 79 | DailySalesCloseDetailScreen | OK | detail screen |
| 80 | ConsumedStocksReportScreen | OK | **ERR-012** |
| 81 | AddPurchaseOrderScreen | OK | bootstrap noise |
| 82 | CreatePurchaseOrderScreen | OK | bootstrap noise |
| 83 | ProductBarcodeScreen | OK | bootstrap noise |
| 84 | AdminDailySalesCloseListScreen | OK | bootstrap noise |
| 85 | AdminSalesExecutiveReportScreen | OK | **ERR-011** (shared report path) |
| 86 | BillingQuotationPageResponsive | OK | bootstrap noise |
| 87 | QuotationsListScreen | OK | bootstrap noise |
| 88 | QuotationDetailsScreen | OK | detail screen (null quotation id) |
| 89 | RestaurantPage (Billing) | OK | bootstrap noise |
| 90 | BillingPageResponsive (Supermarket) | OK | bootstrap noise |
| 91 | ProformaInvoiceListScreen | OK | bootstrap noise |
| 92 | SalesScreen (Online) | OK | online orders list 200 |
| 93 | ExpenseListScreen | OK | **ERR-012** |
| 94 | CreateExpenseScreen | OK | bootstrap noise |
| 95 | ViewExpenseScreen | OK | detail screen |
| 96 | OfflineDataPage | OK | bootstrap noise |
| 97 | RestaurantPage (Store Billing) | OK | bootstrap noise |
| 98 | StockReportScreen | OK | stock report APIs 200 |
| 99 | PurchaseReturnListScreen | OK | bootstrap noise |
| 100 | CreatePurchaseReturnScreen | OK | bootstrap noise |
| 101 | OrdersToReviewPage | OK | bootstrap noise |

**Note on detail screens (indices 11, 24–38, 48, 57, 61, 66–69, 79, 88, 95):** Reached by direct index assignment without in-app list selection, so they render empty/placeholder states but still execute widget `initState` / provider hooks — valid for crash/error surfacing.

### Prior sidebar text-tap gaps (now covered by index sweep)

These sub-items previously failed Marionette text tap when parent menus were collapsed; all are now covered via index navigation:

- Transactions → Invoice (21), Receipts (47), Customer Voucher (70), Proforma (91), Expense (93)
- Reports → Sales Executive (58), Executive Summary (85), Customer/Supplier transaction reports (65/67), Stock (98), Non-stock (77), Consumed stocks (80)
- Purchase → Purchase Orders (81), Purchase Returns (99)
- Party Accounts → Customer/Supplier transactions (23/74)
- Sales → Orders to review (101), Admin day close (84)

### Actions exercised

- [x] Login + store selection
- [x] Dismiss day-close dialog (No)
- [x] **All 102 `SideBarController` indices (0–101)**
- [x] Prior sidebar text tour (`scripts/marionette_audit.ps1`)
- [x] Billing: add product (kitkat), price selection, stock selection, customer, payment, confirm order
- [ ] Create invoice end-to-end (blocked by ERR-001 account-types 404)
- [ ] Print receipt (not tested — no printer configured)

---

## Error Catalog

### ERR-001 — Invoice account types API returns 404

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Screen** | Store bootstrap (all screens after login) |
| **Console signature** | `[InvoiceProvider] Account types response: 404` |
| **API** | `GET /api/v1/transaction/get-account-types?type=invoice&store_id=2` |
| **HTTP** | 404 Not Found (Laravel HTML error page dumped to console) |
| **Source** | `lib/providers/invoice_provider.dart` → `listAllInvoiceAccountTypes()` |
| **Triggered by** | `StoreSessionProvider` / `SyncProvider` during store bootstrap |

**Impact:** Invoice creation, account-type dropdowns, and transaction modules that depend on prefetched account types will be empty or fail silently. In production this blocks invoice workflows entirely.

**Reproduction:**
1. Login as sales executive on demo server.
2. Select store ID 2.
3. Watch debug console during bootstrap (~5–10 s after store selection).
4. Observe 404 on `get-account-types`.

**Expected:** 200 with JSON account type list.  
**Actual:** 404 HTML page logged as `[InvoiceProvider] Account types error: <!DOCTYPE html>...`

---

### ERR-002 — Payment methods API returns 404

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Screen** | Store bootstrap |
| **Console signature** | `[InvoiceProvider] Payment methods response: 404` |
| **API** | `GET /api/v1/transaction/get-payment-methods?store_id=2` |
| **HTTP** | 404 Not Found |
| **Source** | `lib/providers/invoice_provider.dart` |
| **Triggered by** | Same bootstrap path as ERR-001 |

**Impact:** Invoice/voucher payment method lists unavailable for transaction screens.

**Reproduction:** Same as ERR-001; appears immediately after account-types 404.

---

### ERR-003 — Dashboard sales-stats API returns 500 (Laravel ErrorException)

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Screen** | Dashboard (index 1) |
| **Console signature** | `Sales stats response status: 500` → `Sales Stats Error 500: <!DOCTYPE html>... ErrorException` |
| **API** | `GET /api/v1/dashboard/sales-stats` |
| **HTTP** | 500 Internal Server Error (full Laravel debug page in console) |
| **Source** | `lib/providers/dashboard_provider.dart` → `fetchSalesStats()` |
| **Triggered by** | Opening Dashboard; `SalesExecutiveDashboard initState` fetches month period |

**Impact:** Dashboard KPI cards / sales statistics show empty or error state. `fetchSalesStats` rethrows after logging — depending on UI error handling, dashboard widgets may spin forever or show blank panels.

**Reproduction:**
1. Login → select store → navigate to **Dashboard**.
2. Console shows: `Fetching sales stats from: .../dashboard/sales-stats`
3. Followed by `Sales stats response status: 500` and Laravel stack trace HTML.

**Note:** Orders graph and customers graph APIs return **200** — only `sales-stats` fails.

---

### ERR-004 — Sales list fetched with hardcoded `store_id=1` (wrong store)

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Screen** | Sales menu tap (sidebar) |
| **Console signature** | `Query Parameters: {store_id: 1}` → `Status Code: 500` → `{"status":"failed","message":"No Orders Found","data":[]}` |
| **API** | `GET /api/v1/order/executive/list-orders?store_id=1` |
| **HTTP** | 500 (incorrectly used for empty result) |
| **Source** | `lib/widgets/side_menu.dart:529` and `lib/widgets/side_menu_mobile.dart:71` — hardcoded `storeId: 1` |
| **Workaround in app** | `SalesProvider` defensively treats 500 + "No Orders Found" as empty list |

**Impact:** Every Sales menu tap fires a failing API call before the correct `store_id=2` fetch. On a production server without this defensive handling, Sales screen could show errors or hang on loading. Wastes network; pollutes logs; masks real 500s.

**Reproduction:**
1. Login with store ID **2** selected.
2. Tap **Sales** in sidebar.
3. Console shows **two** fetch calls:
   - First: `store_id=1` → 500 "No Orders Found"
   - Second: `store_id=2&filter_store=2` → 200 success

**Fix direction:** Pass `active_store_id` from SharedPreferences instead of literal `1`.

---

### ERR-005 — SalesExecutiveProvider: user not in executives list

| Field | Value |
|-------|-------|
| **Severity** | Medium |
| **Screen** | Billing, Dashboard, any screen calling `getCurrentUser()` |
| **Console signature** | `❌ SalesExecutiveProvider: No executive found with userId 516. Error: Bad state: No element` |
| **Source** | `lib/providers/sales_executive_provider.dart:72-79` — `firstWhere` with no matching executive |
| **User** | Logged-in userId **516** (salesexecutiv2) |

**Impact:** Features that display executive name/phone from `SalesExecutiveProvider.getCurrentUser()` fall back to null. Billing still works (uses AuthModel separately) but executive-linked reports/labels may be blank.

**Reproduction:**
1. Login as `salesexecutive2@funzcart.in` (userId 516).
2. Open Billing or Dashboard.
3. Console repeats the Bad state message on each rebuild.

**Note:** Not a crash — caught and returns `null`. But indicates **data sync gap** between auth user list and sales executives API.

---

### ERR-006 — Day Close Pending dialog on every store entry

| Field | Value |
|-------|-------|
| **Severity** | Medium (UX / workflow blocker) |
| **Screen** | Immediately after store selection |
| **Console signature** | `Day close pending-status response: 200` → `pendingDayClose: true` |
| **UI** | Modal: *"You did not close your last day sales for 04-Sep-2026. Do you want to close it now?"* |
| **Source** | Store bootstrap day-close check |

**Impact:** Blocks all navigation until user answers Yes/No. In production, users who skip day close may hit this every shift start. Choosing **Yes** opens day-close flow; **No** allows continue but leaves pending state.

**Reproduction:**
1. Login → select store.
2. Dialog appears before main screen.
3. Dismiss with **No** to proceed.

---

### ERR-007 — Combined stock row shows zero available quantity

| Field | Value |
|-------|-------|
| **Severity** | Medium (data display) |
| **Screen** | Billing → add multi-stock product (kitkat) |
| **UI** | Stock picker: **Combined Stock (2 stocks)** shows `Available Quantity: 0.0` while individual Stock ID 499 shows `103.0` |
| **Console** | No exception — UI/logic issue |

**Impact:** User may think product is out of stock and pick wrong stock row, or abandon sale. Combined aggregation appears incorrect.

**Reproduction:**
1. Billing → tap quick product **kitkat / PCS**.
2. Select price tier (e.g. SAR 3).
3. Tap **Confirm Order** → stock selection modal appears.
4. Observe Combined Stock qty **0.0** vs Stock ID 499 qty **103.0**.

---

### ERR-008 — Payment shows "Not Configured" until panel opened

| Field | Value |
|-------|-------|
| **Severity** | Low (UX) |
| **Screen** | Billing → Finalize Order modal |
| **UI** | Payment tile shows **"Not Configured"** even though defaults exist; changes to **"Configured"** after tapping Payment and auto-filling card amount |

**Impact:** User may think payment is missing and not proceed. Not a console error.

**Reproduction:**
1. Complete billing flow to Finalize Order.
2. Before opening Payment panel, tile reads "Not Configured".
3. Tap Payment → card field pre-filled SAR 3.00 → tile updates to "Configured".

---

### ERR-009 — Sales API returns 500 for empty order list (backend smell)

| Field | Value |
|-------|-------|
| **Severity** | Low (mitigated client-side) |
| **Screen** | Sales (see ERR-004) |
| **Console signature** | `=== DEFENSIVE HANDLING: Treated 500 "No Orders Found" as empty list ===` |
| **API** | `list-orders` when no orders exist for store |
| **Source** | `lib/providers/sales_provider.dart:442-449` |

**Impact:** Client works around bad API design. Server should return 200 + empty array, not 500.

---

### ERR-010 — Widget dispose listener warning on screen swap

| Field | Value |
|-------|-------|
| **Severity** | Medium (lifecycle / stability) |
| **Screen** | Invoice list and most screens during rapid index navigation (observed on index **21** and across audit) |
| **Console signature** | `Error removing listeners: Looking up a deactivated widget's ancestor is unsafe.` |
| **Source** | Provider / `Listenable` cleanup during `SideBarController` index changes |

**Impact:** Not a red exception banner, but indicates listeners are removed after the widget tree is torn down. In production this can cause flaky state, missed updates, or hard-to-reproduce navigation bugs when switching modules quickly.

**Reproduction:**
1. Login → select store.
2. Run index sweep or rapidly switch sidebar modules (e.g. Billing → Invoice → Dashboard).
3. Console prints deactivated-widget ancestor warning.

---

### ERR-011 — Sales executive report order-details API returns 404

| Field | Value |
|-------|-------|
| **Severity** | Critical (report drill-down) |
| **Screen** | Sales Executive Report (index **58**), Admin Sales Executive Report (index **85**) |
| **Console signature** | `📥 ORDER DETAILS response status: 404` |
| **API** | Order details fetch triggered from sales executive report widgets |
| **HTTP** | 404 Not Found (Laravel HTML page) |

**Impact:** Report rows that depend on order detail enrichment will show incomplete data or fail silently. Blocks executive report drill-down on demo API.

**Reproduction:**
1. Navigate to **Sales Executive Reports** (sidebar index 58) or via index sweep.
2. Observe 404 in console when report loads related order details.

---

### ERR-012 — `setState` / Obx update during build (supplier transaction loader)

| Field | Value |
|-------|-------|
| **Severity** | Medium (framework warning — can cause rebuild loops) |
| **Screen** | Non Stock Report (**77**), Consumed Stocks Report (**80**), Expense List (**93**), and related report shells |
| **Console signature** | `Error loading supplier transaction data: setState() or markNeedsBuild() called during build.` … offending widget: **Obx** while **ListenableBuilder** is building |
| **Source** | Supplier transaction data load triggered synchronously during build |

**Impact:** Flutter allows this in some cases but it is unsafe — can cause missed frames, unstable UI, or infinite rebuild loops on slower devices.

**Reproduction:**
1. Navigate to **Non Stock Report**, **Consumed Stocks Report**, or **Expense** list.
2. Console prints build-phase Obx update warning on first load.

---

## Screens With Minimal New Error Signatures

These indices showed clean log tails (no matched 404/500/Bad state/build warnings beyond cumulative bootstrap buffer):

- **65** CustomerTransactionsReportScreen
- **67** SupplierTransactionReportScreen
- **98** StockReportScreen

Most other indices inherit cumulative bootstrap noise (ERR-001/002/005) from the Marionette log buffer not being cleared between navigations.

**Billing sale flow (prior pass):** Order confirmed successfully — `[Checkout] operation_ms=855 phase=confirmed`. No post-submit errors.

---

## What Was NOT Found

| Check | Result |
|-------|--------|
| Flutter `══╡ EXCEPTION CAUGHT BY` | None |
| `RenderFlex overflowed` | None |
| `Unhandled Exception` | None |
| `setState() called when widget tree was locked` | None |
| App hang / infinite spinner | None (after day-close dismissed) |
| Marionette disconnect | Stable on `ws://127.0.0.1:63701/JTrtmoRLY9k=/ws` |

---

## Recommended Fix Priority

1. **Backend:** Deploy/fix `get-account-types`, `get-payment-methods`, `sales-stats`, and order-details routes on demo API (ERR-001, ERR-002, ERR-003, ERR-011).
2. **Client:** Replace hardcoded `storeId: 1` in `side_menu.dart` / `side_menu_mobile.dart` (ERR-004).
3. **Client:** Defer supplier-transaction Obx updates to post-frame callback (ERR-012); fix listener disposal on sidebar navigation (ERR-010).
4. **Backend:** Return 200 + empty array instead of 500 for "No Orders Found" (ERR-009).
5. **Data:** Ensure logged-in users exist in sales executives list (ERR-005).
6. **UX:** Review day-close gating policy (ERR-006) and combined stock aggregation (ERR-007).

---

## Raw Log Artifacts

| File | Description |
|------|-------------|
| `docs/audit_logs/index_navigation_logs.txt` | Per-index (0–101) log dumps from full `SideBarController` sweep |
| `docs/audit_logs/index_coverage_summary.json` | Machine-readable nav status + error counts per index |
| `docs/audit_logs/full_navigation_logs.txt` | Per-screen log dumps from sidebar text-tap tour |
| Marionette VM | `ws://127.0.0.1:63701/JTrtmoRLY9k=/ws` |

---

## Re-run Instructions

```powershell
# 1. Start app in debug (Windows)
flutter run -d windows --target lib/main.dart

# 2. Find VM service URI (flutter run output or DDS process command line)
# Example: ws://127.0.0.1:63701/<token>/ws

# 3. Login manually or via Marionette (salesexecutive2@funzcart.in / 123456, store ID 2)

# 4. Full index sweep (all 102 screens)
dart run tool/sidebar_index_audit.dart "ws://127.0.0.1:PORT/TOKEN/ws"

# 5. Optional sidebar text tour
powershell -ExecutionPolicy Bypass -File scripts/marionette_audit.ps1

# 6. Single-screen navigate (Marionette MCP)
# call_custom_extension: cloudposAudit.navigate { "index": "58" }
```

**Login:** `salesexecutive2@funzcart.in` / `123456` → Store **متجر النجمة Store** (ID 2).
