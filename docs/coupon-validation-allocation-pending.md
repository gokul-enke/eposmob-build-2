# Pending coupon validation, allocation, VAT and returns

Updated: 10 October 2026.

This handoff describes the remaining work found in the pulled backend at commit `9a3bb33b` and the current Flutter app. It is a source review, not confirmation of a deployed API. The changes below are proposed and have not been implemented by creating this document.

For these pending areas, use this document instead of the older handoff's statement that all backend work was implemented locally. Those earlier local backend changes were removed before pulling the developer's changes. The current checkout does not contain the proposed coupon quote/reservation workflow.

| Pending area | Owner |
| --- | --- |
| Authoritative coupon validation, redemption and usage limits | Backend, with app integration for validation before finalizing a local sale |
| Eligible-item allocation, VAT and exact returns | Backend and app together |

Thermal heading wrapping and the additional A4 signature page are outside this handoff. The existing cart Discount display and receipt Discount column can be reused; no additional fields under the product name are requested.

## 1. Issue

### A. Coupon validation, redemption and usage limits

Some validation already exists. `OrderHelper::discountPrice()` checks tenant, store, validity dates, product/category targeting, category descendants, minimum/maximum order amount, discount cap and logged usage. It excludes qualifying lines already using an active product/category offer. The app also checks downloaded eligibility rules and optional usage counters locally.

The remaining gaps are:

1. **Completed-sale uploads bypass that coupon validation.** In `OrderController`, the `pricing_mode=completed_sale` branch accepts `discount_amount` directly and leaves the coupon result empty. Consequently, this path does not run the normal coupon redemption logging or persist the resolved coupon identity through that result. Sending `coupon_id` and `coupon_code` from the app does not by itself close this gap.
2. **Usage enforcement is not atomic.** The legacy helper counts usage before the later log write. Two sales can both pass when only one use remains. A duplicate-safe log write alone does not protect the global limit against concurrent different sales.
3. **The coupon list does not currently add authoritative `usage_count` / `remaining_uses`.** The app understands these optional fields, but cached counts would still be advisory because another till can redeem a coupon immediately afterwards.
4. **The completed-sale snapshot comparison does not bind coupon identity and allocations.** Coupon identity needs to participate in replay/conflict detection, alongside the existing sale identity and frozen monetary snapshot.
5. **The existing apply-coupon API is not a complete local-cart checkout quote.** It accepts a server cart or a single product/price. The app can have multiple products, sale units and stock/batch splits without a server cart. A preview is also not a redemption or a guaranteed remaining use.
6. **Historical/offline validation needs an explicit policy.** The legacy helper uses today's tenant date and currently active offers. An uploaded sale issued earlier must not be silently recalculated using today's coupon or offer rules.

Relevant backend files: `enkepos/app/Http/Controllers/Api/V1/OrderController.php`, `enkepos/app/Http/Controllers/Api/V1/DiscountController.php`, `enkepos/app/Helper/OrderHelper.php`, `enkepos/app/Services/CompletedSalePricing.php`, and `enkepos/app/Models/DiscountCouponUseLog.php`.

### B. Eligible-item allocation, VAT and returns

**Calculating the correct total coupon amount does not guarantee correct allocation.** The app's coupon evaluator identifies eligible items, but returns only a scalar discount. The app's `CartDiscountBreakdown` and backend's `TaxDiscountHelper` then distribute an order discount across all lines.

A product/category coupon can therefore reduce an ineligible or already offered line. The overall payable may remain correct, while VAT by rate and refunds for individual products are incorrect.

Example: two tax-inclusive lines, quantity one each, with a fixed coupon of 20 that applies only to A:

| Line | Before coupon | Tax rate | Eligible | Correct coupon allocation | Correct final amount | Correct tax |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| A | 100.00 | 15% | Yes | 20.00 | 80.00 | 10.43 |
| B | 100.00 | 5% | No | 0.00 | 100.00 | 4.76 |
| Total | 200.00 | | | 20.00 | 180.00 | 15.19 |

Spreading 10.00 onto each line also produces a payable of 180.00, but produces tax of 16.03. Returning B should reverse 100.00; a whole-order proportional refund would instead deduct 10.00 and produce 90.00. Returning A should reverse 80.00.

The backend's `buildReturnRefundBreakdown()` currently calculates a proportional share of the whole order discount. `CreditNoteService` also calculates an order-level proportional discount for its GST breakdown. The app has the same proportional fallback.

