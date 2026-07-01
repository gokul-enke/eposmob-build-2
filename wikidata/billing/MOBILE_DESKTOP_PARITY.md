# Mobile / Desktop Billing Parity

> **Purpose:** Track intentional parity fixes between mobile billing and desktop billing.
> Each row is a discrete rule change with code references, automated tests, and a device QA step.
>
> **Migration strategy:** Shared domain helpers (`ProductCartHelper`, `CartQuantityStockHelper`,
> `CheckoutService`, `BarcodeSaleUnit`, etc.) are the single source of truth. Mobile widgets and
> controllers call those helpers; desktop `billing_page.dart` / `billing_page_desktop.dart` do the
> same. New parity gaps are fixed by extracting or reusing a helper, then covering with unit tests
> and a row in this table plus `DEVICE_QA_SIGNOFF.md`.

**Related docs:** `todo.md` (production checklist), `DEVICE_QA_SIGNOFF.md` (hardware sign-off),
`README.md` (divergence table).

---

## Parity issues

| ID | Status | Rule | Files | Tests | QA step |
| --- | --- | --- | --- | --- | --- |
| **P-01** | **Fixed** | Sale-unit barcode: pass `selectedSaleUnit` to `ProductCartHelper` only when conversion rate **> 1**. Rate `1` = base unit → plain product line (no sale-unit cart identity). | `lib/features/billing/domain/barcode_sale_unit.dart`, `lib/features/billing/controllers/billing_mobile_controller.dart` | `test/barcode_sale_unit_test.dart` (14 tests) | §2: Scan sale-unit barcode with rate > 1 → correct unit in cart; rate-1 barcode adds as base product |
| **P-02** | **Fixed** | Unknown-barcode create-and-add: after `createProductAPI`, route cart add through `ProductCartHelper` via `addCreatedProductToCart` with **form quantity** and selling price (not hardcoded `quantity: 1` / direct `LocalProductProvider.addToCart`). Opening stock `0` → cart qty `1`. | `lib/features/billing/domain/add_created_product_to_cart.dart`, `lib/features/billing/domain/add_product_form_helpers.dart` (`parseAddToCartQuantity`, `parseAddToCartSellingPrice`), `lib/features/billing/presentation/pages/add_product_mobile.dart`, `lib/features/billing/controllers/billing_mobile_controller.dart` (opens screen with `isAddToCart: true`) | `test/add_created_product_to_cart_test.dart`, `test/add_product_local_sync_test.dart` | §2: Scan unknown barcode → create product with qty **3** → cart line qty **3** (not 1) |
| **P-03** | **Fixed** | Mobile autocomplete search uses **sellable** products only (same as desktop `product_autocomplete_list.dart`). `MarketHomeWidget` passes `sellableProducts` into `MobileProductAutocomplete`; search must not fall back to `LocalProductProvider.products`. | `lib/widgets/product_autocomplete_list_mobile.dart`, `lib/features/billing/presentation/widgets/mobile/home/market_home_widget.dart` | `test/mobile_product_autocomplete_sellable_test.dart` | §1 / settings: With `barcodeSales` OFF, search does not surface non-sellable catalog items |
| **P-04** | **Fixed** | Desktop `AddProductWithBarcodeModal` create-and-add: same as P-02 — route through `addCreatedProductToCart` with **form quantity** and selling price (not hardcoded `quantity: 1` / direct `LocalProductProvider.addToCart`). | `lib/widgets/add_product_modal.dart`, `lib/features/billing/domain/add_created_product_to_cart.dart`, `lib/features/billing/domain/add_product_form_helpers.dart` | `test/add_created_product_to_cart_test.dart` | Desktop: unknown-barcode create with qty **3** → cart line qty **3** |
| **P-05** | **Fixed (slices 1–5 mobile)** | Variant billing on mobile: typed `ProductVariant` model, shared `ProductVariantSelection` resolver, mobile variant picker sheet, cart `variantId`/`variantAttributes`, Hive rehydration (fields 16–17), out-of-stock hard block, variant + sale-unit cart identity, `product_variant_id` in `buildOrderItemsPayload`, mobile add paths via `addProductWithVariantResolution`. Desktop `billing_page.dart` unchanged (deferred). | `lib/models/get_product.dart`, `lib/features/billing/domain/product_variant_selection.dart`, `lib/features/billing/domain/add_product_with_variant.dart`, `lib/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart`, `lib/providers/local_product_provider.dart`, `lib/helpers/product_cart_helper.dart`, `lib/features/billing/presentation/widgets/mobile/home/market_product_grid.dart`, `lib/widgets/product_autocomplete_list_mobile.dart`, `lib/features/billing/controllers/billing_mobile_controller.dart`, `lib/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart` | `test/product_variant_selection_test.dart`, `test/mobile_variant_picker_test.dart`, `test/variant_cart_rehydration_test.dart`, `test/variant_payload_test.dart`, `test/mobile_variant_cart_identity_test.dart`, `test/mobile_checkout_payload_contract_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | §7: Multi-variant picker; single-variant auto-add; variant barcode; OOS greyed + blocked; saved-draft reload keeps variant; confirm payload includes `product_variant_id` |

---

## Fix details

### P-01 — Sale-unit barcode parity

**Problem:** Mobile barcode path always set `selectedSaleUnit` when a sale-unit barcode matched, even when conversion rate was `1`. Desktop only sets sale-unit cart identity when rate > 1.

**Rule:** `BarcodeSaleUnit.resolveBarcodeSaleUnit(matched)` returns the unit only when `resolveSaleUnitQuantity > 1`; quantity for sale-unit scans uses the parsed conversion rate.

### P-02 — Unknown-product create-and-add

**Problem:** `AddProductMobileScreen` bypassed `ProductCartHelper` and added `quantity: 1`, skipping stock modal, sale-unit rules, and wholesale/tax paths.

**Rule:** `addCreatedProductToCart` wraps `ProductCartHelper.handleProductSelection` with `parseAddToCartQuantity` / `parseAddToCartSellingPrice` from the create-product form.

### P-03 — Autocomplete sellable products

**Problem:** `MobileProductAutocomplete._searchProducts` queried `productProvider.products` (full catalog), so non-sellable items could appear in billing search.

**Rule:** Search `widget.productList`, which `MarketHomeWidget` supplies as `LocalProductProvider.sellableProducts`.

### P-04 — Desktop create-and-add parity

**Problem:** Desktop `AddProductWithBarcodeModal` bypassed `ProductCartHelper` and always added `quantity: 1` after creating an unknown-barcode product.

**Rule:** Reuse `addCreatedProductToCart` with `_productQuantityController` / `_productSellingPriceController` — same helper and parsers as mobile P-02.

### P-05 — Variant billing (mobile slices 1–5)

**Problem:** Backend supports `product_variant_id` but Flutter had no typed variant model, no mobile picker, cart lines could not carry variant identity, order payloads omitted `product_variant_id`, and saved drafts did not QA variant rehydration.

**Rule:** `ProductVariantSelection` resolves barcode/single-variant auto-add vs picker; out-of-stock variants (`quantity == 0`) are unselectable and blocked at add. Mobile add paths call `addProductWithVariantResolution` → `ProductCartHelper` with `selectedVariant`. Cart merge keys include `variantId` (independent of `saleUnitId`). Hive fields 16–17 persist `variantId` + `variantAttributes`. `buildOrderItemsPayload` emits `product_variant_id` when present.

**Deferred (desktop-only):** `billing_page.dart` variant picker UI; byte-for-byte mobile vs desktop payload compare (P0.8 integration QA).

#### Slice checklist

| Slice | Scope | Status |
| --- | --- | --- |
| 1 | Model, picker, cart identity, payload, mobile wiring | Done |
| 2 | Saved-draft / active-cart Hive rehydration | Done |
| 3 | Out-of-stock variant hard block (picker + add guard) | Done |
| 4 | Variant + sale-unit interaction (independent merge keys) | Done |
| 5 | Mobile payload contract tests | Done |
| 6 | Wiki + QA docs | Done |
| — | Desktop `billing_page.dart` picker | Deferred |

---

## Tester checklist (fixed items)

### P-01 — Sale-unit barcode

- [ ] Product with sale unit conversion **12** and dedicated barcode: scan barcode → cart shows sale unit, qty reflects conversion.
- [ ] Product with sale unit conversion **1** (base): scan that barcode → adds as normal product line (no sale-unit selector forced).
- [ ] Burst-scan mix of base and sale-unit barcodes → order preserved, no dropped scans.

### P-02 — Create-and-add from unknown barcode

- [ ] Scan barcode not in catalog → Add Product screen opens with barcode prefilled.
- [ ] Set **Quantity = 3**, complete save → cart has **one line, qty 3** at entered selling price.
- [ ] Leave quantity **0** (opening stock default) → cart adds **qty 1** after save.
- [ ] Product with stock groups: create-and-add still opens stock selection when stock enabled.

### P-03 — Autocomplete sellable only

- [ ] Disable `barcodeSales` in settings → Home shows product search.
- [ ] Search for a known **non-sellable** product name → **no** autocomplete match.
- [ ] Search for sellable product → match appears; tap adds via normal cart path.

### P-04 — Desktop create-and-add from unknown barcode

- [ ] Desktop billing: scan unknown barcode → Add Product modal opens (`isAddToCart: true`).
- [ ] Set **Quantity = 3**, complete save → cart has **one line, qty 3** at entered selling price (not hardcoded 1).
- [ ] Leave quantity **0** (opening stock default) → cart adds **qty 1** after save.

### P-05 — Variant billing (mobile)

- [ ] Product with **one** active in-stock variant: tap Add → adds directly (no picker) at variant price.
- [ ] Product with **one** active variant at qty **0**: tap Add → blocked with out-of-stock message (no cart line).
- [ ] Product with **two+** active variants: tap Add → variant picker sheet opens; confirm adds selected line.
- [ ] Out-of-stock variant in picker: row greyed, not selectable, Add button stays disabled.
- [ ] Scan a **variant barcode** on a multi-variant product → adds that variant without picker.
- [ ] Scan barcode of **out-of-stock** variant → does not auto-add; picker shown if multiple variants remain.
- [ ] Cart row shows **product name + variant attributes** (e.g. `T-Shirt (Red | L)`).
- [ ] Same product added with **different variants** → separate cart lines (not merged).
- [ ] Save draft with variant line → load from Orders → variant id, label, and price restored.
- [ ] Kill app / reopen with variant in active cart → variant line still present (Hive rehydration).
- [ ] Product with **both** variants and sale units → separate lines per variant; sale-unit conversion still works.
- [ ] Confirm order API payload includes **`product_variant_id`** for variant lines.

---

## Next fixes to queue

1. **P-05 desktop** — `billing_page.dart` variant picker (mobile complete).
2. **Integration QA** — API payload byte-for-byte compare mobile vs desktop for same cart (noted as open in `todo.md` P0.8 / P0.9).

---

## Test coverage map

> Maps parity QA steps and `DEVICE_QA_SIGNOFF.md` rows to automated tests.
> **Automated** = covered by unit/widget tests in CI. **Device-only** = requires physical hardware or full E2E UI.

### P-01 — Sale-unit barcode

| QA step | Test file | Coverage |
| --- | --- | --- |
| Sale-unit barcode rate > 1 → correct unit in cart | `test/barcode_sale_unit_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| Rate-1 barcode adds as base product (no sale-unit identity) | `test/barcode_sale_unit_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| Burst-scan mix of base and sale-unit barcodes | `test/barcode_scan_queue_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated (queue order); burst on device | Device-only |

