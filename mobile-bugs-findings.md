# Desktop vs Mobile Billing Parity Audit — Findings

## Fix Status (July 2, 2026)

### Fixed (P0 — all)
| # | Item | Files |
|---|------|-------|
| 1 | Payment rehydration `amount > 0` guard | `billing_mobile_controller.dart` |
| 2 | Pristine switch + single-remaining refill | `billing_mobile_ui_controller.dart`, `billing_provider.dart` |
| 3 | B2C default-customer validation | `billing_provider.dart`, `billing_tab.dart` |
| 4 | Extra-method autofill `effectiveOrderTotal` | `billing_provider.dart` |
| 5 | Restore `deliveryCharge` + `balanceAmount` | `billing_mobile_controller.dart`, `billing_provider.dart`, `delivery_charge_helper.dart` |
| 6 | Background customer refresh after sale | `billing_mobile_controller.dart`, `billing_page_mobile.dart` |
| 7 | Customer-credit live sync | `billing_mobile_ui_controller.dart` |

### Fixed (P1)
| # | Item | Files |
|---|------|-------|
| 8 | Walk-in phone-only customer UI | `billing_tab.dart` |
| 9 | Coupon id trimming | `billing_mobile_controller.dart` |
| 10 | Draft update status preservation | `billing_mobile_controller.dart` |
| 11 | Quote-only customer confirm gate | `billing_mobile_ui_controller.dart`, `billing_page_mobile.dart` |
| 12 | Customer search altPhone + digit normalization | `billing_mobile_ui_controller.dart` |
| 13 | Payment step visited gate | `billing_provider.dart`, `billing_tab.dart`, `payment_methods_section.dart` |
| 14 | SelectCustomerPage balance + sales exec hide | `select_customer_page.dart` |
| 15 | Coupon-state on restart | `billing_page_mobile.dart` |
| 16 | `resetToDefaultSalesExecutive` wired via `createNewOrder`/`clearCartData` | `billing_mobile_controller.dart` |

### Fixed (P2 — partial i18n)
| # | Item | Files |
|---|------|-------|
| 17 | i18n sweep (key mobile billing strings) | `en.json`, `BillingMobileErrorMessages`, `payment_methods_section.dart`, `select_customer_page.dart`, `billing_tab.dart` |
| 18 | `mobileNumberText` phone-only storage | `billing_provider.dart`, `billing_mobile_ui_controller.dart` |

### Architecture cleanup
| # | Item | Status |
|---|------|--------|
| 19 | Consolidate reset blocks | Done — `_resetBillingWorkspaceCore` in `billing_mobile_controller.dart` |
| 20 | `OrderStatusBadge` / `OrderStatCard` | Deferred — widgets exist for orders UI; not wired yet |
| 21 | Move SelectCustomerPage network calls to controller | Deferred — needs larger refactor |

### Intentionally deferred (out of scope)
- Dining/table selection (restaurant-only full feature)
- Inline qty/price/add row, preset price grid 1–20, cart keyboard navigation
- Quick-access product grid on Orders tab
- Split `billing_mobile_ui_controller.dart` into files
- Desktop variant resolution fix (separate ticket)
- Full i18n of every `BillingMobileErrorMessages` string (core checkout strings done)

---

