# Multi Sale Unit Stock Handling Explanation

## Purpose

Some products can be sold in more than one unit.

Example:

```text
Base unit: PC
Sale unit: CRT
1 CRT = 12 PC
```

The customer and cashier think in sale units like `CRT`, but stock is usually stored in base units like `PC`.

So the system must always convert sale units back to base units for stock calculation.

## Case 1: Enough stock is available

Example:

```text
Stock = 24 PC
Customer buys 2 CRT
1 CRT = 12 PC
```

Calculation:

```text
2 CRT = 24 PC
```

Result:

```text
Sale is allowed.
Stock becomes 0 PC.
Cart and invoice show 2 CRT.
```

This is the simple case.

Verified current payload behavior:

```text
2 CRT is sent as one row.
stock_id is included.
quantity is 2.
```

## Case 2: Only partial stock is available

Example:

```text
Stock = 16 PC
Customer buys 2 CRT
1 CRT = 12 PC
```

Calculation:

```text
2 CRT = 24 PC
Available = 16 PC
Shortage = 8 PC
```

The cart should still show:

```text
Qty 2 | Unit CRT
```

The system should internally track:

```text
16 PC deducted from stock
8 PC sold as negative / unreserved stock
```

This should be allowed only if the business allows negative stock sales.

Current system behavior:

```text
The cart shows 2 CRT.
But the backend payload is split internally.
16 PC becomes 1.333333 CRT with stock_id.
8 PC becomes 0.666666 CRT without stock_id.
```

This works mathematically, but it is not ideal for order details and printing unless backend groups the rows back to `2 CRT`.

Verified current payload behavior:

```text
Payload row 1: 1.333333 CRT with stock_id
Payload row 2: 0.666666 CRT without stock_id
```

## Case 3: Not enough stock, but negative stock sale is allowed

Example:

```text
Stock = 4 PC
Customer buys 1 CRT
1 CRT = 12 PC
```

Calculation:

```text
Required = 12 PC
Available = 4 PC
Shortage = 8 PC
```

The system should warn the cashier:

```text
Only 4 PC is available. This sale will make stock negative by 8 PC.
```

If cashier confirms, sale is allowed.

Result:

```text
Cart shows 1 CRT.
Stock becomes -8 PC.
```

Current system behavior:

```text
4 PC becomes 0.333333 CRT with stock_id.
8 PC becomes 0.666666 CRT without stock_id.
Together they equal 1 CRT.
```

This is technically correct but confusing for reports, order details, and printing.

Verified current payload behavior:

```text
Payload row 1: 0.333333 CRT with stock_id
Payload row 2: 0.666666 CRT without stock_id
```

## Case 4: Not enough stock, and negative stock sale is not allowed

Example:

```text
Stock = 4 PC
Customer buys 1 CRT
1 CRT = 12 PC
```

If negative stock is disabled, the system should block the sale.

Message:

```text
Insufficient stock for 1 CRT. Available stock is 4 PC.
```

Result:

```text
Sale is not allowed.
Cart should not confirm this item.
```

Verified current payload behavior:

```text
If the item is blocked before cart/confirm, no item payload is sent.
```

## Cart display rule

The billing table should stay simple for the cashier.

Good:

```text
Sample CRT 12 | Qty 2 | Unit CRT | Price 2400 | Total 4800
```

Avoid showing technical stock splits like:

```text
1.333 CRT from stock
0.667 CRT without stock
```

Stock split details should be internal only.

## Backend expectation

Backend should receive the customer-facing sale unit and also know the base quantity.

Example:

```text
Customer buys 2 CRT.
1 CRT = 12 PC.
Backend knows total stock quantity is 24 PC.
```

If stock is partially available, backend should support tracking:

```text
Some quantity deducted from stock
Remaining quantity sold as negative / unreserved stock
```

This avoids confusing cart rows and keeps inventory accurate.

Current payload behavior:

```text
When stock comes from multiple sources, current app sends multiple fractional sale-unit rows.
```

Example:

```text
Customer buys 2 CRT.
16 PC available from stock.
8 PC is unreserved.

Current payload meaning:
1.333333 CRT from stock_id
0.666666 CRT without stock_id
```

Better backend behavior:

```text
Receive one sale item: 2 CRT.
Inside that item, receive stock allocation:
- 16 PC from stock_id
- 8 PC unreserved / negative stock
```

This keeps cart, invoice, and reports clean.

## Order details and print rule

Order details and invoices should show the sold unit.

Correct:

```text
Qty 2 | Unit CRT | Rate 2400
```

Not correct:

```text
Qty 2 | Unit PC | Rate 2400
```

`PC` can still be stored as the base unit, but user-facing screens and invoices should show the sold unit `CRT`.

## Product decision needed

The main product decision is:

```text
Should POS allow negative stock sales?
```

Recommended setting:

```text
allow_negative_stock_sale = true / false
```

If true:

```text
Warn cashier and allow sale.
```

If false:

```text
Block sale when stock is not enough.
```

For supermarket/POS billing, warning and allowing with permission is usually better than hard blocking, because the customer may already have the item at the counter.

## Recommended final behavior

1. Cart always shows the sale unit selected by the cashier.
2. Stock is calculated in base unit.
3. If stock is enough, deduct normally.
4. If stock is short and negative stock is allowed, warn and allow.
5. If stock is short and negative stock is not allowed, block.
6. Order details and print should show the sale unit, not only the base unit.
