# Quotation & Proforma Invoice API

All endpoints require `Bearer` auth (sanctum).

---

## Tenant 2 (LUZINE BAKES) reference data

Use these real IDs when testing against this tenant. Auth as a user whose company is `2` (the tenant resolver picks company from the user/subdomain).

| Resource | ID | Value |
|---|---|---|
| **Company** | `2` | LUZINE BAKES |
| **Store** | `2` | LUZINE BAKES Store |
| **Customer** | `4` | Sales Executive LUZINE BAKES — `9942519669` |
| **Customer** | `5` | Customer LUZINE BAKES — `9953722675` |
| **Customer** | `6` | CASH Customer LUZINE BAKES — `0000000000` |
| **Product** | `1` | Normal Alfaham (F) — `₹400.000` / BUCKET (category 1, no stock rows) |
| **Sale Unit** | `1` | BUCKET (conversion 1.00) for product 1 |
| **Delivery Method** | `5` | Car Delivery |
| **Delivery Method** | `6` | Door Delivery |
| **Delivery Method** | `7` | Store Takeaway |
| **Delivery Method** | `8` | Third Party logistics |
| **Payment Method** (master_data_value) | `95` | COD |
| **Payment Method** | `96` | ONLINE |
| **Payment Method** | `97` | CHEQUE |
| **Payment Method** | `98` | UPI |
| **Payment Method** | `99` | CASH |
| **Payment Method** | `100` | CARD |
| **Existing quotation** | `1` | QTN-00001 — Pending, inline customer "fdsasdfasdf" / `8075595613`, grand ₹400 |
| **Linked proforma** | `1` | INV-852683 — pending, ₹400 |
| **Customer 5 address** | `1` | type `Home`, text "sample address" (the only Address row in tenant 2) |
| **Taxes** | — | None configured. `tax_rate`/`tax_amount` will be `0` until a Tax row is added. |

> Product 1 has no `product_stocks` rows. The samples below leave `product_stock_id` as `null`; the API falls back to the product's own price (400.00). Payment methods can be sent as IDs (preferred) or strings (`"CASH"`, `"UPI"`); the controller resolves strings via `convertPaymentMethodsToIds`.

---

## 1. Create Quotation — `POST /api/v1/quotations`

Send **either** `customer_id` (existing) **or** `customer_name` + `customer_phone` (new). `customer_type` is optional; if omitted it's inferred from which fields are present.

### Existing customer

```json
{
  "customer_type": "existing",
  "customer_id": 12,
  "store_id": 1,
  "address_id": 5,
  "delivery_method_id": 3,
  "shipping_cost": 50.00,
  "quotation_date": "2026-05-23",
  "expiry_date": "2026-06-22",
  "discount": 50.00,
  "items": [
    {
      "product_id": 101,
      "quantity": 2,
      "price": 250.00,
      "product_stock_id": 55,
      "product_sale_unit_id": null
    },
    {
      "product_id": 102,
      "quantity": 1
    }
  ]
}
```

### New customer (no record created at this point — name/phone stored on the quotation)

```json
{
  "customer_type": "new",
  "customer_name": "Ravi Kumar",
  "customer_phone": "9876543210",
  "store_id": 1,
  "delivery_method_id": 3,
  "shipping_cost": 50.00,
  "quotation_date": "2026-05-23",
  "expiry_date": "2026-06-22",
  "items": [
    { "product_id": 101, "quantity": 3 }
  ]
}
```

### Success response

```json
{
  "success": true,
  "message": "Quotation created",
  "data": {
    "quotation_id": 42,
    "quotation_number": "QTN-00042",
    "grand_total": 750.00,
    "invoice_id": 88
  }
}
```

Validation errors return `customer_id is required for existing customer` or `customer_name and customer_phone are required for new customer`.

---

## 2. List Quotations — `GET /api/v1/quotations`

Query params (`quotation_number`, `customer_id`, `store_id`, `status`, `quotation_date_from/to`, `expiry_date_from/to`, `per_page`).

