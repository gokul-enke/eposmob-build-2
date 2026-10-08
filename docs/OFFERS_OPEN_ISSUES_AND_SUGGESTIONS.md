# Product offers: fixes, verification and remaining suggestions

Updated 2026-10-07 for the working tree on `gokul-dev`, based on commit
`bb4a5ff1`. These changes are uncommitted.

## Fixes implemented

### Consistent amounts across cart, receipt and upload

`CartLineAmounts` computes money rounded half-up to two decimals. Every uploaded
batch line retains `total_price = roundMoney(price × quantity)` and inclusive
`tax_amount = roundMoney(total_price × rate / (100 + rate))`. A cart line uses the
sum of those batch amounts. The cart, receipt, kiosk and restaurant displays use
the same calculation. No rounding remainder is assigned to another batch.

| Case | Cart / receipt / upload |
| --- | --- |
| Three separate lines at 16.992 | 50.97 |
| One line at 9.315 × 2 from two batches (1 + 1) | 18.64 |
| 12.35/kg, 0.5 kg from each of two batches | 12.36 |
| Four batch lines at 0.005 | 0.01 each; total 0.04; no negative amount |
| One batch at 16.992 × 3 | 50.98 |

This deliberately follows the existing backend contract, which rounds every
uploaded order line separately. A grouped batch line can therefore cost one
paisa more than rounding its unsplit quantity. Whole-number quantities at
two-decimal unit prices retain their previous totals.

### Price entry and previews

- Desktop and mobile price fields commit on blur or submit. Intermediate text
  does not mark the cart line manual or remove its offer. Retyping the automatic
  price keeps automatic pricing, including when the offer is below the minimum
  manual-price floor. A genuinely different manual price still uses that floor.
- Untouched or cleared fields do not commit a new price. A desktop field keeps
  focused text such as `90.` across provider updates and virtual-keyboard use.
- Focused mobile prices use ungrouped numbers, so a refreshed price above 1,000
  is not truncated by the input filter.
- Add-sheet preview and actual add use the same compatible batch set and rounded
  amount. Wholesale quantity and sale-unit selection still determine eligibility.
- A restaurant re-add matching the offer price rounded to two decimals keeps the
  offer reference and standard price. Arbitrary custom prices are still manual.
- Add-sheet fields no longer show floating-point text such as
  `29.997000000000003`. The restaurant offer badge avoids duplicate accessible
  price text and wraps at narrow widths.

Pack/case/box lines do **not** receive offers by design. The old fractional-pack
example was an untouched-price regression risk, not an eligible offer case.

### Sync and checkout

- Store-cache loading no longer publishes an intermediate empty catalog.
- A missing offers endpoint (404/405) does not schedule automatic retries.
  An explicit later refresh can recover. A stale request from a previous session
  cannot suppress retries for the new session.
- Identical pricing catalogs update the persisted sync cursor without notifying
  every cart listener again. Changes to offers, the switch or meaningful clock
  corrections still notify.
- Server-time measurement uses the midpoint of the request that supplies the
  timestamp, rather than the completion of all pages. After the first correction,
  changes below one second are ignored. A slow first sync is still accepted so
  a badly set device clock can be corrected.
- Offer rechecks wait while checkout/payment is active. Nested dialogs share
  that hold. Closing or cancelling checkout releases it and catches up with
  pending changes. The mobile Billing tab holds prices only while selected.
  Manual quantity, unit and price changes continue to use their normal rules.

## Remaining suggestions and decisions

1. **Repeated catch-up requests while the main sync cursor is deferred.** The
   existing realtime deduplication still includes `updatedTo`. Removing it alone
   could hide a second offer edit while an open cart prevents cursor advancement,
   especially without a socket event. The no-op cart notifications are fixed;
   reducing those network requests needs a reliable offer revision/independent
   cursor or a separately bounded polling design.
2. **Legacy caches without a tenant key.** They remain rejected. Accepting them
   without proof of ownership can expose another tenant's prices. A sync safely
   replaces them; an offline upgrade from those development builds may need its
   first online sync.
3. **Legacy carts with a manual-price flag.** The flag is preserved. The app
   cannot reliably distinguish an old erroneous flag from a real cashier edit,
   so automatic migration would risk changing an intentionally saved price.
4. **Product-preview memoization.** Identical syncs now avoid pricing rebuilds.
   Further caching of product previews is an optional performance improvement.
5. **One order line with `stock_allocations`.** Backend support could keep batch
   inventory while rounding a printed cart line only once. Until agreed, the app
   continues sending one order line per batch. Three-decimal offer prices remain
   unchanged as required by the existing contract.
6. **Additional live display finding.** After the fresh restart, the desktop
   held-order sidebar card (`ORD-1`) reports a 0.27-pixel bottom overflow in debug
   mode. Its card layout is outside the changed offer-pricing code and was not
   changed in this pass.

The backend proposal is recorded in `docs/ask-backend-dev.md`. No backend API or
data migration is included in these app fixes.

## Verification

- Regression tests cover the amount cases above, inclusive tax, discounts,
  retyping automatic prices, focused rebuilds, prices above 1,000, fractional
  sale units, batch preview parity, restaurant re-adds, missing-endpoint retry,
  identical syncs, server-time measurement and nested checkout holds.
- Marionette live checks on CLOUDPOS: offer prices in search and product cards;
  mobile Add popup at quantity four; desktop and mobile retyping of 90; desktop
  quantity four at offer 90, five at wholesale 80, back to four at offer 90;
  manual 95 remaining manual after quantity change; mobile Billing/Cart navigation;
  cart recovery with its offer price after a fresh app restart.
  The added test item was removed and the original demo cart/window restored.
- Automated amount, receipt and payload checks do not establish backend acceptance
  of a newly submitted sale. Those cases were not uploaded during this fix pass.
- Final full automated suite: **2,528 passed, 2 skipped, 0 failed** (6 min 52 s).
  Run: `flutter test --no-pub --enable-impeller --reporter expanded`.
- Static analysis of the final offer/price/checkout changes: **0 errors**;
  existing warnings and style notices remain. `git diff --check` passes.
