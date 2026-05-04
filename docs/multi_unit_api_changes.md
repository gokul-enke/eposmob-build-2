# Multi Unit API Changes

This note is for backend development planning. It lists the API changes that would make multi-unit billing fully reliable in the mobile app and other POS clients.

Current backend already supports:
- `product_sale_units`
- `product_stocks.purchase_unit_id`
- `product_stocks.purchase_qty`
- cart items with `product_sale_unit_id`
- conversion-aware stock validation

The main issue is not database structure. The main issue is that the product/list API response is still too thin for clients to make correct billing decisions automatically.

## Goal

Clients should be able to:
- scan a product barcode
- scan a sale-unit barcode
- choose or auto-pick correct stock
- apply correct tax
- apply correct wholesale threshold
- preserve sale-unit identity in cart

without guessing from purchase data on the client.

## Recommended Product API Additions

## 1. Sale unit billing fields

Each `sale_unit` should optionally return billing-ready fields, not just conversion fields.

### Current

```json
{
  "id": 69,
  "unit_id": 7858,
  "unit_name": "PACKS",
  "conversion_rate": "30.00",
  "barcode": "111000127"
}
```

### Recommended

```json
{
  "id": 69,
  "unit_id": 7858,
  "unit_name": "PACKS",
  "conversion_rate": "30.00",
  "barcode": "111000127",
  "retail_price": "55.00",
  "mrp": "60.00",
  "tax_rate": "18.00",
  "is_base_unit": false,
  "display_quantity": "1.00",
  "base_quantity": "30.00",
  "preferred_stock_ids": [2286],
  "pricing_group_key": "packs_group",
  "allowed_variant_ids": [],
  "display_label": "1 PACKS = 30 PCS"
}
```

### Why

- `retail_price`
  - required when sale-unit pricing is not linear
  - example: 1 pack price is not always piece price × 30

- `mrp`
  - sale-unit-specific MRP may differ from derived base-unit MRP

- `tax_rate`
  - lets client apply correct tax without guessing from stock rows

- `is_base_unit`
  - helps distinguish actual alternate sale units from the default base unit

- `display_quantity`
  - allows clients to preserve `1 PACKS`, `1 CASE`, etc.

- `base_quantity`
  - explicit converted base-unit quantity

- `preferred_stock_ids`
  - lets client auto-resolve stock instead of showing all stock groups

- `pricing_group_key`
  - stable grouping key from backend, better than client-generated grouping

- `allowed_variant_ids`
  - needed when sale units differ by variant

- `display_label`
  - convenience for UI

## 2. Stock response additions

Stock rows should return enough data for billing context resolution.

### Current useful fields
- `id`
- `quantity`
- `price`
- `mrp`
- `tax_rate`
- `wholesale_price`
- `wholesale_min_unit`
- `purchase_unit_id`
- `purchase_qty`

### Recommended response

```json
{
  "id": 2286,
  "product_id": 18221,
  "store_id": 2,
  "quantity": "30.000",
  "price": "2.000",
  "mrp": "200.000",
  "tax_rate": "18.00",
  "wholesale_price": "1.000",
  "wholesale_min_unit": 100,
  "purchase_unit_id": 69,
  "purchase_unit_name": "PACKS",
  "purchase_qty": "1.000",
  "pricing_group_key": "packs_group",
  "supported_sale_unit_ids": [69]
}
```

### Why

- `purchase_unit_name`
  - helpful fallback for clients and debugging

- `pricing_group_key`
  - backend-defined group for stock auto-selection

- `supported_sale_unit_ids`
  - explicit mapping from stock row to sale units

## 3. Clarify wholesale unit basis

Backend should formally define whether `wholesale_min_unit` is measured in:
- base units
- sale units

### Recommended

Always return explicit basis:

```json
{
  "wholesale_price": "1.000",
  "wholesale_min_unit": 100,
  "wholesale_unit_basis": "base_unit"
}
```

Supported values:
- `base_unit`
- `sale_unit`

### Why

Clients should not guess whether:
- `100` means `100 PCS`
- or `100 PACKS`