### P-02 — Create-and-add from unknown barcode

| QA step | Test file | Coverage |
| --- | --- | --- |
| Unknown barcode opens Add Product (`isAddToCart: true`) | — | Device-only (navigation; `BillingMobileController.processBarcode` not widget-tested) |
| Create with qty **3** → cart line qty **3** | `test/add_created_product_to_cart_test.dart`, `test/add_product_local_sync_test.dart` (`P-02 sign-off`) | Automated |
| Opening stock **0** → cart adds qty **1** | `test/add_created_product_to_cart_test.dart` | Automated |
| Stock groups → stock selection modal when enabled | `test/mobile_product_card_add_test.dart`, `test/p0_4_mobile_quantity_stock_test.dart` | Automated (modal path); full create-and-add on device | Device-only |

### P-03 — Autocomplete sellable only

| QA step | Test file | Coverage |
| --- | --- | --- |
| `barcodeSales` OFF → product search shown | `test/mobile_home_barcode_sales_test.dart` | Automated |
| Non-sellable product not in autocomplete | `test/mobile_product_autocomplete_sellable_test.dart` (`sellableProducts` unit + widget) | Automated |
| Sellable product match → tap adds via cart path | `test/mobile_product_autocomplete_sellable_test.dart` | Automated (search scope); tap-to-add E2E | Device-only |

