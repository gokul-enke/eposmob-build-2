> Update, 10 October 2026: backend changes are implemented locally; see [the implementation notes](backend-coupon-offer-implementation.md) and [current handoff](backend-coupon-offer-handoff.md). Deployment and version 2 app integration remain pending.

# Backend offer and coupon changes

For the current developer handoff, send [backend-coupon-offer-handoff.md](backend-coupon-offer-handoff.md). The document below retains the earlier audit and verification history; the handoff supersedes its rollout guidance.

Reviewed on 10 October 2026. Backend source: `enkepos`. No backend code or admin settings were changed.

The app can now print manual price reductions and product offers from the saved original price, and display the API's separate order-discount allocation. The complete coupon workflow is **not yet consistently enforced**. The backend work below is needed before claiming that coupon eligibility, accounting, offline sales and reprints are all correct.

The app is also ready for the extended offer/source response and configurable discount labels described in [the implemented receipt API contract](receipt-discount-api-contract.md). Its two JSON examples define the exact additive response shape for the backend developer. Backend deployment is still required to return these new fields for server orders.

## Discount meanings and receipt calculation

| Value | Meaning | Calculation |
| --- | --- | --- |
| Original rate | Selling rate saved before an offer or cashier edit, in the line's sale unit | `standard_unit_price` |
| Item discount | Price reduction already included in the selling rate | `max(round(original rate × quantity) − total_price, 0)` |
| Line total | Selling amount before the order discount, including tax | `total_price` |
| Order discount share | Allocated coupon/manual order discount | `line_discount` |
| Amount after order discount | Discounted inclusive amount | `discounted_total` |
| Payable | Final bill amount | `sum(total_price) − order_discount + delivery_charge + round_off` |

Do not add item discounts to `discount_amount`: their reduced rates already reduce `total_price`. Do not use MRP as the original selling rate. MRP savings can differ from the actual offer or cashier discount. A price increase is not a negative discount.

Example, with tax-inclusive prices: original rate 100, edited rate 80, quantity 2. Item discount is 40 and the line total is 160. An additional order discount of 16 makes the item amount 144. At 15% VAT the discounted base is 125.22 and VAT is 18.78. A delivery charge of 5 makes payable 149. The receipt displays both discounts, but deducts only 16 in its order totals.

The app prints one separate numeric Discount column, controlled by the current API's `showDiscountColumn` (legacy `showItemDiscount` is supported). Each cell combines the saved item price reduction and its allocated order/coupon share. No discount details are appended to the product name. Rate shows the original unit price and Total shows the final discounted line amount; the footer deducts only the order discount from its subtotal after item reductions. The column is independent of Particulars and the footer Discount switch. No other new display keys are required.

For discounted bills the footer subtotal adds back the order discount to the payable excluding final VAT, so `subtotal - order discount + VAT = payable`. Delivery and round-off currently remain included in that subtotal because the print contract has no separate rows for them. For the example above this is `146.22 - 16 + 18.78 = 149`.

## What is already supported

- `LocalProductProvider.updateItemPrice` keeps the original reference, marks a manual override, and clears the automatic offer. Manual overrides survive quantity changes and Hive storage. Changing an offered item manually therefore prints its total reduction against the original standard price; there is no separate audit of the superseded offer versus the manual portion.
- The app's offer engine resolves product/category rules, store scope, dates, batch scope, base-unit eligibility and wholesale precedence. Only one offer wins. Wholesale is treated as its effective standard selling price, rather than falsely reporting a retail discount.
- `OrderController` returns `standard_unit_price`, `line_discount`, `discounted_total`, `discounted_base_amount` and `discounted_tax_amount` in order details. The app previously discarded these; it now preserves them through model serialization and partial-line copies.
- Local prints now use the saved original reference to compute item reductions and use batch-split rounding. Pack/case lines print quantity and original/current rates in the same sale unit.
- Local cart VAT, VAT breakdown and receipt VAT now use the post-order-discount amount. They mirror the backend's current proportional allocation in submission order. This fixes the previous inflated VAT on local discounted receipts.
- New desktop and mobile completed-sale payloads carry the final payable, round-off and discounted tax snapshots using fields already accepted by the backend. They retain `discount_amount` as the order discount only.
- Discount Categories are organizational labels for coupons. They do not apply discounts by themselves and are different from product categories.

## Required backend and API work

### 1. Provide one coupon quote API for the actual local cart

`DiscountController.applyCoupon` currently accepts a server `cart_id`, or a single `product_id` plus `price`. A local POS cart can contain multiple products, variants, sale units and batches. `CartProvider.applyCoupon` sends only price/code/store, so it fails the current required `product_id`/`cart_id` contract if invoked.

