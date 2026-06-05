# Quotation Details API Fields Needed For Billing Prefill

This note is for the backend changes required by the POS frontend quotation-to-order flow.

## Goal

When the user clicks the convert icon from the quotation list, the frontend will not call the direct convert API. Instead it will:

1. Fetch `GET /api/v1/quotations/{id}`.
2. Load all known quotation data into the billing page/cart.
3. Let the user edit if needed.
4. User confirms order or confirms and prints.
5. Order API receives the normal order body plus `quotation_id`.

For this to prefill accurately, the quotation details response must include all fields used when the quotation was created.

## Current Fields That Are Enough

The current response already supports basic prefill if it includes:

```json
{
  "id": 42,
  "quotation_number": "QTN-00042",
  "status": "Pending",
  "customer": {
    "id": null,
    "name": "Ravi Kumar",
    "phone": "9876543210",
    "is_inline": true
  },
  "store": { "id": 1, "name": "Main Store" },
  "quotation_date": "2026-05-23 00:00:00",
  "expiry_date": "2026-06-22 00:00:00",
  "sub_total": 714.29,
  "discount": 0,
  "tax": 35.71,
  "grand_total": 750.00,
  "items": [
    {
      "id": 301,
      "product_id": 101,
      "product_name": "Widget A",
      "category_id": 7,
      "category_name": "Widgets",
      "unit": "PCS",
      "unit_price": 250.00,
      "quantity": 3,
      "tax_rate": 5,
      "tax_amount": 35.71,
      "total_price": 750.00
    }
  ]
}
```

## Missing Fields Needed For Exact Prefill

Please add these fields to `GET /api/v1/quotations/{id}` when available.

### Delivery / Order-Level Fields

```json
{
  "delivery_method_id": 3,
  "delivery_method_name": "Store Takeaway",
  "shipping_cost": 50.00,
  "comment": "Customer note or delivery note",
  "address_id": 5,
  "address": "Full delivery address",
}
```

Notes:

- `delivery_method_id` should be the same ID accepted by order confirmation APIs.
- `shipping_cost` can also be returned as `delivery_charge`; frontend supports both names.
- `comment` should return the quotation note/customer note if stored.
- `address` can be null for pickup/store takeaway.

### Item-Level Fields

```json
{
  "items": [
    {
      "id": 301,
      "product_id": 101,
      "product_name": "Widget A",
      "category_id": 7,
      "category_name": "Widgets",
      "unit": "PCS",
      "unit_price": 250.00,
      "quantity": 3,
      "tax_rate": 5,
      "tax_amount": 35.71,
      "total_price": 750.00,
      "product_stock_id": 55,
      "product_sale_unit_id": null,
      "sale_unit_name": null,
      "sale_unit_conversion_rate": null
    }
  ]
}
```

Notes:

- `product_stock_id` is important to restore the same stock/batch selected during quotation creation.
- `product_sale_unit_id` is important when the quote was created using BOX/PACK/CASE or another sale unit.
- `sale_unit_name` and `sale_unit_conversion_rate` are needed for display and correct payload reconstruction.
- If no stock or sale unit was used, return `null`.

## Recommended Full Details Response

```json
{
  "success": true,
  "message": "Quotation details",
  "data": {
    "id": 42,
    "quotation_number": "QTN-00042",
    "status": "Pending",
    "customer": {
      "id": null,
      "name": "Ravi Kumar",
      "phone": "9876543210",
      "is_inline": true
    },
    "store": {
      "id": 1,
      "name": "Main Store"
    },
    "address_id": 5,
    "address": "Full delivery address",
    "quotation_date": "2026-05-23 00:00:00",
    "expiry_date": "2026-06-22 00:00:00",
    "delivery_method_id": 3,
    "delivery_method_name": "Store Takeaway",
    "shipping_cost": 50.00,
    "comment": "Customer note or delivery note",
    "sub_total": 714.29,
    "discount": 0,
    "tax": 35.71,
    "grand_total": 750.00,
    "invoice_id": 88,
    "items": [
      {
        "id": 301,
        "product_id": 101,
        "product_name": "Widget A",
        "category_id": 7,
        "category_name": "Widgets",
        "unit": "PCS",
        "unit_price": 250.00,
        "quantity": 3,
        "tax_rate": 5,
        "tax_amount": 35.71,
        "total_price": 750.00,
        "product_stock_id": 55,
        "product_sale_unit_id": null,
        "sale_unit_name": null,
        "sale_unit_conversion_rate": null
      }
    ]
  }
}
```

## Frontend Fallbacks If Fields Are Missing

The frontend can still load the quotation with partial data, but it will use fallbacks:

- Missing `product_stock_id`: frontend auto-selects stock from locally available products.
- Missing `product_sale_unit_id`: item loads as base unit.
- Missing `delivery_method_id`: billing uses default delivery method.
- Missing `shipping_cost`: delivery charge becomes 0.

## Order Confirmation Payload

After billing confirmation, the frontend will send the normal order body with this extra field:

```json
{
  "quotation_id": 42
}
```

This lets backend link/stamp the created order against the original quotation/proforma invoice.
