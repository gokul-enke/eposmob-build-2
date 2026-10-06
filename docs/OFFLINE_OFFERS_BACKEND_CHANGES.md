# Offline offers: what the POS app does (final contract)

This is what the app sends and expects, after the backend developer's contract and reply. If the backend behaves differently, the app breaks or the sale is flagged, so tell us before changing it.

## 1. Switch

`GET /api/v1/website-settings` returns a row in its `data` list, per store (the app already sends `store_id`):

```json
{ "name": "POS Offers", "code": "POS_OFFERS", "value": "", "status": true }
```

- `status: true` turns offers on. `false`, or a missing row, turns them off.
- The app remembers the last value, so offers keep working when it starts offline.
- The `capabilities` block and `POS_OFFERS_ENABLED` are not read.

## 2. Offer feed

`GET /api/v1/offers/pos-sync?store_id=1[&since=<server_time>]` with `X-Tenant`, `Authorization: Bearer`, `Accept: application/json`.

What the app reads from each offer: `id`, `version`, `name`, `store_id` (null means every store), `valid_from`, `valid_until` and `lines`. Dates must carry a time zone offset or `Z`; `valid_until` is exclusive.

What it reads from each line: `line_id` (numeric on product lines; text such as `category-123` is ignored), `product_id`, `stock_id`, `category_distance` (set on category lines), `type` and `value`.

- `type` is `percentage` or `flat_amount`. A line with any other type is skipped.
- A disabled, deleted or moved offer must arrive in `removed_offer_ids`. The app does not read `enabled`.
- `full_snapshot: true` replaces the whole local cache. Without it, returned offers replace the cached ones by id.
- `server_time` becomes the next `since`, and is used to correct the device clock.
- `next_page` is followed if it is ever sent. The app replaces its cache only after the last page.
- `target_type`, `category_id`, `source_types`, `base_unit_only` and `selection` are ignored.
- `changes.offers` in `GET /api/v1/sync/changes` makes the app fetch the feed again.

## 3. Choosing the offer (done in the app, at the time of sale)

The feed carries every eligible rule. The app keeps those valid at the sale time (device clock corrected by `server_time`), for this store, product and batch. Exactly one wins, and offers never stack:

1. A product rule before a category rule.
2. A store-specific offer before a company-wide one.
3. Product rules: a batch (`stock_id`) rule before a product-wide rule, then the highest line id.
4. Category rules: the nearest category (`category_distance` ascending), then the highest offer id.

The winner's price is used; the next rule is never tried.

Calculation, per base unit, with the result rounded half-up to 3 decimals:

- `percentage`: price × (1 − value / 100)
- `flat_amount`: price − value, never below 0

An offer never raises the price. Not applied:

- pack, case and box sale units (they keep their normal price);
- when the quantity qualifies for the wholesale price (wholesale wins);
- a batch rule on a cart line that uses more than one batch;
- the minimum-margin price (it does not apply to offer prices).

A price typed by the cashier removes the offer.

## 4. Uploading a sale

`POST /api/v1/order/add-to-order` for a new, frozen, printed sale: no `order_id`, `source_type: "executive"`, a `store_id`, and the full receipt identity (`client_sale_id`, `pos_device_id`, `receipt_number`, `issued_at` in UTC). Only then does the app add:

```json
{ "pricing_mode": "completed_sale", "delivery_tax_amount": 0 }
```

This applies to every printed sale, with or without an offer. Orders with an `order_id` (confirm or update of an existing draft) and orders without a receipt identity never carry `pricing_mode` or the line snapshot below.

Every line of a completed sale carries:

| Field | Value |
| --- | --- |
| `price` | printed tax-inclusive unit price (offer price when an offer applied) |
| `standard_unit_price` | price before any offer or manual change, same unit as `price`. For a line with no offer and no manual price it equals `price` (wholesale included) |
| `tax_rate` | tax rate in percent |
| `tax_amount` | tax inside the whole line = `round(total_price × rate / (100 + rate), 2)` |
| `total_price` | `round(price × quantity, 2)` |
| `offer_id`, `offer_version` | only on lines that got an offer |

A cart line that spans several batches becomes one order line per batch, each with the same price and the same offer reference.

Not sent: `discount_origin`, `tax_total`, `round_off`, `grand_total`. `discount_amount` is the overall (coupon / order) discount only; the offer reduction is already in the line prices.

## 5. Responses

| Status | The app treats it as |
| --- | --- |
| `200` / `201` with an order id | synced, even when `review: true` |
| `409` | needs review on the device (not retried automatically) |
| `400` / `401` / `403` / `422` | rejected |

Upload retries resend the exact same payload.
