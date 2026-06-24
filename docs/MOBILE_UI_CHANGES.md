# Mobile Billing UI — Refactor Changes

> **Scope:** the mobile billing experience (`width < 650`) only.
> **Desktop (`billing_page.dart`) was NOT touched** by this work — verified via git
> (`git diff` clean; desktop imports none of the files below).
> **Status:** complete & committed · `flutter analyze` 0 errors · full suite 201 tests pass.
> **Commits:** `af33cb6a Mobile ui`, `1dc0f4f6 Mobile UI fully updated`.

---

## 1. Goal

Turn the mobile billing UI into a **scalable, maintainable, feature-first** structure:
- Business logic out of the widgets and into a controller / pure `domain/` helpers.
- The big "god-widget" tab files broken into small, single-responsibility widgets.
- A test net (logic unit tests + a runtime mount smoke test) around the risky parts.
- Shared business logic (pricing, cart, payment, tax) stays in the existing providers —
  **not duplicated** from desktop.

---

## 2. Architecture (after)

```
lib/features/billing/
├── presentation/
│   ├── pages/
│   │   └── billing_page_mobile.dart        # UI orchestration only (820 → 432)
│   └── widgets/mobile/
│       ├── home_tab.dart                    # composition only (405 → 185)
│       ├── billing_tab.dart                 # composition only (828 → 159)
│       ├── orders_tab.dart                  # list + modal + actions (730 → 487)
│       ├── home/
│       │   ├── mobile_home_app_bar.dart     # order label, keyboard/sync/grid, connectivity
│       │   └── mobile_home_cart_card.dart   # cart header + summary + items table
│       ├── billing/
│       │   ├── billing_section_card.dart    # titled card wrapper
│       │   ├── billing_option_button.dart   # small bordered action button
│       │   ├── payment_methods_section.dart
│       │   ├── pine_labs_section.dart        # Pine Labs terminal pay + result handling
│       │   ├── delivery_options_section.dart # delivery selector + comment sheet
│       │   ├── coupon_section.dart
│       │   └── billing_action_buttons.dart   # Save / Print / Confirm bottom bar
│       └── orders/
│           ├── mobile_order_card.dart        # one saved-order card
│           └── orders_empty_state.dart
├── controllers/
│   └── billing_mobile_controller.dart       # ALL mobile business logic (435 lines)
└── domain/
    ├── embedded_barcode.dart                 # pure scale-barcode parser (tested)
    └── order_payment_summary.dart            # pure payment-summary formatter (tested)
```

---

## 3. What changed

### 3.1 Logic extracted from the page → `BillingMobileController`
`billing_page_mobile.dart` previously held ~400 lines of business logic. Moved
**verbatim** into `controllers/billing_mobile_controller.dart`:
- Order **rehydration** / restore from a saved order.
- **Payment-method JSON restore** (multi-payment + single-method).
- **Order-detail restore** (delivery, coupon, comment, credit, dates).
- Default delivery method resolution.
- **Barcode scan** → product resolution → add-to-cart.
- Clear-cart data reset.
- Checkout orchestration: save / confirm / create-and-print / load-for-editing.
- Focus + keyboard-shortcut handling.

The page now keeps only **UI orchestration**: `build`, `setState`, dialogs, snackbars,
tab control, and lifecycle wiring (`initState`/`dispose` provider listeners — kept in
the `State` by design, standard Flutter).

### 3.2 Pure logic → tested `domain/` helpers
- `embedded_barcode.dart` — parses 14-char `000`-prefix scale barcodes (weight / piece
  count / product code). Extracted from `processBarcode`.
- `order_payment_summary.dart` — formats a stored `paymentMethod` into a short display
  string for the orders list. Extracted from `orders_tab`.

### 3.3 Tab widgets decomposed (UI only, behaviour-preserving moves)
| Tab | Before | After | Extracted widgets |
|---|---|---|---|
| `billing_tab.dart` | 828 | **159** | 7 widgets in `mobile/billing/` |
| `orders_tab.dart` | 730 | **487** | `mobile/orders/` (2) + `domain/order_payment_summary.dart` |
| `home_tab.dart` | 405 | **185** | `mobile/home/` (2) |

The 3 tab files dropped from **1,963 → 831 lines**; the remainder now lives in 11
focused widgets + 2 domain helpers.

### 3.4 Cleanup
- Removed dead fields / no-op listeners from the mobile page (`cartProvider`, `keyTile`,
  empty `_handleFocusChange`, unused `summary` local).

---

## 4. Tests added
| File | Covers |
|---|---|
| `test/embedded_barcode_test.dart` | scale-barcode parsing (weight / pieces / product code) |
| `test/order_payment_summary_test.dart` | payment-summary formatting incl. multi-payment JSON |
| `test/billing_mobile_controller_test.dart` | `restorePaymentMethods` against a real `BillingProvider` (multi-payment, ONLINE, single-method, null) |
| `test/billing_page_mobile_smoke_test.dart` | **mounts the real page** behind fake providers; asserts it builds + switches all 3 tabs |

Verification: `flutter analyze` → **0 errors**; full suite → **201 pass**.

> The mount smoke test required faking the network/connectivity calls the providers
> fire on construction (`AppSettings`, `Grid`, `Cart`, `Billing`) — see the test file.

---

## 5. Open items (for manual / device verification)
- **Visual / look-and-feel on a real phone** — not auto-verifiable here (the page hits
  network + connectivity in `initState`, and the mobile layout only renders at width < 650).
- **Home-tab header overflow** — the smoke-test harness surfaced a horizontal overflow in
  the `MobileHomeAppBar` row under tight test width. May be a test artifact or a real layout
  issue → confirm on device.
- **`initState` notify-during-build** — `BillingProvider.initializeDeliveryMethod()` calls
  `notifyListeners()` during the page's `initState`; harmless in release, worth tidying.

---

## 6. Not done (deferred by design — independent of UI work)
- **Phase 6 — scope providers**: move billing-only providers out of the global
  `MultiProvider` in `main.dart` into the billing route. Cross-app runtime risk; do **last**,
  after a read-only provider-usage audit + device check.
- **Phase 1 — delete dead desktop forks**: `billing_page_desktop.dart`,
  `billing_page_restaurant.dart`, `mobile_screen/`. Final cleanup pass.

See `docs/BILLING_RESPONSIVE_REFACTOR_PLAN.md` for the full plan and phase status.
