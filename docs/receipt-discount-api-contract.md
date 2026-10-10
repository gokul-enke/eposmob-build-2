# Expected receipt discount API contract

The requested display is one numeric Discount column in each cart-item row, controlled by the current API's `showDiscountColumn` (`showItemDiscount` remains supported for older configurations). The richer source metadata below is optional accounting/audit data, not a requirement for this display. The app accepts this additive pricing contract. Backend PHP and admin settings have not been changed. Existing responses remain supported. These are receipt snapshots, not instructions to apply discounts again.

Machine-readable examples used by the app's contract tests:

- [Order-details pricing response](api/receipt-discount-order-response.example.json)
- [Document-configuration response](api/receipt-discount-document-config.example.json)

These examples show the relevant pricing/configuration fields. Keep the existing customer, identity, payment, bank, product and document fields; do not replace the full endpoint with this excerpt.

## Order details and reprints

Extend `GET /api/v1/order/executive/order-details/{order_id}` and every draft/restaurant/sync/reprint response that supplies receipt lines. Keep fields directly on each `data.cart.cart_items[]` object.

| Field | Type and meaning |
| --- | --- |
| `standard_unit_price` | Decimal string or null: frozen selling rate before the current offer/manual override. Never MRP or today's catalogue rate. |
| `unit_price`, `quantity`, `total_price` | Existing inclusive selling rate, sale quantity and rounded selling total before order discount. Use the same sale unit as the original rate. |
| `item_discount_amount` | Decimal string: total line price reduction already reflected in `total_price`. Sum the rounded batch reductions for an aggregated line. Explicit zero is authoritative; null/missing makes the app use the original-rate difference when available. |
| `discount_origin` | `offer`, `manual`, `standard` or `wholesale`; null for unknown historical origin. This describes item pricing, not the order coupon. |
| `offer_id`, `offer_version` | Nullable numeric IDs of the applied sale-time offer and version. |
| `offer_name`, `offer_names` | Frozen name and optional `{"en": "...", "ar": "..."}` name translations. Names are data, not template labels. |
| `offer_discount_type` | `percentage` or `flat_amount`. Unknown future types do not print a guessed rule. |
| `offer_discount_value` | Decimal string: percentage points or reduction per selling unit. Snapshot the winning rule, including product/category-line overrides. |
| `tax_rate` | Decimal percentage for this line. Always supply it, even on free/100% discounted lines. |
| `line_discount` | Inclusive order/coupon discount allocated to this line, excluding item price reductions. |
| `discounted_total` | `total_price - line_discount`. |
| `discounted_base_amount`, `discounted_tax_amount` | Stored post-order-discount base/VAT. Their sum equals `discounted_total`; `tax_amount` should agree with discounted VAT. |
| `order_discount_allocations` | Array of stored sources, described below. Its amounts sum exactly to `line_discount`. |

Each order allocation has `source: "coupon"` or `"manual"` and a nonnegative decimal-string `amount`. A coupon also supplies `code`, optional frozen `name`, and optional `names` translations. An ineligible line gets no share of a targeted coupon. Multiple coupons/manual discounts are represented as separate array entries, only if the backend's stacking policy permits them. The print adapter does not authorize stacking.

The app prints a numeric Discount cell, never discount notes inside the product name. Its amount is `item_discount_amount + line_discount`: the item price reduction plus its allocated order/coupon discount. If the explicit item amount is missing, the saved original selling rate supplies that portion when available. Rate shows the original sale-time selling rate before an item reduction; Total shows the stored `discounted_total` after item and order discounts. For consistent snapshots, `Rate × Qty − Discount = Total`, subject to the stored batch rounding. Rate Ex Tax uses the same original rate and saved `tax_rate`; it prints `-` when discounts prevent reconstructing that rate from rounded VAT. The footer continues to reconcile the subtotal after item reductions with the order discount and final VAT. These display values never deduct a discount again. Offer names, rules, original-rate notes, source breakdowns and after-discount notes are not displayed.

