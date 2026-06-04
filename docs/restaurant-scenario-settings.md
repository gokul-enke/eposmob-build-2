# Restaurant Scenario Settings

This guide shows how to configure the kitchen/counter booleans for common restaurant workflows.

## Settings

| Setting | Purpose | Safe default |
|---|---|---|
| `ENABLE_SEND_TO_KITCHEN_BUTTON` | Show normal kitchen-only send button | `true` |
| `ENABLE_KOT_BILL_BUTTON` | Show KOT + BILL / Pre-Bill actions | `false` |
| `KOT_BILL_AUTO_MARK_SERVED` | Auto mark items served during KOT + BILL | `false` |
| `KOT_BILL_ALLOWED_FOR_DINE_IN` | Allow KOT + BILL for table / Dine In context | `false` |

## Recommended Configurations

| Scenario | Send Kitchen | KOT + BILL | Auto Mark Served | Allow Dine In | Notes |
|---|---:|---:|---:|---:|---|
| Classic dine-in waiter service | `true` | `false` | `false` | `false` | Waiter sends KOT only. Bill is handled later from ongoing order or checkout. |
| Dine-in with pre-bill from counter | `true` | `true` | `false` | `true` | Staff can send KOT and optionally print an Order Summary, but food is not marked served early. |
| Fast counter kitchen, bill after ordering | `true` | `true` | `true` | `false` | Counter staff can either send kitchen only or do KOT + BILL. Auto serve is okay when served means released from counter kitchen. |
| Mall / theater / food court token flow | `false` | `true` | `true` | `false` | Every kitchen send should produce Order Summary/token and move items to served workflow. |
| Parcel / takeaway pay later | `true` | `true` | `true` | `false` | Staff can send kitchen only or print an Order Summary before final payment. |
| Parcel / takeaway pay now | `true` | `false` | `false` | `false` | Use normal Confirm / Confirm & Print. KOT + BILL is not needed. |
| Delivery order with payment later | `true` | `true` | `false` | `false` | Order Summary can be printed, but served status should usually wait until dispatch/delivery workflow. |
| Drive-through / car pickup | `true` | `true` | `true` | `false` | Similar to fast counter. Use car number in checkout/order details. |
| Kitchen-only operation | `true` | `false` | `false` | `false` | Staff only sends orders to kitchen. No pre-bill shortcut. |
| Billing-only counter without kitchen status | `false` | `false` | `false` | `false` | Hide kitchen actions. Use checkout confirm flows only. |

## Auto Mark Served Difference

### `KOT_BILL_AUTO_MARK_SERVED=true`

Use when the shop treats KOT + BILL as a counter-kitchen release.

Flow:

1. Press `KOT + BILL`.
2. Send order to kitchen.
3. Open the created ongoing order.
4. Mark all items as `SERVED`.
5. Print `Order Summary`.
6. Open checkout.
7. Salesman confirms manually.

### `KOT_BILL_AUTO_MARK_SERVED=false`

Use when kitchen status must remain accurate until food is actually served.

Flow:

1. Press `KOT + BILL`.
2. Send order to kitchen.
3. Open the created ongoing order.
4. Keep item status as `NEW`, `STARTED`, or `PREPARING`.
5. Print `Order Summary`.
6. Open checkout.
7. Salesman confirms manually.

## Button Visibility Rules

| Desired buttons | `ENABLE_SEND_TO_KITCHEN_BUTTON` | `ENABLE_KOT_BILL_BUTTON` |
|---|---:|---:|
| Only `Send Kitchen` | `true` | `false` |
| Only `KOT + BILL` | `false` | `true` |
| Both buttons | `true` | `true` |
| Hide both | `false` | `false` |

## Practical Recommendation

For most stores, start with:

```text
ENABLE_SEND_TO_KITCHEN_BUTTON=true
ENABLE_KOT_BILL_BUTTON=false
KOT_BILL_AUTO_MARK_SERVED=false
KOT_BILL_ALLOWED_FOR_DINE_IN=false
```

Then enable `ENABLE_KOT_BILL_BUTTON` only for stores that actually need Order Summary / pre-bill behavior.


