# Backend handoff: coupons, offers and receipt discounts

Updated: 10 October 2026. This is the current document to send to the backend developer. It is self-contained. Backend implementation and deployment remain pending; the app and printing changes are already in the working tree.

## 1. Compatibility and rollout boundary

Adding the fields below is compatible with the current app **when existing endpoints, JSON envelopes, field names, types and monetary meanings remain available**. Missing optional receipt metadata still has a legacy fallback. This is not a guarantee for arbitrary response or workflow changes.

| Backend change | Current app support | Rollout requirement |
| --- | --- | --- |
| Add historical original rate, tax rate and item-discount metadata to existing receipt lines | Already parsed by the receipt models and A4/A5/thermal adapters | Add fields; preserve existing line fields and totals |
| Return `showDiscountColumn` visibility and translated table title | Already supported; legacy `showItemDiscount` remains supported | Keep `showDiscount` as the independent footer option |
| Fix explicit document-language selection | App understands `en`, `ar`, `en_ar` | Keep no-language requests on the configured active mode |
| Return a complete, paginated offer catalog | Every refresh already requests a full catalog without `since` | Return every eligible rule across all pages |
| Add coupon `usage_count` and `remaining_uses` | Already parsed and checked when present | Counts must be authoritative; offline cached counts can become stale |
| Correct historical offer review to match the POS rule engine | No new app request fields needed | Keep frozen printed prices; correct false review reasons |
| Add an authoritative local-cart coupon quote endpoint | Current checkout does **not** call this proposed endpoint | Endpoint can be added independently; app integration must precede requiring its token |
| Allocate targeted coupons only to eligible lines | Server receipt allocations are readable; local receipts currently allocate order discounts proportionally across all submitted lines | Coordinate the app's local calculation, VAT, submission and printing changes |
| Require coupon reservation, quote tokens or a new offline coupon policy | Not implemented in the current app | Version/feature-gate enforcement and release the app integration first |
| Return exact allocations for repeated partial returns | Receipt fields are readable; the legacy quantity-copy path still scales amounts | Integrate and test the return workflow before changing its assumptions |

Do not remove old fields, replace existing envelopes, make new snapshot/quote fields mandatory for current clients, or silently reprice an already printed completed sale. New total aliases must supplement the existing `price_summary` fields rather than replace them.

## 2. Preserve these discount meanings

All line rates and quantities must use the same sale unit. Prices below are tax-inclusive.

| Field | Required meaning |
| --- | --- |
| `standard_unit_price` | Frozen selling rate before the current offer/manual price override; never MRP or today's catalog rate |
| `unit_price` | Selling unit rate after the item offer/manual reduction, before the order/coupon discount |
| `total_price` | Rounded selling line amount before the order discount, including tax |
| `item_discount_amount` | Total item price reduction already reflected in `total_price`; exclude order/coupon allocations |
| `line_discount` | This line's allocated order/coupon discount only |
| `discounted_total` | `total_price - line_discount` |
| `tax_rate` | Saved percentage for this line, including free or fully discounted lines |
| `discounted_base_amount`, `discounted_tax_amount` | Saved post-order-discount base and VAT; their sum equals `discounted_total` |
| `tax_amount` in receipt details | Must agree with the final discounted VAT |
| Submitted `discount_amount` | Whole-order/coupon discount only; item reductions are already included in selling prices |

The printed table shows original Rate, one numeric Discount column, and final Total. The Discount cell is `item_discount_amount + line_discount`. For a consistent snapshot, `Rate × Qty - Discount = Total`, subject to stored batch rounding. No discount notes, offer rules or source breakdowns are appended to product names.

Example: original rate 100, selling rate 80, quantity 2, item discount 40, `total_price` 160, order share 16, final amount 144. At 15% VAT the stored base is 125.22 and VAT is 18.78. Do not deduct the item discount a second time in order totals.

## 3. Order-detail, sync and reprint responses

Extend `GET /api/v1/order/executive/order-details/{order_id}` and equivalent draft, restaurant, saved-order/sync and reprint responses. Keep the existing `data.cart.cart_items[]` structure and all existing identity, product, customer and payment fields. Add pricing fields directly to each line; do not move them into a new nested object.