Example: the offered line is 100 × 2 before reduction, 80 × 2 after a 20% offer, with item discount 40. Its additional order discount is 16 (coupon 10 plus manual 6), so its final amount is 144 and VAT at 15% is 18.78. The second example line is manually reduced by 5 with a coupon share of 4.50. Both lines total 205 before order discount, 20.50 order discount and 184.50 payable, including VAT 24.06. The item discount of 45 is already inside 205.

Persist these values at sale time. Do not recompute historical offers, coupon eligibility or VAT allocation using today's records. Expose the existing CartItem pricing metadata in the controller projection; add immutable names/rules and allocations where missing. Historical unknown fields must be null/absent, not invented.

If an offer is overridden manually, set `discount_origin: "manual"` and clear offer fields. The item reduction still contributes to the same numeric Discount cell. Separate offer/manual portions require a separate explicit audit contract; they cannot be reconstructed from the final rate.

For partial returns, return the exact stored return-line amounts and allocations for that quantity. The app's legacy partial-copy fallback scales monetary values; that does not replace authoritative penny allocation for repeated partial returns.

## Completed-sale submission

New local completed-sale line snapshots now also submit `item_discount_amount`, `discount_origin` and the frozen offer name/type/value alongside existing original-price/tax/offer-ID/version fields. Accept and persist these as snapshot metadata. Check offer ID/version and rule against historical authoritative data; a client label or supplied amount does not prove eligibility. Preserve the printed snapshot and report a review reason under the existing offline policy if validation differs.

The app captures the winning offer's name and effective rule when applying it, persists them in backward-compatible Hive field 23, and clears them on manual override. Saved-order printing uses this snapshot, not the refreshed catalogue. Draft submissions strip the new completed-sale snapshot fields; keep draft pricing authoritative on the server.

Existing locally applied coupons have no authoritative quote/source-allocation snapshot. Their allocated order-discount share contributes to the Discount column. `order_discount_allocations` remains optional source/audit metadata; implementing the authoritative coupon quote/reservation workflow is still required separately in [backend requirements](backend-offer-and-coupon-changes.md).

## Document configuration

The current response uses `showDiscountColumn` for the separate numeric Discount column in A4/A5 and thermal cart-item tables. Use the existing `{visible, value, default}` structure: Arabic `value` and English `default` in bilingual responses. The example labels it Discount / الخصم. A null `value` with no `default` uses the document language's built-in label: Discount in English, الخصم in Arabic, and Arabic only in bilingual mode, matching the existing label contract. Supply both `value` and `default` to print both languages. The legacy `showItemDiscount` key is supported when `showDiscountColumn` is absent; the current key takes precedence if both exist.

- Explicit `visible: true` shows the column, including zero cells on undiscounted rows.
- Explicit `visible: false` hides it.
- When absent in an older response, show it only when at least one row has a discount.
- The column is independent of `showParticulars`; hiding the product-name column does not hide Discount.
- Existing `showDiscount` continues to control the footer independently.

No original-rate, offer-name/rule, source-breakdown or after-discount switches are needed. The shared column data feeds all six production A4/A5 themes and all three thermal layout families. Existing theme aliases, unknown-key preservation and printer-setting precedence stay supported.

Fix the backend language filter separately: explicit `language=en`/`language=ar` currently both return `en_ar` because the null-coalescing query expression never executes its second `where`. Honor the requested language and define a fallback when its translation is absent. No-language requests should retain the configured active mode.

## Compatibility and validation

- Missing offer/source metadata does not prevent the Discount column; use the saved item amount/original rate and canonical `line_discount`.
- Malformed/negative/nonfinite explicit monetary metadata is ignored. Valid explicit `item_discount_amount`, including zero, wins over inferred differences.
- Item-source metadata does not add text to the product name or change the numeric Discount cell.
- The numeric column uses canonical `line_discount`; incomplete source metadata never replaces line/order amounts.
- New fields must be preserved through model serialization, local saved orders, sync responses and reprints. Confirm manual, offer, offer-plus-order-discount, mixed coupon eligibility, free-line, sale-unit and split-batch examples against the stored sale-time amounts.

