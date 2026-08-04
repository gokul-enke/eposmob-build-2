# E04 — Pricing, variants, stock, and quantity

Status: Needs follow-up

## Scope

Recorded the safe, non-persistent product-selection path in Billing:

- Opened a product with multiple configured price choices.
- Inspected the stock-lot selector, including an unavailable combined-stock entry and available stock entries.
- Selected an available stock lot.
- Verified unit, price, tax, quantity, and computed total in the in-memory cart.
- Increased quantity from 1 to 2 and verified the total recalculated.
- Cleared the cart and verified the payable amounts returned to zero.

No product, stock, price, barcode, or financial master data was changed. The order was not confirmed.

## Recording

- Session: `rec-20260801-200101-301-yfwvk7`
- Raw capture: `C:\Users\jim\.screencast-mcp\recordings\04-pricing-variants-stock-quantity.mp4` (local only; not approved for sharing)
- Approved capture: `C:\Users\jim\.screencast-mcp\recordings\04-pricing-variants-stock-quantity-sanitized.mp4`
- Frames: `C:\Users\jim\.screencast-mcp\frames\E04-pricing-variants-stock-quantity-sanitized\`

The approved capture redacts the signed-in profile area. No checkout customer grid was opened in this episode.

## Expected and actual result

Expected: a configured product can expose price choices and stock lots, an available lot can be added, quantity changes recalculate totals, and Clear Cart removes the in-memory line.

Actual: price choices and stock-lot details were displayed; the available lot was added; quantity 2 produced a recalculated total; Clear Cart returned the cart to zero. The flow behaved as expected for the exercised path.

## Follow-up / limitations

- A product with a true variant matrix was not available in the current safe account, so variant-specific selection remains unverified.
- Barcode add, unit conversion, fractional quantity, zero/negative quantity, over-stock quantity, and price-edit validation remain unverified.
- Persistent stock changes were intentionally not attempted.

## Runtime errors

No new Flutter runtime error was observed after this episode. The existing DTD error list still contains the previously captured P2 `ListTile background color or ink splashes may be invisible` assertion from `lib/widgets/user_switcher.dart:464`; it is not attributed to E04.

## Media verification

Approved MP4 metadata:

- Duration: 248.933008 seconds
- Resolution: 2560×1440
- Video: H.264, approximately 10.794 fps
- Audio: none
- Size: 2,534,695 bytes

Sampled and visually checked sanitized frames at 35s (price choices), 75s (stock/cart path), 130s (cart quantity path), and 245s (cleared cart).

## Sharing

Cloudflare link: pending creation of the dedicated allow-listed QA-series share folder.