```json
{
  "success": true,
  "message": "List of quotations",
  "data": {
    "data": [
      {
        "id": 42,
        "quotation_number": "QTN-00042",
        "customer_id": null,
        "customer": "Ravi Kumar",
        "customer_phone": "9876543210",
        "store": "Main Store",
        "quotation_date": "2026-05-23 00:00:00",
        "expiry_date": "2026-06-22 00:00:00",
        "sub_total": 714.29,
        "discount": null,
        "tax": 35.71,
        "grand_total": 750.00,
        "status": "Pending",
        "invoice_id": 88,
        "created_at": "2026-05-23T12:30:00.000000Z"
      }
    ]
  }
}
```

---

## 3. Quotation Details — `GET /api/v1/quotations/{id}`

`customer.is_inline` is `true` when no Customer record is linked. `address` is a flat string (the address text), `address_id` is the FK. Item rows now include `product_stock_id`, `product_sale_unit_id`, `sale_unit_name`, and `sale_unit_conversion_rate` so the frontend can recreate the exact selection.

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
    "store": { "id": 1, "name": "Main Store" },
    "address_id": 5,
    "address": "12 MG Road, Bangalore 560001",
    "quotation_date": "2026-05-23 00:00:00",
    "expiry_date": "2026-06-22 00:00:00",
    "delivery_method_id": 3,
    "delivery_method_name": "Store Takeaway",
    "shipping_cost": 50.00,
    "sub_total": 714.29,
    "discount": null,
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

Any of `address_id`, `address`, `delivery_method_id`, `delivery_method_name`, `shipping_cost`, `product_stock_id`, `product_sale_unit_id`, `sale_unit_name`, `sale_unit_conversion_rate` may be `null` if the quotation didn't capture them.

---

## 4. Update Quotation Status — `POST /api/v1/quotations/update-status`

```json
{
  "quotation_id": 42,
  "status": "Confirmed"
}
```

`status` must be one of `Pending`, `Confirmed`, `Cancelled`.

---

## 5. Convert Quotation to Order — recommended flow

**Use `POST /api/v1/order/add-to-order` with a `quotation_id` field.**

This lets the caller modify items and payment methods before finalising the order. The dedicated `/quotations/convert-to-order` endpoint is still available (see §5b) but it does not support item/payment edits.

### Flow

1. **(Inline customer only)** If the quotation has no `customer_id`, create a customer first via your normal customer-create API using the stored name/phone (returned by `GET /api/v1/quotations/{id}`).
2. **Call `POST /api/v1/order/add-to-order`** with:
   - `customer_id` — the existing or newly-created customer
   - `quotation_id` — the source quotation
   - `items` — optionally override or change line items
   - `payment_method`, `paid_methods`, `paid_amount`, etc. — as you normally would
3. The order is created with whatever you sent. After commit, the quotation is automatically marked `order created`, its cart is flipped from `estimate` → `cart`, and the linked proforma invoice is stamped `order created` and re-tied to the customer.

### Example request

```json
{
  "customer_id": 27,
  "store_id": 1,
  "source_type": "admin_panel",
  "quotation_id": 42,
  "items": [
    { "product_id": 101, "quantity": 4, "price": 250.00 },
    { "product_id": 105, "quantity": 1 }
  ],
  "payment_method": ["CASH"],
  "paid_methods": [
    { "method": "CASH", "amount": 1250.00 }
  ],
  "paid_amount": 1250.00,
  "delivery_method_id": 3,
  "delivery_charge": 0,
  "status": "confirmed"
}
```

### Success response

```json
{
  "message": "Order created successfully",
  "order_id": 901,
  "order_number": "ORD-00901",
  "order_details": { /* full order payload */ }
}
```

### Notes

- `quotation_id` is **optional**. Omit it for a normal order.
- If the quotation is already `order created` or `Cancelled`, the conversion step is skipped silently (the order is still created).
- The `customer_id` you send wins. If it differs from the quotation's existing `customer_id`, the quotation is re-stamped with the new one.
- **Item/total sync on conversion**: the quotation's `cart_id` is re-pointed to the order's cart, and `sub_total`, `tax`, `discount`, `grand_total`, `shipping_cost`, `delivery_method_id` are copied from the order. So if the user edited items at billing time, `GET /quotations/{id}` after conversion shows exactly what was sold — not the original quote.
- The proforma invoice's `amount` is updated and its `invoice_items` are deleted + recreated from the new cart contents.
- The orphaned old quotation cart is deleted unless another quotation/order references it.
- The proforma invoice's `status` flips to `order created` (the `invoices.status` enum has been extended to include this value).

