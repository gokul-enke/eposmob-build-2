# E08 — Sales, orders, and statuses

Status: Needs follow-up

## Scope

Recorded a read-only tour of the Sales section:

- Opened Sales / Orders List and inspected order, customer, phone, price, status, business-date, and date-range filters.
- Opened Confirmed Orders and verified the empty-state result in the current filtered view.
- Opened Online Orders and inspected its filter/table/status layout.
- Did not open row details, cancel an order, change a status, print, or perform any mutation.

## Recording

- Session: `rec-20260801-202202-459-5vy4en`
- Raw capture: `C:\Users\jim\.screencast-mcp\recordings\08-sales-orders-statuses.mp4` (local only; not approved for sharing)
- Approved capture: `C:\Users\jim\.screencast-mcp\recordings\08-sales-orders-statuses-sanitized.mp4`
- Frames: `C:\Users\jim\.screencast-mcp\frames\E08-sales-orders-statuses-sanitized\`

The approved capture redacts the signed-in profile and order-row area. Customer names, order numbers, and amounts are not repeated here.

## Expected and actual result

Expected: sales and online-order lists expose safe filters, status visibility, row actions, and controlled status transitions.

Actual: both list pages loaded with expected filters and status/table structure; Confirmed Orders displayed its empty-state message in the current view. Read-only navigation worked.

## Follow-up / limitations

- Requires a designated non-production order fixture to verify view/detail, status transition, cancel, print, online-order acceptance, and duplicate-action guards.
- Existing backend records were visible during local inspection, but their customer/order data is intentionally excluded from shareable media.

## Runtime errors

No new Flutter runtime error was observed after this episode. The existing runtime-error list remained unchanged.

## Media verification

Approved MP4 metadata:

- Duration: 89.9 seconds
- Resolution: 2560×1440
- Video: H.264, approximately 9.889 fps
- Audio: none
- Size: 624,801 bytes

Sampled and visually checked sanitized frames at 30s (Sales list), 60s (Online Orders), and 85s (Online Orders filters).

## Sharing

Cloudflare link: pending creation of the dedicated allow-listed QA-series share folder.