## 4. Sale-unit-aware barcode metadata

For barcode-driven billing, barcode matches should carry more context.

### Recommended

If a barcode belongs to a sale unit, product/list response should already be enough.
Optionally, a dedicated barcode lookup response can also help:

```json
{
  "barcode": "111000127",
  "type": "sale_unit",
  "product_id": 18221,
  "sale_unit_id": 69,
  "sale_unit_name": "PACKS",
  "base_quantity": "30.00",
  "retail_price": "55.00",
  "mrp": "60.00",
  "tax_rate": "18.00",
  "preferred_stock_ids": [2286],
  "pricing_group_key": "packs_group"
}
```

### Why

This makes barcode scan behavior deterministic and simple for all clients.

## 5. Cart API contract for sale units

When clients add items to cart, they should be able to send sale-unit identity directly.

### Recommended request support

```json
{
  "items": [
    {
      "product_id": 18221,
      "quantity": 1,
      "sale_unit_id": 69,
      "stock_id": 2286
    }
  ]
}
```

### Recommended response support

```json
{
  "product_id": 18221,
  "product_name": "Multi Unit Test",
  "quantity": 1,
  "unit_name": "PACKS",
  "product_sale_unit": {
    "id": 69,
    "unit_name": "PACKS",
    "conversion_rate": "30.00"
  },
  "base_quantity": "30.00",
  "unit_price": "55.00",
  "tax_rate": "18.00",
  "tax_amount": "8.39",
  "stock_id": 2286
}
```

### Why

Clients can then:
- display `1 PACKS`
- still keep stock movement in base quantity
- avoid flattening everything into `30 PCS`

## 6. FIFO / stock consumption responsibility

For complex supermarket cases, backend should ideally own final stock consumption order.

### Recommendation

If automatic FIFO/FEFO is required, backend should expose one of:

1. reservation-ready stock choice

```json
{
  "preferred_stock_ids": [2286, 2287]
}
```

2. direct resolved consumption plan

```json
{
  "consumption_plan": [
    { "stock_id": 2286, "base_quantity": "12.00" },
    { "stock_id": 2287, "base_quantity": "18.00" }
  ]
}
```

### Why

Clients should not guess FIFO/FEFO across multiple stock layers if backend already knows the real inventory rules.

## 7. Variant constraints

If a product has variants and sale units together, response should state compatibility.

### Recommended

```json
{
  "sale_units": [
    {
      "id": 69,
      "unit_name": "BOX",
      "allowed_variant_ids": [11, 12]
    }
  ]
}
```

### Why

Clients need to know whether:
- all variants can be sold as `BOX`
- or only some of them can

## 8. Base unit metadata

Backend should explicitly tell clients the base unit row too.

### Recommended

```json
{
  "base_unit": {
    "unit_id": 6953,
    "unit_name": "PCS",
    "barcode": "111000125",
    "conversion_rate": "1.00"
  }
}
```

### Why

This avoids clients inferring base-unit identity from generic product fields.

## Priority Order

If backend team wants phased delivery, this is the best order:

### Phase 1
- expose `purchase_unit_id`
- expose `purchase_unit_name`
- expose `purchase_qty`
- expose `wholesale_unit_basis`

### Phase 2
- add `preferred_stock_ids` on `sale_units`
- add `pricing_group_key` on both `sale_units` and `stock`
- add `supported_sale_unit_ids` on stock rows

### Phase 3
- add sale-unit-specific `retail_price`
- add sale-unit-specific `mrp`
- add sale-unit-specific `tax_rate`
- add `allowed_variant_ids`

### Phase 4
- add dedicated barcode lookup payload or reservation-ready consumption plan

## Final Ask To Backend Team

The database model is already close.
What clients need now is a stronger response contract.

The most important request is:

1. do not make the app infer billing from purchase metadata
2. expose billing-ready sale-unit fields directly in product API
3. expose stock-to-sale-unit mapping explicitly
4. expose sale-unit-specific pricing/tax when it differs from simple conversion math

That will let mobile POS, web POS, and other future clients all behave consistently.