---

## 5b. Convert Quotation to Order (legacy, no item edits) — `POST /api/v1/quotations/convert-to-order`

Kept for backwards compatibility. Cannot modify items.

- If `customer_type` / customer fields are omitted, falls back to whatever is stored on the quotation (existing `customer_id` if present, else stored `customer_name`/`customer_phone`).
- If `customer_type` = `new`, a Customer (+ User) is created via phone lookup (`updateOrCreate` on phone).
- The quotation, its cart, and its proforma invoice get stamped with the resolved `customer_id`.

### Convert using existing customer already on quotation

```json
{
  "quotation_id": 42,
  "payment_method": "CASH",
  "payment_type": "manual",
  "discount": 0,
  "shipping_cost": 0,
  "delivery_method_id": 3
}
```

### Convert and create a new customer

```json
{
  "quotation_id": 42,
  "customer_type": "new",
  "customer_name": "Ravi Kumar",
  "customer_phone": "9876543210",
  "payment_method": "CASH"
}
```

### Success response

```json
{
  "success": true,
  "message": "Quotation converted to order",
  "data": {
    "order_id": 901,
    "order_number": "ORD-00901",
    "quotation_id": 42,
    "quotation_number": "QTN-00042"
  }
}
```

---

## 6. List Proforma Invoices — `GET /api/v1/invoice/proforma-invoices`

Returns paginated proforma invoices (the ones created from quotations). The global "without proforma" scope is bypassed for this endpoint.

### Query params (all optional)

| Param | Type | Notes |
|---|---|---|
| `customer_id` | int | Filter by customer |
| `status` | string | `pending`, `paid`, `overdue`, `order created` |
| `invoice_number` | string | `LIKE` search |
| `customer_search` | string | Matches customer name or phone |
| `date_from` / `date_to` | date (`Y-m-d`) | Filters `invoice_date` |
| `due_date_from` / `due_date_to` | date (`Y-m-d`) | Filters `due_date` |
| `per_page` | int | Page size (default 20) |
| `page` | int | Standard Laravel pagination |

### Example request

```
GET /api/v1/invoice/proforma-invoices?status=pending&date_from=2026-05-01&per_page=15
```

### Success response

```json
{
  "success": true,
  "message": "Proforma invoices listed successfully",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 88,
        "invoice_number": "INV-432109",
        "type": "proforma",
        "status": "pending",
        "amount": 750.00,
        "total_tax": 35.71,
        "total_discount": 0,
        "invoice_date": "2026-05-23",
        "due_date": "2026-06-22",
        "customer": {
          "id": null,
          "name": "Ravi Kumar",
          "phone": "9876543210",
          "is_inline": true
        },
        "quotation": {
          "id": 42,
          "quotation_number": "QTN-00042",
          "status": "Pending"
        },
        "items_count": 1,
        "created_at": "2026-05-23T12:30:00.000000Z"
      }
    ],
    "first_page_url": "...",
    "from": 1,
    "last_page": 1,
    "last_page_url": "...",
    "next_page_url": null,
    "path": "...",
    "per_page": 15,
    "prev_page_url": null,
    "to": 1,
    "total": 1
  }
}
```

---

## 7. Proforma Invoice Details — `GET /api/v1/invoice/proforma-invoices/{id}`

```json
{
  "success": true,
  "message": "Proforma invoice details",
  "data": {
    "id": 88,
    "invoice_number": "INV-432109",
    "type": "proforma",
    "status": "pending",
    "amount": 750.00,
    "total_tax": 35.71,
    "total_discount": 0,
    "invoice_date": "2026-05-23",
    "due_date": "2026-06-22",
    "customer": {
      "id": null,
      "name": "Ravi Kumar",
      "phone": "9876543210",
      "is_inline": true
    },
    "quotation": {
      "id": 42,
      "quotation_number": "QTN-00042",
      "status": "Pending",
      "quotation_date": "2026-05-23 00:00:00",
      "expiry_date": "2026-06-22 00:00:00"
    },
    "items": [
      {
        "id": 501,
        "item_name": "Widget A",
        "quantity": 3,
        "unit_amount": 250.00,
        "tax": 35.71,
        "total_amount": 750.00
      }
    ],
    "created_at": "2026-05-23T12:30:00.000000Z"
  }
}
```

