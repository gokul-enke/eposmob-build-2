# Quotation & Proforma Invoice API

All endpoints require `Bearer` auth (sanctum).

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

Response now includes `customer_id` (nullable) plus the inline name/phone fallback:

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

`customer.is_inline` is `true` when no Customer record is linked:

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
    "address": null,
    "quotation_date": "2026-05-23 00:00:00",
    "expiry_date": "2026-06-22 00:00:00",
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
        "total_price": 750.00
      }
    ]
  }
}
```

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

## 5. Convert Quotation to Order — `POST /api/v1/quotations/convert-to-order`

Behavior:

- If `customer_type` / customer fields are omitted, falls back to whatever is stored on the quotation (existing `customer_id` if present, else stored `customer_name`/`customer_phone`).
- If `customer_type` = `new`, a Customer (+ User) is created via phone lookup (`updateOrCreate` on phone).
- The quotation, its cart, and its proforma invoice get stamped with the resolved `customer_id`.

### Convert using existing customer already on quotation (legacy)

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

### Convert using a different existing customer

```json
{
  "quotation_id": 42,
  "customer_type": "existing",
  "customer_id": 27,
  "payment_method": "UPI",
  "payment_type": "manual"
}
```

### Convert and create a new customer

```json
{
  "quotation_id": 42,
  "customer_type": "new",
  "customer_name": "Ravi Kumar",
  "customer_phone": "9876543210",
  "payment_method": "CASH",
  "payment_type": "manual",
  "discount": 0,
  "shipping_cost": 50,
  "delivery_method_id": 2
}
```

### Convert relying entirely on inline data stored on the quotation

```json
{
  "quotation_id": 42
}
```

If the quotation has no `customer_id` and no stored name/phone, you'll get `customer_name and customer_phone are required to create a new customer`.

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

When the linked Customer record exists, `customer.id` is non-null and `customer.is_inline` is `false`. When the quotation only stored an inline name/phone, those values are surfaced under `customer` with `is_inline: true`.

---

## 7. Proforma Invoice Details — `GET /api/v1/invoice/proforma-invoices/{id}`

### Success response

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

## Field reference (new on quotation endpoints)

| Field | Where | Type | Notes |
|---|---|---|---|
| `customer_type` | create / convert | `"existing"` \| `"new"` | Optional; inferred from other fields |
| `customer_id` | create / convert | int | Required when `customer_type=existing` |
| `customer_name` | create / convert | string (max 255) | Required when `customer_type=new` |
| `customer_phone` | create / convert | string (max 50) | Required when `customer_type=new` |
| `address_id` | create | int | Ignored / nulled when `customer_type=new` |
