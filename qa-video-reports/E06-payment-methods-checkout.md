# E06 — Payment methods and checkout

Status: Blocked at final confirmation

## Scope

Recorded the safe payment-preview path:

- Added one configured catalog item to the in-memory cart.
- Opened Finalize Order and selected the Payment panel.
- Inspected Exact cash, card, cash, UPI, Credit, clear-payments, amount, transaction-reference, balance, and order-summary controls.
- Verified the selected payment preview showed a payable amount and no persistent invoice was created.
- Closed the payment panel, cleared the cart, and verified zero payable/paid/balance values.

The final Confirm action was intentionally not pressed. No financial transaction was created.

## Recording

- Session: `rec-20260801-201332-881-6pi46x`
- Raw capture: `C:\Users\jim\.screencast-mcp\recordings\06-payment-methods-checkout.mp4` (local only; not approved for sharing)
- Approved capture: `C:\Users\jim\.screencast-mcp\recordings\06-payment-methods-checkout-sanitized.mp4`
- Frames: `C:\Users\jim\.screencast-mcp\frames\E06-payment-methods-checkout-sanitized\`

The signed-in profile area is redacted in the approved capture.

## Expected and actual result

Expected: the checkout preview exposes configured tender methods, payment amounts and references, recalculates totals, and requires an explicit confirmation before persistence.

Actual: the payment panel exposed the expected tender controls and summary; the preview recalculated and displayed the expected amount. Closing and clearing restored the empty state. Final persistence was not tested because the current run lacks explicit authorization for a financial transaction and a designated safe invoice fixture.

## Follow-up / limitations

- Execute exact-cash, partial cash, card reference, UPI reference, credit eligibility, overpayment, underpayment, and mixed-payment cases with a non-production test account.
- Verify invoice creation, receipt printing, duplicate-submit protection, rollback, and payment reconciliation after authorization.
- The Payment panel displayed configured/selected state in the preview; backend settlement remains unverified.

## Runtime errors

No new Flutter runtime error was observed after this episode. The existing runtime-error list remained unchanged.

## Media verification

Approved MP4 metadata:

- Duration: 131.25 seconds
- Resolution: 2560×1440
- Video: H.264, approximately 11.931 fps
- Audio: none
- Size: 2,195,817 bytes

Sampled and visually checked sanitized frames at 95s (payment methods) and 128s (cleared cart).

## Sharing

Cloudflare link: pending creation of the dedicated allow-listed QA-series share folder.
