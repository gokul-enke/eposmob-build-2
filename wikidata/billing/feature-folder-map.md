# Billing Feature Folder Map

This map shows where the current billing logic would belong if split into feature-style subfolders. The actual source still has a large desktop page and shared providers.

**Mobile alignment (2026-06-30):** Mobile billing does not yet have a separate `application/use_cases/` layer. It reuses the same shared helpers and providers as desktop, with mobile-specific orchestration in `controllers/billing_mobile_*.dart` and pure rules in `features/billing/domain/`. See `lib/features/billing/README.md` for the live mobile map.

## Suggested Structure

```text
lib/features/billing/
  presentation/
    pages/
      billing_page.dart
      billing_page_mobile.dart
    widgets/
      cart/
      checkout/
      customer/
      delivery/
      payment/
      product_entry/
      sidebar/
      mobile/           # mobile-only presentation
    controllers/
      billing_page_controller.dart
      billing_keyboard_controller.dart
      billing_rehydration_controller.dart
      billing_mobile_controller.dart
      billing_mobile_ui_controller.dart
  application/
    use_cases/          # future: extract from lib/helpers when stable
      add_product_to_cart.dart
      change_cart_quantity.dart
      confirm_order.dart
      create_quotation.dart
      save_draft_order.dart
      load_saved_order.dart
      apply_discount.dart
    coordinators/
      checkout_coordinator.dart
      payment_coordinator.dart
      delivery_coordinator.dart
  domain/
    models/
      billing_cart_item.dart
      billing_payment_state.dart
      billing_delivery_state.dart
      billing_order_snapshot.dart
    services/
      pricing_service.dart
      tax_service.dart
      stock_reservation_service.dart
      sale_unit_service.dart
      payment_payload_service.dart
      payment_validation.dart
      delivery_charge_service.dart
      barcode_service.dart
      barcode_scan_queue.dart
      billing_crash_guards.dart
  data/
    providers/            # still in lib/providers/ until migration
      local_product_provider.dart
      billing_provider.dart
      cart_provider.dart
      delivery_methods_provider.dart
      customer_selection_provider.dart
    local/
      hive_cart_repository.dart
      hive_order_repository.dart
      hive_product_repository.dart
    remote/
      cart_api.dart
      quotation_api.dart
      customer_api.dart
```

## Current Source To Future Ownership

