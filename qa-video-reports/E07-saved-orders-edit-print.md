# E07 — Saved orders, edit, and print

Status: Blocked at persistence

## Scope

Recorded the safe saved-order preview:

- Inspected the Orders pane empty state (`No saved orders yet`) and Create New Order control.
- Created an in-memory cart line only to expose Save Order, Confirm and Print, and Confirm Order controls.
- Inspected stock selection and cart state.
- Did not press Save Order, Confirm and Print, or Confirm Order.
- Cleared the cart and verified the empty order state remained.

No saved order, invoice, print job, or financial transaction was created.

## Recording

- Session: `rec-20260801-201753-834-92jco7`
- Raw capture: `C:\Users\jim\.screencast-mcp\recordings\07-saved-orders-edit-print.mp4` (local only; not approved for sharing)
- Approved capture: `C:\Users\jim\.screencast-mcp\recordings\07-saved-orders-edit-print-sanitized.mp4`
- Frames: `C:\Users\jim\.screencast-mcp\frames\E07-saved-orders-edit-print-sanitized\`

The signed-in profile area is redacted in the approved capture.

## Expected and actual result

Expected: an order can be saved as a draft, resumed and edited, printed or retried, and guarded against duplicate actions.

Actual: the empty saved-order state and controls were available; an in-memory cart displayed Save Order and print/confirm actions; cleanup restored the empty state. Persistence and print execution were not attempted.

## Follow-up / limitations

- Requires an approved non-production draft-order fixture or explicit authorization to save a draft.
- Verify resume/edit, line removal, customer/delivery retention, print failure/retry, duplicate save, and draft cleanup.

## Runtime errors

No new Flutter runtime error was observed after this episode. The existing runtime-error list remained unchanged.

## Media verification

Approved MP4 metadata:

- Duration: 112.5 seconds
- Resolution: 2560×1440
- Video: H.264, 10 fps
- Audio: none
- Size: 1,411,489 bytes

Sampled and visually checked sanitized frames at 1s (empty state), 60s (stock/cart preview), and 105s (cleared state).

## Sharing

Cloudflare link: pending creation of the dedicated allow-listed QA-series share folder.
