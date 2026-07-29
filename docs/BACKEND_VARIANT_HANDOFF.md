# Product Variant API Requirements

**Audience:** Backend developer  
**Client:** Flutter POS application  
**API prefix:** `/api/v1`

## Purpose

The Flutter app already supports product variants. This document lists only the API data and behavior required by the app. The backend developer can choose the database structure and implementation approach.

A variant is a separate sellable version of a product, such as:

```text
Product: T-Shirt
Variant: COLOR=Red, SIZE=L
```

Each variant needs its own ID, SKU, barcode, price, attributes, active status, and stock availability.

## Required settings

The existing app-settings response must expose these setting codes:

| Setting code | Use |
|---|---|
| `PRODUCT_VARIANT_ENABLED` | Enables or disables variant functionality for the tenant. |
| `ALLOW_OVERSELL` | Controls whether the POS can sell more than available stock. |

The app defaults to variants disabled when `PRODUCT_VARIANT_ENABLED` is missing. It defaults to overselling allowed when `ALLOW_OVERSELL` is missing.

## 1. Product properties

### `GET /api/v1/product/list-product-properties`

**Use:** Load the attribute/property options used to create variants, such as Color and Size.

The response must provide stable property IDs and readable property codes/names. Variant attributes reference these property IDs.

The existing alias may also be supported:

```http
GET /api/v1/category/list-product-properties
```

## 2. Create product

### `POST /api/v1/product/create-product`

**Use:** Create a product, optionally with its variants.

The existing product fields remain unchanged. Add support for `variants[]`:

```json
{
  "name": "Cotton T-Shirt",
  "category_id": 12,
  "price": 499,
  "mrp": 599,
  "variant_mode": true,
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

Required behavior:

- Create every submitted variant under the created product.
- Return the created variant IDs.
- Treat `sku`, `barcode`, prices, `reorder_level`, and `active` as variant-level fields.
- Allow blank SKU if the backend generates one.
- Validate that each property ID belongs to the tenant.
- Validate that each variant has valid attributes.
- Validate that two variants of the same product do not have the same attribute combination.
- If `quantity` is supplied, associate the opening stock with that variant.
- Return the product with its variants in the response.

## 3. Edit product and variants

### `POST /api/v1/product/edit-product/{product_id}`

**Use:** Update existing variants, create new variants, or delete variants while editing a product.

```json
{
  "variants": [
    {
      "id": 41,
      "sku": "TS-RED-XL",
      "price": 575,
      "mrp": 599,
      "purchase_price": 300,
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

Payload meaning:

| Payload | Meaning |
|---|---|
| Variant without `id` | Create a new variant. |
| Variant with `id` | Update that variant. |
| Variant with `id` and `_delete: true` | Delete or deactivate that variant according to backend policy. |
| Existing variant omitted from the array | Leave it unchanged. |

When updating a variant, the `attributes` array represents the complete current attribute set.

## 4. Product list and product details

Variants are required in all product responses used by the POS:

### `GET /api/v1/product/list-products`

**Use:** Load the product catalog.

### `GET /api/v1/product/product/{slug}`

**Use:** Load one product and its variants.

### `GET /api/v1/product/executive/list-products`

**Use:** Store-scoped product synchronization for the POS/offline catalog.

The product response must include:

```json
{
  "product_id": 30,
  "product_name": "Cotton T-Shirt",
  "variant_mode": true,
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

Required behavior:

- Include `variant_mode` or `has_variants` on every product.
- Include active variants in normal POS product lists.
- Include `id`, SKU, barcode, prices, active status, attributes, and availability for every variant.
- `attributes` must be a flattened map keyed by property code/name.
- Prefer `available_quantity` for store-specific availability.
- Keep legacy `quantity` if existing clients use it.
- Include `product_variant_id` on every stock row.
- Include zero-quantity rows when the POS needs to show an out-of-stock variant.
- Product and stock changes must appear in incremental synchronization responses.
- A product with `variant_mode: true` and no active variants must not be treated as a normal base product by the POS.

## 5. Product stock APIs

### `POST /api/v1/product/add-stock`

**Use:** Add stock to a product or a specific variant.

The stock request must accept:

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

For a variant stock row, `product_variant_id` is required. For general product stock, it is null/omitted.

### `POST /api/v1/product/update-stock/{stock_id}`

**Use:** Update an existing stock row.

The response must return the updated product ID, variant ID, store ID, quantity, price, and MRP.

### `GET /api/v1/product/list-stocks`

**Use:** Load stock rows for product/variant stock management.

Every stock row must include `product_variant_id`, including null for general stock.

### `POST /api/v1/stocks/move/{stock_id}`

**Use:** Move stock between stores.

The destination stock must preserve the original `product_variant_id`. Variant stock must not become general stock during a transfer.

## 6. Barcode generation and lookup

### `GET /api/v1/product/generate-barcode`

**Use:** Generate a barcode for a new product, sale unit, or variant.

Generated variant barcodes must not conflict with existing:

- Product barcodes.
- Sale-unit barcodes.
- Other variant barcodes.

Barcode comparison should use the same trimming/normalization rules for generation, saving, and lookup.

The variant barcode must be returned in the product response so the POS can scan it directly.

## 7. Cart APIs

Existing cart endpoints:

### `POST /api/v1/cart/add-to-cart`

### `POST /api/v1/cart/add-to-cart-bulk`

**Use:** Add one or multiple product lines to a backend cart.

Cart item input must accept and preserve:

```json
{
  "product_id": 30,
  "product_variant_id": 41,
  "quantity": 2,
  "stock_id": 501,
  "sale_unit_id": 5,
  "product_sale_unit_id": 5,
  "price": 549,
  "mrp": 599
}
```

The cart response must preserve `product_variant_id` and variant attributes for every line.

Cart line identity must distinguish:

- Different products.
- Different variants of the same product.
- Different sale units.
- Different stock selections where the existing POS stock grouping requires separate lines.

## 8. Order and checkout APIs

### `POST /api/v1/order/add-to-order`

**Use:** Submit the POS cart/order lines for order creation or checkout.

Every variant line must accept:

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

Required behavior:

- Validate that the variant belongs to the product and tenant.
- Validate that `stock_id` belongs to the same tenant, store, product, and variant.
- A variant line may use only stock for that exact variant.
- A line without `product_variant_id` may use only general product stock.
- Preserve `product_variant_id` on the cart and order item.
- Save a `variant_attributes` snapshot for historical display.
- Validate sale-unit ownership and conversion rate.
- Apply the configured stock policy and return the resulting stock status.
- Apply server-side pricing rules and return/persist the final charged price.

### `POST /api/v1/order/confirm-order`

**Use:** Confirm/pay the order.

If this endpoint accepts or recalculates order items, it must preserve the same `product_variant_id`, stock identity, quantity, and final price rules as `add-to-order`.

## 9. Order details APIs

### `GET /api/v1/order/order-details/{order_number}`

### `GET /api/v1/order/executive/order-details/{order_number}`

**Use:** Display completed/saved order details in the POS.

Every variant order item must include:

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

The attribute snapshot should remain unchanged if the catalog variant is edited later.

## 10. Sales return APIs

### `POST /api/v1/order/sales-return`

**Use:** Create a sales return using the original order item.

The return flow must retain the original variant ID, variant attributes, store, and stock allocation.

### `POST /api/v1/order/complete-return-order`

**Use:** Complete the return and apply the configured inventory/refund behavior.

The response should identify the returned product variant and restored quantity. Repeating completion must not restore the same stock twice.

## 11. Required validation behavior

The API should return a normal validation error, preferably HTTP `422`, when:

- `product_variant_id` does not belong to `product_id`.
- A variant ID belongs to another tenant.
- A stock ID belongs to another product, variant, store, or tenant.
- A variant barcode or SKU conflicts with an existing record.
- Duplicate attributes are submitted for one product.
- A variant has invalid or missing required attributes.
- A sale unit does not belong to the product.
- Strict stock mode does not have enough stock.

Suggested machine-readable stock conflict response:

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

## 12. Stock status response

For order/cart operations, return enough information for the POS to understand the result:

```json
{
  "stock_status": "allocated",
  "allocated_quantity": 2,
  "unallocated_quantity": 0
}
```

When overselling is allowed:

```json
{
  "stock_status": "oversold",
  "allocated_quantity": 1,
  "unallocated_quantity": 1
}
```

Recommended status values are `allocated`, `oversold`, `out_of_stock`, and `rejected`.

## 13. Minimal end-to-end expectation

The frontend/backend integration is complete when this works:

1. Create one product with Red and Green variants.
2. Sync the product to the POS and receive both variants with separate IDs and stock rows.
3. Scan or select Red and add it to the cart.
4. Confirm the order and ensure only Red stock is affected.
5. Add Red and Green together and keep them as separate order lines.
6. Reload the order and display each variant's attributes.
7. Return Red and restore only Red's quantity.

The backend developer may choose the internal tables, services, transactions, caching, and migration strategy, provided the endpoint behavior and response fields above remain compatible with the Flutter app.
