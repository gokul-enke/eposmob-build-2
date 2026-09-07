# Arabic/GetX Translation Audit — Findings

Audited: all 101 screens registered in `lib/controllers/sidebar_controller.dart` (deduplicated to ~90
underlying files/classes) plus the 8 files you currently have uncommitted for delivery-method work.
100 read-only sub-agents (Haiku 4.5), one file/class each. Translation system is GetX `.tr()` against
`lib/resources/i18n/en.json` / `ar.json` — both files already have matching key sets (119 top-level
keys, no missing-in-either-file gaps), so **the risk is almost entirely per-screen: UI text that was
never wrapped in `.tr()` in the first place**, not JSON drift.

Legend: 🔴 whole screen/file essentially untranslated · 🟠 scattered hardcoded strings · 🟡 minor
(fallback placeholders, date-format hints) · ⚪ missing key (key referenced but not defined)

---

## 🔴 High priority — entire screens or large blocks never wrapped

| File | What's wrong |
|---|---|
| `lib/screens/print/printer_settings.dart` | Near **zero** `.tr()` calls. ~45 hardcoded strings (dialogs, snackbars, section titles, printer names). Matching keys already exist in en.json/ar.json but aren't used. |
| `lib/features/billing/presentation/widgets/checkout_modal.dart` | 37 hardcoded strings across the whole checkout flow: order summary rows, payment status tiles, customer fields, delivery labels, buttons (Close/Done/Next/Back). |
| `lib/features/billing/controllers/billing_mobile_ui_controller.dart` | Entire `BillingMobileErrorMessages` class (~30 error/snackbar strings) is hardcoded `static const`, never routed through `.tr()`. |
| `lib/screens/customer_profile/open_customer_profile.dart` + `widgets/customer_address_form_widget.dart` | ~40 hardcoded strings: tabs, sidebar buttons, all address-form labels/hints/buttons. |
| `lib/screens/sales/admin_daily_sales_close_list.dart` | Entire screen hardcoded — table headers, empty state, tooltips, mobile card labels. |
| `lib/screens/transactions/widgets/view_transaction_details.dart` | Entire screen hardcoded (14 strings) — no `view_transaction_details` section exists in i18n at all. |
| `lib/screens/transactions/widgets/view_voucher_details.dart` | Entire screen hardcoded (10 strings), same pattern. |
| `lib/screens/billing/restaurant/restaurant_page.dart` + `widgets/order_panel_saved_order_item.dart` + `widgets/tables_panel.dart` | ~20 hardcoded tooltips/errors/dialogs. High-impact: this screen backs sidebar slots 55, 89, **and** 97 (attender/billing/store modes). |
| `lib/screens/billing/mobile_screen/widgets/billing_widget.dart` + `lib/features/billing/presentation/pages/billing_page.dart` | ~27 hardcoded strings — order summary, payment breakdown, tax dialogs. |
| `lib/providers/billing_provider.dart` | ~19 hardcoded strings, several where a matching key **already exists** in en.json but isn't called. `getPaymentLabel()` hardcodes "Cash"/"Card"/"UPI"/"COD"/"Online" in English regardless of locale. |
| `lib/screens/suppliers/supplier_list.dart` | 17 hardcoded strings — the supplier-detail modal duplicates content from `supplier_details.dart` but doesn't reuse its (correct) translation keys. |
| `lib/screens/product/tabbar_for_add_new_product.dart`, `tabbar_for_edit_product.dart`, `widgets/view_product.dart` | Same bug copy-pasted 3×: "All Products", tab labels (Primary Details/Product Names/Product Properties/Image-Video) hardcoded in all three. |
| `lib/screens/transactions/receipt_voucher.dart` (`VoucherListScreen`) | 12 hardcoded strings; "Sender"/"Beneficiary" don't even have translation keys defined anywhere. |
| `lib/screens/purchase/widgets/create_purchase_order.dart` | 12 hardcoded validation error messages. |

## 🟠 Your active delivery-method work (uncommitted files)

Directly relevant since this is what you asked about:

| File | Finding |
|---|---|
| `lib/models/delivery_method.dart`, `lib/helpers/delivery_method_display.dart`, `lib/models/delivery_method_registry.dart` | ✅ **Clean.** Correctly resolve labels from the `translations` map first, fall back to bundled `.tr()` keys, branch on stable `code`/`kind` — matches the contract in `TRANSLATION_AGREED_SCOPE.md`. |
| `lib/features/billing/presentation/widgets/delivery_method_modal.dart` | 4 hardcoded: "Car Number:", "Comment:", "Choose an address:", "Address:" hints. |
| `lib/screens/billing/mobile_screen/widgets/delivery_options_section.dart` | 11 hardcoded: loading/empty states, all field labels ("Car Number:", "Delivery Date:", "Delivery Time:", "Comment:"), all hints. |
| `lib/features/billing/presentation/widgets/quick_access_bar.dart` | 4 hardcoded: "Applied"/"Discount" toggle, "Total Paid:", "Balance:" — matching keys already exist under `billing.*`. |
| `lib/providers/delivery_methods_provider.dart` | "Store Takeaway" fallback object not run through translation (keys exist: `billing.store_takeaway`, `common.store_takeaway`). |
| `checkout_modal.dart` (see above) | Also has delivery-specific hardcoded hints: "Car Number:", "Comment:", "Address:", "Delivery Charge". |