Returns `{"success": false, "message": "Proforma invoice not found"}` if the ID doesn't match a proforma invoice.

---

## Field reference

### Quotation create/convert

| Field | Type | Notes |
|---|---|---|
| `customer_type` | `"existing"` \| `"new"` | Optional; inferred from other fields |
| `customer_id` | int | Required when `customer_type=existing` |
| `customer_name` | string (max 255) | Required when `customer_type=new` |
| `customer_phone` | string (max 50) | Required when `customer_type=new` |
| `address_id` | int | Ignored / nulled when `customer_type=new` |
| `delivery_method_id` | int | Optional. References `delivery_methods.id` |
| `shipping_cost` | decimal | Optional. Persisted as-is, no auto-calculation |

### add-to-order (new field)

| Field | Type | Notes |
|---|---|---|
| `quotation_id` | int | If set, marks the quotation as converted after the order commits |

---

# Tenant 2 — End-to-end sample requests (real data)

Replace `{TOKEN}` with a sanctum token for a user whose tenant is LUZINE BAKES (company 2).

---

## A. Create quotation — existing customer (Customer LUZINE BAKES, id=5)

`POST /api/v1/quotations`

```json
{
  "customer_type": "existing",
  "customer_id": 5,
  "store_id": 2,
  "delivery_method_id": 7,
  "shipping_cost": 0,
  "quotation_date": "2026-05-25",
  "expiry_date": "2026-06-24",
  "discount": 0,
  "items": [
    {
      "product_id": 1,
      "quantity": 2,
      "price": 400.00,
      "product_stock_id": null,
      "product_sale_unit_id": 1
    }
  ]
}
```

### curl

```bash
curl -X POST 'https://luzine.<your-domain>/api/v1/quotations' \
  -H 'Authorization: Bearer {TOKEN}' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "customer_type": "existing",
    "customer_id": 5,
    "store_id": 2,
    "delivery_method_id": 7,
    "shipping_cost": 0,
    "quotation_date": "2026-05-25",
    "expiry_date": "2026-06-24",
    "discount": 0,
    "items": [
      { "product_id": 1, "quantity": 2, "price": 400.00, "product_sale_unit_id": 1 }
    ]
  }'
```

### Expected response

```json
{
  "success": true,
  "message": "Quotation created",
  "data": {
    "quotation_id": 2,
    "quotation_number": "QTN-00002",
    "grand_total": 800.00,
    "invoice_id": 2
  }
}
```

---

## B. Create quotation — new (walk-in) customer

`POST /api/v1/quotations`

```json
{
  "customer_type": "new",
  "customer_name": "Anwar Walk-in",
  "customer_phone": "9876500001",
  "store_id": 2,
  "delivery_method_id": 6,
  "shipping_cost": 30.00,
  "quotation_date": "2026-05-25",
  "expiry_date": "2026-06-24",
  "items": [
    { "product_id": 1, "quantity": 3, "price": 400.00, "product_sale_unit_id": 1 }
  ]
}
```

### Expected response

```json
{
  "success": true,
  "message": "Quotation created",
  "data": {
    "quotation_id": 3,
    "quotation_number": "QTN-00003",
    "grand_total": 1200.00,
    "invoice_id": 3
  }
}
```

The Customer table is **not** touched. `customer_name` / `customer_phone` are persisted on the quotation row.

---

## C. List quotations

`GET /api/v1/quotations?status=Pending&per_page=10`

### Expected response (truncated)