**Date:** July 2, 2026  
**Scope:** `lib/features/billing` — desktop (`billing_page.dart`, related widgets) vs mobile rewrite (`billing_page_mobile.dart`, `BillingMobileController`, domain layer)  
**Audit type:** Three-part parity review (Checkout & Payments · Orders & Customers · Product & Cart)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Recommended Fix Order](#recommended-fix-order)
3. [P0 — Fix First (Bugs & Regressions)](#p0--fix-first-bugs--regressions)
4. [P1 — Missing Capabilities](#p1--missing-capabilities)
5. [P2 — Minor Gaps](#p2--minor-gaps)
6. [Desktop Bugs Found](#desktop-bugs-found-fix-desktop-not-mobile)
7. [Where Mobile Is Better](#where-mobile-is-better)
8. [Architecture Notes](#architecture-notes)
9. [Parity Tables](#parity-tables)
   - [Checkout & Payments](#checkout--payments)
   - [Orders & Customers](#orders--customers)
   - [Product & Cart](#product--cart)

---

## Executive Summary

The mobile rewrite (`lib/features/billing`) is **architecturally sound** and **faithful on shared core logic**:

- `LocalProductProvider`
- `ProductCartHelper`
- `PaymentValidation`
- `BillingTotals`
- `OrderCustomerFields`

Most gaps are **desktop UX patterns not yet ported to mobile**, plus a handful of **specific regressions** that should be fixed before treating mobile as production-parity.

| Category | Count | Risk |
|----------|-------|------|
| P0 — Bugs / regressions | 5 | Incorrect totals, wrong payment state, broken resume |
| P1 — Missing capabilities | 14+ | Workflow friction, blocked restaurant/B2B flows |
| P2 — Minor gaps | 10+ | i18n, dead code, layering |
| Desktop-only bugs | 2 | Variant resolution, barcode queue |

**Bottom line:** Fix the five P0 items first, then walk through P1 by cashier impact. Mobile already leads in several areas (variants, barcode queue, Pine Labs, offline save).

---

## Recommended Fix Order

| # | Item | Priority | Effort (est.) |
|---|------|----------|---------------|
| 1 | Payment rehydration guard (`amount > 0`) | P0 | Small |
| 2 | Pristine switch + single-remaining refill | P0 | Medium |
| 3 | B2C default-customer validation alignment | P0 | Small |
| 4 | Extra-method autofill `effectiveOrderTotal` | P0 | Small |
| 5 | Restore `deliveryCharge` + `balanceAmount` on resume | P0 | Small |
| 6 | Walk-in phone entry UI on mobile | P1 | Medium |
| 7 | i18n sweep (`.tr` parity) | P2 | Medium |
| 8 | Desktop variant resolution | Desktop | Medium |
| 9 | Inline entry row, preset price grid, cart keyboard | P1/P2 | Large (tablet targets) |

---

## P0 — Fix First (Bugs & Regressions)

### 1. Payment rehydration selects zero-amount methods

**Badge:** `P0`  
**Impact:** Multi-payment drafts show wrong selected chips; confirm gating may pass incorrectly.

On resume, mobile re-selects CASH / CARD / UPI / COD when amount keys exist at `0`. Desktop requires `amount > 0` via `hasMethodOrAmount` guard.

| Platform | Location | Behavior |
|----------|----------|----------|
| Desktop | `billing_page.dart` ~784–792 | `hasMethodOrAmount` — only selects method if amount > 0 |
| Mobile | `billing_mobile_controller.dart` ~173–206 | `amounts.containsKey(...)` without `amount > 0` check |

**Fix:** Mirror desktop guard when rehydrating payment methods from saved order amounts.

---

### 2. Split-payment UX missing (pristine switch + single-remaining refill)

**Badge:** `P0`  
**Impact:** Cashier must manually fix amounts when customer changes payment type mid-checkout.

Desktop implements two helpers when toggling tender type during split payment:

| Helper | Desktop location | Purpose |
|--------|------------------|---------|
| `_applyPristineSwitch` | `payment_method_modal.dart` ~728 | Resets sibling methods when switching to a "pristine" single-method state |
| `_refillIfSingleCollectedMethodRemaining` | `payment_method_modal.dart` ~837 | Auto-fills remaining balance when only one collected method remains |

Mobile `toggleMethod` in `billing_mobile_ui_controller.dart` ~1386–1414 has neither behavior.

**Fix:** Port both helpers (or equivalent logic) into mobile payment toggle flow.

---

### 3. B2C default-customer validation

**Badge:** `P0`  
**Impact:** B2C customers with store credit may show wrong net-due on mobile.

| Platform | Location | Behavior |
|----------|----------|----------|
| Desktop | `checkout_modal.dart` ~3225–3245, ~3049–3050 | Uses `CustomerSelectionProvider` + configured default phone; zeroes previous balance for default customers |
| Mobile | `billing_provider.dart` ~1299–1307 | Infers default from `customerType == 'default' \|\| 'b2c'` and passes raw balance |

**Fix:** Align mobile with desktop: check configured default customer phone via provider and zero `prevBalance` for defaults before net-due calculation.

---

### 4. Extra-method autofill round-off bug

**Badge:** `P0`  
**Impact:** Cheque / Wallet autofill amount off by round-off delta.

| Code path | Total used | Location |
|-----------|------------|----------|
| `toggleExtraMethod` | Raw `_totalOrderAmount` | `billing_provider.dart` ~1117 |
| Typed methods (CASH, CARD, etc.) | `effectiveOrderTotal` | `remainingPayable` ~1381–1384 |

**Fix:** Use `effectiveOrderTotal` (or same helper as typed methods) in `toggleExtraMethod` autofill.

---

### 5. Saved order restore gaps

**Badge:** `P0`  
**Impact:** Resumed drafts lose delivery charge and customer balance context.

| Field | Desktop restore | Mobile restore |
|-------|-----------------|----------------|
| `deliveryCharge` | Restored ~904–905 | **Missing** |
| `balanceAmount` | Restored ~913 | **Missing** |

| Platform | Location |
|----------|----------|
| Desktop | `billing_page.dart` ~904–905, ~913 |
| Mobile | `billing_mobile_controller.dart` `restoreOrderDetails` ~260–301 |

**Fix:** Add `deliveryCharge` and `balanceAmount` to mobile `restoreOrderDetails`.

---

## P1 — Missing Capabilities

### Orders & Customers

| # | Gap | Desktop reference | Mobile gap | Priority |
|---|-----|-------------------|------------|----------|
| 1 | **Walk-in phone-only customer** | `customer_input.dart` ~299–307 — allows typing arbitrary phone as `mobileNumberText` | No UI to write user-typed text into `mobileNumberText` (only `SelectCustomerPage` or full create flow) | P1 |
| 2 | **Quick-access product grid on Orders tab** | `orders_tab.dart` ~73–79 embeds `HorizontalProductViewLocal` | `orders_screen.dart` has no equivalent | P1 |
| 3 | **Server-side customer search** | Searches per keystroke via API | Loads all customers once, filters client-side — `select_customer_page.dart` ~45–92 | P1 |
| 4 | **Coupon id trimming** | Trims whitespace → `null` if empty | Passes raw whitespace string | P1 |
| 5 | **Forced `status: 'saved'` on draft update** | Preserves existing order status on update | Always passes `status: 'saved'` on update | P1 |
| 6 | **`resetToDefaultSalesExecutive` never called** | N/A (mobile-only dead path) | Defined in controller but no callers on mobile page | P1 |

---

### Checkout & Payments

| # | Gap | Desktop reference | Mobile gap | Priority |
|---|-----|-------------------|------------|----------|
| 7 | **Quote-only customer confirm gate** | `checkout_modal.dart` ~898–927, ~3160–3162 — blocks confirm for unsaved quotation-only customers | No equivalent gate | P1 |
| 8 | **Dining / table selection** | `dining_selection_modal.dart` | No mobile counterpart (restaurant flow blocked) | P1 |
| 9 | **Payment step visited gate** | Requires `paymentStepVisited` before confirm | Can confirm without opening payment accordion | P1 |

---

### Product & Cart

| # | Gap | Desktop reference | Mobile gap | Priority |
|---|-----|-------------------|------------|----------|
| 10 | **Always-visible inline qty/price/add row** | `billing_page.dart` ~2706–2950 | Only barcode/autocomplete header; add via bottom sheet | P1 |
| 11 | **Preset price grid (1–20)** | `horizontal_product_view_local.dart` + `PriceSelectionModal` | Missing on mobile | P1 |
| 12 | **Cart keyboard navigation** | Arrow keys, Ctrl+Q/U/P, Delete, H for history | Touch-only | P1 (tablet) |

---

## P2 — Minor Gaps

### Internationalization (i18n)

Mobile hardcodes English in many places while desktop uses `.tr`:

| Area | Examples (hardcoded on mobile) |
|------|--------------------------------|
| `BillingMobileErrorMessages` | Various error strings |
| `payment_methods_section` | Payment labels |
| `select_customer_page` | Search / select copy |
| `billing_status_header` | Status labels |
| `billing_page_mobile` snackbars | `'Cart Cleared Successfully'`, `'Exact cash'`, `'Save Order'`, `'Search Product'` |

**Fix:** Sweep mobile billing strings and wire through existing i18n keys used on desktop.

---

### Other Minor

| Gap | Detail |
|-----|--------|
| Customer balance visibility | `SelectCustomerPage` doesn't pass `salesExecutivePhone` to `shouldShowCustomerBalance` (desktop hides balance for sales exec) |
| `mobileNumberText` format | Mobile stores `"name phone"` vs phone-only on desktop |
| Coupon-state on restart | Mobile infers coupon state without current order; desktop rehydrates `isCouponApplied` from `priceSummary` |
| Dead code | `OrderStatusBadge`, `OrderStatCard`, `resetToDefaultSalesExecutive` — no callers |
| Triplicated reset blocks | `clearCartData`, `resetBillingWorkspaceAfterOrder`, `resetToDefaultSalesExecutive` in `billing_mobile_controller` |
| Layering violation | `SelectCustomerPage` performs network calls in-widget |
| Controller size | `billing_mobile_ui_controller.dart` ~2000 lines — should split |

---

## Desktop Bugs Found (Fix Desktop, Not Mobile)

These were discovered during parity review but belong on **desktop** backlog.

### 1. Variant products never resolved on desktop

**Badge:** Desktop bug  
**Impact:** Variant SKUs added without variant picker on desktop.

| Platform | Location | Behavior |
|----------|----------|----------|
| Desktop | `product_autocomplete_list.dart` ~212 | Uses `ProductCartHelper` only; never calls `addProductWithVariantResolution` |
| Mobile | `product_autocomplete_list_mobile.dart` ~190 | Correctly shows variant picker |

**Fix (desktop):** Call variant resolution path when product has variants, matching mobile.

---

### 2. Barcode queue error isolation

**Badge:** Desktop bug  
**Impact:** Desktop inline queue can stall on scan error; mobile queue continues.

| Platform | Implementation |
|----------|----------------|
| Desktop | Inline queue in billing page — poor error isolation |
| Mobile | `barcode_scan_queue.dart` — FIFO queue with robust error handling |

**Fix (desktop):** Adopt mobile `BarcodeScanQueue` pattern or equivalent error boundaries.

---

## Where Mobile Is Better

Mobile rewrite intentionally improves several areas. **Do not regress these** when closing parity gaps.

| Area | Mobile advantage | Key files / notes |
|------|------------------|-------------------|
| Variant resolution | Picker sheet before add | `add_product_with_variant.dart`, `mobile_variant_picker_sheet` |
| Barcode handling | FIFO queue, error isolation | `barcode_scan_queue.dart` |
| Pine Labs | Terminal integration | `pine_labs_section.dart` |
| Print retry | Retry without re-ordering | `billing_page_mobile.dart` ~727–757 |
| Offline | Save & Print fallback | — |
| Save failure | Cart preserved on failure | `SaveOrderResult` enum |
| Price validation | Validated before save | `checkout_service.dart` ~505–514 |
| Testability | Pure domain layer + unit tests | `domain/` |
| Delivery UX | Fee chips with free-delivery threshold | — |
| Empty cart | CTA when cart empty | — |
| Stability | Crash guards | `BillingCrashGuards` |
| Order load | Listener rehydrates from anywhere | — |
| Customer add | Parses API response directly | vs desktop re-query |

---

## Architecture Notes

### Mobile layering (follows `README.md`)

```
billing_page_mobile.dart     → orchestration only
BillingMobileController      → context-bound logic
BillingMobile*Controller       → pure, unit-tested
domain/                        → pure Dart helpers
```

### Desktop anti-patterns

- `billing_page.dart` ~9300 lines with duplicate state alongside `BillingProvider`
- Widgets reach page state via `findAncestorStateOfType`

### Shared layer (both platforms)

Both desktop and mobile correctly delegate to:

- `LocalProductProvider`
- `ProductCartHelper`
- `PaymentValidation`
- `BillingTotals`
- `OrderCustomerFields`

### Cart line identity merge key

From `local_product_provider.dart` ~2384–2390:

```
productId + selectedStock/stockGroupIds + saleUnitId + variantId
```

---

## Parity Tables

### Checkout & Payments

| Feature | Desktop | Mobile | Status |
|---------|---------|--------|--------|
| Core payment validation | `PaymentValidation` | `PaymentValidation` | ✅ Parity |
| Billing totals | `BillingTotals` | `BillingTotals` | ✅ Parity |
| Multi-payment split | Full UX (pristine switch, refill) | Basic toggle only | ❌ P0 |
| Payment rehydration on resume | `amount > 0` guard | Key presence only | ❌ P0 |
| B2C default customer balance | Zeroed via provider | Raw balance passed | ❌ P0 |
| Extra method autofill (Cheque/Wallet) | Uses effective total | Raw total (round-off bug) | ❌ P0 |
| Quote-only customer gate | Blocks confirm | Missing | ❌ P1 |
| Dining / table selection | Modal flow | Missing | ❌ P1 |
| Payment step visited gate | Required | Skippable | ❌ P1 |
| Pine Labs terminal | — | Integrated | ✅ Mobile better |
| i18n payment labels | `.tr` | Hardcoded English | ⚠️ P2 |

---

### Orders & Customers

| Feature | Desktop | Mobile | Status |
|---------|---------|--------|--------|
| Customer fields | `OrderCustomerFields` | `OrderCustomerFields` | ✅ Parity |
| Walk-in phone entry | Free-text phone in `CustomerInput` | Select/create only | ❌ P1 |
| Customer search | Server-side per keystroke | Client-side filter | ❌ P1 |
| Default customer / B2C balance | Provider + phone check | Type string inference | ❌ P0 |
| Coupon id handling | Trim → null | Raw whitespace | ❌ P1 |
| Draft status on update | Preserves status | Forces `'saved'` | ❌ P1 |
| Restore `deliveryCharge` | Yes | No | ❌ P0 |
| Restore `balanceAmount` | Yes | No | ❌ P0 |
| Sales exec balance hide | `shouldShowCustomerBalance` | Not wired | ⚠️ P2 |
| Customer add API handling | Re-query after add | Direct parse | ✅ Mobile better |

---

### Product & Cart

| Feature | Desktop | Mobile | Status |
|---------|---------|--------|--------|
| Cart merge key | Shared `LocalProductProvider` | Shared | ✅ Parity |
| `ProductCartHelper` | Yes | Yes | ✅ Parity |
| Variant resolution on add | **Missing** | Variant picker sheet | ✅ Mobile better |
| Barcode scan queue | Inline (fragile) | FIFO queue | ✅ Mobile better |
| Inline qty/price/add row | Always visible | Bottom sheet only | ❌ P1 |
| Preset price grid (1–20) | `HorizontalProductViewLocal` | Missing | ❌ P1 |
| Quick product grid (Orders tab) | Embedded grid | Missing | ❌ P1 |
| Cart keyboard shortcuts | Full set | Touch only | ❌ P1 (tablet) |
| Price validation before save | — | `checkout_service.dart` | ✅ Mobile better |
| Empty cart CTA | — | Yes | ✅ Mobile better |

---

## Appendix — File Reference Index

| File | Relevance |
|------|-----------|
| `billing_page.dart` | Desktop monolith; payment rehydration, restore, inline entry |
| `billing_page_mobile.dart` | Mobile orchestration; print retry |
| `billing_mobile_controller.dart` | Payment rehydration bug; restore gaps; reset blocks |
| `billing_mobile_ui_controller.dart` | Payment toggle; ~2000 lines |
| `billing_provider.dart` | B2C validation; extra-method autofill |
| `checkout_modal.dart` | B2C balance, quote-only gate |
| `payment_method_modal.dart` | Pristine switch, single-remaining refill |
| `customer_input.dart` | Walk-in phone entry (desktop) |
| `orders_tab.dart` / `orders_screen.dart` | Quick product grid |
| `select_customer_page.dart` | Client-side search; balance visibility |
| `product_autocomplete_list.dart` | Desktop variant gap |
| `product_autocomplete_list_mobile.dart` | Mobile variant resolution |
| `barcode_scan_queue.dart` | Mobile barcode queue |
| `local_product_provider.dart` | Cart line merge key |
| `checkout_service.dart` | Price validation before save |
| `horizontal_product_view_local.dart` | Preset price grid (desktop) |
| `dining_selection_modal.dart` | Restaurant flow (desktop only) |

---

*Document generated from three-part desktop-vs-mobile billing parity audit — July 2, 2026.*
