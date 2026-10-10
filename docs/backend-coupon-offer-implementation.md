# Coupon, offer and document API implementation

Updated 10 October 2026. Changes are implemented locally in `enkepos`; they have not been deployed. This supplements [the compatibility and acceptance handoff](backend-coupon-offer-handoff.md).

## Existing API changes

- Document configuration keeps `document_configurations` and object-shaped display options. Explicit `en`, `ar`, and `en_ar` select that translation, including inactive translations. Without a language, the active configured translation wins. A missing requested translation falls back to the active translation, then English, then the first available translation; the response reports its actual language. Unknown templates return 404. Company filtering applies to both all-template and single-template requests.
- `showDiscountColumn` maps to the admin editor's existing `discountHeader` text. Missing titles use `Discount` / `الخصم`; bilingual responses supply the English default. `showDiscount` remains the separate footer option. Double-encoded historical flags are handled consistently. No printer-settings API change.
- Receipt/cart projections add saved `tax_rate`, item discount and offer metadata, client line identity, allocation version, coupon/manual source allocations, and saved post-discount totals/base/VAT when available. Existing fields and envelopes remain. Quantities are decimal strings. No additional display switches or product-name discount notes.
- Cart item metadata is stored in the existing `pricing_metadata` JSON column. Completed sales accept `standard`, `manual`, and legacy `none` / `manual_price` origins. Historical offer names and effective overrides come from saved rule versions. Manual overrides clear the superseded offer identity and rule. Unknown historical original rates remain unknown.
- Historical offer review supports expanded category rules, batch precedence, product/category/store precedence across known sale-time versions, and no POS margin floor. Printed amounts are preserved. Later rule edits/removal do not reprice the sale.
- Existing full offer sync already returns all relevant current/scheduled rules without `since`; no new feed workflow is needed. Legacy delta requests remain supported.
- Coupon list adds integer `usage_count` and nullable integer `remaining_uses`; active reservations consume capacity. Unlimited coupons return null remaining uses. Existing coupon fields, types, enums, and the nested list envelope are preserved.
- Non-numeric strings in legacy `coupon_id` are normalized as codes before validation. Numeric IDs/strings remain identities. Contradictory code/ID combinations are rejected for normal online orders. Normalization preserves the original request fields used by offline idempotency hashes.
- Legacy coupon confirmation holds a coupon row lock and counts active reservations. Completed-sale uploads now validate coupon identity/rules and log recognized coupon usage in the sale transaction. Invalid/unverifiable already-printed legacy coupons add pricing-review reasons without changing the printed sale. A replay returns the existing order before redemption work.
- Saved allocations are reused in VAT calculation, receipts, product discount reports, tax reports and tax exports. Existing unsnapshotted orders retain the legacy proportional calculation.

## Optional version 2 POS coupon workflow

Existing apps do not call these endpoints and do not need new tokens. All endpoints require the existing tenant context, authenticated user and membership of that company. They do not change the existing `apply-coupon` endpoint.

### 1. Quote: `POST /api/v1/discount/quote-coupon`

```json
{
  "store_id": 2,
  "coupon_id": 7,
  "coupon_code": "SAVE10",
  "issued_at": "2026-10-10T10:00:00Z",
  "items": [
    {
      "client_line_id": "row-1",
      "product_id": 123,
      "stock_id": null,
      "product_variant_id": null,
      "product_sale_unit_id": null,
      "quantity": 2,
      "unit_price": "80.000",
      "standard_unit_price": "100.000",
      "total_price": "160.00",
      "tax_rate": "15.000",
      "offer_id": null,
      "offer_version": null,
      "discount_origin": "manual"
    }
  ]
}
```

Either coupon ID or code is required; when both are supplied they must agree. Line IDs must be unique. Server time and `issued_at` must be within two minutes. Prices are inclusive POS sale-unit prices; manual item rates remain allowed under the existing POS pricing policy. The server validates line arithmetic and tenant/product/stock/variant/sale-unit scope and resolves tax using the normal cart tax resolver. A changed submitted tax rate requires a cart refresh.

The server checks validity in tenant time, store, product/category descendants, order minimum/maximum, usage capacity, discount amount cap and stacking. Product scope takes precedence over category scope. Offered lines are excluded; manual item reductions can stack. Version 2 has one coupon order discount and does not combine an additional manual order discount.

The response is `{ "status": "success", "data": { ... } }`. Its data contains:

- `coupon_pricing_version: 2`, numeric coupon ID, code, `coupon_version` (definition fingerprint), store and sale time.
- `eligible_subtotal`, `discount_amount`, and `lines`, linked by `client_line_id`. Each line includes its normalized identities/rates/quantity, `eligible`, `line_discount`, `discounted_total`, `discounted_base_amount`, `discounted_tax_amount`, and `order_discount_allocations` with the frozen coupon code/name.
- `totals.net_total`, `discount`, `net_payable`, `total_tax`, and `net_exc_tax`. These are item totals; the app adds its separately saved inclusive delivery charge/tax and round-off.
- Signed/encrypted `quote_token` and `expires_at`. Quotes last ten minutes, bounded by the coupon's local end date. A quote does not reserve or redeem usage.

Discount cents are allocated only to eligible lines by largest remainder, with deterministic input-order ties and bounds on every line. Ineligible and offered lines get zero coupon allocation. Free and fully discounted lines retain their tax rate and have zero final VAT.

