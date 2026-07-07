# Product Variants — API Guide

How product variants work across the mobile/POS API. This mirrors the web
**Manage Variants** page (`app/Filament/Tenant/Pages/ManageVariants.php`) but keeps
the payloads flat and simple for API clients.

A **variant** is a specific sellable version of a product (e.g. *T‑Shirt · Red · L*).
Each variant carries its own `sku`, `barcode`, pricing and stock, and a set of
**attributes** (property → value pairs such as `COLOR → Red`, `SIZE → L`).

## Data model

| Table | Purpose |
|-------|---------|
| `product_variants` | one row per variant (`product_id`, `sku`, `barcode`, `price`, `mrp`, `purchase_price`, `quantity`, `reorder_level`, `active`) |
| `product_variant_attributes` | attribute rows (`product_variant_id`, `product_prop_id`, `value`) |
| `product_stocks.product_variant_id` | stock is scoped to a variant when set, else it is general product stock |
| `cart_items.product_variant_id` / `variant_attributes` | variant chosen for an order line + a snapshot of its attributes |

**Attributes** reference `product_props` (type `LST`, `MLT`, or `TXT`). Fetch the
selectable properties/values for a product's category with:

```
GET /api/v1/product/list-product-properties
```

> Variants are gated by the `PRODUCT_VARIANT_ENABLED` setting. When it is `0`,
> clients should hide variant UI; the API still stores whatever is sent.

---

## 1. Create — `POST /api/v1/product/create-product`

Send a `variants[]` array alongside the normal product fields. Omit `id` to create.
`sku` is auto‑generated from the product SKU + attributes when left blank.

```jsonc
{
  "name": "Cotton T-Shirt",
  "category_id": 12,
  "price": 499,
  "unit": 3,
  "variants": [
    {
      "sku": null,                 // optional — auto-generated when null
      "barcode": "TS-RED-L",       // optional
      "price": 549,                // optional — falls back to product price
      "mrp": 599,                  // optional
      "purchase_price": 300,       // optional
      "reorder_level": 5,          // optional (default 5)
      "active": true,              // optional (default true)
      "attributes": [
        { "product_prop_id": 7, "value": "Red" },
        { "product_prop_id": 9, "value": "L" }
      ]
    }
  ]
}
```

**Rules**

- `variants` — `nullable|array`
- `variants.*.price|mrp|purchase_price|reorder_level` — `nullable|numeric|min:0`
- `variants.*.active` — `nullable|boolean`
- `variants.*.attributes.*.product_prop_id` — `required|exists:product_props,id`
- `variants.*.attributes.*.value` — `nullable|string`

The response includes the created variants (see the variant object shape below).

---

## 2. Edit — `POST /api/v1/product/edit-product/{id}`

Same `variants[]` array. The `id` field on each item controls the action:

| Payload | Action |
|---------|--------|
| item **without** `id` | create a new variant |
| item **with** `id` | update that variant |
| item with `id` + `"_delete": true` | delete that variant (and its attributes) |
| variant simply omitted from the array | **left untouched** (no implicit deletes) |

```jsonc
{
  "variants": [
    { "id": 41, "price": 575, "attributes": [
        { "product_prop_id": 7, "value": "Red" },
        { "product_prop_id": 9, "value": "XL" }
    ]},
    { "id": 42, "_delete": true },
    { "barcode": "TS-BLU-M", "attributes": [
        { "product_prop_id": 7, "value": "Blue" },
        { "product_prop_id": 9, "value": "M" }
    ]}
  ]
}
```

On every update the variant's attributes are **fully replaced** (delete + recreate),
so always send the complete attribute set for a variant.

**Additional rule:** `variants.*.id` — `nullable|integer|exists:product_variants,id`.

---

## 3. Get Products

Variants are returned by every product read endpoint via `ProductVariantResource`.
Only **active** variants are eager‑loaded.

- `GET /api/v1/product/list-products`
- `GET /api/v1/product/product/{slug}`
- `GET /api/v1/product/executive/list-products`

**Variant object shape**

```jsonc
{
  "id": 41,
  "sku": "COTTON-TS-RED-L",
  "barcode": "TS-RED-L",
  "price": "549.00",
  "mrp": "599.00",
  "purchase_price": "300.00",
  "quantity": 12.0,
  "active": true,
  "attributes": { "COLOR": "Red", "SIZE": "L" },   // flattened prop code → value
  "images": [ { "url": "...", "alt": "...", "title": "..." } ]
}
```

---

## 4. Add to Order — `POST /api/v1/order/add-to-order`

Pass `product_variant_id` on the order line. Stock is validated against that
variant's stock rows; when omitted, only general (non‑variant) product stock is used.
Pricing precedence is **variant price → product price**.

```jsonc
{
  "items": [
    {
      "product_id": 30,
      "product_variant_id": 41,   // nullable
      "quantity": 2,
      "sale_unit_id": 5           // optional
    }
  ]
}
```

The cart line stores `product_variant_id` and a `variant_attributes` snapshot
(e.g. `{ "COLOR": "Red", "SIZE": "L" }`) so the chosen variant is preserved even if
the variant is later edited.

Validation: `items.*.product_variant_id` — `nullable|exists:product_variants,id`.

---

## 5. Sales Return — `POST /api/v1/order/sales-return`

Returns operate on the original order items, which already carry
`product_variant_id`. Reference the order item being returned; the variant and its
attribute snapshot are preserved and stock is restored to the correct variant.
No extra variant fields are required in the return payload beyond the order item
reference.

---

## 6. Order Details

- `GET /api/v1/order/order-details/{order_number}`
- `GET /api/v1/order/executive/order-details/{order_number}`

Each order item includes:

```jsonc
{
  "product_id": 30,
  "product_variant_id": 41,
  "variant_attributes": { "COLOR": "Red", "SIZE": "L" },
  "quantity": 2,
  "price": 549
}
```

`variant_attributes` is the snapshot captured at order time, so historical orders
render correctly regardless of later variant edits.

---

## Quick reference

| Flow | Endpoint | Variant handling |
|------|----------|------------------|
| Create | `POST /product/create-product` | `variants[]` (no `id`) → create |
| Edit | `POST /product/edit-product/{id}` | `variants[]` with `id` / `_delete` → update/delete |
| Get Products | `GET /product/list-products`, `/product/{slug}` | active variants via `ProductVariantResource` |
| Add to Order | `POST /order/add-to-order` | `product_variant_id` per line |
| Sales Return | `POST /order/sales-return` | inherits variant from order item |
| Order Details | `GET /order/order-details/{order_number}` | `product_variant_id` + `variant_attributes` |
</content>
</invoke>
