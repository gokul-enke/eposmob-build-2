# Sales Return — Backend To-Do (Round 2)

**From:** Mobile / POS app team  
**Date:** 2026-06-30

---

## 1. Fix `paid_amount` ceiling when delivery is refundable

When `is_delivery_refundable` is true, cash refund may include delivery. Update `completeReturnOrder`:

```php
$maxCashRefund = $selectedItemsTotal
    + ($request->boolean('is_delivery_refundable') ? (float) ($order->shipping_cost ?? 0) : 0);

if ($request->boolean('has_payment') && (float) $request->paid_amount > $maxCashRefund) {
    return $this->errorResponse(
        'Paid amount cannot exceed the maximum cash refund (' . $maxCashRefund . ').',
        [],
        422
    );
}
```

**Do not** change validation to net-after-discount only. Cash refund may go up to returned items total (+ delivery); pro-rata discount is optional at the counter.

---

## 2. Return `refund_breakdown` in sales return API responses

Attach breakdown from `buildReturnRefundBreakdown` to responses.

**`POST complete-return-order`** (required):

```json
{
  "id": 78,
  "total_amount": "80.00",
  "refund_breakdown": {
    "order_items_total": "200.00",
    "returned_items_total": "100.00",
    "pro_rata_discount": "20.00",
    "delivery_refund": "0.00",
    "net_refund": "80.00"
  }
}
```

**`POST sales-return`** draft response (optional): same `refund_breakdown` after each line submit.

```php
$completed = $orderReturn->fresh();
$completed->setAttribute('refund_breakdown', $refundBreakdown);

return $this->successResponse('Return Order Completed', $completed);
```

---

## 3. Use HTTP 422 for validation / business rule failures

In sales return endpoints (`salesReturn`, `completeReturnOrder`, `listReturnOrderItems`), return **422** instead of default **500** for validation and business errors:

```php
return $this->errorResponse('Validation error', $validator->errors(), 422);
```

Apply to: validation failures, qty exceeded, price exceeded, already completed, paid amount too high, no items.

---

## Files

- `enkepos/app/Http/Controllers/Api/V1/OrderController.php` — `completeReturnOrder`, `salesReturn`
- `enkepos/app/Http/Traits/ApiResponseTrait.php` — `errorResponse` status code
