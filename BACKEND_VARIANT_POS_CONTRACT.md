# Product Variants — Backend Contract for Flutter POS

**Audience:** Backend developer (`enkepos`)  
**Client:** Flutter POS (`eposmob`)  
**API prefix:** `/api/v1`  
**Status:** Authoritative handoff — implement against this document

---

## Summary

The Flutter POS **already implements** product variants end-to-end for shop billing. This document is the single contract the backend must satisfy. Internal audit notes (`docs/qdoc/backend-varient.md`, `docs/backend_findings_for_dev.md`) are supplementary only.

A **variant** is a sellable version of a product (e.g. T-Shirt · Red · L) with its own ID, SKU, barcode, price, attributes, and stock rows.

---

## How the Flutter POS uses variants (read this first)

Shop billing does **not** use backend cart APIs for the main flow.

```text
1. Sync catalog     GET /api/v1/product/executive/list-products
2. Local cart       Hive + LocalProductProvider (offline)
3. Variant resolve  barcode match / picker / single-variant auto-pick
4. Checkout         POST /api/v1/order/add-to-order  (source_type: executive)
5. Print / history  GET /api/v1/order/order-details/{order_number}
```

Backend cart endpoints (`/cart/add-to-cart`) apply to **restaurant/kiosk** flows only, not primary shop billing.

The POS sends `product_variant_id` on order and quotation items. It does **not** always send `variant_attributes` on create — the backend must snapshot attributes from the catalog at order/quotation time.

---

## Required tenant settings

| Setting code | Purpose | App default if missing |
|---|---|---|
| `PRODUCT_VARIANT_ENABLED` | Show variant UI and resolve variants on add-to-cart | `false` (variants off) |
| `ALLOW_OVERSELL` | Allow selling more than available stock | `true` (oversell allowed) |

---

## Field name aliases (important)

The Flutter app uses different keys in different flows. Backend should accept the documented aliases.

| Concept | Order checkout (`add-to-order`) | Quotation create |
|---|---|---|
| Stock row ID | `stock_id` | `product_stock_id` |
| Sale unit ID | `sale_unit_id` and/or `product_sale_unit_id` | `product_sale_unit_id` |
| Variant ID | `product_variant_id` | `product_variant_id` |

Quotation detail responses should accept **either** `product_stock_id` or `stock_id` when reading stock back.

---

## 1. Product properties

### `GET /api/v1/product/list-product-properties`

Load attribute definitions (Color, Size, etc.) for the variant editor.

Alias (may also be supported):

```http
GET /api/v1/category/list-product-properties
```

Response must expose stable `id`, `code`, `name`, and `type` per property. Variant create/edit payloads reference properties by `product_prop_id`.

---

## 2. Create product

### `POST /api/v1/product/create-product`

```json
{
  "name": "Cotton T-Shirt",
  "category_id": 12,
  "price": 499,
  "mrp": 599,
  "barcode": "890000000",
  "unit": 3,
  "quantity": 0,
  "variants": [
    {
      "sku": "TS-RED-L",
      "barcode": "890000001",
      "price": 549,
      "mrp": 599,
      "purchase_price": 300,
      "quantity": 20,
      "reorder_level": 5,
      "active": true,
      "attributes": [
        { "product_prop_id": 7, "value": "Red" },
        { "product_prop_id": 9, "value": "L" }
      ]
    }
  ]
}
```

**Write payload rules**

- `attributes` on create/edit: array of `{ product_prop_id, value }`.
- `variant_mode` is optional; backend may infer variant mode when `variants[]` is non-empty.
- `variants.*.quantity` must be validated: `nullable|numeric|min:0`.
- Reject duplicate attribute combinations within the same product (HTTP `422`).
- Reject duplicate variant barcodes/SKUs within tenant (HTTP `422`).
- Auto-generate SKU when blank.
- Validation failures must return HTTP **422**, not 500.

**Critical: opening stock for variants**

When `variants[].quantity` is supplied, backend must create a **`product_stocks` row** scoped with `product_variant_id`, not only update `product_variants.quantity`.