### P-04 — Desktop create-and-add

| QA step | Test file | Coverage |
| --- | --- | --- |
| Desktop unknown barcode → modal with `isAddToCart: true` | — | Device-only (desktop UI) |
| Create with qty **3** → cart qty **3** | `test/add_created_product_to_cart_test.dart` | Automated (shared helper) |
| Opening stock **0** → cart qty **1** | `test/add_created_product_to_cart_test.dart` | Automated |

### P-05 — Variant billing (mobile)

| QA step | Test file | Coverage |
| --- | --- | --- |
| Single in-stock variant → auto-add at variant price | `test/product_variant_selection_test.dart` | Automated |
| Single variant qty **0** → blocked, no cart line | `test/product_variant_selection_test.dart` | Automated |
| Two+ variants → picker sheet; confirm adds selection | `test/mobile_variant_picker_test.dart` | Automated |
| OOS variant in picker greyed, Add disabled | `test/mobile_variant_picker_test.dart` | Automated |
| Variant barcode on multi-variant → direct add | `test/product_variant_selection_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| OOS variant barcode → no auto-add | `test/product_variant_selection_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| Cart row shows name + variant attributes | `test/product_variant_selection_test.dart`, `test/mobile_variant_cart_identity_test.dart` | Automated |
| Different variants → separate cart lines | `test/mobile_variant_cart_identity_test.dart` | Automated |
| Save draft → reload keeps variant id/label/price | `test/variant_cart_rehydration_test.dart` | Automated |
| App kill/reopen → variant in active cart (Hive 16–17) | `test/variant_cart_rehydration_test.dart` | Automated |
| Variants + sale units → separate lines, conversion intact | `test/variant_payload_test.dart`, `test/mobile_variant_cart_identity_test.dart` | Automated |
| Confirm payload includes `product_variant_id` | `test/variant_payload_test.dart`, `test/mobile_checkout_payload_contract_test.dart` | Automated |
| Mixed cart checkout `items[]` key contract (P0.8) | `test/mobile_checkout_payload_contract_test.dart` | Automated |

