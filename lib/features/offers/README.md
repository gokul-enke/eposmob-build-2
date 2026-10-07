# Product offers

Automatic product offers (percentage or flat amount off) applied to cart lines, online and offline.
What the app sends and expects from the backend is in `docs/OFFLINE_OFFERS_BACKEND_CHANGES.md`.

## Flow

1. `AppSettingsProvider` reads the `POS_OFFERS` setting row and calls `ProductOfferRepository.applySetting`.
   The repository remembers the value per store, so offers keep working after an offline start.
2. `ProductOfferRepository` downloads `GET /api/v1/offers/pos-sync` (full, then deltas with `since`), stores the catalog in the `product_offers` Hive box and measures the device clock offset from `server_time`.
   Syncs are triggered by the setting, a manual product sync (`SyncProvider`) and `offers` changes in `sync/changes` (`RealtimeSyncRepository`).
3. `LocalProductProvider` resolves the standard price as before, then calls `resolveProductOfferPrice` (`domain/product_offer_pricing.dart`), which picks one winning rule from the feed.
   Every cart line keeps `standardUnitPrice`; offer lines also keep `offerId` and `offerVersion`.
4. `buildOrderItemsPayloadFrom` adds `offer_id` / `offer_version` on offer lines and, on every line, the completed-sale snapshot (`standard_unit_price`, `tax_rate`, `tax_amount`, `total_price`).
   `OrderSubmissionPayload` keeps the snapshot and adds `pricing_mode: completed_sale` only for a new, frozen, printed sale (no `order_id`, executive source, store and full receipt identity); otherwise it strips the snapshot.
5. `CartOfferBadge` shows the "Offer" tag and the struck-through standard price in the cart.
6. The mobile market's grid, list and compact cards and Add popup use
   `LocalProductProvider.previewProductPrice`. It shares the cart's pricing
   and batch allocation without reserving stock. The popup includes the quantity
   already in a matching cart line, updates automatic prices when quantity or
   sale unit changes, and submits a custom price only after a cashier edit.
   Ambiguous batch or variant choices defer the final price until selection.

## Rules

- Exactly one rule wins, offers never stack: product before category, store-specific before company-wide, batch before product-wide then highest line id, nearest category then highest offer id.
- Offer prices are rounded half-up to 3 decimals (`domain/offer_money.dart`).
- Only base-unit lines get an offer; pack/case/box sale units do not.
- Wholesale price wins over an offer.
- A batch rule applies only when the cart line uses that one batch.
- Minimum-price rules are not applied to offer prices.
- A manual price edit removes the offer and keeps the standard price as its reference; committing the unchanged price is not an edit.
- A line added with an explicit price keeps it: the offer is applied only when that price is the standard price, and a line re-added at its offer price keeps its offer reference.
- Open cart lines are re-checked whenever the catalog changes (sync, removal, `POS_OFFERS` switch, store change), when a store offer starts or ends (one timer for the next `valid_from` / `valid_until`, also updating product previews), after a restart and when a held order is resumed.
  Only non-manual lines at their standard or offer price are re-priced; manual and other explicit prices are never touched.
- Offline, cached offers keep applying until `valid_until`, checked against the server-corrected clock.
  A sale printed at an offer price is synced at that price.
