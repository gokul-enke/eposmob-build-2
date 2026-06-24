# Multi Sale Unit Stock Handling

## 1. Enough stock is available

Example:

```text
Stock = 24 PC
1 CRT = 12 PC
Customer buys 2 CRT
```

Result:

```text
2 CRT = 24 PC
Stock after sale = 0 PC
```

Cart should show one line:

```text
Sample CRT 12 | Qty 2 | Unit CRT | Price 2400 | Total 4800
```

Backend can deduct all quantity from the selected stock.

Current payload:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 2,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": 8273,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    }
  ]
}
```

Current payload meaning:

```text
Sell 2 CRT.
Use stock_id 8273.
Backend must calculate that 2 CRT = 24 PC.
```

This works when all required base stock comes from one stock row.

Verified current payload from tests:

```json
[
  {
    "product_id": 29708,
    "quantity": 2,
    "price": 2400.0,
    "mrp": 3600.0,
    "stock_id": 8273,
    "sale_unit_id": 7254,
    "product_sale_unit_id": 7254
  }
]
```

Better payload:

```json
{
  "product_id": 29708,
  "quantity": 2,
  "quantity_unit": "sale_unit",
  "price": 2400,
  "price_unit": "sale_unit",
  "product_sale_unit_id": 7254,
  "sale_unit_name": "CRT",
  "conversion_rate": 12,
  "base_quantity": 24,
  "base_unit": "PC",
  "base_price": 200,
  "stock_allocations": [
    { "stock_id": 8273, "base_quantity": 24 }
  ]
}
```

Meaning:

```text
Sell 2 CRT.
Deduct 24 PC from stock_id 8273.
```

## 2. Partial stock is available

Example:

```text
Stock = 16 PC
1 CRT = 12 PC
Customer buys 2 CRT
```

Needed:

```text
2 CRT = 24 PC
```

Available:

```text
16 PC
```

Shortage:

```text
8 PC
```

Cart should still show one clean line:

```text
Sample CRT 12 | Qty 2 | Unit CRT | Price 2400 | Total 4800
```

Internally, the app/backend should remember:

```text
16 PC taken from stock
8 PC sold without stock / negative stock
```

Do not show split rows in the cart UI.

Current payload:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 2,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": 8273,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    }
  ]
}
```

Current payload problem:

```text
The real current payload builder does not keep this as one row.
It splits by stock reservation.
Because 16 PC and 8 PC are converted back to CRT, the backend receives fractional CRT rows.
```

Actual current payload from tests:

```json
[
  {
    "product_id": 29708,
    "quantity": 1.3333333333333333,
    "price": 2400.0,
    "mrp": 3600.0,
    "stock_id": 8273,
    "sale_unit_id": 7254,
    "product_sale_unit_id": 7254
  },
  {
    "product_id": 29708,
    "quantity": 0.6666666666666666,
    "price": 2400.0,
    "mrp": 3600.0,
    "stock_id": null,
    "sale_unit_id": 7254,
    "product_sale_unit_id": 7254
  }
]
```

Actual current payload meaning:

```text
1.333333 CRT comes from stock_id 8273.
0.666666 CRT is unreserved / no stock_id.
Together they equal 2 CRT.
```

Verified test case:

```text
2 CRT = 24 PC
16 PC reserved from stock_id 8273
8 PC unreserved / stock_id null
Payload rows = 1.333333 CRT + 0.666666 CRT
```

Better payload:

```json
{
  "product_id": 29708,
  "quantity": 2,
  "quantity_unit": "sale_unit",
  "price": 2400,
  "price_unit": "sale_unit",
  "product_sale_unit_id": 7254,
  "sale_unit_name": "CRT",
  "conversion_rate": 12,
  "base_quantity": 24,
  "base_unit": "PC",
  "base_price": 200,
  "stock_allocations": [
    { "stock_id": 8273, "base_quantity": 16 },
    { "stock_id": null, "base_quantity": 8, "type": "negative_stock" }
  ]
}
```

Meaning:

```text
Sell 2 CRT.
Total base quantity = 24 PC.
Deduct 16 PC from stock_id 8273.
Record 8 PC as unreserved / negative stock.
```

## 3. Not enough stock, negative stock is allowed

Example:

```text
Stock = 4 PC
1 CRT = 12 PC
Customer buys 1 CRT
```

Shortage:

```text
8 PC
```

The app should warn:

```text
Only 4 PC available. This sale will make stock negative by 8 PC.
```

If the user confirms, allow the sale.

Stock after sale:

```text
-8 PC
```

