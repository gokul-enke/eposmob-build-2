# Translation Review

Language under test: Malayalam (`ml`)

This file contains only English text that is dynamic, tenant-configured, API-provided,
user-entered, product/catalog data, printer/configuration data, or intentionally preserved
as a language identifier. Static UI labels found during the audit are being fixed in code
instead of being listed here.

## Dynamic or externally supplied English values

| Exact source | Line | Runtime value / reason |
|---|---:|---|
| `lib/providers/delivery_methods_provider.dart` | 35-39 | Fallback delivery method label is created from the translation key, but API delivery methods can still return English names such as `Door Delivery`, `Store Takeaway`, `Car Delivery`, `Third Party logistics`, `Hungerstation`, and `Dine In`. Do not replace these blindly; resolve the API `translations` payload or backend locale coverage. |
| `lib/models/delivery_method.dart` | 156-160 | `DeliveryMethod.label` resolves the active API translation and falls back to the server `name`; the rendered label is dynamic tenant data. |
| `lib/helpers/delivery_method_display.dart` | 70-87 | Backend translations intentionally take precedence over bundled labels because tenants may rename delivery methods. |
| `lib/providers/sales_provider.dart` |  — | Sales/order/customer names, statuses, and messages are API data and must not be translated as static UI text. Verify each rendered field against its API `translations` payload when reviewing a specific record. |
| `lib/providers/local_product_provider.dart` |  — | Product names, item codes, units, and catalog descriptions are tenant/catalog data. English product values visible in billing are not evidence of a missing UI translation. |
| `lib/widgets/store_switcher.dart` |  — | Store names and addresses are account/store data. Examples observed: `Store NAME`, `Al Hamra`, and `Al Zahra`. |
| `lib/widgets/user_switcher.dart` |  — | User names and email addresses are account data. Example observed: `salesexecutiv2@funzcart.in`. |
| `lib/screens/print/widgets/receipt_configuration_workspace.dart` | 548, 583 | `English` is a receipt configuration column/variant label, not an app-language UI sentence. It should remain available when configuring bilingual receipts. |
| `lib/screens/settings/settings.dart` | 633 | `English` is intentionally hardcoded in the language selector so users can identify the language in its native name, regardless of the currently selected locale. Arabic and Malayalam follow the same rule. |
| `lib/screens/print/printer_settings.dart` | 70-86 | Receipt-theme names (`Classic`, `Premium`, `Bilingual`, etc.) are configuration identifiers/options. Review separately if product requirements require localized option names. |
| `lib/screens/print/layouts/standard_receipt_layout.dart` | 83 | Receipt output language (`English`, `Arabic`, `Bilingual`) is derived from receipt configuration and is diagnostic/print-layout data, not the app chrome. |
| `lib/screens/print/thermal/thermal_printer.dart` | 508 | Printed receipt language/source diagnostic is derived from printer configuration and app locale. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 956-957, 7823-7824 | `DeliveryMethodRegistry.defaultMethod?.name` and the fallback `Store Takeaway` represent delivery-method data; do not replace the value without confirming the selected method and backend translations. |
| `lib/screens/billing/billing_page_restaurant.dart` | 1855, 6880 | Selected/default delivery-method names may come from API/store configuration; the fallback is used in order state and should be reviewed with delivery-method backend behavior. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 312, 407, 447, 1223, 3115 | Delivery-method names are persisted order/API values or a fallback object; changing them blindly could alter order semantics. |
| `lib/features/billing/controllers/billing_mobile_controller.dart` | 322, 406 | Current/default delivery-method names are order/provider data. |
| `lib/screens/billing/mobile_screen/widgets/home_widget.dart` | 606 | Current order delivery method is dynamic order data. |
| `lib/providers/billing_provider.dart` | 2902 | `Store Takeaway` is used as a provider fallback value and needs a coordinated delivery-method translation/data-layer review. |
| `lib/features/billing/presentation/widgets/checkout_modal.dart` | 3853-3904 | The button labels are supplied through `confirmButtonTitle` and `printButtonTitle`; the values can be mode-specific and are now translated at the callers. Any remaining English value here is caller/configuration supplied, not safe to replace inside the shared widget. |
| `lib/screens/print/printer_settings.dart` | 70-86, 855, 896 | Paper sizes and receipt-theme names are configuration options/identifiers (`112mm`, `A4`, `Classic`, `Bilingual`, etc.), not ordinary prose. |

## Static items fixed during this audit

- Sidebar collapse/expand tooltip: `lib/widgets/side_menu.dart:212-219`
- Keyboard-shortcut tooltip: `lib/features/billing/presentation/pages/billing_page.dart:2556`,
  `lib/screens/billing/billing_page_restaurant.dart:2657`, and
  `lib/features/billing/presentation/widgets/header.dart:95`
- Font-size tooltip prefix: `lib/features/billing/presentation/pages/billing_page.dart:2598`
  and `lib/screens/billing/billing_page_restaurant.dart:2699`
- Font-size tooltip translation key: added the missing `billing.font_prefix` entries to
  `lib/resources/i18n/en.json` and `lib/resources/i18n/ml.json` after live verification
  exposed the raw key `billing.font_prefixSmall`.
- Confirm/confirm-and-print actions: `lib/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart:302-362`,
  `lib/widgets/billing_sidebar_footer.dart:514`, and
  `lib/screens/billing/billing_page_restaurant.dart:1914-1919`
- Customer-copy prompt: `lib/features/billing/presentation/pages/billing_page.dart:9362-9363`,
  `lib/screens/billing/billing_page_restaurant.dart:6905-6906`,
  `lib/screens/billing/restaurant/widgets/order_panel.dart:6888-6889`, and
  `lib/features/billing/controllers/billing_mobile_controller.dart:1475-1476`
- Multi-sale-unit error: `lib/screens/billing/billing_page_restaurant.dart:1636`
- Cash-drawer tooltip fallback: `lib/widgets/open_cash_drawer_button.dart:14-18, 54-58`
- Printer disabled-note: `lib/screens/print/printer_settings.dart:1008-1010`
- Unsaved quotation-customer notice: `lib/features/billing/presentation/widgets/checkout_modal.dart:1674-1680`

## Route-level findings still requiring additional passes

The route audit identified the following confirmed static UI literals beyond the fixes
above. They remain in scope for subsequent implementation batches; they are listed
here with exact source locations so they are not lost between passes:

