# Offers / Promotions — Design Recommendation

> Time-limited offer prices for products, plus category-based offers (all products
> under a fixed set of categories).

## Key context that drives the design

This app is an **offline-first POS**. Products are cached in Hive (`HiveGetProduct`),
and the unit price is resolved at a **single choke point** —
`_resolveUnitPrice` in `lib/providers/local_product_provider.dart:535`:

```dart
return _parseAmount(selectedStock?.price) ??
    _parseAmount(product.price?.price?.toString()) ??
    fallbackPrice ?? 0.0;
```

The existing `offerPrice` field (`lib/models/get_product.dart:100`) is a dead,
display-only value — it is shown in the product details dialog
(`lib/widgets/product_details_dialog.dart:1236`) but **never feeds into the actual
selling price, and carries no time window**. So it cannot support
"sell at offer price for a duration."

That offline + single-choke-point reality is what determines the answer.

## Recommendation: hybrid, NOT "offer field inside each product"

### Don't put the schedule inside each product
A raw `offer_price` per product can't express *when* it's valid, and for
**category offers** you'd have to stamp the same offer onto every product in the
category — meaning a full product-list re-sync every time a campaign starts/ends or
a product changes category. Wrong place to keep it.

### Do this instead — two parts

**1. A separate `/promotions` (offers) endpoint** — the source of truth, cached in
Hive like products/categories already are. Each campaign is one row, scoped to
products *or* categories:

```json
{
  "promotions": [
    {
      "id": 12,
      "name": "Weekend Soda 20% Off",
      "scope": "category",           // "product" | "category"
      "target_ids": [4, 7],          // category ids (or product ids)
      "discount_type": "percentage", // "percentage" | "flat" | "fixed_price"
      "value": "20",
      "starts_at": "2026-06-06T00:00:00Z",
      "ends_at":   "2026-06-08T23:59:59Z",
      "priority": 10,
      "active": true
    }
  ]
}
```

Why a separate endpoint, given offline:
- One campaign row instead of duplicating it across hundreds of products.
- Editing/ending a campaign = sync one small list, not the whole catalog.
- The client evaluates `starts_at`/`ends_at` **locally** at sell time — critical,
  because a cached POS can't rely on the server to "turn the offer on" at the right
  moment. The window travels with the data.

**2. The product-list API stays almost as-is** — just keep `category_id` (already
present) so the client can match category-scoped promos. A denormalized convenience
flag is optional, not required.

### Where the code changes go
Resolve the offer client-side, right inside `_resolveUnitPrice`, so *every* call
site (add to cart, refresh pricing — the 6 call sites) gets it for free:

```dart
double _resolveUnitPrice({...}) {
  final basePrice = _parseAmount(selectedStock?.price) ??
      _parseAmount(product.price?.price?.toString()) ??
      fallbackPrice ?? 0.0;

  // wholesale check stays as-is...

  final offer = _activePromotionFor(product, DateTime.now()); // checks window + scope
  if (offer != null) {
    return offer.apply(basePrice); // min(base, computed) for safety
  }
  return basePrice;
}
```

## Decisions to nail down with client / backend

| Concern | Recommendation |
|---|---|
| **Product vs category conflict** | Use `priority`; product-scoped beats category-scoped on tie. Resolve to a single winning price, never stack. |
| **Clock source** | Evaluate against device time, but consider syncing a server-time offset on login — a POS with a wrong clock would mis-apply offers. |
| **Tax** | Decide if the offer is the new taxable base (almost always yes). Tax calc runs off the resolved unit price, so this is automatic if the offer feeds `_resolveUnitPrice`. |
| **MRP / strike-through** | Keep base price as `mrp`/`oldPrice` for the UI to show "was X now Y". |
| **Offer vs manual override** | `isManualPriceOverride` already exists — a manual price should win over an auto-offer. Honor that flag. |

## Bottom line
- **No** raw offer field stamped per-product for the schedule.
- **Yes** a separate cached `/promotions` endpoint (product- *and* category-scoped,
  with `starts_at` / `ends_at` / `priority`).
- Resolve locally in `_resolveUnitPrice` so it works offline and flows through tax +
  cart automatically.

## Implementation pieces (when ready to build)
1. `Promotion` model + Hive adapter (cache alongside products/categories).
2. Fetch + cache logic for `/promotions` (mirror existing product/category sync).
3. `_activePromotionFor(product, now)` resolver — filters by active window, matches
   product- or category-scope, picks winner by `priority`.
4. Hook into `_resolveUnitPrice` (`local_product_provider.dart:535`).
5. UI: strike-through MRP + offer price in product cards and details dialog.