The desktop modal, mobile controller and restaurant checkout calculate from downloaded coupon definitions. The app now checks store, dates, order minimum/maximum, product/category descendants, offer exclusion and the per-order cap. It recalculates when the cart changes, blocks confirmation if an applied rule becomes invalid, and saves the rule with held orders while freezing confirmed receipt amounts. Usage is checked when `usage_count` or `remaining_uses` is returned; the current list endpoint supplies neither. Passing coupon identity alongside locally calculated amounts still does not prove server validation.

Checkout now sends the selected numeric `coupon_id` and a separate `coupon_code`. Legacy code-only paths send `coupon_code`, rather than putting a code in the integer field. Percentage fields carry the rate, while `discount_amount` carries money. The coupon amount is represented locally as a fixed calculated amount plus its retained rule, so a capped/targeted percentage does not become a blanket cart percentage.

Add a non-mutating quote endpoint accepting:

```json
{
  "store_id": 2,
  "coupon_code": "SAVE10",
  "issued_at": "2026-10-09T10:00:00Z",
  "items": [
    {
      "client_line_id": "cart-row-1",
      "product_id": 123,
      "stock_id": 456,
      "product_variant_id": null,
      "product_sale_unit_id": null,
      "quantity": 2,
      "unit_price": "80.000",
      "standard_unit_price": "100.000",
      "offer_id": null,
      "offer_version": null,
      "total_price": "160.00"
    }
  ]
}
```

Validate tenant/store ownership, coupon enablement, store/product/category descendants, dates in the tenant timezone, usage limits, order thresholds, discount cap and stacking policy. Return the applied coupon code/ID, eligible subtotal, exact discount amount, payable, VAT and a per-line breakdown linked by `client_line_id`. Also return a quote token/version and explicit invalidation conditions.

After this API exists, wire both `CouponModal` and `BillingMobileCouponController` to its result. Requote when item price, quantity, batch, sale unit, product, store, offer validity or coupon selection changes. Do not leave a capped/targeted coupon as a blanket percentage on a later cart.

### 2. Separate coupon calculation from allocation

`OrderHelper.discountPrice` calculates a coupon using eligible products/categories and excludes lines at an active promotion price. However, `TaxDiscountHelper.calculateDiscountedCartTotals` then allocates the resulting discount across **all** cart lines. Thus an ineligible/promoted line can receive a printed share and a tax reduction.

Allocate targeted coupon discounts only to their eligible lines. Allocate a manual order discount across lines according to a separately documented policy. If manual discounts can stack on offers, state that explicitly. Coupon stacking on manual item reductions also needs an explicit decision; currently manual reductions are not generally excluded.

Persist the resulting line allocations at sale time. Use them for invoice details, reprints, tax reports, returns and credit notes. Returning the same stored allocations prevents rounding or eligibility changes when offers expire or products move categories. Use deterministic cent allocation that never makes a line share negative or greater than its line total, including tiny/zero-price lines.

### 3. Validate and account for coupons on completed sales

In `OrderController.addToOrder`, the `pricing_mode == completed_sale` branch trusts submitted `discount_amount` and skips `handleCouponDiscount`. As a result, a coupon code on a locally printed sale does not go through the normal authoritative coupon path or its associated usage accounting. An expired, over-cap or exhausted coupon can be represented only as an arbitrary order discount.

Keep the existing guarantee that a printed offline sale is not silently repriced. Add explicit coupon snapshot fields: validated coupon identity/version, quote token, eligible line IDs, discount sources and allocations. For online sales, validate/reserve coupon usage atomically before confirmation. For offline sales, define a policy: cached authorized allowance or a review status when limits/validity cannot be established. Record coupon use once per `client_sale_id`; idempotent replay must not consume it twice. Report mismatches as review reasons while retaining the printed receipt snapshot.

### 4. Preserve historical pricing and units in every response

Return the same pricing contract for draft, confirmed, restaurant, offline-sync and detail/reprint endpoints:

```json
{
  "standard_unit_price": "100.000",
  "unit_price": "80.000",
  "quantity": "2.000",
  "item_discount_amount": "40.00",
  "line_discount": "16.00",
  "discounted_total": "144.00",
  "tax_rate": "15.000",
  "discounted_base_amount": "125.22",
  "discounted_tax_amount": "18.78",
  "discount_origin": "manual",
  "offer_id": null,
  "offer_version": null,
  "offer_name": null,
  "offer_discount_type": null,
  "offer_discount_value": null,
  "coupon_code": "SAVE10"
}
```

