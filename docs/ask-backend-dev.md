# Offline offers: what we need from the backend (round 2)

Thanks for the detailed reply. The app now follows it. The full list of what the app sends and expects is in `OFFLINE_OFFERS_BACKEND_CHANGES.md`. Short version:

- every printed offline sale is sent with `pricing_mode: "completed_sale"`, with or without an offer;
- every line carries `standard_unit_price`, `tax_rate`, `tax_amount` and `total_price`; offer lines also carry `offer_id` / `offer_version`;
- the app chooses the winning rule itself from your feed, using your order (product before category, store-specific before company-wide, batch before product-wide then highest line id, nearest category then highest offer id), and rounds offer prices half-up to 3 decimals.

---

## Needed before the app can work

### 1. `POS_OFFERS` row in `website-settings`

The reply says `POS_OFFERS` is not implemented. The app only turns offers on from this row, so **please add it**. It goes in the `data` list, per store, like `POS_OFFLINE_SALES`:

```json
{ "name": "POS Offers", "code": "POS_OFFERS", "value": "", "status": true }
```

`status: false` or a missing row means off. This is the only switch the app reads.

### 2. Fix the one-paisa tolerance

Please fix the floating-point comparison (for example `abs(80.01 - 80) > 0.01` is true in PHP) in the line total, grand total and historical offer price checks. Without it, correct sales can be flagged or rejected.

### 3. Deploy the backend changes to staging

Run the migration and the seeder, and confirm `GET /api/v1/offers/pos-sync` and the order changes are live on staging. Then please create the test store: a product offer (`percentage`), a product offer (`flat_amount`), a category offer on the same product that ends later, a store-specific offer, a batch (`stock_id`) offer, an offer that expires today, and a future offer.

---

## Please confirm

### 4. Tax after an overall discount

The app prints the order tax before any overall (coupon / order) discount. It does **not** send `tax_total`, `round_off` or `grand_total`.

**Question:** on a completed sale with `discount_amount > 0` and no `tax_total`, will the backend derive the tax after discount from the line taxes (for example `sum(line tax) × (items total − discount) / items total`) without a review reason? Or what formula do you check against? If it is `discounted_tax_snapshot_missing`, every discounted sale will be flagged.

### 5. Round-off and grand total

The app's price round-off only affects the amount paid; today the backend order total ignores it. Confirm that omitting `round_off` and `grand_total` is accepted without review, and the backend computes `items − discount + delivery_charge`.

### 6. Delivery tax

The app never prints delivery tax, so it sends `delivery_tax_amount: 0` on every completed sale. Confirm that `0` clears `delivery_tax_snapshot_missing` and that `delivery_charge` is taken as the final amount.

### 7. `discount_origin` is not sent

Confirm that a missing `discount_origin` causes no review reason and that reports use `standard_unit_price − price` for the item discount (a manual price shows its reduction, wholesale shows none).

### 8. Product-wide offer on a multi-batch line

When a product-wide offer applies to a cart line that uses two batches, the app sends two order lines with the same price and the same `offer_id`. The app never applies a batch-scoped offer (`stock_id` set) to a cart line that uses more than one batch.

**Question:** confirm this does **not** trigger `offer_scope_mismatch` (it should only fire when a batch-scoped offer is used on another batch).

### 9. Sale identity

`client_sale_id` is a UUID v7 and `pos_device_id` a UUID v4. Confirm both are accepted as UUIDs.

### 10. `409` and `review: true`

The app treats `200`/`201` with `order_id` as success, including `review: true`. A `409` is kept on the device as "needs review" and is not retried. Confirm that matches your intent for a conflicting `client_sale_id`.