```json
{
  "success": true,
  "message": "List of quotations",
  "data": {
    "data": [
      {
        "id": 3,
        "quotation_number": "QTN-00003",
        "customer_id": null,
        "customer": "Anwar Walk-in",
        "customer_phone": "9876500001",
        "store": "LUZINE BAKES Store",
        "quotation_date": "2026-05-25 00:00:00",
        "expiry_date": "2026-06-24 00:00:00",
        "sub_total": 1142.86,
        "discount": null,
        "tax": 57.14,
        "grand_total": 1200.00,
        "status": "Pending",
        "invoice_id": 3,
        "created_at": "2026-05-25T14:35:00.000000Z"
      },
      {
        "id": 1,
        "quotation_number": "QTN-00001",
        "customer_id": null,
        "customer": "fdsasdfasdf",
        "customer_phone": "8075595613",
        "store": "LUZINE BAKES Store",
        "grand_total": 400.000,
        "status": "Pending",
        "invoice_id": 1
      }
    ]
  }
}
```

---

## D. Quotation details (prefill source for billing page)

`GET /api/v1/quotations/3`

### Expected response

```json
{
  "success": true,
  "message": "Quotation details",
  "data": {
    "id": 3,
    "quotation_number": "QTN-00003",
    "status": "Pending",
    "customer": {
      "id": null,
      "name": "Anwar Walk-in",
      "phone": "9876500001",
      "is_inline": true
    },
    "store": { "id": 2, "name": "LUZINE BAKES Store" },
    "address_id": null,
    "address": null,
    "quotation_date": "2026-05-25 00:00:00",
    "expiry_date": "2026-06-24 00:00:00",
    "delivery_method_id": 6,
    "delivery_method_name": "Door Delivery",
    "shipping_cost": 30.00,
    "sub_total": 1200.00,
    "discount": null,
    "tax": 0,
    "grand_total": 1200.00,
    "invoice_id": 3,
    "items": [
      {
        "id": 901,
        "product_id": 1,
        "product_name": "Normal Alfaham (F)",
        "category_id": 1,
        "category_name": "Alfaham",
        "unit": "BUCKET",
        "unit_price": 400.00,
        "quantity": 3,
        "tax_rate": 0,
        "tax_amount": 0,
        "total_price": 1200.00,
        "product_stock_id": null,
        "product_sale_unit_id": 1,
        "sale_unit_name": "BUCKET",
        "sale_unit_conversion_rate": 1.0
      }
    ]
  }
}
```

> Tenant 2 has no Tax rows configured, so `tax_rate` / `tax_amount` are `0`. On a tenant with active taxes the response will show the calculated values (e.g. `tax_rate: 5`, `tax_amount: 57.14`).

---

## E. Recommended convert flow — `add-to-order` with `quotation_id`

For an **inline-customer quotation**, create a customer record first using your existing customer-create API, then call:

`POST /api/v1/order/add-to-order`

```json
{
  "customer_id": 5,
  "store_id": 2,
  "source_type": "admin_panel",
  "quotation_id": 3,
  "items": [
    { "product_id": 1, "quantity": 3, "price": 400.00, "product_sale_unit_id": 1 }
  ],
  "payment_method": [99],
  "paid_methods": [
    { "method": 99, "amount": 1230.00 }
  ],
  "paid_amount": 1230.00,
  "delivery_method_id": 6,
  "delivery_charge": 30.00,
  "status": "confirmed"
}
```

- `payment_method: [99]` → `CASH` (master_data_value id from tenant 2).
- `paid_methods[].method` is the same id.
- The trailing `quotation_id: 3` triggers the auto-link: quotation 3 → `order created`, its cart flips to `cart`, proforma INV-something is stamped `order created` and tied to customer 5.

### curl

```bash
curl -X POST 'https://luzine.<your-domain>/api/v1/order/add-to-order' \
  -H 'Authorization: Bearer {TOKEN}' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "customer_id": 5,
    "store_id": 2,
    "source_type": "admin_panel",
    "quotation_id": 3,
    "items": [
      { "product_id": 1, "quantity": 3, "price": 400.00, "product_sale_unit_id": 1 }
    ],
    "payment_method": [99],
    "paid_methods": [{ "method": 99, "amount": 1230.00 }],
    "paid_amount": 1230.00,
    "delivery_method_id": 6,
    "delivery_charge": 30.00,
    "status": "confirmed"
  }'
```

### Expected response

```json
{
  "message": "Order created successfully",
  "order_id": 1234,
  "order_number": "INV-554301",
  "order_details": { /* full order payload from getOrderDetails */ }
}
```

---

## F. Mixed payment example — CASH + UPI on a converted order