| Exact source | Lines | Static English still requiring localization |
|---|---:|---|
| `lib/features/billing/presentation/pages/billing_page_mobile.dart` | 701, 1026, 1169-1171, 1188 | Fixed during this pass via existing/new `billing` and `order_list` keys |
| `lib/features/billing/presentation/widgets/customer_input.dart` | 54, 273 | Fixed during this pass via `billing.phone_number_hint` and `billing.enter_mobile_number` |
| `lib/features/billing/presentation/widgets/mobile/home/market_home_widget.dart` | 203, 268, 276, 284, 390-391, 584 | Fixed during this pass via `billing.search_products`, view-mode keys, loading keys, and `billing.barcode` |
| `lib/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart` | 263-308, 465, 504, 559, 567, 681, 770, 964, 1496, 1564, 1639, 1657, 1665, 1716, 1724 | Static auth/barcode/translation/permission/stock messages and product-entry hints |
| `lib/features/billing/presentation/widgets/mobile/billing/delivery_options_sheet.dart` | 40, 64-65 | Fixed during this pass via `billing.select_delivery_method` and `billing.done` |
| `lib/features/billing/presentation/widgets/mobile/billing_tab.dart` | 402, 415 | Fixed during this pass via `billing.select_delivery_method` and `billing.coupon` |
| `lib/features/billing/presentation/widgets/mobile/orders/order_stat_card.dart` | 75, 90 | Fixed during this pass via `billing.active_orders` and `billing.ready_for_pickup` |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 2577-2600, 3393-3420, 3943-3960, 5143, 5194, 5597, 5660, 5739, 5832-5850, 5977-5985 | Order-panel UI labels localized via `order_panel.*`; order numbers and runtime response/error details remain dynamic |
| `lib/features/billing/presentation/widgets/coupon_modal.dart` | 195-261, 320, 410, 499, 506, 511, 550, 580, 650, 710, 749, 805, 822 | Fixed during this pass via `coupon.*` and `general.skip`/`general.clear` keys; coupon names remain dynamic |
| `lib/features/billing/presentation/widgets/payment_method_modal.dart` | 1629-1630, 1709, 1763-1805, 1844-1847, 2284, 2793, 2989, 3435-3451 | Fixed during this pass via `billing.*`; amounts/currency and payment method codes remain dynamic |
| `lib/features/billing/presentation/widgets/product_variant_details_section.dart` | 57, 140-143, 202-211 | Fixed during this pass via `product_detail.*`; SKU/variant IDs/supplier values remain data |
| `lib/features/billing/presentation/widgets/pos_security_key_dialog.dart` | 106, 109 | Fixed during this pass via `security_key.*`; action text is runtime context |
| `lib/screens/transactions/invoice_list_mobile.dart` | 145, 179, 316, 352-392, 478-484, 564 | Fixed during this pass via `invoice.*`; invoice values/statuses remain data |
| `lib/screens/transactions/widgets/customer_voucher_print.dart` | 328, 400, 554, 625 | Loading, paper/printer, scan, and empty-state labels localized via `voucher_print.*`; printer names/addresses remain device data |
| `lib/screens/transactions/widgets/supplier_voucher_print.dart` | 418, 458, 507, 542, 551, 680, 706, 727 | Printer selection/list/scan labels localized via `voucher_print.*`; printer names/addresses remain device data |
| `lib/widgets/side_menu.dart` | 1172, 1183, 1230 | Fixed during this pass via `general.logged_out_successfully`, `general.logged_out_locally`, and `general.default_name` |

## Verification notes

