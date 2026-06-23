# features/billing

Feature-first home for the billing/POS screen. See
`docs/BILLING_RESPONSIVE_REFACTOR_PLAN.md` for the full migration plan and phase
status.

## Structure
```
features/billing/
├── presentation/
│   ├── pages/      # entry/orchestrator widgets (billing_page*, responsive, mobile)
│   ├── widgets/    # shared building blocks (cart, modals, sidebar, summary, …)
│   ├── utils/      # presentation-only helpers (focus order constants, …)
│   └── layouts/    # (Phase 5) per-form-factor arrangements over shared widgets
├── controllers/    # coordinators + (future) BillingProvider-level orchestration
├── domain/         # (Phase 4) pure billing rules (pricing/discount/tax/payment)
└── data/           # (Phase 4) models, repositories, datasources
```

## Dependency rules (enforce these)
- `core/` must **not** import `features/`.
- This feature may import `core/` but **not** another feature.
- `presentation/` may import `controllers/`, `domain/`, `data/`.
- `domain/` imports no Flutter — pure Dart, unit-testable without a widget.

## Status (2026-06-23)
- ✅ Phase 2 — single breakpoint source in `core/responsive/`.
- ✅ Phase 3 — pages/widgets/utils/coordinators relocated here (pure move).
- 🔄 Phase 4 — strategy changed to **parallel/strangler**: the desktop monolith
  (`presentation/pages/billing_page.dart`) is left untouched and proven; mobile
  work happens in the separate `presentation/pages/billing_page_mobile.dart`
  (shown for width < 650), which already reuses the shared providers.
  - Extracted pure logic to `domain/` + `presentation/utils/` with tests:
    `embedded_barcode.dart` (scale-barcode parsing), `billing_sidebar_metrics.dart`
    (sidebar clamp math). Mobile page dead code removed.
- ✅ Runtime smoke test for the mobile page: `test/billing_page_mobile_smoke_test.dart`
  mounts the real `BillingPageMobile` behind fake providers (network/connectivity
  stubbed) and asserts it builds + switches all 3 tabs. Surfaced a finding: the
  Home-tab header `Row` (home_tab.dart:56) overflows horizontally under tight
  width — confirm/fix on-device.
- ✅ Mobile business logic extracted to `controllers/billing_mobile_controller.dart`
  (order rehydration, payment-JSON restore, order-detail restore, delivery
  defaults, barcode scan, clear-cart, checkout/print). The page
  (`billing_page_mobile.dart`) is now UI orchestration only (820 → 432 lines).
  Covered by `test/billing_mobile_controller_test.dart` (payment-restore) +
  the mount smoke test. Lifecycle wiring (provider listeners, subscriptions)
  intentionally stays in the widget `State`.
- ✅ Mobile tab widgets decomposed into focused sub-widgets (desktop untouched):
  - `mobile/billing/` — section card, option button, payment-methods, pine-labs,
    delivery-options, coupon, action-buttons (billing_tab.dart 828 → 159).
  - `mobile/orders/` — order card, empty state; payment-summary formatting moved
    to `domain/order_payment_summary.dart` + tests (orders_tab.dart 730 → 487).
  - `mobile/home/` — app-bar, cart card (home_tab.dart 405 → 185).
- ℹ️ Desktop page (`billing_page.dart`) still can't be hermetically mounted (same
  network-in-`initState` pattern); verify it in the running app. **Untouched by
  all mobile work.**

## Adding a new feature page
Mirror this shape from day one: page = orchestrator, layouts per form factor,
widgets shared, logic in `controllers/`/`domain/`, breakpoints from
`core/responsive`, providers scoped to the route.
