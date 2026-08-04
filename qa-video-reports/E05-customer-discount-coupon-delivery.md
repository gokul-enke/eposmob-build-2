# E05 — Customers, discounts, coupons, and delivery

Status: Needs follow-up

## Scope

Recorded a safe read-only and in-memory checkout preview:

- Inspected the Customers module, filters, account-type display, balances, pagination, and view actions.
- Returned to Billing and added one catalog item to the in-memory cart.
- Opened Finalize Order and verified customer search/selection area, delivery methods, discount state, payment state, and order summary.
- Opened the delivery selector and verified configured methods and charges without applying one.
- Closed the preview, cleared the cart, and verified payable amounts returned to zero.

No customer was created/edited, no coupon or discount was applied, and no order or financial transaction was committed.

## Recording

- Session: `rec-20260801-200752-429-na226i`
- Raw capture: `C:\Users\jim\.screencast-mcp\recordings\05-customer-discount-coupon-delivery.mp4` (local only; not approved for sharing)
- Approved capture: `C:\Users\jim\.screencast-mcp\recordings\05-customer-discount-coupon-delivery-approved.mp4`
- Frames: `C:\Users\jim\.screencast-mcp\frames\E05-customer-discount-coupon-delivery-approved\`

The customer-list portion and signed-in profile area are redacted in the approved capture. Raw customer contact values are not included in this report.

## Expected and actual result

Expected: customer data can be searched and selected; configured delivery methods and charges can be reviewed; discounts/coupons affect the order summary before confirmation.

Actual: the customer module loaded with filters and paginated records; Finalize Order exposed customer search, delivery methods, and Discount/Payment states. The current safe preview showed `Not Applied` for discount and `Not Configured` for payment, and the order summary remained unchanged. The preview and cleanup behaved as expected.

## Follow-up / limitations

- A designated safe customer and a non-production coupon/discount fixture are required to verify selection, validity, stacking, expiry, and recalculation.
- Delivery method selection, address validation, charge calculation, and delivery-note persistence were inspected but not committed.
- Customer create/edit, credit-limit behavior, and customer-specific price/discount rules were not modified.

## Runtime errors

No new Flutter runtime error was observed after this episode. Existing DTD follow-up events remain documented in E00-E02; no credentials or contact values are repeated here.

## Media verification

Approved MP4 metadata:

- Duration: 149.416667 seconds
- Resolution: 2560×1440
- Video: H.264, approximately 11.859 fps
- Audio: none
- Size: 2,359,403 bytes

Sampled and visually checked sanitized frames at 25s (redacted customer page), 55s (price selector), 90s (in-memory cart), and 145s (cleared cart).

## Sharing

Cloudflare link: pending creation of the dedicated allow-listed QA-series share folder.
