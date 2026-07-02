# features/billing

Feature-first home for the billing/POS screen. See
`docs/BILLING_RESPONSIVE_REFACTOR_PLAN.md` for the full migration plan and phase
status. Behaviour reference: `wikidata/billing/`.

## Structure

```text
features/billing/
├── presentation/
│   ├── pages/          # billing_page (desktop), billing_page_mobile, responsive
│   ├── widgets/        # shared + mobile/* sub-trees
│   ├── utils/          # presentation-only helpers (focus order, sidebar metrics)
│   └── layouts/        # (Phase 5) per-form-factor arrangements
├── controllers/        # mobile orchestration + desktop coordinators
├── domain/             # pure billing rules (no Flutter)
└── data/               # (Phase 4, future) models, repositories
```

## Dependency rules (enforce these)

- `core/` must **not** import `features/`.
- This feature may import `core/` but **not** another feature.
- `presentation/` may import `controllers/`, `domain/`, `data/`.
- `domain/` imports no Flutter — pure Dart, unit-testable without a widget.

## Mobile architecture map (2026-06-30)

Mobile billing (`billing_page_mobile.dart`, width &lt; 650) reuses the same
providers and shared helpers as desktop. Business rules live in controllers,
domain helpers, and `lib/helpers/` — not in widget `build` methods.

### Entry / orchestration

| Location | Responsibility |
| --- | --- |
| `presentation/pages/billing_page_mobile.dart` | Tab shell, busy flags, lifecycle (listeners, barcode stream), `setState`, snackbars/dialogs, delegates to controllers |
| `presentation/pages/billing_page_responsive.dart` | Breakpoint switch to mobile vs desktop page |

### Controllers (`controllers/`)

| File | Responsibility |
| --- | --- |
| `billing_mobile_controller.dart` | Saved-order rehydration, payment/delivery/customer restore, barcode `processBarcode`, save/confirm/print via `CheckoutService`, keyboard shortcut dispatch, `CreateOrderAndPrintResult` / print retry |
| `billing_mobile_ui_controller.dart` | Focused UI-domain controllers (no `BuildContext` in pure methods): |
| ↳ `BillingMobileConnectivityController` | Online-checkout connectivity gate |
| ↳ `BillingMobileSettingsController` | `barcodeSales`, stock-enabled sync, coupon/history/date visibility, default payment |
| ↳ `BillingMobileMarketController` | Product grid filtering / category selection |
| ↳ `BillingMobileCartController` | Quantity via `CartQuantityStockHelper`, sale-unit switch, price/MRP commit, cart totals |
| ↳ `BillingMobileCouponController` | Discount validation, coupon apply/clear, payment remap trigger |
| ↳ `BillingMobilePaymentController` | Typed + dynamic backend methods, collected-total, debit exclusion, Pine Labs gate |
| ↳ `BillingMobileDeliveryController` | Delivery method sync, charge via `delivery_charge_helper` |
| ↳ `BillingMobileCustomerController` | Select/clear/add customer across `BillingProvider` + `CustomerSelectionProvider` |
| ↳ `BillingMobileErrorMessages` | User-facing error and recovery copy |
| `coordinators/payment_coordinator.dart` | Desktop payment coordination (unchanged) |

### Domain (`domain/` — feature-local pure Dart)

| File | Responsibility |
| --- | --- |
| `barcode_scan_queue.dart` | FIFO scanner queue (no dropped events) |
| `embedded_barcode.dart` | Scale-barcode quantity parsing |
| `payment_validation.dart` | Collected-payment sum, net due, confirm gating |
| `order_payment_summary.dart` | Saved-order payment summary formatting |
| `billing_crash_guards.dart` | Null-safe price/MRP/tax/customer/token guards |
| `billing_debug_log.dart` | Debug-only structured checkout logging |
| `billing_sidebar_metrics.dart` | Desktop sidebar clamp math |

### Shared helpers (`lib/helpers/` — desktop + mobile)

