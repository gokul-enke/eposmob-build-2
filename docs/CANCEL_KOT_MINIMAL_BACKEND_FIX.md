# Cancel KOT Minimal Backend Fix

## Goal

Implement cancel KOT printing for edited restaurant orders with the smallest safe backend change.

The key requirement is:

- If an item that was already sent to kitchen is reduced or removed later, the backend must preserve a cancel delta that can be printed.
- Once a cancel KOT is printed, the same cancel quantity must not be printed again on the next cancel KOT.
- New cancel events created after a previous print must remain pending until they are printed and acknowledged.

No database migration is required for this minimal solution.

---

## Why The Current Flow Is Not Enough

Today, cart quantity updates mutate or delete the live `cart_items` row.

That causes a problem for cancel KOT logic:

- after a quantity reduction, the original kitchen-sent quantity is no longer available from the cart row alone
- after a removal, the row may be deleted completely
- if the backend tries to derive cancel KOT only from current cart state, repeated cancel prints can become cumulative or incorrect

This is especially risky in this scenario:

1. Kitchen already received item A x3
2. User reduces item A by 1
3. Cancel KOT prints item A x1
4. Later user removes item B x2
5. Next cancel print must show only item B x2

If there is no persisted cancel queue or acknowledgment logic, the backend can incorrectly print both the old cancel and the new cancel together.

---

## Minimal Safe Design

Use one existing `order_props` entry.

Add a single prop:

- `KOT_CANCEL_QUEUE`

Its value is a JSON array of pending cancel events.

Each time a kitchen-sent item is reduced or removed, append one event to this array.

The app prints only the currently pending events.

After successful printing, the app calls a tiny acknowledgment endpoint so the backend removes only the printed event ids from the queue.

If the queue becomes empty, the prop can be deleted.

---

## Why One Prop Is Better Than Multiple Rows

Some order responses flatten `order_props` by `code` into a key-value map.

Because of that, repeated rows using the same prop code are not a good fit for queue semantics.

Using one prop with one JSON array avoids collisions and is easier to update atomically.

---

## Suggested Event Shape

```json
[
  {
    "event_id": "uuid",
    "cart_item_id": 123,
    "product_id": 45,
    "product_name": "Chicken Fried Rice",
    "variant_attributes": {
      "size": "Full"
    },
    "comment": "no onion",
    "cancel_qty": 1,
    "created_at": "2026-04-20T10:00:00Z"
  }
]
```

Notes:

- `event_id` must be unique per cancel event
- store the printable snapshot in the queue entry itself
- do not rely on the cart row later for product name, comment, or variant details
- `printed_at` is optional in this minimal version because acknowledged events are removed from the queue entirely

---

## Queue Rules

### 1. Item Was Never Sent To Kitchen

If edited item has `status == null`, do not create a cancel event.

Reason:

- that item was never sent to kitchen
- deleting or reducing it should not create a cancel KOT

### 2. Kitchen-Sent Item Quantity Reduced

If edited item has `status != null` and quantity changes from `old_qty` to `new_qty`, and `new_qty < old_qty`:

- append one queue event with `cancel_qty = old_qty - new_qty`

### 3. Kitchen-Sent Item Removed Completely

If edited item has `status != null` and the item is removed:

- append one queue event with `cancel_qty = old_qty`

### 4. Quantity Increased

Do not use this queue for add-on items.

This document only covers cancel KOT.

---

## New Endpoint

### Request

`POST /api/v1/orders/acknowledge-kot-print`

```json
{
  "order_id": 123,
  "type": "cancel",
  "event_ids": ["e1", "e2"]
}
```

### Meaning

This endpoint means:

- the app has already printed these cancel KOT events successfully
- remove only those event ids from the pending cancel queue

It does **not** mean:

- clear the whole queue unconditionally

---

## Acknowledge Endpoint Logic

Server logic:

