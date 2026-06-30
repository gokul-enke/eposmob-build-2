# Billing Feature Folder Map

This map shows where the current billing logic would belong if split into feature-style subfolders. The actual source still has a large desktop page and shared providers.

## Suggested Structure

```text
lib/features/billing/
  presentation/
    pages/
      billing_page.dart
    widgets/
      cart/
      checkout/
      customer/
      delivery/
      payment/
      product_entry/
      sidebar/
    controllers/
      billing_page_controller.dart
      billing_keyboard_controller.dart
      billing_rehydration_controller.dart
  application/
    use_cases/
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
  data/
    providers/
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

| Current source | Current responsibility | Future folder |
| --- | --- | --- |
| `presentation/pages/billing_page.dart` | Desktop page orchestration, state, shortcuts, layout, checkout/order flows | `presentation/pages`, `presentation/controllers`, `application/coordinators` |
| `providers/local_product_provider.dart` | Local products, cart, stock reservations, totals, saved/confirmed orders, Hive | `data/providers`, `data/local`, `domain/services` |
| `helpers/product_cart_helper.dart` | Product selection, stock grouping, sale-unit stock preference, add-to-cart | `application/use_cases/add_product_to_cart.dart` |
| `helpers/cart_quantity_stock_helper.dart` | Quantity sync, stock availability, alternate stock selection | `application/use_cases/change_cart_quantity.dart` |
| `helpers/payment_helper.dart` | Stored payment JSON parsing and API paid-method normalization | `domain/services/payment_payload_service.dart` |
| `helpers/payment_auto_fill_helper.dart` | Single-method auto-fill, generic remaining fill, remap after discount | `domain/services/payment_payload_service.dart` |
| `features/billing/domain/payment_validation.dart` | Collected-payment validation, net due, checkout completion gate | `domain/services/payment_validation.dart` |
| `widgets/stock_selection_modal.dart` | Stock grouping UI and grouping-key function | `presentation/widgets/cart`, `domain/services/stock_reservation_service.dart` |
| `features/billing/presentation/widgets/checkout_modal.dart` | Stepper for customer, delivery, discount, payment, quotation dates | `presentation/widgets/checkout` |
| `features/billing/presentation/widgets/payment_method_modal.dart` | Payment method loading, extra methods, amount entry, balance display | `presentation/widgets/payment`, `application/coordinators/payment_coordinator.dart` |
| `features/billing/presentation/widgets/coupon_modal.dart` | Manual/coupon discount UI validation | `presentation/widgets/checkout`, `application/use_cases/apply_discount.dart` |
| `features/billing/presentation/widgets/delivery_method_modal.dart` | Delivery method, car number, address, date/time | `presentation/widgets/delivery` |
| `features/billing/presentation/widgets/price_fields.dart` | Cart row price/MRP/tax inputs and minimum sale price enforcement | `presentation/widgets/cart` |
| `widgets/compact_quantity_control_local.dart` | Cart row quantity editor and sale-unit display conversion | `presentation/widgets/cart` |
| `providers/cart_provider.dart` | Server cart/order/coupon API calls | `data/remote/cart_api.dart` |
| `providers/billing_provider.dart` | Connectivity, legacy billing state, payment IDs, modal payment mirror | `data/providers/billing_provider.dart` |
| `providers/delivery_methods_provider.dart` | Delivery method cache/fetch/default resolution | `data/providers/delivery_methods_provider.dart` |
| `providers/customer_selection_provider.dart` | Globally selected customer for helpers | `application/coordinators/customer_selection.dart` |
| `services/print_service.dart`, `screens/print/print.dart` | Saved order print, live order print, auto-print fallback | `data/services/print_service.dart` |
| `services/quotation_print_service.dart` | Quotation print formatting and printing | `data/services/quotation_print_service.dart` |

## Dependency Direction To Preserve

- Presentation should ask application/use cases to mutate cart/order state.
- Application should call domain services for pure calculations.
- Data providers/repositories should hide Hive and HTTP details.
- Domain services should not depend on Flutter widgets or `BuildContext`.

## Logic That Must Not Stay Hidden In Widgets

The following logic currently lives inside UI widgets but is business behavior:

- Payment modal balance calculation and to-customer-credit behavior (partially shared via `PaymentValidation.computeNetDue`).
- Payment modal dynamic extra method support and unified pristine/split/deselect rules.
- Coupon modal discount validation.
- Stock-selection grouping key and combined quantity behavior.
- Price field minimum-sale-price enforcement.
- Quantity control conversion between display quantity and base quantity.
- Checkout modal confirm/print gating rules.