| File | Used for |
| --- | --- |
| `product_cart_helper.dart` | Add-to-cart, stock modal routing, sale-unit preference |
| `cart_quantity_stock_helper.dart` | Stock-aware quantity +/- |
| `payment_auto_fill_helper.dart` | Single-method fill, remap after discount |
| `delivery_charge_helper.dart` | Free-delivery threshold / method base price |
| `payment_helper.dart` | Payment JSON parse, API paid-method normalization |
| `api_response_helper.dart` | Shared API error message extraction |

### Shared services & providers (outside feature folder)

| Location | Responsibility |
| --- | --- |
| `services/checkout_service.dart` | `SaveOrderResult`, save draft, confirm, confirm-print |
| `services/print_service.dart` | Order print, saved-order print |
| `providers/local_product_provider.dart` | Cart, stock reservations, saved/confirmed orders, Hive |
| `providers/billing_provider.dart` | Payment state, connectivity, delivery/payment IDs |
| `providers/cart_provider.dart` | Online order API |
| `providers/customer_selection_provider.dart` | Global selected customer for helpers |
| `providers/delivery_methods_provider.dart` | Delivery method cache |

### Mobile presentation widgets (`presentation/widgets/mobile/`)

| Subfolder | Widgets |
| --- | --- |
| `home/` | `home_tab`, `market_home_widget`, `product_card`, `market_product_grid`, barcode/search entry |
| `cart/` | `cart_tab`, `cart_screen`, `cart_item_card`, `mobile_cart_price_fields`, `cart_action_buttons` |
| `billing/` | `billing_tab`, customer, delivery, coupon, payment, Pine Labs, action buttons |
| `orders/` | `orders_tab`, `orders_screen`, `order_card` |
| `shared/` | `mobile_app_bar`, `mobile_search_bar` |

Desktop widgets (`sidebar`, `checkout_modal`, `price_fields`, `action_buttons`, …)
remain under `presentation/widgets/` and are used only by `billing_page.dart`.

### Tests (representative)

| Test file | Covers |
| --- | --- |
| `test/billing_page_mobile_smoke_test.dart` | Mount + tab switch |
| `test/billing_mobile_controller_test.dart` | Payment rehydration, delivery date/time |
| `test/billing_mobile_ui_controller_test.dart` | Cart, payment, delivery, customer controllers |
| `test/billing_mobile_rehydration_test.dart` | Full saved-order field restore |
| `test/save_order_result_test.dart` | P0.1 save-without-clear-on-failure |
| `test/barcode_scan_queue_test.dart` | P0.2 FIFO scanner |
| `test/p0_4_mobile_quantity_stock_test.dart` | P0.4 stock-aware quantity |
| `test/delivery_charge_helper_test.dart` | P0.9 delivery charge |
| `test/mobile_*` | P1/P2 widget and controller coverage |

## Status (2026-06-30)

- ✅ Phase 2 — single breakpoint source in `core/responsive/`.
- ✅ Phase 3 — pages/widgets/utils/coordinators relocated here (pure move).
- ✅ Phase 4 (mobile) — parallel/strangler: desktop monolith (`billing_page.dart`)
  left untouched; mobile in `billing_page_mobile.dart` reuses shared providers.
- ✅ Mobile business logic extracted to `billing_mobile_controller.dart` +
  `billing_mobile_ui_controller.dart`; page is UI orchestration only.
- ✅ Mobile tab widgets decomposed under `presentation/widgets/mobile/`.
- ✅ P0/P1 mobile safety and parity items implemented with unit/widget tests
  (see `wikidata/billing/todo.md`).
- ✅ P2.1 — widget business logic moved to controllers; P2.2 — folder map
  documented in `wikidata/billing/feature-folder-map.md`.
- ℹ️ Desktop page (`billing_page.dart`) still can't be hermetically mounted;
  verify in the running app. **Untouched by all mobile work.**

## Adding a new feature page

Mirror this shape from day one: page = orchestrator, layouts per form factor,
widgets shared, logic in `controllers/`/`domain/`, breakpoints from
`core/responsive`, providers scoped to the route.