Rule rejections return HTTP 422 with `status: failed`, a structured `code`, `message`, and `errors`. Examples: `coupon_identity_invalid`, `coupon_store_mismatch`, `coupon_outside_validity`, `coupon_exhausted`, `coupon_minimum_not_met`, `coupon_maximum_exceeded`, `coupon_no_eligible_lines`, `tax_rate_changed`, `line_total_mismatch`.

### 2. Reserve: `POST /api/v1/discount/reserve-coupon`

```json
{
  "quote_token": "<returned quote token>",
  "client_sale_id": "<sale UUID>",
  "pos_device_id": "<device UUID>"
}
```

This locks the coupon row, validates the quote's tenant/signature/expiry and coupon fingerprint, rechecks taxes/eligibility/capacity, and reserves one use. The response's data contains `coupon_pricing_version: 2`, `coupon_reservation_token`, `expires_at`, and `client_sale_id`.

An identical active retry reuses the reservation. A conflicting active reservation requires release and a fresh quote. Expired/released reservations can be replaced for the same sale identity with a new token. The final available use cannot be reserved by another sale while the reservation remains active. MySQL concurrent transaction behavior must also be verified in staging; SQLite tests verify the capacity and replay rules sequentially.

### 3. Release: `POST /api/v1/discount/release-coupon`

Send `coupon_reservation_token`, `client_sale_id`, and `pos_device_id`. Matching unredeemed reservations are released; the call is idempotent. Released tokens cannot be used to confirm a sale. An expired unredeemed reservation stops consuming capacity automatically; no scheduled cleanup is required for correctness.

### 4. Confirm using existing `POST /api/v1/order/add-to-order`

Version 2 currently applies to `pricing_mode: completed_sale` executive POS sales. Preserve the existing completed-sale identity, item and total snapshot fields; additionally send:

```json
{
  "coupon_pricing_version": 2,
  "coupon_id": 7,
  "coupon_code": "SAVE10",
  "coupon_reservation_token": "<reservation UUID>",
  "discount_amount": "16.00",
  "items": [
    {
      "client_line_id": "row-1",
      "product_id": 123,
      "price": "80.000",
      "standard_unit_price": "100.000",
      "quantity": 2,
      "tax_rate": 15,
      "tax_amount": "20.87",
      "total_price": "160.00"
    }
  ]
}
```

This is a pricing excerpt, not a complete order request. Items use the existing submission names (`price`, `stock_id`, `sale_unit_id`), while quote lines use `unit_price` / `product_sale_unit_id`.

The reservation binds coupon, company, store, sale/device UUIDs and line identity/product/stock/variant/sale-unit/quantity/rates/tax/offer identity. Altered lines, mismatched identity/amount, released or already-used tokens are rejected. Saved quoted line allocations drive order VAT and reprints. Redemption and recognized coupon use logging occur in the sale transaction; existing sale idempotency prevents repeated counting.

An already-printed completed sale uploaded after reservation expiry is accepted with review and keeps its reserved amounts. Changed coupon definitions or capacity exhausted at delayed upload also produce review reasons. This is the explicit offline policy; it may exceed a global cap when devices upload late after capacity was released. It is not a guaranteed offline allowance. Old uploads without a token remain accepted under the documented review policy and keep proportional allocations.

## Returns and credit notes

Version 2 sale lines retain exact order discount, net, base and VAT cents. API and admin returns store a `pricing_metadata` snapshot on each returned line. Repeated partial returns use cumulative integer prefixes, preserving all original cents and never allocating negative discount or VAT above the returned value. Original/current rates, tax rate, item discount, order share and quantity slice are returned. Gross `price` remains the existing return field; exact final amounts are additive metadata.

Refund calculation uses the stored returned discount instead of redistributing a targeted coupon. Tax screen/export and credit-note calculations consume stored return amounts. Legacy sales keep their existing return calculation. The app still needs to consume these exact return snapshots before relying on version 2 throughout its return UI and printing.

## Deployment and remaining integration

1. Review and deploy the local backend changes plus both migrations: `2026_10_10_000001_create_pos_coupon_reservations_table.php` and `2026_10_10_000002_add_pricing_metadata_to_order_return_items.php`. Use normal deployment backup/migration procedures. No migration has been run on the working/production database by this task.
2. Check current and supported older app binaries against staging, including pending offline replay. Preserve existing integer coupon fields, string quantities and object-shaped display options. Additive fields are not a blanket guarantee for every older binary.
3. Integrate quote/reserve/release into the app, use quoted line allocations for local totals/VAT/printing, submit version 2 snapshots, and use exact returned allocations. Requote after cart/store/coupon/offer changes. Until then, the app keeps version 1 behavior.
4. Exercise simultaneous MySQL redemptions, real tenant/store/stock/sale-unit fixtures, returns/credit notes, and original/reprinted A4/thermal bills in staging. Physical printers and the deployed API have not been tested by these local checks.

Local validation: **115 PHPUnit tests / 445 assertions passed**; syntax checks passed for all 27 changed PHP files. New PHP files were formatted with Pint and Git whitespace checks were clean. These are isolated service/controller/model regressions; full seeded HTTP checkout/return flows and simultaneous MySQL transactions remain staging checks. PHPUnit tests use isolated in-memory SQLite; Composer scripts were disabled during local dependency installation. The unrelated missing local EXIF extension was ignored for installation; production must meet its normal Composer platform requirements.
