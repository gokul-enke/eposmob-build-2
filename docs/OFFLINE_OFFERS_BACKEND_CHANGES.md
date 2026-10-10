# Offline offers: what the POS app does (final contract)

For the current coupon/offer/receipt backend rollout, use [backend-coupon-offer-handoff.md](backend-coupon-offer-handoff.md).

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

`GET /api/v1/offers/pos-sync?store_id=1` with `X-Tenant`, `Authorization: Bearer`, `Accept: application/json`. Every app refresh requests the full catalog; it does not send `since`, even when its cache contains offers and a saved timestamp.

What the app reads from each offer: `id`, `version`, `name`, `store_id` (null means every store), `valid_from`, `valid_until` and `lines`. Dates must carry a time zone offset or `Z`; `valid_until` is exclusive.

What it reads from each line: `line_id` (numeric on product lines; text such as `category-123` is ignored), `product_id`, `stock_id`, `category_distance` (set on category lines), `type` and `value`.

- `type` is `percentage` or `flat_amount`. A line with any other type is skipped.
- A disabled, deleted or moved offer must arrive in `removed_offer_ids`. As a safeguard the app also removes an offer returned with `enabled: false`, an offer it cannot read (for example without `valid_until`), and an id sent in both `offers` and `removed_offer_ids`.
- Every successful full download replaces the whole local cache, including an empty snapshot. The server must return every eligible offer for the requested store across its pages. A missing unchanged offer in a partially populated cache is recovered by the next refresh.
- `server_time` records the last successful sync and corrects the device clock; it is not sent as a delta cursor.
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

New completed-sale snapshots also carry optional item-discount/origin/name/rule metadata, including `item_discount_amount` and `discount_origin`. They submit final `grand_total`, `round_off` and discounted `tax_total` when available; older payloads can omit them. `discount_amount` is the overall (coupon / order) discount only; the offer reduction is already in the line prices. Keep the new fields optional for existing clients.

## 5. Responses

| Status | The app treats it as |
| --- | --- |
| `200` / `201` with an order id | synced, even when `review: true` |
| `409` | needs review on the device (not retried automatically) |
| `400` / `401` / `403` / `422` | rejected |

Upload retries resend the exact same payload.