| Stock type | `product_variant_id` |
|---|---|
| General (non-variant) product stock | `null` |
| Variant stock | variant `id` |

A product with variants must **not** sell variant quantity from a general stock row (`product_variant_id = null`).

---

## 3. Edit product and variants

### `POST /api/v1/product/edit-product/{product_id}`

```json
{
  "variants": [
    {
      "id": 41,
      "sku": "TS-RED-XL",
      "price": 575,
      "mrp": 599,
      "active": true,
      "attributes": [
        { "product_prop_id": 7, "value": "Red" },
        { "product_prop_id": 9, "value": "XL" }
      ]
    },
    { "id": 42, "_delete": true },
    {
      "sku": "TS-BLUE-M",
      "barcode": "890000002",
      "price": 549,
      "active": true,
      "attributes": [
        { "product_prop_id": 7, "value": "Blue" },
        { "product_prop_id": 9, "value": "M" }
      ]
    }
  ]
}
```

| Payload | Action |
|---|---|
| No `id` | Create new variant |
| With `id` | Update variant (attributes are fully replaced) |
| `id` + `_delete: true` | Delete/deactivate variant |
| Omitted from array | Leave unchanged |

---

## 4. Product sync (primary POS endpoint)

### `GET /api/v1/product/executive/list-products`

This is the **main catalog sync** used by shop billing (not only `list-products`).

**Query parameters the POS sends**

| Param | Purpose |
|---|---|
| `store_id` | Store-scoped stock |
| `updated_at_range` | Delta sync: `{iso_from},{iso_to}` |
| `page` | Pagination |
| `type=sellable` | Optional sellable filter |

**Required product shape**

```json
{
  "product_id": 30,
  "product_name": "Cotton T-Shirt",
  "variant_mode": true,
  "has_variants": true,
  "variants": [
    {
      "id": 41,
      "sku": "TS-RED-L",
      "barcode": "890000001",
      "price": "549.00",
      "mrp": "599.00",
      "purchase_price": "300.00",
      "quantity": 12,
      "available_quantity": 12,
      "active": true,
      "attributes": {
        "COLOR": "Red",
        "SIZE": "L"
      },
      "images": []
    }
  ],
  "stock": [
    {
      "id": 501,
      "product_id": 30,
      "product_variant_id": 41,
      "store_id": 1,
      "quantity": 12,
      "price": "549.00",
      "mrp": "599.00",
      "sku": "TS-RED-L"
    }
  ]
}
```

**Read response rules**

- Include `variant_mode` and/or `has_variants` on every product (app falls back to `variants.length > 0` if absent).
- Return only **active** variants in POS list responses.
- `attributes` must be a **flattened map keyed by property `code`** (e.g. `COLOR`, `SIZE`), not display name.
- Prefer `available_quantity` for store-scoped availability; keep `quantity` as fallback.
- **Every `stock[]` row must include `product_variant_id`** (`null` for general stock). **This is required for offline POS stock scoping.**
- Include zero-quantity stock rows when the POS must show out-of-stock variants.
- Variant, product, and stock changes must appear in `updated_at_range` delta sync responses.
- Index variant barcodes for lookup the same as product and sale-unit barcodes.

Also applies to:

- `GET /api/v1/product/list-products`
- `GET /api/v1/product/product/{slug}`

---

## 5. Stock scoping rules (strict)

| Sale type | Stock rows that may be consumed |
|---|---|
| Plain product (no `product_variant_id` on line) | Rows where `product_variant_id` IS NULL |
| Variant line (`product_variant_id = 41`) | Rows where `product_variant_id = 41` only |

Never deduct variant sales from general stock, or general sales from variant stock.

**Pricing precedence** (when client does not send explicit price):

1. Client-provided `price` (always wins)
2. Variant `price` (if > 0)
3. Stock `retail_price` (when `stock_id` provided)
4. Product base `price`

Same pattern for MRP using variant MRP → product MRP.

---

## 6. Product stock APIs

### `POST /api/v1/product/add-stock`