`line_discount` must mean order-discount allocation only; `item_discount_amount` must mean the price reduction already reflected in `unit_price`. Original rate, current rate and quantity must use the same sale unit. Retain immutable original rate for manually priced drafts as well as completed-sale snapshots. If separate offer/manual portions are required, store them explicitly; the current net reduction cannot reconstruct that history.

The live executive order-details response was checked directly. It does not expose `offer_id`, `offer_version`, `discount_origin`, `offer_name` or offer-rule details. The backend CartItem model already supports the first three in pricing metadata, but the controller's detail projection omits them. Expose the stored values and add immutable offer-name/type/value snapshots. Do not resolve historical receipts against the current offer record: its label, rule or validity may have changed. These fields are optional source/audit metadata. Printing the requested numeric Discount column requires only the saved item reduction (or original rate) and canonical line_discount; source names/rules are not displayed.

Always return `tax_rate`, including 100% discounted lines. Current detail mappings return adjusted tax/base amounts but omit this rate. Rounded discounted base/tax cannot reliably reconstruct the original gross Rate Ex Tax, especially after a large discount or a 100% discount. The app now uses `tax_rate` when supplied and prints `-` for an affected historical line when it is missing, rather than guessing an inaccurate rate. VAT amounts and discount shares can still print from the response.

For old orders without a historical original reference, omit it. The app deliberately prints no invented item discount from today's catalogue or MRP. Backfill only from reliable sale-time records.

### 5. Align completed-sale offer review with the current offer engine

The app's current offer resolver intentionally does not impose minimum-margin floors on offer prices. `CompletedSalePricing.line` still applies historical minimum-margin floors when comparing an offer price. Its historical matching also searches product lines directly, while the POS feed includes category-derived rules. These can create false `price_mismatch`/`offer_scope_mismatch` review flags for a correctly applied offer.

Use the same product/category precedence, store/batch scope, base-unit/wholesale exclusions, time boundaries and floor policy in both the feed and historical snapshot validator. Version category-derived eligibility sufficiently to validate the sale-time rule after category changes.

### 6. Make order totals and savings unambiguous

Return `items_total_before_order_discount`, `item_discount_total`, `order_discount_total`, `delivery_charge`, `delivery_tax_amount`, `round_off`, `grand_total`, `tax_total` and `net_exc_tax`. Avoid overloading `total_saved` with MRP savings, coupon discount, shipping or return values. MRP total should be independent of delivery and round-off.

The app now sends grand total, round-off and tax for new desktop/mobile completed sales. Confirm that sync and response mappings preserve those fields. Keep restaurant draft pricing server-authoritative: those submissions do not use completed-sale snapshot fields. Restaurant completion, returns and partial reprints should consume stored allocations rather than recomputing offers/coupons from today's catalogue.

### 7. Complete discount controls and language handling in document configuration

Fresh read-only requests to the running app's configured API, `https://erpdemo.cloudposai.com`, succeeded:

- `GET /api/v1/document/document-configs?store_id=2` returns 23 document types. Relevant Bill, Bill A4, Sales and Return Bill and Sales and Return Bill A4 records contain `display_configuration`, `resolved_labels`, `theme` and `language: en_ar`. The app accepts the live `{visible, value, default}` option structure and maps `theme` to its `activeTheme` model field.
- The latest supplied Bill A4 response contains `showDiscountColumn: {"visible": true, "value": null}`. This explicitly enables the table column and uses its built-in Arabic title الخصم for the supplied bilingual mode. Supply Arabic `value` and English `default` to print both languages. `showDiscount` controls the footer independently. Hiding Particulars does not hide Discount.
- The app consumes the `showDiscountColumn` label/visibility option across A4/A5 and thermal layouts. It also supports legacy `showItemDiscount`; the current key takes precedence if both exist. When both are absent, the app shows the column only when a row is discounted. Bilingual translated headers print both languages when the API supplies Arabic `value` and English `default`.
- Keep the single `showDiscountColumn` option in the backend configuration and admin editing UI, as in [the contract example](api/receipt-discount-document-config.example.json). To customize its table title, populate its `value` / `default`; changing `showDiscount.value` changes the footer title instead. No additional table display keys are required.

The language parameter has a backend bug. Both `GET /api/v1/document/document-configs?store_id=2&type=bill&language=en` and the same request with `language=ar` returned Bill with `language: en_ar`. In `DocumentPrintConfigurationController.getAllConfigurations`, `$q->where('is_active', true) ?? $q->where('language', $lang)` never executes the language filter, because the first `where` returns a query builder. Honor explicitly requested languages with a documented fallback. Keep no-language requests compatible with the configured active language.