Required for reliable original-rate/discount printing: retain `standard_unit_price`, `unit_price`, `quantity`, `total_price`, `line_discount`, `discounted_total`, discounted base/VAT, and add `tax_rate` wherever it is currently missing. `item_discount_amount` is recommended to preserve exact item reductions, especially for aggregated batch lines. If absent, the app infers that portion only from a reliable saved original rate.

The following is a complete pricing excerpt for one offered line and its summary. It does not replace unrelated fields in the full endpoint response.

```json
{
  "status": "success",
  "data": {
    "orders_id": 123,
    "store_id": 2,
    "delivery_charge": "0.00",
    "cart": {
      "cart_items": [
        {
          "id": 101,
          "product_id": 123,
          "product_name": "Offer product",
          "product_unit": "PCS",
          "quantity": "2.000",
          "standard_unit_price": "100.000",
          "unit_price": "80.000",
          "total_price": "160.00",
          "item_discount_amount": "40.00",
          "tax_rate": "15.000",
          "line_discount": "16.00",
          "discounted_total": "144.00",
          "discounted_base_amount": "125.22",
          "discounted_tax_amount": "18.78",
          "tax_amount": "18.78",
          "discount_origin": "offer",
          "offer_id": 7,
          "offer_version": 3,
          "offer_name": "Summer offer",
          "offer_names": {"en": "Summer offer", "ar": "عرض الصيف"},
          "offer_discount_type": "percentage",
          "offer_discount_value": "20.000",
          "order_discount_allocations": [
            {"source": "manual", "amount": "16.00"}
          ]
        }
      ],
      "price_summary": {
        "sub_total": "160.00",
        "net_total": "160.00",
        "discount": "16.00",
        "net_payable": "144.00",
        "total_tax": "18.78",
        "net_exc_tax": "125.22"
      }
    }
  }
}
```

Source fields are optional accounting/audit metadata, not additional display requirements:

- `discount_origin`: `offer`, `manual`, `standard` or `wholesale`; null/absent when historically unknown.
- `offer_id` and `offer_version`: numeric, nullable, identifying the sale-time winning rule.
- `offer_name`, optional `offer_names`, `offer_discount_type` (`percentage`/`flat_amount`) and `offer_discount_value`: immutable snapshots of the effective winning rule, including product overrides.
- `order_discount_allocations`: stored source entries with `source` (`coupon`/`manual`) and nonnegative `amount`. Coupon entries can also contain frozen `code`, `name` and `names`. Amounts must sum to canonical `line_discount`.

Expose existing CartItem pricing metadata in controller projections and persist any missing snapshots. Do not resolve historical names, prices, categories or offers against today's records. When an offer is manually overridden, use origin `manual` and clear offer identity/rule fields. A separate audit of the superseded offer versus manual portion needs explicit stored data; it cannot be inferred from the final rate.

For unknown historical original prices, return null/omit the reference rather than inventing one from MRP. Valid explicit `item_discount_amount: 0` is authoritative. Monetary values may be numbers or plain decimal strings; do not include currency symbols or thousands separators. Original Rate Ex Tax uses saved `tax_rate`; the app prints `-` when a discounted historical line lacks a reliable rate.

## 4. Document configuration: only one table discount option

Keep `GET /api/v1/document/document-configs` and the existing `document_configurations` envelope. The latest supplied Bill A4 response already contains `showDiscountColumn`; retain this exact key and expose its title in the admin editor.

```json
{
  "status": "success",
  "document_configurations": {
    "Bill A4": {
      "type": "Bill A4",
      "language": "en_ar",
      "theme": "boxed_header_tax_invoice",
      "display_configuration": {
        "showDiscountColumn": {
          "visible": true,
          "value": "الخصم",
          "default": "Discount"
        },
        "showDiscount": {
          "visible": true,
          "value": "خصم الطلب",
          "default": "Order discount"
        }
      }
    }
  }
}
```

This is an excerpt: preserve all other existing document flags and labels. Apply the column option to the appropriate Bill/A4 and sale/return document configurations rather than only the example record.

