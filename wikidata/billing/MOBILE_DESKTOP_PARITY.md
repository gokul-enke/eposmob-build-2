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

---

## Next fixes to queue

1. **Variant billing** — See `variant-implementation.md` (backend ready; Flutter picker + `product_variant_id` payload pending).
2. **Integration QA** — API payload byte-for-byte compare mobile vs desktop for same cart (noted as open in `todo.md` P0.8 / P0.9).