### DEVICE_QA_SIGNOFF cross-reference (§1–§6)

| Section | Representative step | Test file | Coverage |
| --- | --- | --- | --- |
| §1 Core sale | Tenant currency on product cards | `test/mobile_accessibility_test.dart` | Automated |
| §1 Core sale | Out-of-stock card still adds (helper decides) | `test/mobile_product_card_add_test.dart` | Automated |
| §1 Core sale | Double-tap Confirm → one order | `test/mobile_busy_guards_test.dart` | Automated |
| §2 Barcode | FIFO burst 10 scans | `test/barcode_scan_queue_test.dart` | Automated (queue); wedge hardware | Device-only |
| §2 Barcode | Embedded weight barcode (KG/PCS) | `test/embedded_barcode_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| §2 Barcode | Sale-unit barcode (P-01) | `test/barcode_sale_unit_test.dart`, `test/billing_mobile_barcode_resolution_test.dart` | Automated |
| §2 Barcode | Unknown barcode create qty 3 (P-02) | `test/add_created_product_to_cart_test.dart` | Automated |
| §3 Thermal printer | Confirm & Print, retry, reprint | `test/save_order_result_test.dart` | Automated (orchestration); physical print | Device-only |
| §4 Pine Labs | Approve / decline / cancel | `test/mobile_online_payment_gate_test.dart` | Automated (gate logic); real terminal | Device-only |
| §5 Parity | Discount/coupon remap | `test/mobile_coupon_discount_test.dart`, `test/payment_auto_fill_helper_test.dart` | Automated |
| §5 Parity | Car Delivery car number block | `test/billing_mobile_rehydration_test.dart` | Automated (validation); confirm E2E | Device-only |
| §5 Parity | Variant picker + payload (P-05) | `test/mobile_variant_picker_test.dart`, `test/mobile_checkout_payload_contract_test.dart` | Automated |
| §5 Parity | Save draft rehydration | `test/billing_mobile_rehydration_test.dart`, `test/variant_cart_rehydration_test.dart` | Automated |
| §5 Parity | Invalid price save blocked, cart kept | `test/save_order_result_test.dart` | Automated |
| §6 Stress | Airplane mode confirm blocked | `test/mobile_offline_behavior_test.dart` | Automated |
| §6 Stress | Airplane mode save draft (Hive) | `test/mobile_offline_behavior_test.dart`, `test/save_order_result_test.dart` | Automated |
| §6 Stress | Background/resume stale busy flags | `test/mobile_busy_guards_test.dart` | Automated (flag reset); lifecycle on device | Device-only |
| §6 Stress | Small phone keyboard clipping | `test/mobile_accessibility_test.dart` | Automated (layout); real keyboard | Device-only |

### Remaining device-only gaps (top priority)

1. **Physical barcode wedge** — burst scan order and unknown-barcode modal on real scanner input.
2. **Thermal printer** — receipt content (currency, tax, sale-unit lines, dynamic payment, delivery charge).
3. **Pine Labs terminal** — approve/decline/cancel on live hardware.
4. **P0.8 byte-for-byte** — mobile vs desktop full API body compare for identical cart/payment (items contract automated; envelope/manual QA open).
5. **Settings toggle** — `barcodeSales` / `askDeliveryDate` behavior after app restart without stale provider state.
6. **End-to-end saved draft** — load → edit → confirm → print on device.

### New tests added (2026-07-01 audit)

| File | Tests | Closes |
| --- | --- | --- |
| `test/billing_mobile_barcode_resolution_test.dart` | 7 | P-01 mobile path, §2 embedded, P-05 variant/OOS barcode |
| `test/mobile_variant_cart_identity_test.dart` | 3 | P-05 separate lines, merge, payload |
| `test/add_product_local_sync_test.dart` | +1 | P-02 qty-3 sign-off |
| `test/mobile_product_autocomplete_sellable_test.dart` | +1 | P-03 `sellableProducts` filter |
| `test/product_variant_selection_test.dart` | enhanced | P-05 single-variant price |