| Current source | Current responsibility | Future folder | Implemented mobile (2026-06-30) |
| --- | --- | --- | --- |
| `presentation/pages/billing_page.dart` | Desktop page orchestration, state, shortcuts, layout, checkout/order flows | `presentation/pages`, `presentation/controllers`, `application/coordinators` | N/A — desktop only |
| `presentation/pages/billing_page_mobile.dart` | Mobile tab shell, busy flags, lifecycle, delegates to controllers | `presentation/pages` | `presentation/pages/billing_page_mobile.dart` |
| `controllers/billing_mobile_controller.dart` | Rehydration, barcode processing, save/confirm/print, shortcuts | `presentation/controllers`, `application/coordinators` | `controllers/billing_mobile_controller.dart` |
| `controllers/billing_mobile_ui_controller.dart` | Cart, payment, coupon, delivery, customer, settings, connectivity UI-domain logic | `application/coordinators`, `domain/services` | `controllers/billing_mobile_ui_controller.dart` |
| `providers/local_product_provider.dart` | Local products, cart, stock reservations, totals, saved/confirmed orders, Hive | `data/providers`, `data/local`, `domain/services` | Shared — same provider for mobile + desktop |
| `helpers/product_cart_helper.dart` | Product selection, stock grouping, sale-unit stock preference, add-to-cart | `application/use_cases/add_product_to_cart.dart` | Shared — called from mobile home/cart + `billing_mobile_controller` |
| `helpers/cart_quantity_stock_helper.dart` | Quantity sync, stock availability, alternate stock selection | `application/use_cases/change_cart_quantity.dart` | Shared — via `BillingMobileCartController.changeQuantity` |
| `helpers/payment_helper.dart` | Stored payment JSON parsing and API paid-method normalization | `domain/services/payment_payload_service.dart` | Shared — rehydration in `billing_mobile_controller` |
| `helpers/payment_auto_fill_helper.dart` | Single-method auto-fill, generic remaining fill, remap after discount | `domain/services/payment_payload_service.dart` | Shared — via `BillingMobilePaymentController` / `BillingMobileCouponController` |
| `helpers/delivery_charge_helper.dart` | Free-delivery threshold and method base price | `domain/services/delivery_charge_service.dart` | Shared — via `BillingMobileDeliveryController` |
| `features/billing/domain/payment_validation.dart` | Collected-payment validation, net due, checkout completion gate | `domain/services/payment_validation.dart` | Shared — mobile confirm gating + `BillingMobilePaymentController` |
| `features/billing/domain/barcode_scan_queue.dart` | FIFO barcode serialization | `domain/services/barcode_service.dart` | `domain/barcode_scan_queue.dart` — wired in `billing_page_mobile.dart` |
| `features/billing/domain/embedded_barcode.dart` | Scale-barcode quantity parsing | `domain/services/barcode_service.dart` | Shared — `billing_mobile_controller.processBarcode` |
| `features/billing/domain/billing_crash_guards.dart` | Null-safe display guards | `domain/services/` | Mobile widgets + controllers |
| `features/billing/domain/order_payment_summary.dart` | Saved-order payment summary text | `domain/models/` | `presentation/widgets/mobile/orders/` |
| `widgets/stock_selection_modal.dart` | Stock grouping UI and grouping-key function | `presentation/widgets/cart`, `domain/services/stock_reservation_service.dart` | Shared modal — opened via `ProductCartHelper` from mobile |
| `features/billing/presentation/widgets/checkout_modal.dart` | Stepper for customer, delivery, discount, payment, quotation dates | `presentation/widgets/checkout` | Desktop only — mobile uses inline `billing_tab` sections |
| `features/billing/presentation/widgets/payment_method_modal.dart` | Payment method loading, extra methods, amount entry, balance display | `presentation/widgets/payment`, `application/coordinators/payment_coordinator.dart` | Desktop modal — mobile uses `payment_methods_section.dart` + `BillingMobilePaymentController` |
| `features/billing/presentation/widgets/coupon_modal.dart` | Manual/coupon discount UI validation | `presentation/widgets/checkout`, `application/use_cases/apply_discount.dart` | Desktop modal — mobile uses `coupon_section.dart` + `BillingMobileCouponController` |
| `features/billing/presentation/widgets/delivery_method_modal.dart` | Delivery method, car number, address, date/time | `presentation/widgets/delivery` | Desktop modal — mobile uses `delivery_options_section.dart` + `BillingMobileDeliveryController` |
| `features/billing/presentation/widgets/price_fields.dart` | Cart row price/MRP/tax inputs and minimum sale price enforcement | `presentation/widgets/cart` | Desktop cart table — mobile uses `mobile_cart_price_fields.dart` + `BillingMobileCartController` |
| `widgets/compact_quantity_control_local.dart` | Cart row quantity editor and sale-unit display conversion | `presentation/widgets/cart` | Desktop — mobile quantity in `cart_item_card.dart` via `BillingMobileCartController` |
| `providers/cart_provider.dart` | Server cart/order/coupon API calls | `data/remote/cart_api.dart` | Shared — confirm/save API from `CheckoutService` |
| `providers/billing_provider.dart` | Connectivity, legacy billing state, payment IDs, modal payment mirror | `data/providers/billing_provider.dart` | Shared |
| `providers/delivery_methods_provider.dart` | Delivery method cache/fetch/default resolution | `data/providers/delivery_methods_provider.dart` | Shared |
| `providers/customer_selection_provider.dart` | Globally selected customer for helpers | `application/coordinators/customer_selection.dart` | Shared — `BillingMobileCustomerController` writes both providers |
| `services/checkout_service.dart` | Save draft, confirm, confirm-print, `SaveOrderResult` | `application/coordinators/checkout_coordinator.dart` | Shared — mobile page calls via `billing_mobile_controller` |
| `services/print_service.dart`, `screens/print/print.dart` | Saved order print, live order print, auto-print fallback | `data/services/print_service.dart` | Shared — print retry in `billing_page_mobile.dart` |
| `services/quotation_print_service.dart` | Quotation print formatting and printing | `data/services/quotation_print_service.dart` | Desktop only — quotation scoped out on mobile v1 |

## Dependency Direction To Preserve

- Presentation should ask application/use cases to mutate cart/order state.
- Application should call domain services for pure calculations.
- Data providers/repositories should hide Hive and HTTP details.
- Domain services should not depend on Flutter widgets or `BuildContext`.

## Logic That Must Not Stay Hidden In Widgets

The following logic currently lives inside UI widgets but is business behavior. Mobile extraction status as of 2026-06-30:

| Logic | Desktop location | Mobile location (extracted) |
| --- | --- | --- |
| Payment balance / collected total | `payment_method_modal.dart` | `BillingMobilePaymentController` + `PaymentValidation` |
| Dynamic extra payment methods | `payment_method_modal.dart` | `BillingMobilePaymentController` |
| Coupon discount validation | `coupon_modal.dart` | `BillingMobileCouponController` |
| Delivery charge | `billing_page.dart` | `delivery_charge_helper.dart` + `BillingMobileDeliveryController` |
| Stock-selection grouping key | `stock_selection_modal.dart` | Shared modal via `ProductCartHelper` |
| Price minimum-sale-price enforcement | `price_fields.dart` | `BillingMobileCartController` + `mobile_cart_price_fields.dart` |
| Quantity display ↔ base conversion | `compact_quantity_control_local.dart` | `BillingMobileCartController` + `CartQuantityStockHelper` |
| Checkout confirm/print gating | `checkout_modal.dart`, `billing_page.dart` | `billing_page_mobile.dart` guards + `CheckoutService` |

## Not Yet Migrated

- No `application/use_cases/` Dart files — shared helpers in `lib/helpers/` remain the cross-platform use-case layer.
- No `billing_payment_state` / `billing_delivery_state` model classes — state still lives in `BillingProvider` fields.
- Desktop `billing_page.dart` monolith not split into feature controllers.