The app already parses `refund_breakdown`, but its adapter reconstructs the refund from gross amount, discount and the screen's delivery selection. It does not directly use the server's `net_refund`, `maximum_cash_refund` or `refund_available` as the authoritative result. Fixing only the API response will therefore leave app work outstanding.

Relevant files: `enkepos/app/Helper/TaxDiscountHelper.php`, `enkepos/app/Helper/OrderHelper.php`, `enkepos/app/Http/Controllers/Api/V1/OrderController.php`, `enkepos/app/Services/CreditNoteService.php`, `lib/features/billing/domain/cart_discount_breakdown.dart`, and `lib/features/sales_returns/domain/models/sales_return_refund_breakdown.dart`.

## 2. Solution

### A. Validate before finalizing; redeem once

Use one server coupon service for eligibility, calculation and redemption across the relevant checkout paths. For an online local-cart sale, resolve and validate the full cart before the app irreversibly saves/prints the completed sale.

If a strict global usage limit must be guaranteed between validation and finalization, claim/reserve capacity atomically before finalization. A quote without a capacity claim cannot guarantee the last remaining use. A separate quote/reserve/release API is one possible design; those endpoints are **not present in the reviewed backend**, and their names and contract must be agreed before integration.

Bind the validated result to tenant, store, sale/device identity, coupon, cart contents, rule version and expiry. Revalidate after a material cart change. Commit one redemption with the successful sale in a transaction; release unused reservations on cancellation/expiry. Previewing, opening checkout or an unsuccessful transaction must not consume a redemption.

For offline sales, choose a policy explicitly: approved offline capacity, or accepting a frozen sale with a clearly recorded reconciliation/review outcome. Alternatively, disable limited coupons offline before the sale is finalized. Arbitrary offline coupon acceptance cannot guarantee a strict global cap. Do not silently alter an already printed sale or make all old queued sales depend on a new token they never had.

### B. Freeze an eligible-line allocation and reverse it on returns

Build a deterministic allocation over eligible submitted lines only. Use integer minor units for monetary allocation, keep ineligible allocations at zero, cap each allocation at its line amount, and assign rounding remainder deterministically within the eligible set. Both app and backend must use the same algorithm and submitted-line ordering/identity.

For tax-inclusive lines, calculate the taxable value from the final discounted amount, then calculate tax as final amount minus taxable value. Freeze the coupon identity, eligibility result, allocation and final tax amounts on the sale. Receipt endpoints, local reprints, server reprints and returns must read that snapshot rather than reconstructing eligibility from today's catalog.

Keep these meanings distinct:

| Field | Meaning |
| --- | --- |
| `standard_unit_price` | Frozen selling rate before the item offer/manual price reduction, in the sale unit |
| `unit_price` | Selling rate after the item reduction, before the order/coupon discount |
| `total_price` | Tax-inclusive line amount before the order/coupon discount |
| `item_discount_amount` | Item reduction already reflected in the selling amount; do not subtract it again |
| `line_discount` | Allocated order/coupon discount for this line |
| `discounted_total` | `total_price - line_discount` |
| `discounted_base_amount` / `discounted_tax_amount` | Taxable value and tax corresponding to that final amount; retain these existing receipt field names |

The displayed line discount can combine the item saving and allocated order saving. The order-discount footer must total only order/coupon allocations. It must not include the item saving again.

For a partial return, reverse the returned quantity's original frozen net amount, discount and tax. Track cumulative refunded quantities and minor-unit amounts so repeated partial returns cannot over-refund and the last return resolves the remaining rounding cents exactly. Keep delivery refunds and available cash/customer credit rules separate and explicit.

## 3. Backend changes needed

### A. Coupon validation and accounting