The app now checks the downloaded coupon's eligibility and cap and retains its rule for cart changes and held-order restoration. Local saved receipts also retain coupon names/codes in the source breakdown. Restaurant offline bills use the same receipt calculation as desktop/mobile. Server validation, global usage accounting and eligible-line allocation remain backend work; a printed label does not prove server validation.

The latest supplied document response on 10 October 2026 returns `showDiscountColumn: {"visible": true, "value": null}` for Bill A4, independently of the footer's `showDiscount`. The app now honors the current column key in every production PDF and thermal layout. The app accepts both `display_configuration` and `display_flags`, including encoded maps and boolean/numeric/string flags, with explicit configuration entries taking precedence. Unknown switches and translated labels survive cache serialization. Extended pricing/source examples remain proposed additive backend fields, not a claim that they are deployed.

## App verification

On 10 October, the coupon/payload/live-label suite passed 66 tests, the offer/receipt generation suite passed 88 tests, and the wider checkout/configuration/thermal/return integration suite passed 126 tests (one environment-dependent test skipped). These suites overlap. All 36 newly generated A4/A5 PDFs and six 58mm/80mm thermal images were visually reviewed. The running app hot-reloaded successfully with no new runtime exceptions. These are generated-output checks; physical printer hardware was not exercised.

The documented JSON responses are parsed by automated contract tests. Regression checks passed for legacy completed-sale requests, manual/offer pricing, model round trips, Hive persistence, partial monetary copies, visibility, translated labels, malformed metadata and mismatched source totals. A confirmed order retains its offer name/rule after the live offer feed is removed.

Generated and inspected 36 PDFs (six production themes, English/Arabic/bilingual, A4/A5) and six 58mm/80mm thermal images. The richer A5 bilingual Classic example now fits on one page after reducing unused footer spacing. The running app hot-reloaded successfully and reprinted existing order `ORD-004730` with its current response; Marionette logs reported success and no new exceptions. The deployed backend does not yet return the future metadata, so live automatic-offer/coupon-source printing awaits its implementation.

On 10 October, the display scope was corrected to one separate Discount column. The screenshot's four order shares (2.73, 3.64, 10.91, 2.72) appear in numeric cells; no discount notes are appended to product names. The column is informative and leaves payable/tax calculations unchanged.

The later rate/total correction shows original rates and final discounted totals in all A4/A5 and thermal item rows. The 2.00 sample's totals are now 0.27, 0.36, 1.09 and 0.28. Offer 28's fixed product override prints Rate 20.00, Qty 1, Discount 3.00 and Total 17.00. Its product override replaces the offer's general percentage rule. Every offer refresh now downloads the full catalog without `since`, including automatic refreshes, retries and populated caches. This recovers missing unchanged offers even when one or more rules remain cached. All pages must complete before the snapshot replaces the cache. Failed downloads keep cached prices and retry the full list. Backend files remain unchanged.

For this correction, 42 offer-repository/receipt contract tests and 104 cart, offer presentation, receipt configuration, thermal total and return-price tests passed. All 38 generated A4/A5 PDFs fit on one page; the 36 theme/language/paper combinations, two samples and six thermal images were visually inspected. The app hot-reloaded successfully, a full live sync completed, and the existing cart applied offer 28 at 17.00 without confirming a sale. Physical printer hardware was not exercised.

The final always-full-sync/current-column-key update passed 98 offer, API pagination, realtime-sync, document-label and thermal-total regression tests, with clean targeted static analysis. The missing-offer test removes one rule from a still-populated cache during the session and verifies that ordinary refresh restores it without a delta cursor. Column tests cover the supplied null-title response, all language modes, custom bilingual labels, explicit visibility, footer independence and legacy-key precedence. The 38 one-page PDF samples and six thermal previews were regenerated and inspected, and the running app hot-reloaded successfully.