1. Load `KOT_CANCEL_QUEUE` for the order
2. If the prop does not exist, return success or no-op
3. Filter out only the entries whose `event_id` is in `event_ids`
4. If the remaining array is empty, delete the prop
5. Otherwise save the remaining array back to `KOT_CANCEL_QUEUE`
6. Return the remaining pending count

Pseudo logic:

```php
$queue = getOrderProp($order, 'KOT_CANCEL_QUEUE') ?? [];

$remaining = array_values(array_filter($queue, function ($event) use ($request) {
    return !in_array($event['event_id'], $request->event_ids, true);
}));

if (empty($remaining)) {
    updateOrderProp($order, 'KOT_CANCEL_QUEUE', null); // deletes prop
} else {
    updateOrderProp($order, 'KOT_CANCEL_QUEUE', $remaining);
}
```

---

## Why The Endpoint Must Remove Only Matching Event Ids

This prevents data loss in concurrent edit flows.

Example:

1. Queue currently contains `e1`, `e2`
2. App fetches and prints `e1`, `e2`
3. Before app sends acknowledgment, user cancels one more item and backend appends `e3`
4. App acknowledges `e1`, `e2`

Correct result:

- queue should still contain `e3`

Wrong result:

- clearing the whole queue would lose `e3`

So yes, the prop can be deleted fully, but only when there are no remaining unacknowledged events after filtering.

---

## Where To Hook This In

Use the existing order prop helpers already present in `OrderHelper.php`.

Relevant backend areas:

- append cancel events when quantity is reduced or item is removed in cart/order edit flow
- add the new acknowledgment endpoint in the order API controller
- read the queue when app asks for pending cancel KOT items

No migration is needed because `order_props` already stores JSON values.

---

## Important Edge Cases

### Case 1: Same Item Cancelled Twice At Different Times

Example:

1. Item A reduced by 1 -> create event `e1`
2. `e1` printed and acknowledged
3. Later item A reduced by 2 more -> create event `e2`

Expected result:

- next cancel print contains only `e2`

### Case 2: App Printed But Crashed Before Acknowledgment

Expected result:

- the queue entry remains pending
- the cancel KOT may print once again on retry
- this is safer than losing the cancel event completely

### Case 3: Item Removed After Previous Cancel KOT Already Printed

Expected result:

- only the new removal delta is added
- old acknowledged events do not return

### Case 4: Unsent Item Removed

Expected result:

- no cancel queue entry is created

---

## Acceptance Criteria

Backend implementation is correct if all of these are true:

1. Reducing a kitchen-sent item creates a pending cancel event
2. Removing a kitchen-sent item creates a pending cancel event
3. Reducing or removing an unsent item does not create a cancel event
4. Acknowledging printed events removes only those event ids
5. Newly added cancel events are not lost if they were created before acknowledgment arrives
6. Once acknowledged, an old cancel event is never printed again
7. If queue becomes empty after acknowledgment, the `KOT_CANCEL_QUEUE` prop is deleted

---

## Recommended Minimal API Contract

### Pending Cancel KOT Source

Return pending cancel events from `KOT_CANCEL_QUEUE`.

### Acknowledge Print

`POST /api/v1/orders/acknowledge-kot-print`

```json
{
  "order_id": 123,
  "type": "cancel",
  "event_ids": ["e1", "e2"]
}
```

### Response Example

```json
{
  "status": "success",
  "message": "KOT print acknowledged",
  "data": {
    "order_id": 123,
    "type": "cancel",
    "acknowledged_event_ids": ["e1", "e2"],
    "remaining_pending_count": 1
  }
}
```

---

## Summary

Your backend does not need a new table for the first version.

The minimal safe implementation is:

- keep pending cancel deltas in one `order_props` JSON array called `KOT_CANCEL_QUEUE`
- append a queue event whenever a kitchen-sent item is reduced or removed
- print only the pending queue events
- acknowledge only the printed event ids
- delete the prop only when the queue becomes empty

This is enough to prevent repeated cumulative cancel prints while staying close to the current backend structure.