Current payload:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 1,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": 8273,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    }
  ]
}
```

Current payload problem:

```text
The real current payload builder splits by stock reservation.
Because 4 PC and 8 PC are converted back to CRT, the backend receives fractional CRT rows.
```

Actual current payload:

```json
[
  {
    "product_id": 29708,
    "quantity": 0.3333333333333333,
    "price": 2400.0,
    "mrp": 3600.0,
    "stock_id": 8273,
    "sale_unit_id": 7254,
    "product_sale_unit_id": 7254
  },
  {
    "product_id": 29708,
    "quantity": 0.6666666666666666,
    "price": 2400.0,
    "mrp": 3600.0,
    "stock_id": null,
    "sale_unit_id": 7254,
    "product_sale_unit_id": 7254
  }
]
```

Actual current payload meaning:

```text
0.333333 CRT comes from stock_id 8273.
0.666666 CRT is unreserved / no stock_id.
Together they equal 1 CRT.
```

Verified test case:

```text
1 CRT = 12 PC
4 PC reserved from stock_id 8273
8 PC unreserved / stock_id null
Payload rows = 0.333333 CRT + 0.666666 CRT
```

Better payload:

```json
{
  "product_id": 29708,
  "quantity": 1,
  "quantity_unit": "sale_unit",
  "price": 2400,
  "price_unit": "sale_unit",
  "product_sale_unit_id": 7254,
  "sale_unit_name": "CRT",
  "conversion_rate": 12,
  "base_quantity": 12,
  "base_unit": "PC",
  "base_price": 200,
  "stock_allocations": [
    { "stock_id": 8273, "base_quantity": 4 },
    { "stock_id": null, "base_quantity": 8, "type": "negative_stock" }
  ]
}
```

Meaning:

```text
Sell 1 CRT.
Total base quantity = 12 PC.
Deduct available 4 PC from stock_id 8273.
Record 8 PC as unreserved / negative stock.
```

## 4. Not enough stock, negative stock is not allowed

Example:

```text
Stock = 4 PC
1 CRT = 12 PC
Customer buys 1 CRT
```

The app should block the sale.

Message:

```text
Insufficient stock for 1 CRT. Available stock is 4 PC.
```

The cart should not allow increasing or confirming that quantity.

Current payload:

```text
No order payload should be sent for this item.
```

Reason:

```text
Negative stock is disabled.
Available stock is only 4 PC.
Requested quantity is 12 PC.
Sale must be blocked before confirm order.
```

Better payload:

```text
No order payload should be sent for this item.
```

Better handling:

```text
Frontend blocks before confirm order.
Backend should also validate and reject if such a payload is received.
```

Verified current payload behavior:

```text
If the item is blocked before it enters cart, buildOrderItemsPayloadFrom receives no item.
Payload = []
```

Example backend validation error:

```json
{
  "status": "failure",
  "message": "Insufficient stock for CRT. Available stock is 4 PC.",
  "required_base_quantity": 12,
  "available_base_quantity": 4
}
```

## 5. Cart UI rule

Always show sale-unit items as one customer-friendly line.

Good:

```text
Sample CRT 12 | Qty 2 | Unit CRT | Price 2400 | Total 4800
```

Avoid:

```text
Sample CRT 12 | Qty 1.333 CRT | stock_id 8273
Sample CRT 12 | Qty 0.667 CRT | no stock_id
```

Split stock details are implementation details. They should not leak into the billing table.

## 6. Recommended backend payload

Best structure:

```json
{
  "product_id": 29708,
  "quantity": 2,
  "price": 2400,
  "product_sale_unit_id": 7254,
  "stock_allocations": [
    { "stock_id": 8273, "base_quantity": 16 },
    { "stock_id": null, "base_quantity": 8 }
  ]
}
```

Meaning:

```text
Customer bought 2 CRT.
Each CRT is 12 PC.
Total base quantity is 24 PC.
16 PC came from stock_id 8273.
8 PC is unreserved / negative stock.
```

## 7. Current split payload if backend cannot support stock allocations

The app currently sends split rows when one cart line is backed by multiple stock reservations or by reserved plus unreserved quantity.

The split rows use fractional sale-unit quantity.

Current payload:

```json
[
  {
    "product_id": 29708,
    "quantity": 1.333,
    "price": 2400,
    "stock_id": 8273,
    "product_sale_unit_id": 7254
  },
  {
    "product_id": 29708,
    "quantity": 0.667,
    "price": 2400,
    "stock_id": null,
    "product_sale_unit_id": 7254
  }
]
```

This is not ideal because it exposes fractional sale units.

Backend must group these rows back for order details and printing.

Expected grouped display:

```text
Qty 2 | Unit CRT | Rate 2400 | Total 4800
```

Prefer `stock_allocations` instead.

Alternative split payload for base quantities:

```json
[
  {
    "product_id": 29708,
    "quantity": 16,
    "price": 200,
    "stock_id": 8273,
    "product_sale_unit_id": 7254,
    "quantity_unit": "base"
  },
  {
    "product_id": 29708,
    "quantity": 8,
    "price": 200,
    "stock_id": null,
    "product_sale_unit_id": 7254,
    "quantity_unit": "base"
  }
]
```

If this style is used, backend must still group order details as:

```text
Qty 2 | Unit CRT | Rate 2400 | Total 4800
```

## 8. Recommended setting

Use a business setting:

```text
allow_negative_stock_sale = true / false
```

If true:

```text
Warn and allow sale.
```

If false:

```text
Block sale.
```

This keeps both inventory control and POS counter workflow clear.

## 9. Order details and print response

Order details API should return the sold unit, not only the base product unit.

Expected cart item response:

```json
{
  "product_id": 29708,
  "product_name": "Sample CRT 12",
  "quantity": "2.000",
  "unit_price": "2400.000",
  "total_price": "4800.000",
  "product_unit": "PC",
  "product_sale_unit_id": 7254,
  "sale_unit_name": "CRT"
}
```

UI and print should display:

```text
Qty 2 | Unit CRT
```

`product_unit` can remain as the base unit for stock calculations.

## 10. Current app payload

Current app payload sends sale-unit quantity and sale-unit price.

If the cart item uses one stock row, it sends one row.

If the cart item uses multiple stock rows, or has unreserved quantity, it sends split rows.

One-stock example:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 2,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": 8273,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    }
  ],
  "phone": "7034598461",
  "customer_id": 2325,
  "payment_method": ["7973"],
  "paid_methods": [
    { "method": "7973", "amount": 4800.0 }
  ],
  "source_type": "executive",
  "balance": "0.0",
  "delivery_method_id": "199",
  "status": "confirmed",
  "store_id": 2
}
```