```json
{
  "customer_id": 5,
  "store_id": 2,
  "source_type": "admin_panel",
  "quotation_id": 1,
  "items": [
    { "product_id": 1, "quantity": 1, "price": 400.00, "product_sale_unit_id": 1 }
  ],
  "payment_method": [99, 98],
  "paid_methods": [
    { "method": 99, "amount": 200.00 },
    { "method": 98, "amount": 200.00 }
  ],
  "paid_amount": 400.00,
  "transaction_number": "UPI-REF-7788",
  "delivery_method_id": 7,
  "delivery_charge": 0,
  "status": "confirmed"
}
```

---

## G. Legacy direct convert (no item edits) — `quotations/convert-to-order`

`POST /api/v1/quotations/convert-to-order`

For QTN-00001 (inline customer), let the API create the customer from stored name/phone:

```json
{
  "quotation_id": 1,
  "customer_type": "new",
  "customer_name": "fdsasdfasdf",
  "customer_phone": "9999911111",
  "payment_method": 99,
  "payment_type": "manual",
  "delivery_method_id": 7
}
```

### Expected response

```json
{
  "success": true,
  "message": "Quotation converted to order",
  "data": {
    "order_id": 1235,
    "order_number": "INV-554302",
    "quotation_id": 1,
    "quotation_number": "QTN-00001"
  }
}
```

---

## H. Update quotation status

`POST /api/v1/quotations/update-status`

```json
{
  "quotation_id": 2,
  "status": "Cancelled"
}
```

---

## I. List proforma invoices for tenant 2

`GET /api/v1/invoice/proforma-invoices?status=pending&per_page=10`

### Expected response (truncated)

```json
{
  "success": true,
  "message": "Proforma invoices listed successfully",
  "data": {
    "data": [
      {
        "id": 1,
        "invoice_number": "INV-852683",
        "type": "proforma",
        "status": "pending",
        "amount": 400.000,
        "invoice_date": "2026-05-23",
        "due_date": "2026-06-22",
        "customer": {
          "id": null,
          "name": "fdsasdfasdf",
          "phone": "8075595613",
          "is_inline": true
        },
        "quotation": {
          "id": 1,
          "quotation_number": "QTN-00001",
          "status": "Pending"
        },
        "items_count": 1,
        "created_at": "2026-05-23T10:12:00.000000Z"
      }
    ]
  }
}
```

---

## Migrations introduced for this feature

Run with `php artisan migrate`. All three are required for the flow above.

| File | What it does |
|---|---|
| `2026_05_23_130000_add_inline_customer_to_quotations_and_make_cart_customer_nullable.php` | Adds `customer_name`, `customer_phone` to `quotations`; makes `carts.customer_id` nullable so inline-customer quotations can have a cart. |
| `2026_05_25_140000_add_delivery_to_quotations_table.php` | Adds `delivery_method_id` (FK, nullable) and `shipping_cost` (decimal, nullable) to `quotations`. |
| `2026_05_25_161500_add_order_created_to_invoices_status_enum.php` | Extends `invoices.status` enum to include `'order created'` (required when converting via `add-to-order` or `convert-to-order`). |

---

## J. Proforma invoice details

`GET /api/v1/invoice/proforma-invoices/1`

```json
{
  "success": true,
  "message": "Proforma invoice details",
  "data": {
    "id": 1,
    "invoice_number": "INV-852683",
    "type": "proforma",
    "status": "pending",
    "amount": 400.000,
    "invoice_date": "2026-05-23",
    "due_date": "2026-06-22",
    "customer": {
      "id": null,
      "name": "fdsasdfasdf",
      "phone": "8075595613",
      "is_inline": true
    },
    "quotation": {
      "id": 1,
      "quotation_number": "QTN-00001",
      "status": "Pending",
      "quotation_date": "2026-05-23 00:00:00",
      "expiry_date": "2026-06-22 00:00:00"
    },
    "items": [
      {
        "id": 1,
        "item_name": "Normal Alfaham (F)",
        "quantity": 1,
        "unit_amount": 400.00,
        "tax": 0,
        "total_amount": 400.00
      }
    ],
    "created_at": "2026-05-23T10:12:00.000000Z"
  }
}
```