**Net:** the new delivery-method *data layer* (models/helpers) was built correctly, but none of the
*UI* that consumes it (modal, options section, checkout, quick access bar) was updated to actually
call `.tr()` on its own labels yet.

## 🟠 Medium — scattered hardcoded strings (a handful per file)

`view_product.dart`/`tabbar_for_edit_product.dart` (dup, see above) · `open_customer_profile` (see above) ·
`transaction_list.dart` (mobile empty-state duplicates a desktop view that's correctly translated) ·
`add_customers.dart` ("All Customers", "Add New Customer" — key exists, unused) ·
`stock.dart` (AddStockScreen: dropdown items, dialog title, snackbar) ·
`add_product_stock.dart` ("Qty"/"MRP" headers) · `add_product.dart` (5× "N/A" fallbacks) ·
`sales.dart` (date-format hint ×5) · `sales_order_details.dart` (error messages, PDF/email text, fallbacks) ·
`company_accounts.dart` (error message, 3× fallback) · `company_info.dart` (fallback email ×3, name fallback) ·
`whatsapp_settings.dart` (default message text, hint) · `open_supplier_profile.dart` ("ID: " prefix ×2) ·
`customer_transaction_details_screen.dart` (dropdown option lists) · `supplier_transaction_details_screen.dart` (dropdown option lists) ·
`create_customer_voucher.dart` / `create_supplier_voucher.dart` (validator text, dead-code dropdown) ·
`product_barcode.dart` ("MRP" label, "All Categories" sentinel ×6) · `daily_sales_close_detail.dart` (payment type/method labels never translated) ·
`purchase_orders.dart` (permission message, date hint) · `quotations_list.dart` / `proforma_invoice_list.dart` (status-filter option lists) ·
`create_purchase_return.dart` (Previous/Next pagination) · `stock_report.dart` ("PCS" fallback ×2) ·
`expense_list_screen.dart` ("All" filter default ×4, one snackbar) · `view_expense_screen.dart` ("Dr."/"Cr." prefixes, month abbreviations) ·
`offline_data_page.dart` (snackbar text, store fallback) · `settings.dart` (hardcoded "العربية" label — likely intentional, worth a quick look) ·
`sales_return.dart` / `sales_return_list.dart` (one error message, "Unknown" fallback ×2) · `edit_order.dart` (one success snackbar) ·
`kitchen_master.dart` (one fallback, cooking-time unit suffix) · `receipt_list.dart` ("N/A" fallback) ·
`company_accounts` add screen (dropdown option arrays — Cash/Bank/Store 1-3/Account 1-3/payment methods) ·
`admin_sales_executive_report.dart` / `sales_executive_report.dart` (date-format hint ×2 each) ·
`non_stock_report.dart` ("-"/"0" fallbacks — likely fine, flagged for consistency).

## ⚪ Missing translation keys (referenced but undefined)

- `receipt_voucher.dart`: "Sender" and "Beneficiary" table headers have no key anywhere in en.json/ar.json.

## ✅ Clean — no issues found

`billing_page_responsive.dart`, `dashboard.dart`, `support.dart`, `customers.dart`, `add_category.dart`,
`add_category_properties.dart`, `add_category_screen.dart`, `edit_category_screen.dart`, `view_category.dart`,
`purchase.dart`, `add_purchase.dart`, `purchase_voucher.dart`, `view_purchase.dart`, `view_voucher.dart`,
`add_voucher_details.dart`, `view_invoice.dart`, `view_receipt_details.dart`, `account_book.dart`,
`product_sales_report.dart`, `sales_report.dart`, `supplier_sales_report.dart`, `location_managment.dart`,
`category_list.dart`, `home_new.dart`, `confirmed_orders.dart`, `supplier_details.dart`,
`account_details_screen.dart`, `add_company_account.dart` (minus dropdown arrays noted above),
`customer_voucher_list.dart`, `supplier_voucher_list.dart`, `daily_sales_close_list.dart`,
`consumed_stocks_report.dart` (minus "#" prefix), `supplier_transaction_report.dart`,
`billing_quotation_page_responsive.dart`, `quotation_details.dart`, `create_expense_screen.dart`,
`stock_details.dart`, `add_voucher_details.dart`, `delivery_method.dart`, `delivery_method_display.dart`,
`delivery_method_registry.dart`.

---

## Suggested next step

Given the volume, the highest-leverage fix order is:
1. `checkout_modal.dart` + `billing_mobile_ui_controller.dart` + `billing_provider.dart` — core billing flow, biggest single blocks, and directly touches your active delivery-method PR.
2. The delivery-method UI files (`delivery_method_modal.dart`, `delivery_options_section.dart`, `quick_access_bar.dart`) — small diffs, finishes what you're already mid-way through.
3. `printer_settings.dart` and `restaurant_page.dart` — largest remaining full-screen gaps.
4. Everything else in the 🟠 medium list, batched by screen.