- `showDiscountColumn` controls the item-table column and its title in A4/A5 and thermal output. `showDiscount` independently controls the footer discount row/title. `showParticulars` independently controls product names.
- `visible: true` shows the table column, including zero values. `visible: false` hides it. If the column key is absent in an old response, the app shows it when a row has a discount.
- In bilingual mode, `value` is the Arabic title and `default` is the English title. Supplying both prints both. The latest `{ "visible": true, "value": null }` response enables the column but uses the built-in Arabic title `الخصم` in `en_ar` mode. English mode falls back to `Discount`.
- Legacy `showItemDiscount` remains supported when `showDiscountColumn` is absent. The current key takes precedence when both exist. No original-rate, offer-name, source-breakdown or after-discount display switches are requested.

Fix explicit language selection in `DocumentPrintConfigurationController.getAllConfigurations`. The current `$q->where('is_active', true) ?? $q->where('language', $lang)` does not execute the language filter. Explicit `language=en`/`language=ar` requests should select the requested translation when available. Define a fallback for a missing translation and return its actual language; do not label Arabic text as English. Requests without `language` must retain the configured active mode.

No response change is requested for `/api/v1/document/printer-settings`. Preserve the existing printer preference/theme precedence.

## 5. Offers: complete snapshots and historical review

The app now always requests `GET /api/v1/offers/pos-sync?store_id={id}` without `since`, including settings refreshes, manual sync, realtime-triggered refreshes and retries. A cache with one surviving offer can still be incomplete; every full refresh repairs missing unchanged rules.

Keep the existing top-level `offers`, `removed_offer_ids`, `server_time`, `full_snapshot` and `next_page` contract:

- Return every enabled, relevant store/company offer and its eligible rules across all pages, including scheduled rules the app needs to activate at their start time. Do not return only recently changed records when `since` is absent.
- Set `full_snapshot: true` for a full request. An empty successful full snapshot means there are no applicable cached offers to retain.
- If paginated, return an integer `next_page`; use null/absence at the end. Keep pages consistent for the snapshot. The app follows pages and replaces the catalog only after the complete download succeeds; request/pagination failures retain the cached catalog and retry.
- Preserve `id`, `version`, `name`, `store_id` (null = company-wide), `valid_from`, `valid_until`, and `lines`. Dates require a timezone offset or `Z`; start is inclusive and end is exclusive.
- Lines need `product_id`, nullable `stock_id`, `type` (`percentage`/`flat_amount`), `value`, numeric product `line_id`, and `category_distance` for category-derived rules. Keep category rules expanded to eligible product/stock lines; a category-only target is insufficient for the current parser.
- Keep disabled/deleted/moved offers out of the eligible full feed. Continue removal IDs for clients that still use deltas. Preserve `changes.offers` notifications in `/api/v1/sync/changes`; the app responds by fetching the full offer feed.
- Preserve the `POS_OFFERS` setting in `/api/v1/website-settings`; its status controls whether cached rules are used.

Align `CompletedSalePricing.line` with the POS resolver: product rule before category, store-specific before company-wide, batch before product-wide, highest product line ID, nearest category then highest offer ID, base-unit eligibility and wholesale precedence. One offer wins; offers do not stack. Offer prices use half-up rounding to three decimals and do not impose minimum-margin floors. Current historical review still applies a minimum-margin floor and searches product lines directly, which can falsely flag valid category/offer prices.

Version the resolved category scope and effective product override sufficiently to validate sale-time rules later. Offer 28's product override is fixed 3: standard rate 20 gives 17, regardless of the offer's general 3% value. Reviewing or reprinting this sale must retain that historical result after the live offer is edited or removed.

## 6. Coupon list, quote and eligible-line allocation

### Compatible list additions

Keep `/api/v1/discount/list-discounts`, its existing `data` list, and all existing coupon fields: numeric `id`, `coupon_code`, `coupon_name`, store/product/category scope, validity dates, discount type/value, minimum/maximum order amount, amount cap and usage limit. `discount_category_id` is an organizational coupon label; it is not a product-category eligibility rule.

Add optional integer `usage_count` and `remaining_uses`. The app already checks them when present. Use null/absence for unavailable counts; do not report zero remaining for unknown/unlimited usage. Return usable tenant/store coupon definitions and preserve the existing discount types (`percent`/`percentage`, `fixed`). Changing these to a new enum requires app integration. Cached counts cannot guarantee global usage under concurrency or offline operation.

