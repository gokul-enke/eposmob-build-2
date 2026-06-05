# Kitchen Button Changes

## Summary

Added settings-controlled **Send Kitchen** and **KOT + Bill** flows for restaurant billing counter mode.

## New App Settings

- `ENABLE_SEND_TO_KITCHEN_BUTTON`
  - Shows or hides the normal Send Kitchen action.
  - Default should be `true` if the API key is missing, so old API users keep existing behavior.

- `ENABLE_KOT_BILL_BUTTON`
  - Shows or hides the KOT + Bill flow.

- `KOT_BILL_AUTO_MARK_SERVED`
  - When enabled, KOT + Bill automatically marks order items as served.

- `KOT_BILL_ALLOWED_FOR_DINE_IN`
  - Allows KOT + Bill for selected table / Dine In orders.

## Current Cart Behavior

When enabled, **KOT + Bill**:

1. Sends the cart to kitchen/order.
2. Opens the created ongoing order.
3. Marks items served if the setting allows it.
4. Prints an ongoing-order copy titled **Order Summary**.
5. Opens checkout for manual final confirmation.

It does not automatically confirm the sale.

## Button Behavior

- `ENABLE_SEND_TO_KITCHEN_BUTTON=true` and `ENABLE_KOT_BILL_BUTTON=false`
  - Show only `Send Kitchen`.

- `ENABLE_SEND_TO_KITCHEN_BUTTON=false` and `ENABLE_KOT_BILL_BUTTON=true`
  - Show only `KOT + BILL`.

- `ENABLE_SEND_TO_KITCHEN_BUTTON=true` and `ENABLE_KOT_BILL_BUTTON=true`
  - Show both `Send Kitchen` and `KOT + BILL`.

- `ENABLE_SEND_TO_KITCHEN_BUTTON=false` and `ENABLE_KOT_BILL_BUTTON=false`
  - Hide both kitchen actions. Usually not recommended.

Suggested labels when both are visible:

- `Send Kitchen`
- `KOT + BILL`

## Auto Mark Served Scenarios

### `KOT_BILL_AUTO_MARK_SERVED=true`

Use for mall, theater, food court, or fast counter kitchens where served means the order is released from kitchen workflow.

Flow:

1. Press `KOT + BILL`.
2. Send order to kitchen.
3. Open created ongoing order.
4. Mark all items as served automatically.
5. Print **Order Summary**.
6. Open checkout.
7. Salesman confirms manually.

### `KOT_BILL_AUTO_MARK_SERVED=false`

Use for dine-in/table service where kitchen status should remain accurate until food is actually served.

Flow:

1. Press `KOT + BILL`.
2. Send order to kitchen.
3. Open created ongoing order.
4. Keep item status as new/started/preparing.
5. Print **Order Summary**.
6. Open checkout.
7. Salesman confirms manually.

## Ongoing Order Behavior

Ongoing orders now show a **Pre-Bill** button when KOT + Bill is enabled in billing counter mode.

The Pre-Bill button prints the selected ongoing order as **Order Summary** without marking served or confirming the order.


