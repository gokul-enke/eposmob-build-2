# Multi-Unit Pricing — Implementation Guide (Mobile App)

> How the Flutter POS app resolves prices when selling in alternate units (PC, Dozen, Pack, Case), and how that maps to the API contract described in the backend developer guide.

---

## 1. Core invariant

**All prices inside the cart are stored per base unit (per PC).**

Quantity is also stored in base units. When the cashier sees or the API receives a sale-unit line, the app scales up at the boundary:

| Direction | Formula | Example (Dozen, rate 12) |
|-----------|---------|--------------------------|
| Storage → display | `displayPrice = basePrice × conversionRate` | 75 × 12 = **900** per Dozen |
| Storage → payload | same `toDisplayAmount()` | sends `price: 900` |
| Display → storage | `basePrice = displayPrice ÷ conversionRate` | 900 ÷ 12 = **75** per PC |

This matches `enkepos/docs/multi-unit-stock-pricing.md`: `product_stocks.retail_price` and cart internals are always per-base; selling in a bigger unit scales the price up, never down.

---

## 2. Price resolution chain (as implemented)

When a cart line has a `saleUnitId`, `_resolveSaleUnitBasePrice()` runs **before** wholesale or plain retail logic. Priority:

```
1. stocks[].unit_prices[sale_unit_id]   → batch override (per sale unit)
2. sale_units[].price                   → master price (per sale unit)
3. sale_units[].resolved_price          → backend pre-resolved (per sale unit)
4. (null → fall through)                → wholesale (if qty qualifies) OR stock/product retail (per base)
```

Each explicit sale-unit price (tiers 1–3) is **divided by `conversionRate`** before storage so the per-base invariant holds. Display and payload multiply it back.

> **Spec note:** Batch override always wins, even over quantity-based wholesale. Master price and `resolved_price` also run before wholesale — consistent with treating them as explicit unit prices.

### Worked example — Nivea Men

Product setup:

| Field | Value |
|-------|-------|
| Base retail (`products.price`) | 100 per PC |
| Sale unit Dozen (`id: 100`) | `conversion_rate: 12` |
| Master Dozen price | 900 |
| Batch #3279 override for Dozen | 1000 |

#### Tier 1 — Batch override (batch selected)

```
override     = 1000          (per Dozen, from unit_prices["100"])
stored base  = 1000 / 12     = 83.333…
display      = 83.333 × 12    = 1000  ✓
```

#### Tier 2 — Master price (no override)

```
master       = 900
stored base  = 900 / 12      = 75
display      = 75 × 12        = 900  ✓
```

#### Tier 3 — `resolved_price` (no override, no master)

```
resolved     = 960
stored base  = 960 / 12      = 80
display      = 80 × 12        = 960  ✓
```

#### Tier 4 — Auto (no explicit sale-unit price)

Falls through to stock/product retail (already per base):

```
stored base  = 100           (per PC)
display      = 100 × 12       = 1200  ✓  (= base × conversion)
```

---

## 3. Code map

| Concern | Location |
|---------|----------|
| Parse `resolved_price`, `conversionRateValue` | `SaleUnit` in `lib/models/get_product.dart` |
| Parse `unit_prices` map/list | `Stock.unitPriceOverrides`, `_parseUnitPriceOverrides()` |
| Resolution chain | `_resolveSaleUnitBasePrice()` → `_resolveUnitPrice()` in `lib/providers/local_product_provider.dart` |
| Re-price on qty/stock/unit change | `_refreshCartItemPricing()` |
| Display scaling | `LocalCartItem.toDisplayAmount()`, `toDisplayQuantity()` |
| Order payload | `buildOrderItemsPayloadFrom()` — sends `sale_unit_id`, `stock_id`, display `quantity`/`price` |

---

## 4. API request shape

For a Dozen sale from batch #3279:

```jsonc
{
  "product_id": 18788,
  "stock_id": 3279,
  "sale_unit_id": 100,
  "quantity": 1,        // 1 Dozen (not 12)
  "price": 1000         // per Dozen (display-scaled)
}
```

The app **always sends `price`** today (pre-existing behaviour). Per the backend guide, an explicit `price` bypasses server-side resolution. Sending `stock_id` + `sale_unit_id` without `price` would let the backend resolve — that is **not** current app behaviour.

---

## 5. Business-logic review

### Correct

- **Divide-then-multiply round-trip** — Storing `override / rate` and displaying via `toDisplayAmount()` produces the correct per-unit price. Verified in `test/multi_unit_pricing_test.dart`.
- **Override > master > resolved > auto** — Matches the documented priority.
- **Wholesale ordering** — Sale-unit explicit prices run before `_qualifiesForWholesalePrice()`; batch override beats wholesale as required.
- **Quantity in base units** — Wholesale threshold compares `item.quantity` (base), which is correct.
- **Unit change re-prices** — `changeCartItemSaleUnit()` calls `_refreshCartItemPricing()` with the new `saleUnitId`.

### Caveats / possible improvements

| Item | Severity | Notes |
|------|----------|-------|
| **Conversion rate source** | Medium | Pricing divides by `saleUnit.conversionRateValue` from the product's `saleUnits` list, but display/payload uses `item.saleUnitConversionRate`. If product data is refreshed and rates diverge, price and display could disagree. **Improvement:** fall back to cart-stored rate when lookup fails or rates differ. |
| **`resolved_price` vs selected batch** | Low | `resolved_price` reflects the default in-stock batch. When a *different* batch is selected and there is no override/master, auto tier uses that batch's `retail_price` (correct). `resolved_price` is only used when tiers 1–2 are absent — acceptable. |
| **Explicit `price` in payload** | Low | Always sent; backend cannot re-resolve. Pre-existing; document for API consumers. |
| **Zero price treated as unset** | Low | `> 0` checks mean a deliberate free sale-unit price (0) falls through to base retail. Rare in practice. |
| **No matching `saleUnitId`** | Low | Falls through to base retail; cart may still carry a stale `saleUnitConversionRate` for display. Edge case if product sale units change after add-to-cart. |

### No bugs found in the core math

The implementation is **business-logic correct** for the documented contract. The main follow-up worth considering is aligning conversion-rate sources (product lookup vs cart field) under stale-data scenarios.

---

## 6. Tests

| File | Coverage |
|------|----------|
| `test/multi_unit_pricing_test.dart` | Model parsing, full resolution chain via `addToCart`, edge cases |
| `test/sale_unit_payload_test.dart` | Payload quantity/price scaling, `sale_unit_id` presence |
| `test/sale_unit_cart_change_test.dart` | Unit switching semantics |
| `test/barcode_sale_unit_test.dart` | Barcode → sale unit selection rules |

Run:

```bash
flutter test test/multi_unit_pricing_test.dart test/sale_unit_payload_test.dart
```

---

## 7. Quick checklist (for developers)

- [ ] Show units from `product.saleUnits`; pass `saleUnitId` + `saleUnitConversionRate` into `addToCart`.
- [ ] Do not pre-multiply quantity by conversion rate — backend deducts base units.
- [ ] Expect cart `price` to be per-base; use `displayPrice` in UI for sale-unit lines.
- [ ] When a batch is chosen, ensure `selectedStock` includes `unitPriceOverrides` from API `unit_prices`.
- [ ] Prefer not sending `price` in new API integrations if backend resolution is desired (current app always sends it).