### Proposed authoritative quote workflow: app integration required

The current `/api/v1/discount/apply-coupon` requires a server `cart_id`, or a single `product_id` plus `price`. It cannot quote the complete local POS cart through the current price/code/store-only caller. Desktop, mobile and restaurant coupon checkout currently calculate from downloaded definitions; they do not use an authoritative cart quote/reservation token.

Add a non-mutating local-cart quote operation, through a new endpoint or a backward-compatible extension of the existing operation. Agree its final URL/schema before the app integration. It must accept store, coupon identity, sale time and all cart lines, including stable `client_line_id`, product/variant, stock/batch, sale unit, quantity, standard/current rate and applied offer ID/version. Example proposed request:

```json
{
  "store_id": 2,
  "coupon_code": "SAVE10",
  "issued_at": "2026-10-10T10:00:00Z",
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

Validate tenant/store ownership, enablement, product/category descendants, sale time in the tenant timezone, order thresholds, eligible subtotal, per-order cap, global usage and stacking policy. Product selection takes precedence over category selection. The current app excludes offered lines from coupons; define whether manual item reductions and manual order discounts can stack.

The quote response must identify coupon ID/code/version, eligible lines/subtotal, exact order discount, each line's discount/final amount/base/VAT, totals, a quote token/version, expiration/invalidation conditions, and a structured rejection code plus readable reason. Link each line by `client_line_id`. Reserve/redeem usage atomically during confirmation; a non-mutating quote alone does not reserve usage. The exact quote/token keys are a new integration contract, not fields the current checkout already consumes.

Correct the allocation mismatch: `OrderHelper.discountPrice` calculates an eligible coupon amount, but `TaxDiscountHelper.calculateDiscountedCartTotals` allocates it over all lines. Targeted coupons must give ineligible/promoted lines zero coupon allocation. Keep manual-order allocations separate under an explicit policy. Store allocations once, including deterministic cent remainders, and reuse them for VAT, details, reprints, reports, returns and credit notes. Never make an allocation negative or greater than its line amount.

**Coordinate this allocation change with the app.** Its current `CartDiscountBreakdown` mirrors proportional allocation across all submitted lines. Backend-only changes can make a newly printed local receipt and its server reprint disagree, especially with mixed tax rates. Update local cart totals, VAT, completed-sale payloads and printing to use the agreed quote/allocation before enabling the new policy for those clients. Requote on product, quantity, price, stock, sale unit, store, offer validity or coupon changes.

## 7. Completed sales, coupon accounting and offline uploads

Preserve `POST /api/v1/order/add-to-order` compatibility. Current checkout sends numeric `coupon_id` when known and a separate `coupon_code`; code-only legacy paths omit a numeric identity instead of putting the code into the integer field. Percentage values are rates, while `discount_amount` is money. Do not reject existing code-only requests solely because the numeric ID is absent; resolve and verify identity server-side.

A new frozen local sale carries `pricing_mode: completed_sale`, receipt identity (`client_sale_id`, `pos_device_id`, `receipt_number`, UTC `issued_at`), store and item snapshots. The app submits original rate, tax, selling total, offer identity/version and optional item-discount/origin/name/rule metadata. It also submits final `grand_total`, `round_off` and discounted `tax_total` when available, and `delivery_tax_amount: 0` under its current delivery snapshot contract. Accept and persist these fields, but do not trust client metadata as proof of eligibility. Existing older snapshots without the newer optional metadata must remain accepted under the existing review policy. Draft/restaurant server orders retain server-authoritative pricing and do not become completed-sale snapshots merely because they contain a coupon.

The current `OrderController.addToOrder` completed-sale branch trusts submitted `discount_amount` and bypasses `handleCouponDiscount`, leaving authoritative coupon validation/redemption incomplete. Implement validation and usage accounting without silently changing a printed bill:

- Bind coupon identity/version, agreed quote/reservation token and eligible-line/source allocations to the sale. New mandatory quote fields need a coordinated app release.
- Online: validate/reserve/redeem atomically before confirmation under the agreed workflow. Count redemption once per `client_sale_id`, including retries and duplicate uploads.
- Offline: agree cached authorized allowance or an accepted-with-review policy when global limits/validity cannot be established. Preserve the printed rates, payable, VAT and receipt identity. Do not unexpectedly reject every old pending offline sale because it lacks a newly introduced quote token.
- Keep existing success responses and order IDs. Current uploads treat a successful 200/201 order response as synced, including `review: true`; a new device-side review UI would need integration. HTTP 409 stops automatic retry and requires review; 400/401/403/422 are rejected. Do not change these meanings as part of a response-only release.

## 8. Totals, returns and consistency

Preserve `data.cart.price_summary.sub_total`, `net_total`, `discount`, `net_payable`, `total_tax`, `net_exc_tax`, and existing MRP/savings fields. The current app reads these canonical names. A new `grand_total` or `tax_total` response alias alone does not replace `net_payable` or `total_tax`.

Optional accounting additions: `items_total_before_order_discount`, `item_discount_total`, `order_discount_total`, `delivery_charge`, `delivery_tax_amount`, `round_off`, `grand_total`, `tax_total`, `net_exc_tax`. Make aliases reconcile with the existing summary. Item reductions are already reflected in `net_total`; its order discount must not include them again. Keep `total_saved`/MRP savings separate from coupon discounts, delivery and round-off. Follow the existing inclusive-delivery convention so delivery tax is not added twice.

For quantity-specific returns, return exact original sale-time amounts, original/current rates in the correct unit, VAT and discount allocations for the returned quantity. Repeated partial returns must reconcile to the frozen original bill without recomputing eligibility or moving the cent remainder differently each time. The app's existing proportional quantity-copy fallback does not by itself guarantee this; coordinate the return adapter/workflow before relying on a new allocation policy.

## 9. Acceptance and rollout

Deploy additive receipt fields, document labels, language selection, complete offer snapshots and compatible coupon-list counters first. Keep current request contracts valid. Then integrate and release coupon quotes/reservations, eligible-line calculations and exact return allocations in the app before requiring them on the backend. Use an explicit API version/capability policy for new mandatory behavior; do not infer support from the presence of coupon ID alone.

Verify these cases against original prints, stored data and reprints:

1. Standard item, manual item reduction, manual price increase and offer overridden manually; never infer a discount from MRP.
2. Offer 28: Rate 20, Qty 1, Discount 3, Total 17; also product/category precedence, product override, wholesale, sale units and split batches.
3. The 2.00 sample: rates 3/4/12/3, discount cells 2.73/3.64/10.91/2.72, final cells 0.27/0.36/1.09/0.28; footer order discount 20 and final VAT 0.24.
4. Coupon product/category descendants, mixed eligible/ineligible/promoted lines, min/max amount, cap, expired/not-started/exhausted coupon, concurrent redemption and idempotent replay.
5. Mixed VAT rates, tiny/zero lines, 100% discount, delivery and round-off; stored line totals/base/VAT must reconcile to the summary.
6. Offline restart/upload, delayed upload after offer edit/removal, restaurant completion, held-cart restoration and repeated partial returns.
7. Full offer refresh with an empty cache, a nonempty cache missing an unchanged offer, pagination and a failed later page; successful full snapshots remove absent rules, failed downloads keep the old catalog.
8. A4/A5 and 58mm/80mm thermal output: custom Discount title, visible/hidden column, zero-discount lines, English/Arabic/bilingual mode, and independent footer/Particulars switches.
9. Existing app requests without future quote tokens and old receipts without optional source metadata; preserve the documented compatibility behavior.

Current app evidence: 98 offer/API-pagination/realtime/document-label/thermal regression tests passed, targeted static analysis was clean, 38 one-page PDF samples and six thermal previews were generated and reviewed, and the running app hot-reloaded successfully. These checks cover the app's current response contract and fallbacks; they do not prove a future backend deployment or the proposed quote/reservation workflow. Physical printer hardware and the backend test suite were not exercised for this handoff.

Backend implementation locations: `app/Http/Controllers/Api/V1/OrderController.php`, `DiscountController.php`, `DocumentPrintConfigurationController.php`, `PosOfferController.php`, `app/Helper/OrderHelper.php`, `TaxDiscountHelper.php`, and `app/Services/CompletedSalePricing.php`.