The separate `GET /api/v1/document/printer-settings` response is valid. It supplies B2C `A4` / `bilingual_centered_tax_invoice` and B2B `A5` / `boxed_header_tax_invoice`; all four values exist in its returned options. These match the running app's stored preferences. PrintPage prefers the stored printer theme over the document record's theme, so Bill A4's `boxed_header_tax_invoice` document theme does not override the current B2C bilingual theme. This is the existing selection precedence, not a parsing failure. If the admin document theme should take priority instead, agree that behavior and change the app's precedence explicitly.

## Remaining app work that depends on the backend contract

- Replace local coupon-value application with the authoritative quote, including caps, eligibility, usage and a visible rejection reason.
- Persist coupon quote and allocation snapshots in Hive and the sync outbox; support the agreed offline coupon policy.
- Restore original rate and discount source when editing server drafts rather than inferring history from the current catalogue.
- Use stored discounted line amounts for partial returns and sales-only reprints. Quantity scaling alone is insufficient for deterministic penny allocation across multiple returns.

Completed app preparation: order-details parsing/serialization preserves the extended source snapshots; local offer name/rule snapshots survive Hive storage; all receipt layouts use the same numeric Discount column. Configuration needs only showDiscountColumn; source metadata remains optional for accounting/audit. Older responses retain amount-only printing. The coupon quote/reservation workflow above remains separate work.

## Verification and deployment boundary

The source audit covered billing pages, checkout, local provider/Hive snapshots, coupon selection, order payloads, order-detail models and production receipt layouts. Marionette connected to the supplied VM service and hot reload succeeded. Existing order `ORD-004730` was inspected and reprinted using its existing Open PDF output; no sale, payment or backend setting was created or changed. Its order shares were 2.73, 3.64, 10.91 and 2.72, adding to the order discount of 20. Its footer reconciled as `21.76 - 20 + 0.24 = 2`.

A fresh read-only `GET /api/v1/order/executive/order-details/ORD-004730` confirmed the deployed pricing fields. Its four standard rates equal its selling rates: 3, 4, 12 and 3, each with quantity 1. Thus this response indicates no item-level reduction, and only its separate order discount can be printed. If a cashier/offer had previously reduced these prices, this record does not retain evidence of that earlier price. Every line includes the discounted total/base/tax and order allocation, but omits explicit `tax_rate` and the offer/source fields listed above. This one order verifies order-discount printing; it does not verify a deployed automatic-offer example.

Regression checks: 141 existing offer, model, receipt, tax, coupon and checkout tests passed. Ten new tests cover manual/offer reductions, missing references, price increases, free lines, sale units, split-batch rounding, saved receipt order, mixed VAT, penny allocation, API serialization, partial copies, completed-sale snapshots and unknown historical ex-tax rates. Generated and visually checked 36 A4/A5 PDFs (six themes, three language modes) and six actual 58mm/80mm thermal images saved through the Development Printer. Static analysis reported no errors; existing warnings/info remain. The test fake uses the already installed path-provider interface as a direct dev dependency; its version was not upgraded.

The follow-up configuration checks passed 31 document-refresh, document-resolver and receipt-configuration tests, plus two printer-settings tests. The live API responses were inspected using only selected pricing/configuration fields in tool output; credentials and customer/payment data were not included.

After implementing the future receipt contract in the app, 142 regression tests passed. The ten discount tests additionally generated 36 future-response PDFs and six thermal images; a final 43-test receipt/contract/configuration run passed after the A5 footer adjustment. The supplied VM hot-reloaded and the existing order reprint succeeded with no new runtime exceptions. These checks validate the app's expected contract and its legacy fallback, not the pending backend deployment or coupon eligibility/accounting.

The CLOUDPOSDEMO Product Offers, Discount Coupons and Discount Categories tabs were discovered, but page reads failed on the browser connector's focus/CDP timeout (an earlier attempt also failed to load its request-header policy). Their actual configured records remain unverified. Direct API verification used the running app's configured `erpdemo.cloudposai.com` host, rather than assuming the browser's `eposdemo.yougoit.in` records are the same tenant. Other order endpoints and a real deployed offered-item response remain unverified. No backend test suite was executed.

Before release, check an actual API response and original/reprinted receipt for: manual reduction, automatic product/category offer, mixed eligible/ineligible coupon cart, cap, exhausted/expired coupon, offer plus manual order discount, wholesale, sale units, split batches, 100% discount, delivery, round-off, offline sync, restaurant completion and partial returns. Verify totals and VAT against stored sale-time allocations. Do not claim the complete coupon setup is correct until the backend items above are implemented and those scenarios pass.

Display correction on 10 October: discount notes were removed from product-name cells and replaced by one numeric Discount column for A4/A5 and thermal output. The response example now contains only the current showDiscountColumn switch; the previously proposed extra display switches are unnecessary.