1. Route legacy and completed-sale coupon handling through the shared service. Validate tenant ownership of coupon and referenced products/stock, store, configured discount availability, dates, targeting, offer exclusion, amount thresholds, supported discount type/value, caps and remaining capacity. Preserve product targeting precedence and category descendant behavior already implemented.
2. Preserve numeric `coupon_id` plus separate `coupon_code`, and the existing normalization of legacy requests containing a coupon code in `coupon_id`. Reject conflicting supplied identities. Define whether thresholds use whole-cart or eligible subtotal; current app/helper thresholds use the whole cart. Do not change that meaning in only one layer.
3. Enforce usage capacity inside a database transaction with appropriate locking and database uniqueness for the redemption identity. Integrate with the existing completed-sale identity using tenant, device and `client_sale_id`; retries must not create another order or redemption. Keep validation, capacity consumption and successful order persistence consistent. Rollback a failed sale without consuming usage.
4. Persist coupon identity, applied amount, pricing/rule version and allocation fingerprint. Include them in completed-sale replay comparison. An exact replay returns the original result; a changed coupon or monetary snapshot under the same sale identity produces a conflict through the agreed client contract.
5. Add authoritative optional integer `usage_count` and `remaining_uses` to the coupon-list response. Use `remaining_uses: null` for an unlimited coupon in the new additive field, and zero only when exhausted. Preserve legacy limit field types and semantics. If reservations are introduced, distinguish committed usage from reserved capacity and make availability account for both.
6. Provide validation for a complete local-cart payload, including stable submitted-line identifiers, product/stock identity, sale unit, quantity, frozen selling values and issue time. Derive trusted eligibility on the server; do not trust an app-supplied eligibility flag. If a reservation flow is added, document request/response fields, expiry, cancellation, replay and error codes.
7. Define historical issue-time validation and offline reconciliation. Preserve the receipt snapshot when a completed sale is accepted for review. Expose a clear review outcome; do not silently treat a reviewed/exhausted coupon as a normal successful redemption.
8. Define redemption treatment for cancellation, full/partial returns and customer changes. Do not automatically restore coupon capacity on a return unless that policy is explicitly intended. The currently inspected usage limit is a coupon-wide count; implement per-customer limits only if the business requires them, with separate counters and tests.

Existing routes to preserve: `/api/v1/discount/list-discounts`, `/api/v1/discount/apply-coupon`, and `/api/v1/order/add-to-order`. Add new contracts alongside them or capability-gate them. Preserve existing response envelopes and status handling for old clients.

### B. Allocation, VAT and return responses

1. Extend the shared pricing result with stable line identities and source-specific allocations. A product ID alone is insufficient when the same product has multiple units, prices or batches. A proposed `client_line_id` must identify each submitted split and map to the persisted cart/order line.
2. Teach `TaxDiscountHelper` and completed-sale pricing to consume the agreed allocation plan. Keep whole-cart allocation for manual order discounts where that is the existing policy; use eligible-only allocation for targeted coupons. If stacking is permitted, record each source and its application order. Do not merge all discounts into an ambiguous scalar.
3. Persist each line's pre-order-discount amount, coupon/order allocation, final net amount, taxable value and tax. Validate line sums against order discount, VAT and payable. Store an allocation version so historical sales retain their original calculation.
4. Return the same frozen values through order details, print details and relevant restaurant/sales endpoints. Preserve the receipt field meanings above and all existing aliases. Do not recompute older printed sales under the new policy; retain their historical amounts and mark any reconciliation separately.
5. Replace whole-order proportional refund calculation for versioned eligible allocations with the selected original sale lines and quantities. Apply the same result to return creation, completion, payment limits, tax breakdown and credit-note printing. Preserve existing delivery, outstanding-balance and customer-credit rules.
6. Return exact session/cumulative amounts and line identity in `refund_breakdown` or an additive return-line structure. Keep the existing `pro_rata_discount` key for compatibility, documenting it as the returned discount amount for the new version even when obtained from exact allocation. Keep `net_refund`, `maximum_cash_refund` and `refund_available` consistent with the actual completion/payment checks.
7. Lock/validate remaining return quantities and refundable amounts. Make repeated completion/retry safe; repeated partial returns must never exceed the original sold quantity, net amount or tax.

Any new quote token, allocation version, `client_line_id`, per-source allocations or review status fields are **proposed contract additions**, not claims about today's API. Agree one sample request/response with the app developer before implementing mandatory enforcement.

## 4. App changes needed

### A. Authoritative checkout integration

Already available: local coupon eligibility/preview, separate outgoing coupon identity/code, and parsing/checking optional usage counters. These are useful for immediate feedback; they do not reserve capacity or guarantee server redemption.

1. Integrate the agreed full-cart validation/claim API before finalizing online coupon sales. Use the same checkout flow for desktop billing, mobile billing and restaurant billing. Show the returned eligibility/limit error and refreshed availability before saving/printing.
2. Invalidate a quote/claim when products, quantities, unit, batch, price, store, offer or coupon changes. Persist and submit the accepted token/version and frozen coupon identity with the sale; handle reservation expiry/release according to the agreed protocol.
3. Implement the chosen offline policy and retain it in the saved sale. Refresh coupon counts after sync/reconnection, but do not treat cached counts as an authoritative capacity lock.
4. Handle server review/conflict/rejection explicitly. The current completed-sale success can include `review: true`; a success response alone must not imply an ordinary coupon redemption. Keep the frozen receipt, prevent duplicate submission/redemption, and expose a pending review outcome where required.

