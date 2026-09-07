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
- Do not treat English account names, product names, store names, email addresses, currency codes, receipt-config values, or language identifiers as missing static translations.
- The second route-level fix batch was hot-restarted successfully in Malayalam. The running app exposed the expected Malayalam keyboard tooltip after restart.
- The coupon, invoice-list, variant-stock, and POS security-key static labels were localized and lint-checked successfully. Dynamic coupon names, invoice values/statuses, variant IDs/SKUs, and security-key action text remain runtime data/context.
- A further source sweep found additional mobile billing labels and localized the bottom navigation, cart actions, coupon section, quotation customer fields, and product-card action semantics. These changes were lint-checked successfully.
- The latest mobile-component pass localized dining selection labels, cart price/tax labels, variant-picker copy, coupon-sheet title, product-grid/cart action semantics, and corresponding Malayalam keys. These changes were hot-restart verified below.
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