```json
{
  "product_id": 30,
  "product_variant_id": 41,
  "store_id": 1,
  "quantity": 20,
  "price": 549,
  "mrp": 599,
  "purchase_price": 300
}
```

- `product_variant_id` is **required** when the product has active variants and `PRODUCT_VARIANT_ENABLED` is on.
- Omit or null for general product stock.

### `POST /api/v1/product/update-stock/{stock_id}`

Response must include updated `product_id`, `product_variant_id`, `store_id`, `quantity`, `price`, `mrp`.

### `GET /api/v1/product/list-stocks`

Every row includes `product_variant_id` (null for general stock).

### `POST /api/v1/stocks/move/{stock_id}`

Destination stock must preserve `product_variant_id`. Variant stock must not become general stock on transfer.

---

## 7. Barcode generation

### `GET /api/v1/product/generate-barcode`

Generated barcodes must not conflict with existing product, sale-unit, or variant barcodes. Use consistent trim/normalization for save and lookup.

---

## 8. Order checkout (shop billing — primary)

### `POST /api/v1/order/add-to-order`

The POS sends `source_type: "executive"` and an `items[]` array built locally (not from backend cart).

**Per-item payload**

```json
{
  "product_id": 30,
  "product_variant_id": 41,
  "quantity": 2,
  "price": 549,
  "mrp": 599,
  "stock_id": 501,
  "sale_unit_id": 5,
  "product_sale_unit_id": 5,
  "warranty_enabled": false
}
```

**Backend must**

- Validate `product_variant_id` belongs to `product_id` and tenant.
- Validate `stock_id` belongs to same product, variant, store, and tenant.
- Apply variant-scoped stock deduction on confirm (`product_variant_id` threaded through validate + adjust).
- Persist `product_variant_id` on cart/order item.
- **Snapshot `variant_attributes`** on the order line at creation time (client may omit them).
- Support `quotation_id` when converting a quotation to an order.

### `POST /api/v1/order/confirm-order`

If this endpoint recalculates items, preserve the same `product_variant_id`, stock identity, quantity, and price rules as `add-to-order`.

---

## 9. Quotations (required — Flutter already sends variant ID)

### `POST /api/v1/quotations`

### `GET /api/v1/quotations/{id}`

### `POST /api/v1/quotations/convert-to-order`

**Create item payload (from Flutter)**

```json
{
  "product_id": 30,
  "product_variant_id": 41,
  "product_stock_id": 501,
  "product_sale_unit_id": 5,
  "quantity": 2,
  "price": 549
}
```

**Backend must**

- Validate and store `product_variant_id` on quotation cart items.
- Select stock and price using the same variant scoping rules as orders.
- Return `product_variant_id` (and `variant_attributes` when possible) on quotation detail items.
- Preserve variant identity when converting quotation → order.

---

## 10. Order details

### `GET /api/v1/order/order-details/{order_number}`

### `GET /api/v1/order/executive/order-details/{order_number}`

Every variant line must include:

```json
{
  "product_id": 30,
  "product_variant_id": 41,
  "variant_attributes": {
    "COLOR": "Red",
    "SIZE": "L"
  },
  "quantity": 2,
  "price": 549,
  "mrp": 599
}
```

`variant_attributes` is a **historical snapshot** — do not rewrite it when the catalog variant is edited later.

`variant_attributes` may be returned as a JSON object or JSON-encoded string; the Flutter client parses both.

---

## 11. Sales return

### `POST /api/v1/order/sales-return`

Flutter submits:

```json
{
  "order_id": 1001,
  "cart_item_id": 55,
  "quantity": 1,
  "price": 549,
  "reason": "Damaged"
}
```

No extra variant fields required in the request — resolve variant from the original `cart_item_id`.

### `GET` return item listing

Include `product_variant_id` and `variant_attributes` on each returnable line.

### `POST /api/v1/order/complete-return-order`

When restoring physical stock, call stock adjustment with **all** of:

- `product_stock_id`
- `product_variant_id`
- `store_id`

Restore only the returned variant's stock row. Do not restore to general stock for a variant sale.

Stock restore happens on **complete**, not on the draft `sales-return` call (to avoid double restoration).