Meaning:

```text
Sell 2 CRT.
Each CRT price is 2400.
Total is 4800.
Use stock_id 8273.
```

Problem:

```text
This one-row payload is okay only when the full sale quantity comes from one stock_id.
```

Split-stock example:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 1.3333333333333333,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": 8273,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    },
    {
      "product_id": 29708,
      "quantity": 0.6666666666666666,
      "price": 2400.0,
      "mrp": 3600.0,
      "stock_id": null,
      "sale_unit_id": 7254,
      "product_sale_unit_id": 7254
    }
  ]
}
```

Split-stock meaning:

```text
Customer bought 2 CRT.
1.333333 CRT is from stock_id 8273.
0.666666 CRT is unreserved / no stock_id.
Together they equal 2 CRT.
```

Problem:

```text
Backend receives fractional sale units.
Order details and print must group them back to 2 CRT.
This is harder than receiving one item with stock_allocations.
```

## 11. Better payload

Better payload keeps the cart item clean and adds stock allocation details.

Example:

```json
{
  "items": [
    {
      "product_id": 29708,
      "quantity": 2,
      "quantity_unit": "sale_unit",
      "price": 2400.0,
      "price_unit": "sale_unit",
      "mrp": 3600.0,
      "product_sale_unit_id": 7254,
      "sale_unit_name": "CRT",
      "conversion_rate": 12,
      "base_quantity": 24,
      "base_unit": "PC",
      "base_price": 200.0,
      "stock_allocations": [
        {
          "stock_id": 8273,
          "base_quantity": 16
        },
        {
          "stock_id": null,
          "base_quantity": 8,
          "type": "negative_stock"
        }
      ]
    }
  ],
  "phone": "7034598461",
  "customer_id": 2325,
  "payment_method": ["7973"],
  "paid_methods": [
    { "method": "7973", "amount": 4800.0 }
  ],
  "source_type": "executive",
  "balance": "0.0",
  "delivery_method_id": "199",
  "status": "confirmed",
  "store_id": 2
}
```

Meaning:

```text
Customer sees and buys 2 CRT.
Backend knows 2 CRT = 24 PC.
Backend deducts 16 PC from stock_id 8273.
Backend records 8 PC as negative stock.
Invoice/order details still show 2 CRT.
```

Order details response should return:

```json
{
  "product_id": 29708,
  "product_name": "Sample CRT 12",
  "quantity": "2.000",
  "unit_price": "2400.000",
  "total_price": "4800.000",
  "product_unit": "PC",
  "product_sale_unit_id": 7254,
  "sale_unit_name": "CRT",
  "conversion_rate": "12",
  "base_quantity": "24.000"
}
```

UI should display:

```text
Qty 2 | Unit CRT | Rate 2400 | Total 4800
```

Backend can still use:

```text
product_unit = PC
base_quantity = 24
```

for stock calculation and reports.