- Malayalam was selected through Settings and verified in the running app.
- The app was restarted after the code changes; the main billing page rendered Malayalam labels.
- The pending day-close prompt was dismissed without changing demo data.
- The running demo displayed an English `Store Takeaway` delivery label; this is recorded above as API/config/order data.
- Final live verification after the locale restart reached the authenticated billing shell and then the dashboard in Malayalam. The shell showed Malayalam sidebar labels, Malayalam billing headings/actions, and `ഫോണ്ട്: Small`; dashboard headings/cards also rendered in Malayalam. English values observed there (`salesexecutiv2`, email, `SAR`, ZATCA, numeric metrics) are account/domain/data values.
- A source sweep after the live verification localized the invoice email-search hint (`lib/screens/transactions/invoice_list.dart:1443`) and the restaurant order-panel error prefix (`lib/screens/billing/restaurant/widgets/order_panel.dart:3565`), then hot reloaded successfully.
- Additional live route checks reached Category List and Product List in Malayalam. Their titles, search/reset controls, table headings, pagination controls, and action labels rendered in Malayalam; English category/product names, slugs, units, SKUs, and barcodes were catalog/API values and remain review-only.
- Further live checks reached the sidebar's expanded route groups: Suppliers, Supplier Transactions/Vouchers, Printer, Settings, Customers, and Party Accounts. Visible headings, filters, table columns, reset/pagination controls, and status labels rendered in Malayalam. English supplier/customer names, email addresses, invoice/reference IDs, dates, amounts, `N/A`, store identifiers, and `2025 CloudPOS App` remain runtime/account/device/version data.
- The Party Accounts submenu was expanded and Customer Transactions was opened live. Its title, filters, date selector, reset action, table headings, debit/credit/status labels, and pagination rendered in Malayalam. Customer names, invoice/reference numbers, dates, amounts, and store text remained transaction/account data.
- A fresh Windows debug rebuild completed successfully and Marionette reconnected to the new VM service. Hot reload then failed at the VM service (`Unable to reload sources`), so the source fixes are present and locale JSON is valid, but this latest batch needs a subsequent reload/restart verification once the VM is stable.
- Source sweep follow-up fixed static labels in customer forms, shared confirmation/mobile sheet controls, stock confirmation headers, billing customer-copy prompts, restaurant order-panel errors, and standard PDF/return-bill preparation and success messages. Remaining English printer names, device/API errors, report/document output labels, and runtime data are intentionally retained and should be reviewed as dynamic/configuration output.
- The current source sweep also found and fixed static product-media form labels (`Title`, `Alt`, `File`, `Is Primary`, `Attachment`), the purchase-details permission fallback, and remaining shared mobile close controls. These fixes require a successful reload/revisit for final runtime confirmation.
- A follow-up scan found additional standard-PDF workflow messages (`PDF opened for printing`, `PDF shared. Please open it to print`, and PDF-generation failures) in customer/supplier voucher and transaction-report printers. These are now translation-backed; printed document field labels (`Date`, `Payment`, `Name`, `Phone`, totals, signatures, and amount-in-words) remain separately classified as receipt/PDF template output rather than app chrome.
- The latest source pass localized remaining app-facing failures in mobile order cancellation, restaurant cart quantity/removal/clear/draft actions, and supplier creation. Printer-layout “print job sent” messages and receipt/PDF labels remain document/device output and are not blindly translated; their exact source locations remain represented by the print-output review entries above.
- The live report-printer pass found and localized the customer/supplier printer-selection buttons (`Select`/`Selected`), printer permission prompt, printer screen headings, scan/loading/empty states, device-count text, retry action, and report print/share actions. Hot reload completed successfully; report rows and printer/device values remain dynamic.
- The live purchase-return pass verified the return list, voucher item-selection screen, and dynamic item values in Malayalam. A purchase-order validation fallback (`Selected item`) was also localized with `purchase_order.selected_item`; the product name remains dynamic.
- The current pass also localized PDF-generation fallbacks in the standard print/report/voucher flows and printer-target feedback (`Voucher sent to @printer`). The `@printer` value is intentionally dynamic OS/device data.
- After the rebuild reported missing GetX extensions and nullable printer names in the supplier/customer voucher printer paths, the required imports and null-safe placeholder handling were corrected. Hot reload completed successfully afterward; the only remaining diagnostics in those paths are unrelated pre-existing unused-variable warnings.
- A clean Windows rebuild now completes successfully and exposes the new VM service. Marionette reconnected successfully; the initial route is the Malayalam login screen with Malayalam “Login”, “Remember me”, “Continue”, and keyboard controls visible. The authenticated route audit must continue by signing in again after this rebuild.
- After signing in and selecting the first demo store, the pending day-close prompt rendered in Malayalam and was dismissed. The authenticated billing shell was verified live: sidebar labels, billing actions, keyboard/font/cash-drawer tooltips, cart headers, totals, and saved-order controls rendered in Malayalam. `Store Takeaway`, product names, SKUs, prices, currency, user/email, and store name remained runtime/configuration/catalog data.
- The Category List route was opened live from the authenticated sidebar. Its title, add/search/reset controls, table headings, and pagination rendered in Malayalam. Category names and slugs such as `Chicken Buckets`, `Juice`, `Fried chicken`, `Burgers`, `Beverages`, and `Bath and body care` remained catalog/API values.
- The Product List route was opened live from the authenticated sidebar. Product-list controls and headings rendered in Malayalam. Product names, category names, unit codes (`PCS`, `PC`, `FT`, `NOS`), SKUs/barcodes, and prices remained catalog/API/domain data.
- The Purchase route was opened live. Purchase-list controls, headings, pagination, and action labels rendered in Malayalam. Supplier/product names, `General Item`, `N/A`, quantities, currency values, prices, dates, and status/data fields remained purchase/catalog/API values.
- Do not treat English account names, product names, store names, email addresses, currency codes, receipt-config values, or language identifiers as missing static translations.
- The second route-level fix batch was hot-restarted successfully in Malayalam. The running app exposed the expected Malayalam keyboard tooltip after restart.
- The coupon, invoice-list, variant-stock, and POS security-key static labels were localized and lint-checked successfully. Dynamic coupon names, invoice values/statuses, variant IDs/SKUs, and security-key action text remain runtime data/context.
- A further source sweep found additional mobile billing labels and localized the bottom navigation, cart actions, coupon section, quotation customer fields, and product-card action semantics. These changes were lint-checked successfully.
- The latest mobile-component pass localized dining selection labels, cart price/tax labels, variant-picker copy, coupon-sheet title, product-grid/cart action semantics, and corresponding Malayalam keys. These changes were hot-restart verified below.
- A temporary locale-loading regression was detected after adding navigation keys: both locale JSON files had trailing commas, causing raw `login.*` keys at runtime. The commas were removed, both files were parsed successfully with Node, and a hot restart restored Malayalam login labels.
- Remaining source-sweep items are separated below: API/error payloads, account/product names, printer/device values, and print-document labels are dynamic or configuration data and remain review-only.

### Additional unresolved/dynamic source-sweep items