---

## 12. Backend cart APIs (secondary)

Used by restaurant/kiosk, **not** primary shop billing.

### `POST /api/v1/cart/add-to-cart`

### `POST /api/v1/cart/add-to-cart-bulk`

Should accept and return `product_variant_id` and `variant_attributes` when used. Cart line identity must distinguish product, variant, sale unit, and stock selection.

---

## 13. Validation and error responses

Return HTTP **422** for:

- `product_variant_id` not belonging to `product_id`
- Variant from another tenant
- Stock row mismatch (wrong product / variant / store)
- Duplicate variant barcode or SKU
- Duplicate attribute combination on same product
- Invalid or missing required variant attributes
- Sale unit not belonging to product
- Insufficient stock when `ALLOW_OVERSELL` is off

**Suggested stock conflict body** (optional but recommended):

```json
{
  "message": "Insufficient stock for selected variant",
  "code": "VARIANT_STOCK_CONFLICT",
  "product_id": 30,
  "product_variant_id": 41,
  "requested_quantity": 3,
  "available_quantity": 1,
  "stock_status": "rejected"
}
```

**Stock status values** (optional on order/cart responses): `allocated`, `oversold`, `out_of_stock`, `rejected`.

---

## 14. Acceptance test checklist

Integration is complete when all of the following pass:

- [ ] Create product with Red and Green variants, each with own `product_stocks` row (`product_variant_id` set).
- [ ] Sync via `executive/list-products` — each `stock[]` row includes `product_variant_id`.
- [ ] Variant `attributes` keyed by property code (`COLOR`, `SIZE`).
- [ ] Scan Red variant barcode → POS resolves Red (parent product + variant match).
- [ ] Add Red and Green → two separate cart lines in POS.
- [ ] Confirm order with `product_variant_id` → only Red/Green respective stock decreases.
- [ ] Order details show `product_variant_id` + `variant_attributes` snapshot.
- [ ] Create quotation with Red → `product_variant_id` stored and returned on GET.
- [ ] Convert quotation to order → variant preserved.
- [ ] Return Red item → only Red stock restored on `complete-return-order`.
- [ ] Duplicate variant attribute combo rejected with 422 on create/edit.

---

## 15. Known gaps to fix (as of POS audit)

Track these against `enkepos` before marking variant work done:

| Priority | Issue |
|---|---|
| **P0** | `executive/list-products` (and related product responses): `stock[]` mapper omits `product_variant_id` |
| **P0** | `QuotationController`: does not validate/store `product_variant_id` on cart items |
| **P1** | `completeReturnOrder()`: stock restore must pass `product_variant_id` + `store_id` to `adjustStock()` |
| **P1** | Variant create: `variants[].quantity` should create `product_stocks` row, not only `product_variants.quantity` |
| **P2** | Expose `available_quantity` on variant resource (keep `quantity` as fallback) |
| **P2** | Expose `variant_mode` / `has_variants` on product responses |

---

## 16. Out of scope for this document

- Flutter print layout gaps (receipt variant label) — frontend follow-up
- Non-variant backend findings (additive edit quantity, margin floor server-side, etc.) — see `docs/backend_findings_for_dev.md`
- Database schema choices — backend team's decision, as long as API contract above is met

---

## Reference: Flutter files implementing this contract

| Area | Path |
|---|---|
| Variant resolution | `lib/features/billing/domain/product_variant_selection.dart` |
| Add-to-cart entry | `lib/helpers/product_cart_helper.dart` |
| Cart line model | `lib/providers/local_product_provider.dart` (`LocalCartItem`) |
| Order payload | `LocalProductProvider.buildOrderItemsPayload()` |
| Quotation payload | `lib/features/billing/domain/quotation_checkout.dart` |
| Product model | `lib/models/get_product.dart` (`ProductVariant`, `Stock.productVariantId`) |

---

*This document supersedes `BACKEND_VARIANT_HANDOFF.md` and `docs/qdoc/PRODUCT_VARIANTS_API.md` for POS integration purposes. Update this file when the contract changes.*
