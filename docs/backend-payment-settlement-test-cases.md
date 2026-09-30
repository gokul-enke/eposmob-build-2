# Backend Payment Settlement Test Cases

Originally tested: 15 September 2026  
Retested in the Windows POS: 16 September 2026  
Endpoint: `POST /api/v1/order/add-to-order`  
Client: Windows POS (Flutter)

Payment method IDs observed in the test environment:

- `7974` = CASH
- `7973` = CARD

The phone number and transaction reference are redacted below. All other values are the values captured in the admin panel API request logs.

## Test 1: Whole-number split payment

Order: `ORD-004636` (server ID `6214`)  
Request ID: `07cdb925-79c0-4945-aac7-6aeb36ff4329`  
HTTP result: `201` in 328 ms; admin marked the request as not slow.

### Request body

```json
{
  "items": [
    {
      "mrp": 2.5,
      "price": 1,
      "quantity": 5,
      "stock_id": 499,
      "product_id": 15446,
      "warranty_enabled": false
    }
  ],
  "phone": "[redacted]",
  "status": "confirmed",
  "balance": "0.0",
  "store_id": 2,
  "coupon_id": null,
  "customer_id": 2527,
  "source_type": "executive",
  "paid_methods": [
    { "amount": 3, "method": "7974" },
    { "amount": 2, "method": "7973" }
  ],
  "flat_discount": 0,
  "payment_method": ["7974", "7973"],
  "delivery_charge": 0,
  "discount_amount": 0,
  "delivery_method_id": "149",
  "to_customer_credit": false,
  "transaction_number": "[redacted]",
  "percentage_discount": 0
}
```

### Observed result

- Total: SAR `5.00`
- Backend payments: CARD `2.00` + CASH `3.00`
- `BALANCE`: `0.0`
- `payment_status`: `paid`
- Admin paid amount: SAR `5.00`

This case is correct.

## Test 2: Whole-number partial payment / credit

Order: `ORD-004637` (server ID `6215`)  
Request ID: `d4f0fdee-391c-4472-bbae-9082e63f1c31`  
HTTP result: `201` in 230 ms; admin marked the request as not slow.

### Request body

```json
{
  "items": [
    {
      "mrp": 5,
      "price": 5,
      "quantity": 1,
      "stock_id": 499,
      "product_id": 15446,
      "warranty_enabled": false
    }
  ],
  "phone": "[redacted]",
  "status": "confirmed",
  "balance": "3.0",
  "store_id": 2,
  "coupon_id": null,
  "customer_id": 2527,
  "source_type": "executive",
  "paid_methods": [
    { "amount": 2, "method": "7973" }
  ],
  "flat_discount": 0,
  "payment_method": ["7973"],
  "delivery_charge": 0,
  "discount_amount": 0,
  "delivery_method_id": "149",
  "to_customer_credit": false,
  "transaction_number": "[redacted]",
  "percentage_discount": 0
}
```

### Observed result

- Total: SAR `5.00`
- Backend response payments: CARD `2.00` + CREDIT `3.00`
- `BALANCE`: `3.0`
- Admin paid amount: SAR `2.00`
- Backend `payment_status`: `paid` (**incorrect**)

Expected status: `pending`/`credit`, because SAR `3.00` remains outstanding. The request body is correct; the status calculation was wrong at the time of this test.

## Test 3: Retest after the backend change

Order: `ORD-004641` (server ID `6219`)  
Created from the Windows POS on 16 September 2026 with the same whole-number partial-payment scenario: a SAR `5.00` sale, CARD SAR `2.00`, and SAR `3.00` left as customer due. The client completed the order locally first, then the background request created the order successfully.

### Verified result

- `grand_total`: `5.000`
- Payment method: `CARD`
- `BALANCE`: `3.0`
- `payment_status`: `pending`
- Order status: `confirmed`

This is now correct. The backend preserves the outstanding balance and no longer marks this partial/credit sale as paid.

## Related decimal case

An earlier order sent the same structure with a SAR `1.00` total and two payments of SAR `0.50` + SAR `0.50`, with `balance: "0.0"`. That order was displayed with paid amount SAR `2.00` and a CASH payment of SAR `1.00`, suggesting a separate decimal split-payment allocation or reporting problem.

## Backend checks requested

Please inspect the raw payment rows and the admin-panel query separately from the order status calculation. The expected rules are:

```text
paid_amount = sum(paid_methods.amount)
order_balance = max(grand_total - paid_amount, 0)
payment_status = paid only when order_balance == 0
```

For partial/credit sales, the customer ledger should also receive one idempotent debit equal to `order_balance`.

No API contract change appears necessary. The POS sent the correct body in all tests, and the live retest confirms the backend settlement-status issue is fixed. The decimal split-payment case still needs a separate retest before it can be marked resolved.