| Exact source | Line(s) | Reason |
|---|---:|---|
| `lib/screens/transactions/widgets/share_helper.dart` | 172-1666 | Static error prefixes can be localized in a later dedicated pass, but filenames, phone numbers, provider errors, and exception text are dynamic. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 1695, 1705, 3565, 6688, 6765, 7167, 7872, 8027, 8335, 8733 | Fixed error prefixes are mixed with API responses/exceptions; preserve server/device details while localizing templates. |
| `lib/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart` | 263, 308, 465, 499, 504, 559, 567, 681, 770, 964, 1427, 1564, 2043 | Several messages contain dynamic language names, barcode values, exceptions, tax names, or product names; static portions require placeholder-based localization. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 1422, 3228, 3277, 4526-4635, 8172-8326, 9258-9300 | Error/status messages include runtime API/error details and need a dedicated placeholder review. |
| `lib/screens/print/widgets/receipt_configuration_workspace.dart` | 75-694 | Receipt field/language/configuration labels may intentionally remain configuration identifiers; verify product requirements before changing. |
| `lib/screens/invoice/invoice_pdf.dart` | 138-273 | Printed document template labels and company/customer placeholders are document-output content, not app chrome; review separately. |
| `lib/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart` | 263-964, 1496-1724 | Mixed static/API/device text; dynamic barcode, language, exception, stock, and tax/product values require placeholder-based review. |
| `lib/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart` | 311, 532 | Input hints overlap the shared payment flow and should be kept aligned with its translation keys. |
| `lib/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart` | 422-534 | Purchase-history messages include feature configuration and API/product context; preserve dynamic details while localizing fixed templates. |
| `lib/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart` | 300-532 | Transaction reference and customer-credit labels/hints localized; payment amounts and customer balances remain dynamic. |
| `lib/features/billing/presentation/widgets/mobile/mobile_bottom_nav.dart` | 248 | Cart item count localized with a placeholder; count remains dynamic. |
| `lib/features/billing/presentation/widgets/mobile/home/mobile_market_add_sheet.dart` | 194-253 | Sale-unit, quantity, unit-price, MRP, and add-to-cart labels localized; catalog values remain dynamic. |
| `lib/features/billing/presentation/pages/add_product_mobile.dart` | 1261-1920 | Static product-form labels, hints, category/unit fields, translation fields, pricing/stock labels, and multi-sale-unit copy localized; product names, language names, category/unit data, barcode values, and API errors remain dynamic. |
| `lib/widgets/side_menu_mobile.dart` | 187, 292, 400, 506, 609, 718, 783 | Mobile navigation section headers localized via `nav.section_*`; menu item values are already translation-backed. |
| `lib/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart` | 263-308, 561-569, 683, 772, 966, 1496, 1520, 1564 | Static auth/barcode/permission/stock/translation labels localized; barcode values, exceptions, language names, tax names, and product descriptions remain dynamic. |
| `lib/screens/sales/widgets/mobile_order_card.dart` | 240, 274, 327, 335 | Fixed success/return templates localized; cancellation exceptions and order numbers remain dynamic. |
| `lib/widgets/horizontal_saved_orders_view.dart` | 259, 285, 504-523 | Saved-order success/reset/delete UI localized using existing translation keys; order numbers remain dynamic. |
| `lib/features/billing/presentation/widgets/keyboard_shortcuts_help_dialog.dart` | 472-496 | Shortcut category headings localized via `keyboard.*`. |
| `lib/widgets/edit_stock_dialog.dart` | 256-436 | Stock-edit buttons, auth fallback, and update feedback localized; entered stock values and errors remain runtime data. |
| `lib/widgets/product_autocomplete_list_mobile.dart` | 265 | Product search hint localized via `common.search_product`. |
| `lib/widgets/billing_sidebar_footer.dart` | 219, 311-500 | Customer search and billing summary/action labels localized; customer/payment values remain dynamic. |
| `lib/widgets/add_category_modal.dart` | 266, 304-330, 390-401 | Translation action, tax selector, and parent-category labels localized; category/tax names remain data. |
| `lib/widgets/product_details_dialog.dart` | 2578-2598 | Sale-unit selector and removal tooltip localized; unit options and product values remain dynamic. |
| `lib/widgets/user_switcher.dart` | 157-182 | Switch/cancel/password validation labels localized; user identity and authentication errors remain dynamic. |
| `lib/widgets/category_list_item.dart` | 115, 291, 250-257 | Category/product search and item-count suffix localized; category/product names and counts remain dynamic. |
| `lib/screens/reports/**` | Route targets 39-42, 58, 65-68, 77, 80, 85, 98 | Source sweep found report UI is predominantly `.tr`-backed. Remaining printer scan messages, device names, exception details, and PDF labels are recorded as dynamic/configuration content below. |
| `lib/screens/print/**` | Route targets 53 and print/report helpers | App-facing printer settings are predominantly `.tr`-backed. Receipt/PDF layout labels, language identifiers, printer names, file paths, and device/API errors remain configuration/document/runtime data. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart` | 836 | Printer-scan tooltip localized via `voucher_print.scan_for_printers`; printer/device data remains dynamic. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 795 | Printer-scan tooltip localized via `voucher_print.scan_for_printers`; printer/device data remains dynamic. |
| `lib/screens/print/print_daily_close.dart` | 731 | Printer-scan tooltip localized via `voucher_print.scan_for_printers`; report/device data remains dynamic. |
| `lib/screens/print/print_kot.dart` | 951 | Printer-scan tooltip localized via `voucher_print.scan_for_printers`; KOT/order/printer data remains dynamic or document output. |
| `lib/screens/print/print_kot.dart` | 113, 502 | Static KOT-disabled message localized via `print.kot_disabled`; document configuration state remains runtime. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 688-689 | Printer selection buttons now use `voucher_print.selected` / `voucher_print.select`; printer names remain device data. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart` | 706-707 | Printer selection buttons now use `voucher_print.selected` / `voucher_print.select`; printer names remain device data. |
| `lib/screens/print/print_daily_close.dart` | 339 | Static printer-selection error localized via `voucher_print.select_printer_first`; selected printer remains device data. |
| `lib/widgets/order_list.dart` | 327, 1094-1103 | Mobile/payment input hints and balance label localized; order/customer/payment values remain dynamic. |
| `lib/widgets/sync_button.dart` | 156-167, 247-258 | Sync success/failure templates localized; exception details remain dynamic. |
| `lib/screens/transactions/widgets/customer_voucher_print.dart` | 328 | Static document-configuration failure prefix localized; provider/device error details remain dynamic. |
| `lib/widgets/side_menu_mobile.dart` | 187-797 | All section headers and menu item titles are translation-backed after the fix; store/user names and version text remain account/package data. |
| `lib/screens/sales/widgets/mobile_order_card.dart` | 510 | Clipboard confirmation localized via `sales.order_number_copied`; order number remains dynamic. |
| `lib/screens/transactions/invoice_list.dart` | 2835 | Clipboard confirmation localized via `invoice.number_copied`; invoice number remains dynamic. |
| `lib/widgets/add_category_modal.dart` | 59 | Required-field validation localized via `general.fill_required_fields`; entered category data remains dynamic. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 6745 | Static item-removal success message localized via `billing.item_removed_successfully`; item and server error details remain dynamic. |
| `lib/screens/category/category_form_mixin.dart` | 122 | Category translation validation localized; entered category name and translation response remain dynamic. |
| `lib/screens/sales/widgets/change_payment_status_modal.dart` | 222-229 | Payment-status and amount validation messages localized; selected status and amount remain user input. |
| `lib/screens/sales/widgets/change_order_status_modal.dart` | 344-365 | Order-status/refund validation messages localized; order status, payment method, and amount remain user input. |
| `lib/screens/sales/widgets/cancel_order_modal.dart` | 279-288 | Cancellation payment/refund validation messages localized; selected method and amount remain user input. |
| `lib/screens/billing/restaurant/widgets/order_panel_current_cart.dart` | 776-976 | Quantity/cart save/remove messages are mixed static/API templates; preserve server exceptions and localize templates with placeholders in a dedicated follow-up. |
| `lib/screens/transactions/widgets/share_helper.dart` | 197-1666 | PDF/email/WhatsApp messages mix static templates with provider, phone, filename, and exception values; preserve dynamic values and localize templates with placeholders in a dedicated follow-up. |
| `lib/features/billing/presentation/pages/add_product_mobile.dart` | 589-897 | Barcode/product creation and translation messages now use placeholder-safe translation keys; barcode, language, category, and exception values remain dynamic. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 1422 | Offline-sync validation localized via `billing.no_internet_sync`. |
| `lib/features/billing/controllers/billing_mobile_ui_controller.dart` | 2000-2007 | Payment configuration validation localized; provider validation error remains dynamic when supplied. |
| `lib/features/billing/controllers/coordinators/payment_coordinator.dart` | 253 | Coupon/payment fallback localized; server response and authentication state remain dynamic. |
| `lib/screens/print/print_daily_close.dart` | 701 | Static printer-selection validation localized; selected printer remains device data. |
| `lib/screens/print/print_kot.dart` | 914-920 | Printer selection and missing-document-configuration messages localized; printer/configuration state remains runtime. |
| `lib/screens/billing/restaurant/widgets/order_panel_current_cart.dart` | 776-818 | Quantity and removal success messages localized; cart item values and exception/server details remain dynamic. |
| `lib/features/billing/presentation/pages/add_product_mobile.dart` | 538, 583 | Authentication and barcode fallback messages localized; API-provided failure messages remain dynamic when returned. |
| `lib/features/products/presentation/variant_editor_section.dart` | 476, 558, 588 | Variant option/value entry hints localized; option and value contents remain product-property data. |
| `lib/features/billing/presentation/widgets/price_fields.dart` | 295, 442, 544 | Price, MRP, and tax hints localized; numeric values remain dynamic. |
| `lib/features/billing/presentation/widgets/mobile/billing/pine_labs_section.dart` | 27-35 | Pine Labs action, processing, and success labels localized; terminal response remains dynamic. |
| `lib/features/billing/presentation/widgets/mobile/orders/order_card.dart` | 144, 150 | Saved-order accessibility labels localized; order contents remain dynamic. |
| `lib/widgets/customer/location_picker_dialog.dart` | 103, 279, 312, 345, 362, 376 | Location-picker title, loading, empty state, controls, and asset fallback localized; address/GPS/WebView errors remain dynamic. |
| `lib/screens/print/print.dart` | 831, 939, 955, 1244, 1508, 1549 | Printer selection/scan and document-configuration messages remain partly mixed/static; device names and exceptions are dynamic and need placeholder-safe localization. |
| `lib/screens/print/preview.dart` | 84 | Printing progress label localized via `voucher_print.printing`; receipt contents remain document output. |
| `lib/screens/print/print_kot.dart` | 653-930 | Remaining printer-screen headings, paper/printer states, retry, and KOT action labels require a dedicated pass; selected printer/device values remain dynamic. |
| `lib/screens/print/print_daily_close.dart` | 484-709 | Remaining daily-close printer-screen headings, paper/printer states, and report action labels require a dedicated pass; selected printer/device values remain dynamic. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 365, 483, 748 | Document configuration and printer-screen labels require a dedicated pass; report/PDF values remain document output. |
| `lib/screens/print/print.dart` | 831, 939, 955, 1244, 1508-1549 | Printer selection, document configuration, receipt action, and scan tooltip localized; printer names and exception details remain dynamic. |
| `lib/screens/print/preview.dart` | 84 | Printing progress label localized via `voucher_print.printing`; receipt contents remain document output. |
| `lib/screens/print/print_kot.dart` | 653-930 | Printer/KOT screen headings, states, retry, and print action localized; printer/device values remain dynamic. |
| `lib/screens/print/print_daily_close.dart` | 484-709 | Daily-close printer headings, states, and report action localized; printer/device values remain dynamic. |
| `lib/screens/sales/widgets/cancel_order_modal.dart` | 92-329 | Cancellation/refund headings, explanatory copy, totals, validation, and actions localized; refund amount and payment method remain user input. |
| `lib/screens/sales/widgets/change_payment_status_modal.dart` | 86-264 | Payment-status headings, labels, order-total template, validation, and actions localized; status and amount remain user input. |
| `lib/screens/sales/widgets/change_order_status_modal.dart` | 124-424 | Order-status/logistics/refund headings, labels, total validation, and actions localized; status, logistics, payment method, and totals remain runtime/user data. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 1546, 2212, 3228-3277, 3715-3752, 7813 | Multi-sale-unit, loading, cart-unit, stock-state, permission, purchase-history, and finalize-order labels localized; catalog, stock, and order values remain dynamic. |
| `lib/features/billing/controllers/billing_mobile_controller.dart` | 593 | Multi-sale-unit validation localized; store configuration remains runtime. |
| `lib/screens/billing/billing_page_desktop.dart` | 721, 1159 | Multi-sale-unit and payment-selection validation localized; store/payment state remains runtime. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 748 | Printer-selection validation localized; printer remains device data. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart` | 766 | Printer-selection validation localized; printer remains device data. |
| `lib/screens/print/return_bill_print.dart` | 822 | Printer-selection validation localized; printer/document state remains runtime. |
| `lib/screens/transactions/widgets/customer_voucher_print_thermal.dart` | 80 | Printer-selection validation localized; printer remains device data. |
| `lib/components/add_customer_form.dart` | 462-517 | State/district labels and search hints localized; location values remain API data. |
| `lib/services/print_service.dart` | 111 | Print-preparation error mixes static prefix with runtime exception; preserve exception detail and localize template separately. |
| `lib/services/cash_drawer_service.dart` | 86 | Cash-drawer failure is device/service runtime output; review with hardware error handling. |
| `lib/screens/print/print_standard.dart` | 208, 2471 | Printer selection and printed “amount in words” are app/document output; printer/document values remain configuration-dependent. |
| `lib/screens/print/layouts/*.dart` | Multiple receipt-layout locations | Receipt labels such as signatures, payment methods, and customer fields are generated document output; do not treat them as app chrome without a separate print-template localization decision. |
| `lib/widgets/stock_selection_modal.dart` | 676 | Stock-selection cancel action localized. |
| `lib/screens/category/add_category_screen.dart` | 659-740 | Category image/icon labels and selection actions localized; selected image/icon data remains dynamic. |
| `lib/screens/category/edit_category_screen.dart` | 519-590 | Category image/icon labels and selection actions localized; selected image/icon data remains dynamic. |
| `lib/screens/product/widgets/add_product/add_image_or_video.dart` | 263, 297 | Product image selection and add-more actions localized; files/attachments remain dynamic. |
| `lib/screens/product/widgets/edit_product/edit_image_or_video.dart` | 380, 414, 781 | Product image selection and add-more actions localized; files/attachments remain dynamic. |
| `lib/components/build_tax_modal.dart` | 97 | Tax dialog close action localized; tax names/amounts remain dynamic. |
| `lib/widgets/payment_selector_examples.dart` | 28, 518 | Example/demo widget contains hardcoded payment-selector labels; not referenced by sidebar routes, so review separately if this demo screen is exposed. |
| `lib/screens/homenew/category_list_item_new.dart` | 541, 719 | Legacy home alias contains add-to-cart labels; route 46 may expose this alias and requires a dedicated parity pass if enabled. |
| `lib/screens/suppliers/widgets/supplier_auto_complete.dart` | 107 | Supplier search hint remains static and requires localization if this autocomplete is visible on supplier routes. |
| `lib/screens/print/print_standard.dart` | 2471 | `Amount in Words` is generated printed-document output, not app chrome; preserve for separate receipt/PDF template localization. |
| `lib/widgets/category_list_item.dart` | 819-891 | Demo/catalog product names remain dynamic product data, not UI copy. |
| `lib/screens/homenew/category_list_item_new.dart` | 541-719 | Legacy home add-to-cart labels localized; product/API response values remain dynamic. |
| `lib/screens/suppliers/widgets/supplier_auto_complete.dart` | 107 | Supplier search hint localized; supplier names remain dynamic. |
| `lib/components/virtual_keyboard_widget.dart` | 272 | Keyboard confirm action localized. |
| `lib/services/print_service.dart` | 111 | Static print-preparation prefix localized; exception details remain dynamic. |
| `lib/services/cash_drawer_service.dart` | 86 | Cash-drawer failure label localized; hardware/service details remain dynamic. |
| `lib/screens/billing/billing_page_desktop.dart` | 1058-1132 | Cart-clear/order-load success and fallback messages localized; provider/order errors remain dynamic. |
| `lib/components/add_customer_form.dart` | 920 | Payment-type validation localized; selected payment type remains user input. |
| `lib/screens/product/widgets/add_product/add_image_or_video.dart` | 663, 961 | Image-selection/cancel controls localized; media/file values remain dynamic. |
| `lib/screens/product/widgets/edit_product/edit_image_or_video.dart` | 1079 | Cancel control localized; media/file values remain dynamic. |
| `lib/features/subscription/presentation/subscription_action_guard.dart` | 127-132 | Subscription verification title/fallback and retry action localized; provider error message remains dynamic. |
| `lib/screens/transactions/widgets/share_helper.dart` | 215-1666 | Remaining PDF/email/WhatsApp messages mix static templates with provider/API/device values; preserve dynamic details and localize in a placeholder-safe dedicated pass. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 1695-8737 | Remaining order-panel errors mix static prefixes with API/exception/order data; preserve dynamic details and localize templates separately. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 955-957, 7823-7825, 9339-9340 | Authenticated billing runtime showed `Store Takeaway`; delivery-method fallback/order data, not static UI. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 452-455 | Authenticated billing runtime showed `Test Default`; configured store/order/customer data, not static UI. |
| `lib/screens/sales/widgets/mobile_order_card.dart` | 104 | Authenticated sales/report data showed customer name `Gokul VAT Test`; customer/account data, not static UI. |
| `lib/screens/print/**` | Multiple thermal/standard receipt layout locations | English receipt labels such as `Voucher #`, `Date`, `Customer Details`, `Item`, `Qty`, `Amount`, `TOTAL`, `Status`, and `Payment` are printed-document template output; keep separate from app chrome and review with receipt-template localization requirements. |
| `lib/screens/transactions/widgets/share_helper.dart` | 335, 394, 513, 1300-1304 | File paths, customer/supplier phone numbers, WhatsApp provider responses, filenames, and exception details remain dynamic. Static share/error templates were moved to `share_helper.*` translation keys. |
| `lib/features/billing/presentation/widgets/mobile/home/product_card.dart` | 193 | Add-to-cart accessibility label localized; product/catalog data remains dynamic. |
| `lib/screens/billing/restaurant/widgets/order_panel_current_cart.dart` | 848, 877, 925 | Cart-cleared, empty-cart, and local-draft messages localized; cart/order state and server errors remain dynamic. |
| `lib/screens/billing/restaurant/restaurant_page.dart` | 3470-3477, 4204-5627 | Runtime KOT + Bill action and related status/error text is translation-backed; the visible `KOT + ബിൽ` label intentionally retains the KOT document acronym. |
| `lib/screens/billing/restaurant/widgets/order_panel_current_cart.dart` | 392 | Runtime `KOT + ബിൽ` action label is translation-backed; KOT is a document acronym intentionally preserved. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 312-3115 | Runtime `Store Takeaway` and customer/store values are delivery/order/account data; do not translate blindly. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 452-455, 7823-7825, 9339-9340 | Runtime `Test Default` and `Store Takeaway` values are configured customer/delivery data; do not translate blindly. |
| `lib/features/billing/presentation/pages/billing_page.dart` | 137-184 | Runtime category names `Chicken Buckets` and `Juice`, and product name `Hayfa Velazquez Test New`, are catalog/API data. |
| `lib/screens/billing/restaurant/restaurant_page.dart` |  — | Kitchen Master runtime order numbers, item names, customer notes, and modifiers such as `AUTO RACING CAR`, `Water gun`, `LESS SUGAR`, and `NO ICE, EXTRA SPICY` are order/product/user-entered data. The `KOT print` tooltip is already Malayalam and translation-backed. |
| `lib/screens/sales/**` |  — | Sales runtime order numbers, customer names, phone numbers, dates, amounts, statuses, and server-provided order content are dynamic transaction data; visible Malayalam filter labels and empty-state copy are translation-backed. |
| `lib/screens/sales/widgets/create_quotation_screen.dart` |  — | Quotation customer/product/order values are dynamic account and catalog data; visible action labels and validation templates are translation-backed. |
| `lib/screens/category/**` |  — | Runtime category names and slugs such as `Chicken Buckets`, `Juice`, `Fried chicken`, `Burgers`, `Beverages`, and `Bath and body care` are catalog/API data; category list headings, search, reset, pagination, and action labels are translation-backed. |
| `lib/screens/product/**` |  — | Runtime product names, descriptions, unit codes, and variant/catalog values such as `Hayfa Velazquez Test New`, `Fugiat voluptate qui`, `ICECream`, `Mughlai White Mutton`, `MUTTON CUISINE`, `painting set`, `Toys`, `SILK FABRIC`, `12 BARBECUE CUBES`, and `General Item` are product/API data. `MRP` is a domain abbreviation; the surrounding product-list UI is translation-backed. |
| `lib/screens/purchase/**` |  — | Purchase-order runtime dates, store names, supplier names (`Ktr suppliers`, `Supplier 1FUNZCART`), currency amounts, item counts, and status values are purchase/API data; purchase headings, filters, table headers, reset, pagination, and creation actions are translation-backed. |
| `lib/screens/purchase/widgets/create_purchase_order.dart` | 1343, 1357 | Validation fallback is now translation-backed via `purchase_order.selected_item`; the product name remains dynamic. |
| `lib/screens/purchase/widgets/purchase_return*.dart` | Runtime return items | Live purchase-return list and item-selection screens showed supplier/store/product names, voucher numbers, dates, currency, and quantities; these are purchase/API/catalog values. |
| `lib/screens/reports/**` |  — | Sales report runtime executive names, phone numbers, dates, order counts, currency amounts, printer/device values, and API/report rows are dynamic report data; visible report headings, filters, table columns, reset, and navigation labels are translation-backed. |
| `lib/screens/reports/sales_executive_report/sales_executive_report.dart` | Runtime rows | Live Malayalam verification showed executive usernames (`salesexecutiv2`), phone numbers, currency values (`SAR 0.00`), and report metrics; these are account/report data, not untranslated UI labels. |
| `lib/screens/reports/stock_report/stock_report.dart` | Runtime rows | Live Malayalam verification showed product names (`painting set`, `Toys`, `SILK FABRIC`, `12 BARBECUE CUBES`, `General Item`), unit codes (`PCS`), barcodes, quantities, and prices; these are catalog/stock data. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 132-137, 482-780 | Printer permission copy, printer controls, device count, unknown-device fallback, document-loading state, retry, and print action are now translation-backed; printer names/addresses and document configuration remain runtime/device data. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart` | 130-817 | Printer permission copy, printer controls, device count, unknown-device fallback, document-loading state, retry, print, and share actions are now translation-backed; printer names/addresses and document configuration remain runtime/device data. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print_standard.dart` | 973-1032, 1310 | Printed transaction-summary labels and `N/A` are document-template output; keep them under the separate print-template localization review. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print_standard.dart` | 260-349, 767-783 | Printed footer/header labels and `Date`/`Type`/`Debit`/`Credit`/`Status` fallbacks are document/configuration output; printer and transaction values remain runtime data. |
| `lib/screens/transactions/**` |  — | Transaction runtime invoice/order numbers, customer names, phone numbers, dates, currency amounts, ZATCA state values, and provider/API details are dynamic transaction data; visible transaction headings, filters, table headers, reset, and actions are translation-backed. |
| `lib/screens/customers/**` |  — | Customer runtime names, phone numbers, email addresses, tax/B2C classification values, and account/API data are dynamic; customer-list headings, filters, actions, and empty/loading states are translation-backed. `B2C` is a domain classification acronym. |
| `lib/screens/suppliers/**` |  — | Supplier runtime names, emails, phone numbers, addresses, balances, and API values such as `Supplier 1FUNZCART`, `Ktr suppliers`, `Pizahutsupplier`, `John`, `James`, and `beena` are dynamic supplier/account data; supplier headings, filters, table headers, reset, pagination, and actions are translation-backed. |
| `lib/screens/transactions/company_accounts/**` |  — | Company-account runtime customer names, invoice/receipt numbers, phone/account identifiers, dates, balances, and currency values are dynamic transaction data; search, headings, filters, table headers, reset, and actions are translation-backed. |
| `lib/screens/transactions/invoice_list.dart` | Runtime invoice rows | Live Malayalam verification showed invoice/order identifiers, customer usernames, dates, amounts, `ZATCA`, and provider state values; these are transaction/account/domain data. |
| `lib/screens/transactions/company_accounts/**` | Runtime account rows | Live invoice/party-account verification showed customer names, invoice/order identifiers, dates, amounts, phone/account values, and ZATCA/provider statuses; these are runtime transaction/account data. |
| `lib/screens/customer_profile/**` | Runtime customer rows | Live customer transaction verification showed customer names, reference IDs, dates, amounts, invoice identifiers, and payment/status values; these are customer and transaction data. |
| `lib/screens/suppliers/**` | Runtime supplier/transaction rows | The live supplier route currently resolves to the shared customer-transaction view; visible names, references, dates, amounts, and payment statuses are runtime data and remain unchanged. |
| `lib/screens/supplier_profile/**` | Runtime supplier profile/transaction values | Supplier names, reference IDs, dates, amounts, invoice identifiers, and payment/status values shown by the live route are runtime data. |
| `lib/screens/settings/settings.dart` | 633 | `English` in the language picker is an intentional native language name, alongside `العربية` and `മലയാളം`; it is not an untranslated app-facing label. |
| `lib/screens/settings/settings.dart` | 621-715 | Live Malayalam settings verification showed translated cards and controls. Runtime cache count/date values and technical terms such as `Reverb`, `API`, and `CloudPOS` remain configuration/product data. |
| `lib/screens/settings/widgets/offline_data_page.dart` | 150-1041 | Live Malayalam verification showed translated offline-data sections, tiles, sync/clear actions, and counts. Runtime cache counts, timestamps, connection state, and technical names (`UPI`, invoice/receipt templates) remain configuration/runtime data. |
| `lib/screens/print/printer_settings.dart` | 106-900 | Live Malayalam verification showed printer settings headings, tabs, actions, paper/theme labels, scan/select controls, and advanced sections translated. Printer model names (`Microsoft Print to PDF`, `HP DeskJet 2300 series`), paper sizes, B2C/B2B, PDF, and runtime device counts are device/configuration values. |
| `lib/screens/sales/widgets/buid_order_return_details_widget.dart` | 83-88 | Static `No order returns available.` was localized via `sales_return.no_items_available`. |
| `lib/screens/sales/confirmed_orders_ui_only.dart` | 1155-1159 | Static sync-success message was localized via `confirmed_orders.successfully_synced`; the count is dynamic. |
| `lib/screens/invoice/invoice_pdf.dart` | 138-273 | PDF labels and placeholder company/customer fields are print-template output and runtime/configuration values; retain under print-template review rather than blindly changing generated documents. |
| `lib/screens/reports/customer_transactions_reports/transaction_report_print.dart` | 360-365 | Document-configuration retry error now uses `voucher_print.document_config_not_loaded_retry`; the visible normal printer route was verified separately. |
| `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart` | 325-330, 398-402 | Document-configuration retry errors now use `voucher_print.document_config_not_loaded_retry`; normal printer UI was verified separately. |
| `lib/screens/billing/**` | Live Others-route verification | The authenticated Malayalam billing route showed translated controls/tooltips and billing labels. `Test Default`, `Store Takeaway`, product names, units, clock time, currency amounts, and store/account identity are runtime/configuration/catalog values. |
| `lib/screens/category/category_form_mixin.dart` | 136-172 | Static category translation errors and success message were localized via `general.auth_token_missing`, `category.translated_to`, and `category.translation_failed`. |
| `lib/screens/product/widgets/view_primary_details.dart` | 101 | Static `Next` button localized via `general.next`. |
| `lib/screens/product/widgets/view_image_or_video.dart` | 133 | Static `Back` button localized via `general.back`. |
| `lib/screens/category/**` | Live category-list verification | Category UI headings, search, reset, add, table headers, navigation, and actions are Malayalam. Category names/slugs such as `Chicken Buckets`, `Juice`, `Fried chicken`, `Burgers`, `Beverages`, and their slugs are catalog/API data and remain dynamic. |
| `lib/screens/product/**` | Live product-list verification | Product headings, filters, table headers, reset, pagination, and actions are Malayalam. Product names, category names, units, barcodes, prices, MRP, stock values, and property values such as `Toys`, `General`, `PCS`, `NOS`, and `Mughlai White Mutton` are catalog/API data. |
| `lib/screens/purchase/**` | Live purchase route verification | The active route remained the product-list page because the sidebar purchase entry is shared/role-dependent in this session; purchase source files and previously verified purchase-return/order pages are covered by the static/source audit. Purchase suppliers, products, dates, voucher numbers, quantities, prices, and statuses remain runtime data. |
| `lib/screens/sales/confirmed_orders_ui_only.dart` | 550, 690, 713, 888, 915, 965, 975, 1038, 1046, 1057, 1108, 1118, 1138 | Static confirmed-orders labels were localized with `confirmed_orders.*` keys and hot reloaded. Order numbers, delivery timestamps, quantities, payment methods, currency amounts, and product names remain runtime/order data. |
| `lib/widgets/add_category_modal.dart` | 218, 470, 490-518, 568, 587 | Static category form labels were localized with `category.*` keys. Language names and tax/category values remain runtime configuration/data. |
| `lib/widgets/order_list.dart` | 182-214, 1002-1075, 1297 | Static order/payment/print labels were localized with existing `general.*` and `billing.*` keys. Order number, customer data, and payment transaction values remain dynamic. |
| `lib/widgets/stock_selection_modal.dart` | 212, 229, 292-331, 422-440, 517-552 | Static stock-selection headings and field prefixes were localized with `stock.*` keys. Product names, stock IDs, prices, quantities, expiry dates, units, and tax/stock records remain runtime data. |
| `lib/screens/print/**` |  — | Printer settings runtime device names such as `Microsoft Print to PDF` and `HP DeskJet 2300 series` are OS/device data; `B2B`, `B2C`, and PDF are document/domain acronyms. Printer settings headings, labels, and explanatory copy are translation-backed. |
| `lib/screens/settings/**` |  — | Settings runtime cache counts, timestamps, store/account configuration, API/device status, and provider errors are dynamic; the visible settings cards, language controls, offline-data labels, sync controls, developer-mode labels, and logout text are Malayalam/translation-backed. |
| `lib/screens/settings/company_info.dart` | 512, 561, 610 | `Bearer`, `Asia/Riyadh`, and `https://eposdemo.yougoit.in` are authentication/time-zone/endpoint configuration values, not translatable UI labels. Account username, company name, email, role, and IDs are runtime account data. |
| `lib/screens/transactions/invoice_list.dart` | 1443 | Invoice email search hint localized via `invoice.search_email_hint`. |
| `lib/screens/billing/restaurant/widgets/order_panel.dart` | 3565 | Error prefix localized via `general.error_prefix`; `_error` remains runtime/provider data. |
| `lib/widgets/payment_selector_examples.dart` | 28, 518 | Unreferenced example/demo widget contains `Payment Selector Examples` and `Payment processed successfully!`; it is not in `SideBarController.screens` or the sidebar navigation. Review separately if this demo widget is later exposed. |
| `lib/widgets/category_list_item.dart` | 573-780 | Legacy add-to-cart labels and fallback success/error messages localized; catalog and API response messages remain dynamic. |
| `lib/widgets/category_list_item_widget.dart` | 121-287 | Legacy add-to-cart labels and fallback messages localized; catalog and API response messages remain dynamic. |
| `lib/widgets/horizontal_product_view.dart` | 153-164 | Add-to-cart success and action labels localized; product/API response values remain dynamic. |
| `lib/widgets/user_switcher.dart` | 134-306 | Password, authentication, store-access, and switch-success templates localized; user names and exception/API details remain dynamic. |
| `lib/widgets/edit_stock_dialog.dart` | 498 | Dynamic field-entry hint localized with `stock.enter_value`; field label remains dynamic. |
| `lib/widgets/product_details_dialog.dart` | 3131 | Edit-stock action localized; stock/product values remain dynamic. |
| `lib/features/billing/presentation/pages/add_product_mobile.dart` | 293-423, 765-773, 1132-1258, 1978-2141 | Duplicate-barcode flow, step titles, validation, navigation, and save actions localized; barcode/product names, quantities, and catalog data remain dynamic. |
| `lib/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart` | 423-535 | Purchase-history error templates localized; customer/product IDs, price thresholds, and API details remain dynamic. |
| `lib/components/virtual_keyboard_widget.dart` | 240 | Clear action localized via `general.clear`; keyboard input remains user data. |
| `lib/screens/print/return_bill_print.dart` | 860 | Printer-scan tooltip localized via `voucher_print.scan_for_printers`; selected printer remains device data. |
| `lib/components/add_customer_form.dart` | 314 | Street-address hint localized via `customer.hint_street_address`; entered address remains user data. |
| `lib/components/add_customer_form.dart` | 231-360 | Customer form field labels (`First Name`, `Last Name`, `Email Address`, `Phone Number`, `Building / Apartment`, `Country`, `Street Address`, `Balance`) localized via `add_customer.*`; entered customer values remain user data. |
| `lib/widgets/order_list.dart` | 743 | Error template localized via `general.error_prefix`; the snapshot/provider exception remains dynamic. |
