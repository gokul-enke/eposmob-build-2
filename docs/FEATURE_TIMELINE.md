# Feature Timeline

Where each screen stands in the move to the feature architecture
(`lib/features/<feature>/{domain,data,presentation}`) and the shared UI kit
(`lib/core/ui/ui.dart`: `ListPageScaffold`, `FilterPanel`, `AppDataTable`,
`AppAdaptiveList`, `DetailPageScaffold`, tokens). `features/customers` is the
reference template.

Snapshot: 2026-10-27, branch `gokul-dev` (level with `origin/staging`).

**Legend**

- Architecture / UI: ✅ done · 🟡 partial · ❌ not started
- Size, by lines of legacy code to move: **S** < 400 · **M** 400–1,200 ·
  **L** 1,200–3,000 · **XL** > 3,000
- Sidebar slot = index in `SideBarController.screens`. Never remove a slot;
  point it at the new page instead.

---

## 1. To do, ranked smallest first

Hand these out from the top. S and M items fit a junior developer. Keep L and
XL for experienced developers, and split them first.

| # | Size | Area | Screen | Legacy files (`lib/screens/…`) | Lines | Architecture | UI | To do |
|---|---|---|---|---|---|---|---|---|
| 1 | S | Cleanup | Dead code (nothing imports it) | `transactions/invoice_list_mobile.dart`, `transactions/receipt_list_mobile.dart`, `sales/widgets/create_quotation_screen.dart`, `dashboard/dashboard_ui_only.dart`, `billing/billing_page_restaurant.dart`, `billing/billing_page_desktop.dart`, `billing/mobile_screen/**` | ~14,800 (delete) | – | – | Confirm each has no references, delete it, then run `flutter analyze` and the full tests |
| 2 | S | Support | Support | `support/support.dart` | 50 | ❌ | ❌ | Create `features/support` and use the shared page scaffold |
| 3 | S | Categories | Category properties + View category (slots 13, 27) | `category/add_category_properties.dart`, `category/widgets/view_category.dart` | 236 | 🟡 | ❌ | Move into `features/categories` (list/add/edit are done there) |
| 4 | S | Orders | Cart / pending orders (slot 3) | `cart/cart_list.dart`, `cart/widgets/pending_order_widget.dart` | 337 | ❌ | ❌ | Create `features/cart` and use `ListPageScaffold` + `AppAdaptiveList` |
| 5 | S | Notifications | Notifications (slot 7) | `notifications/**` | 358 | ❌ | ❌ | Create `features/notifications` with a repository and a list page on the kit |
| 6 | M | Loyalty | Loyalty card (slot 6) | `loyality_card/loyality.dart` | 415 | ❌ | ❌ | Create `features/loyalty`, using the customers loyalty widgets for reference |
| 7 | M | Transactions | Old detail views: invoice, receipt, transaction (slots 31, 48, 30) | `transactions/widgets/view_invoice.dart`, `view_receipt_details.dart`, `view_transaction_details.dart` | 457 | 🟡 | ❌ | The features already have details dialogs. Point the slots or callers at them, then delete the old files |
| 8 | M | Reports | Account Book (slot 39) | `reports/account_book/account_book.dart` | 453 | ❌ | ❌ | Move into `features/reports` with the same pattern as the stock report |
| 9 | M | Reports | Sales Report (slot 41) | `reports/sales_report/sales_report.dart` | 480 | ❌ | ❌ | Move into `features/reports` and export through `ExportController` |
| 10 | M | Reports | Supplier Sales Report (slot 42) | `reports/supplier_sales_report/supplier_sales_report.dart` | 482 | ❌ | ❌ | Move into `features/reports`. It is nearly a copy of #9, so do it right after |
| 11 | M | Invoices | Create new invoice, full page (slot 24) | `transactions/widgets/create_new_invoice.dart` | 496 | 🟡 | ❌ | The feature has `invoice_create_dialog`. Reuse it, retire the page, and keep the slot |
| 12 | M | Settings | Company info + Location management (slots 64, 43/44) | `settings/company_info.dart`, `settings/location_managment/**` | 616 | ❌ | ❌ | Create `features/settings` and use the form widgets from `core/ui/form` |
| 13 | M | Products | View product (slot 28) | `product/widgets/view_product*.dart`, `view_primary_details.dart`, `view_image_or_video.dart` | 761 | ❌ | ❌ | Move into `features/products` and use `DetailPageScaffold` |
| 14 | M | Settings | WhatsApp settings (slot 63) | `settings/whatsapp_settings.dart` | 461 | ❌ | ❌ | Add to `features/settings` (after #12) |
| 15 | M | Stock | Stock details + adjust / move / withdraw modals (slot 33) | `product/widgets/stock_details.dart`, `adjust_stock_modal.dart`, `move_stock_modal.dart`, `withdraw_stock_modal.dart` | 1,303 | 🟡 | ❌ | Move into `features/stock/presentation/widgets` (the list is done there) |
| 16 | M | Barcodes | Barcode details / print modal / mobile filters | `product/widgets/product_barcode_responsive.dart`, `confirm_barcode_print_modal.dart`, `barcode_mobile_filters.dart` | 1,266 | 🟡 | ❌ | Move into `features/product_barcodes` (it still imports `product_barcode_responsive.dart`) |
| 17 | M | Quotations | Quotation details (slot 88) | `sales/widgets/quotation_details.dart`, `build_quotation_details_widget.dart`, `quotations_responsive.dart` | 1,182 | 🟡 | ❌ | Move into `features/quotations` and use `DetailPageScaffold`. Move `test/quotations_responsive_test.dart` with it |
| 18 | L | Profile | My profile + change password (slot 10) | `profile/**` | 1,442 | ❌ | ❌ | Create `features/profile`. Can be split into view / edit / change password |
| 19 | L | Vouchers | Old voucher list / create / details / add-details (slots 22, 25, 32, 37) | `transactions/receipt_voucher.dart`, `widgets/create_new_voucher.dart`, `view_voucher_details.dart`, `add_voucher_details.dart` | 2,071 | 🟡 | ❌ | `features/vouchers` already has the new pages. Point these slots at them, move the remaining logic, then delete |
| 20 | L | Accounts | Company accounts list / add / details (slots 59–61) | `transactions/company_accounts/**` | 2,216 | ❌ | ❌ | Create `features/company_accounts` (list → add → details). Split into 3 tasks |
| 21 | L | Settings | Settings home + offline data (slots 62, 96) | `settings/settings.dart`, `widgets/settings_responsive.dart`, `widgets/offline_data_page.dart` | 2,938 | ❌ | ❌ | Add to `features/settings` after #12 / #14 |
| 22 | L | Edit order | Edit order (slot 51) | `edit_order/edit_order.dart` | 2,371 | ❌ | ❌ | Move into `features/sales` (orders). Needs billing knowledge |
| 23 | L | Login | Login, API key, base URL, forgot/reset password, store selection | `login/**` | 2,418 | ❌ | ❌ | Create `features/auth`. Risky: test every login path on all platforms |
| 24 | L | Kiosk | Legacy kiosk shell, order and billing pages, FAQ/terms/privacy | `kiosk/**` | 2,397 | 🟡 | ❌ | `features/kiosk` has the new pages. Move the rest, then add a README and tests |
| 25 | L | Home | Legacy home (slots 45, 46) | `home/**`, `homenew/**` | 2,207 | ❌ | ❌ | First check whether these slots are still reachable. If not, delete them instead of migrating |
| 26 | XL | Products | Add / Edit product (slots 17, 35) | `product/tabbar_for_*.dart`, `widgets/add_product/**`, `widgets/edit_product/**` | ~6,100 | ❌ | ❌ | Move into `features/products` and share one form for add and edit. Split by tab |
| 27 | XL | Dashboard | Dashboards: admin, company admin, sales executive | `dashboard/**` | 7,425 | ❌ | ❌ | Create `features/dashboard`. Split per role |
| 28 | XL | Products | Add product stock (slot 18) | `product/widgets/add_product_stock.dart` (+ `stock_responsive.dart`) | 8,525 | ❌ | ❌ | One very large file. Plan the split before giving it to anyone |
| 29 | XL | Billing | Restaurant page + Kitchen master (slots 55, 56, 89, 97) | `billing/restaurant/**`, `billing/kitchen_master.dart`, `restaurant/widgets/**` | ~21,000 | ❌ | ❌ | Senior developer only. `order_panel.dart` alone is 8,500 lines |
| 30 | XL | Print | Receipt / PDF / KOT / barcode printing | `print/**` | ~89,000 | ❌ | n/a | Out of scope for the UI kit. Keep the separate print-layout plan |

## 2. Moved into features, still needs work

| Area | Feature | Screens | Architecture | UI | To do |
|---|---|---|---|---|---|
| Billing | `billing` | Billing page (desktop/mobile/responsive), Quotation billing, Add product (mobile) | ✅ | 🟡 | Only 3 tests. Add tests. A POS screen does not need the list kit |
| Kiosk | `kiosk` | Welcome, Home, Product options, Cart review, Payment, Success / Failure, Order details | ✅ | 🟡 | No README, no tests, does not use `core/ui` (see #24) |
| Admin report | `reports` | Admin sales executive report (slot 85) | 🟡 | ✅ | The 208-line wrapper in `reports/sales_executive_report/` still holds store/role fallback logic. Move it into the feature |
| Offers | `offers` | – (service only) | ✅ | n/a | None |
| Realtime sync | `realtime_sync` | – (service only) | ✅ | n/a | Add a README |
| Weigh machine | `weigh_machine` | Export page (slot 101) | ✅ | 🟡 | Add a README |
| Subscription | `subscription` | – | ✅ | n/a | Add a README and tests |

## 3. Done (architecture + UI)

| Area | Feature | Screens | Architecture | UI | Tests | To do |
|---|---|---|---|---|---|---|
| Customers | `customers` | Customers list, Add/Edit customer, Customer profile (info, orders, transactions, loyalty, chat, purchase history) | ✅ | ✅ | 30 | None (reference template) |
| Suppliers | `suppliers` | Suppliers list, Supplier profile | ✅ | ✅ | 14 | None |
| Categories | `categories` | Category list, Add category, Edit category | ✅ | ✅ | 6 | Rest is in #3 |
| Products | `products` | Product list | ✅ | ✅ | 6 | Rest is in #13, #26, #28 |
| Barcodes | `product_barcodes` | Barcode list | ✅ | ✅ | 4 | Rest is in #16 |
| Stock | `stock` | Stock list | ✅ | ✅ | 4 | Rest is in #15 |
| Sales | `sales` | Sales list, Online sales, Sales order details, Confirmed orders, Daily sales close list + detail, Admin daily sales close list | ✅ | ✅ | 17 | None |
| Sales returns | `sales_returns` | Sales return list, Create sales return, Return detail | ✅ | ✅ | 15 | None |
| Quotations | `quotations` | Quotation list | ✅ | ✅ | 5 | Rest is in #17 |
| Invoices | `invoices` | Invoice list, Create invoice dialog, Invoice details | ✅ | ✅ | 3 | Rest is in #7, #11 |
| Receipts | `receipts` | Receipt list, Create receipt dialog, Receipt details | ✅ | ✅ | 3 | Rest is in #7 |
| Proforma | `proforma_invoices` | Proforma list, Proforma details | ✅ | ✅ | 2 | None |
| Customer ledger | `customer_ledger` | Customer transactions list | ✅ | ✅ | 2 | None |
| Supplier ledger | `supplier_ledger` | Supplier transactions list | ✅ | ✅ | 2 | None |
| Vouchers | `vouchers` | Customer voucher list + create, Supplier voucher list + create | ✅ | ✅ | 8 | Rest is in #19 |
| Expenses | `expenses` | Expense list, Create expense, View expense | ✅ | ✅ | 15 | None |
| Purchases | `purchases` | Purchase order list, Create PO, Purchase, Add purchase, Purchase details, Purchase voucher + details | ✅ | ✅ | 14 | Remove the `legacy_*` widgets once nothing uses them |
| Purchase returns | `purchase_returns` | Purchase return list, Create, Details | ✅ | ✅ | 7 | None |
| Day close | `day_closes` | Day close list, Admin day close list | ✅ | ✅ | 4 | None |
| Reports | `reports` | Admin executive, Product sales, My sales, Stock, Non-stock, Consumed stocks, Customer transactions + details, Supplier transactions + details | ✅ | ✅ | 44 | Rest is in #8–#10 |
