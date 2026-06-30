# Billing Logic Wiki

This folder documents the current billing logic in a feature-style structure.
It is a behavior inventory, not a Dart refactor. The source scope is:

- `lib/features/billing/presentation/pages/billing_page.dart`
- `lib/providers/local_product_provider.dart`
- Direct helpers, widgets, providers, and services that those files call for billing behavior.

Generated from the current workspace on 2026-06-30.

## File Index

- `feature-folder-map.md` - suggested feature-subfolder ownership map for the current monolith logic.
- `presentation/state-lifecycle-and-keyboard.md` - page state, lifecycle, rehydration, focus, shortcuts, connectivity, sidebar layout.
- `presentation/product-entry-sidebar-cart.md` - product search, barcode, sidebar, stock selection, cart table, cart editing.
- `presentation/customer-checkout-orders.md` - customer selection, checkout modal orchestration, save/confirm/print/quotation flows.
- `domain/pricing-stock-payment.md` - pricing, tax, discount, delivery charge, stock reservation, sale units, payment validation, collected-method modal behavior, and balance rules.
- `data/local-product-provider.md` - complete local product/cart/order provider responsibility map.
- `data/api-providers-and-services.md` - online APIs, provider bridges, printing, sync, settings, master data.
- `widgets/helpers-and-modals.md` - helper and modal behavior used by billing.

## Mobile scope (production v1)

Mobile billing (`billing_page_mobile.dart`, width < 650) is intentionally limited to the retail POS flow. **Quotation mode is desktop-only** until Phase 2 — no Create Quotation button, no quotation page mode, and no quotation-specific checkout on mobile. See `todo.md` P1.10 (decision 2026-06-30) and `presentation/customer-checkout-orders.md` for details.

## Mobile-specific divergence from desktop (approved v1)

Documented exceptions where mobile intentionally differs from `billing_page.dart`. Product owner approval required before adding more.

| Area | Desktop | Mobile v1 |
| --- | --- | --- |
| **Quotation** | `BillingPageMode.quotation`, Create Quotation, quotation checkout without payment | **Not supported** — scoped out (P1.10, 2026-06-30) |
| **Checkout UX** | Multi-step `CheckoutModal` sidebar stepper | Inline accordion sections on Billing tab (`billing_tab.dart`) |
| **Payment entry** | `PaymentMethodModal` dialog | Inline `payment_methods_section.dart` driven by `BillingMobilePaymentController` |
| **Product entry layout** | Sidebar + autocomplete header | Tabbed Home (grid + barcode/search), no desktop sidebar |
| **Cart editing** | `CartItemsTable` + `PriceFields` + `CompactQuantityControlLocal` | `cart_item_card.dart` + `mobile_cart_price_fields.dart` |
| **Keyboard shortcuts** | Full desktop F-key set + checkout modal bindings | Subset via `BillingMobileController.resolveShortcutAction` (F2–F9, F12, Esc, Ctrl+A) — see P1.5 |
| **Orders UI** | Desktop orders tab in sidebar | Dedicated mobile Orders tab with saved/local order cards |
| **Page orchestration** | Monolithic `BillingPageState` (~8k lines) | Thin `billing_page_mobile.dart` + `billing_mobile_controller.dart` + `billing_mobile_ui_controller.dart` |

**Shared (no divergence):** cart mutations (`ProductCartHelper`, `CartQuantityStockHelper`), stock reservations (`LocalProductProvider`), payment payload rules (`PaymentHelper`, `PaymentValidation`), delivery charge (`delivery_charge_helper.dart`), confirm/save (`CheckoutService`), online API payload (`CartProvider.addToOrderAPI`), barcode queue semantics (`BarcodeScanQueue`).

Architecture map: `feature-folder-map.md` (Implemented mobile column) and `lib/features/billing/README.md`.

## Highest-Level Billing Rules

- The desktop billing page is still the main orchestrator. It owns UI state, keyboard flow, customer/payment/delivery state, order actions, and resets.
- `LocalProductProvider` owns local products, local cart, stock reservations, local discounts, saved drafts, confirmed local orders, price summaries, and Hive persistence.
- Cart item quantities and prices are stored in base units. Sale units are display and payload conversions layered over base quantity/price.
- Product prices are tax-inclusive. Tax is extracted from price using `price * quantity * rate / (100 + rate)`.
- `LocalProductProvider.priceSummary` is refreshed as a side effect of reading `cartTotal`. Most page flows force-read `cartTotal` before using summaries.
- Stock reservation can be partial. If requested quantity exceeds available stock, stock is clamped at zero and the remaining cart quantity can still exist without reservations.
- Saved drafts restore stock when clearing the billing workspace, then re-reserve stock when loaded again. Confirmed/online sales clear the cart without restoring stock.
- Online confirm and confirm-print require internet, valid collected payment, and a completed payment step (sidebar modal or checkout payment step). Offline/local save-and-print uses the same payment validation; draft save does not require payment.
- Quotation mode has separate validation and does not use payment. It requires a valid quotation customer and expiry date not before quotation date.

## Important Source Anchors

- `billing_page.dart:113` starts `BillingPageState`.
- `billing_page.dart:324` initializes listeners, defaults, connectivity, barcode, cart API load, and rehydration.
- `billing_page.dart:584` rehydrates saved/current order state into page state.
- `billing_page.dart:1296` starts barcode queue and barcode processing.
- `billing_page.dart:3220` renders and mutates cart rows.
- `billing_page.dart:5550` builds checkout/action buttons.
- `billing_page.dart:5749` saves local draft orders.
- `billing_page.dart:6321` creates online order and prints.
- `billing_page.dart:6687` confirms online order without printing.
- `billing_page.dart:7573` creates quotation payloads.
- `billing_page.dart:7841` serializes local payment data.
- `billing_page.dart:7909` calculates payment balance and customer credit.
- `local_product_provider.dart:56` defines `LocalCartItem`.
- `local_product_provider.dart:259` defines `PriceSummary`.
- `local_product_provider.dart:1571` computes `cartTotal` and discount summary.
- `local_product_provider.dart:2286` adds products to cart.
- `local_product_provider.dart:3346` starts saved/confirmed order logic.

## Refactor Safety Notes

- Keep order action busy guards. They prevent duplicate save/confirm/print requests.
- Keep payment state and `BillingProvider.updatePaymentFromModal` synchronized after every payment modal update.
- Use `PaymentValidation` for confirm gating and apply-button checks; do not treat selection flags alone as valid payment.
- Preserve cart-change payment reset: when the cart changes after payment was configured, clear collected amounts and require payment reconfiguration.
- Keep customer state duplicated into both page fields and `CustomerSelectionProvider`; product helpers read the global provider fallback.
- Preserve stock reservation release semantics when clearing carts, saving drafts, confirming sales, and loading saved orders.
- Preserve delivery charge split behavior: footer summary adds delivery to payable, while effective order total adds delivery after optional round-off.
- Preserve barcode queue serialization. Multiple scanner events must process one at a time.
- Preserve sale-unit identity in cart matching, quantity controls, price fields, payload building, and remove/update operations.