Main touchpoints: `lib/features/billing/domain/coupon_calculation.dart`, `lib/features/billing/controllers/coupon_context.dart`, `lib/providers/local_product_provider.dart`, shared checkout/order submission and saved/offline sale storage.

### B. Allocation, VAT, printing and returns

1. Extend `CouponCalculation` to return eligible submitted-line allocations, not only the total amount. Extend `CartDiscountBreakdown` to accept a source/allocation plan. Keep the existing manual-discount and legacy-snapshot paths where appropriate.
2. Use that result consistently for cart totals, VAT, checkout preview, saving, offline upload and local receipt creation. Preserve stable IDs through reversed submission ordering and batch/unit splits, then group split amounts back to cart rows for display.
3. Persist final line amounts, tax and allocation version in saved orders, including the necessary storage migration/defaults for existing records. Local reprints must use the saved snapshot. Update server receipt adapters to consume the same authoritative fields.
4. Reuse the existing cart discount rows and A4/thermal Discount column. Continue showing the original selling rate and the discount separately. Keep these display changes confined to the requested discount presentation.
5. For returns, parse/use the server's exact line allocation, net refund, maximum cash refund and availability. The current `SalesReturnRefundBreakdown.toRefundSummary()` reconstructs net/max cash locally; replace that behavior for the new contract. When delivery selection changes, request a corresponding server result or use an explicitly agreed exact calculation.
6. Update local return fallback, quantity-copy paths and return-print adapters to reverse the frozen sale allocation. Where an older sale lacks exact allocations, retain its documented historical fallback rather than claiming eligible-only precision.

Main touchpoints: `lib/features/billing/domain/cart_discount_breakdown.dart`, `lib/providers/local_product_provider.dart`, `lib/services/print_service.dart`, `lib/features/sales_returns/domain/sales_return_calculation_helper.dart`, `lib/features/sales_returns/domain/models/sales_return_refund_breakdown.dart`, `lib/features/sales_returns/data/sales_return_api.dart`, and `lib/features/sales_returns/presentation/printing/sales_return_print_items.dart`.

## 5. Verification required before calling this complete

- Coupon identity: numeric ID/code, legacy code in ID, mismatched identity, wrong tenant/store, expired/future coupon, disabled discounts and unsupported type/value.
- Eligibility: selected product, parent/child category, excluded active offers, minimum/maximum thresholds, fixed/percentage caps, no eligible items and cart changes after validation.
- Redemption: two tills competing for the last use, exact retry, changed-payload retry, failed sale rollback, reservation expiry/cancellation and counter refresh. Exactly one valid final-slot redemption must win.
- Offline: stale/exhausted cached coupon, sale uploaded after expiry, old pending payload without new fields and the agreed review/allowance behavior. No silent alteration of a printed sale.
- Allocation: the mixed-tax example above, fractional quantity, different sale units, duplicate products/batches, zero-rated items, 100% coupon and cent remainders. Allocation sums and taxable value plus tax must equal frozen totals.
- Returns: eligible versus ineligible items, repeated partial returns, final rounding remainder, already-returned quantity, completion retries, delivery selection, outstanding balances and cash/customer-credit limits.
- Presentation: desktop/mobile/restaurant totals, first A4/thermal print, saved local reprint, server sales-page reprint and return print must agree on rate, discount, net and tax.
- Compatibility: replay captured requests from actual supported older app releases, including queued offline sales. Additive fields alone do not prove every old release works with new mandatory workflow rules.

## 6. Rollout and acceptance

Backend can first add optional counters, a versioned validation contract and snapshot storage while keeping legacy behavior available. Release the app integration and matching allocation algorithm before requiring new tokens or allocation fields. Enable the coordinated behavior through a version/capability gate; preserve old response types, aliases and envelopes.

Before implementation, agree the threshold basis, offer/manual-discount stacking, offline capacity policy, redemption reversal policy and delivery refund policy. These are business choices; neither layer should invent a different rule.

The backend developer should provide the final API contract/sample payloads and concurrency/return test results. The app developer must then integrate and verify the shared calculation and checkout flow. **Backend completion alone does not finish eligible-item allocation, local VAT, local printing or return integration.**
