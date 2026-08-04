# E03 - Basic sale and payment

Status: Blocked at final confirmation

## Scope

Recorded the safe cart and checkout preview path without committing a sale. The cart was cleared before the episode ended.

## Recorded steps and results

1. Inspected Billing with an empty cart.
2. Opened an existing product and inspected its available price choices.
3. Inspected multiple stock lots, quantities, prices, and expiry dates.
4. Selected a low-value test price and added one item to the in-memory cart.
5. Opened Finalize Order and inspected customer selection, delivery, discount, payment, and order-summary surfaces.
6. Opened Payment Methods and inspected card, cash, UPI, and credit options.
7. Closed the checkout preview and cleared the cart.

Expected: a safe QA account can add a product, choose price/stock, select payment, confirm, and verify an invoice.

Actual: all pre-confirmation UI was reachable. The app displayed a test item total of SAR 2.00 and tax of SAR 0.17 in the temporary checkout state. Final Confirm/Confirm & Print was intentionally not pressed because a current per-episode authorization for a persistent financial transaction and a designated non-production test account were not available. No sale was committed.

## Blocker and defects

- Blocker: final sale confirmation requires explicit authorization and confirmed safe test data.
- The checkout customer grid exposed phone-number data in the raw capture; the approved video redacts the customer-selection area during that interval.
- No new runtime error was observed during this episode; the previously captured user-switcher ListTile assertion remains open.

## Media verification

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\03-basic-sale-payment-approved.mp4`
- Duration: 150.933 seconds
- Frame: 2560x1440
- Frame rate: 14.728 fps
- Video: H.264; audio: none
- Size: 2,650,984 bytes
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E03-basic-sale-payment-approved\`
- The raw and intermediate files are not approved for sharing.

## Sharing

Cloudflare link: Pending.
