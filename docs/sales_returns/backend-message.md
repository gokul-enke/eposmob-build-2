# Sales Return — Backend Change Request

**From:** Mobile / POS app team  
**Feature:** Sales return (`POST sales-return`, `POST complete-return-order`)  
**Date:** 2026-06-30

The app now calculates refunds using **pro-rata discount** (discount proportional to returned line value). Please align the backend with the rules below so UI totals, validation, and API responses match.

---

## 1. Use pro-rata discount on complete (not full order discount)

### Current backend behaviour (incorrect for partial returns)

```
totalAmount = itemsTotal - order.discount + deliveryRefund
```

This subtracts the **entire** order discount even when only some lines are returned.

### Expected behaviour

```
orderItemsTotal = sum(original cart line totals for the order)
returnedItemsTotal = sum(order_return_items.price)   // line return totals
proRataDiscount = order.discount * (returnedItemsTotal / orderItemsTotal)
deliveryRefund = is_delivery_refundable ? order.shipping_cost : 0
totalAmount = max(0, round(returnedItemsTotal - proRataDiscount + deliveryRefund))
```

### Why

Order-level discounts often apply to the whole basket. If the customer returns Product A only, they should not lose the discount share that applied to Product B they kept. Pro-rata matches standard retail/POS practice and what the app already shows cashiers.

**Apply in:** `completeReturnOrder` (and anywhere `order_returns.total_amount` is recalculated on item submit if shown to clients).

---

## 2. Validate `paid_amount` against net refund (after pro-rata discount)

### Current backend behaviour

```
paid_amount <= itemsTotal   // pre-discount sum of return lines
```

### Expected behaviour

```
netRefund = returnedItemsTotal - proRataDiscount + deliveryRefund
paid_amount <= netRefund    // when has_payment is true
paid_amount >= 0
```

Cash refund (`has_payment: true`) should not exceed what the customer is owed **after** proportional discount and optional delivery refund.

---

## 3. Return `computed_refund` in API responses (recommended)

To avoid client/server drift, include explicit totals in responses:

**`POST complete-return-order` success `data`:**

```json
{
  "id": 78,
  "total_amount": "450.00",
  "refund_breakdown": {
    "returned_items_total": "500.00",
    "pro_rata_discount": "50.00",
    "delivery_refund": "0.00",
    "net_refund": "450.00"
  }
}
```

**`GET list-return-order-items`** — optional but helpful:

```json
{
  "cart_item_id": 456,
  "remaining_quantity": 3,
  ...
}
```

`remaining_quantity = cart_item.quantity - already_returned_quantity` so clients do not recompute.

---

## 4. Quantity rules (already correct server-side — keep as-is)

```
remainingQty = cartItem.quantity - alreadyReturnedQty
reject if request.quantity > remainingQty
```

App now caps UI using the same rule. No backend change required unless `remaining_quantity` is added to the list endpoint (see §3).

---

## 5. Decimal quantities for weighted products

Backend already accepts numeric `quantity`. Please keep accepting decimals (e.g. `1.250`) for weight-based items. App now sends `quantity` as a number, not forced integer.

---

## 6. `price` validation minimum

Current rule: `price` min `1` rejects items with unit price below 1.00. Please change to `min:0.01` (or `gt:0`) so low-priced / fractional items can be returned.

---

## 7. Error responses

Please continue returning:

```json
{ "status": "failed", "message": "Human readable reason", "data": "..." }
```

App now surfaces `message` / first validation error from `data` to the cashier.

Prefer **HTTP 422** for validation/business rule failures instead of 500 where possible.

---

## 8. `is_delivery_refundable` default

When omitted on complete, default should be **`false`** (delivery is not refunded unless explicitly requested). App sends the field explicitly.

---

## Summary checklist for backend dev

| Item | Action |
|------|--------|
| Pro-rata discount on complete | **Change required** |
| `paid_amount` vs net refund | **Change required** |
| `price` min validation | **Change recommended** |
| `remaining_quantity` in list items | **Nice to have** |
| `refund_breakdown` in complete response | **Nice to have** |
| Decimal quantity support | **Keep** |
| `is_delivery_refundable` default false | **Confirm** |

---

## App alignment (already done)

- Refund UI uses pro-rata discount.
- Return qty capped at `sold qty − returned qty`.
- API errors shown to user.
- `is_delivery_refundable` sent explicitly from UI toggle (default off).

Once backend ships §1 and §2, partial returns with order-level discounts will match end-to-end.
