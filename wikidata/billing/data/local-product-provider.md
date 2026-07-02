# LocalProductProvider Logic

Source: `lib/providers/local_product_provider.dart`.

`LocalProductProvider` is the main local billing data owner. It combines product cache, barcode lookup, local cart, stock reservation, discounts, saved drafts, confirmed local orders, and Hive persistence.

## Data Models

`StockReservation`:

- `stockId`
- `quantity`
- JSON serialization/deserialization.
- Reads both `stockId` and `stock_id`.

`LocalCartItem`:

- Product snapshot.
- Base price, MRP, tax rate, tax amount.
- Base quantity.
- Selected stock snapshot.
- Deducted stock quantity.
- Stock group ids.
- Reservation list.
- Comment.
- Manual price override flag.
- Sale unit id/name/conversion.
- Helpers for display quantity, base quantity, display price/MRP, base amount conversion, safe sale-unit payload check, and quantity normalization.

`SavedOrder`:

- Local id and order number.
- Cart item snapshots.
- Customer name, phone, id, type.
- Comment, created date, total.
- Payment method, paid amount, balance, transaction.
- Delivery method/id, car no, delivery date/time/address, delivery charge.
- Coupon id, discount values, customer credit flag.
- Table, alternate number, VAT/CR, quotation id/number.

`PriceSummary`:

- Discount.
- Net payable.
- Subtotal.
- Total tax.
- Net total.
- Flat discount.
- Percentage discount amount.
- Original subtotal.

## Provider State

The provider owns:

- Hive boxes for products, cart items, saved orders, and confirmed orders.
- Product list and filtered product list.
- Product barcode map.
- Selected product and selected stock.
- Cart items.
- Saved and confirmed order lists.
- Current order being edited.
- Current `PriceSummary`.
- Product pagination state.
- Stock enabled flag and static cached flag.
- Local flat and percentage discounts.
- Active stock grouping fields.

Constructor behavior:

- Loads stock-enabled preference/cache.
- Loads products from Hive.
- Loads cart from Hive.
- Loads saved orders from Hive.
- Initializes confirmed order box.

## Products And Search

`initializeProducts`:

- Sets products and filtered products.
- Rebuilds barcode index.
- Saves products to Hive.
- Notifies listeners.

`fetchProductsFromAPI`:

- Uses SharedPreferences tenant/api key and access token.
- Supports full refresh and delta sync with last product sync timestamp.
- Fetches product pages in batches of 3.
- Uses sellable/raw product endpoint depending on parameters.
- For delta sync, merges changed products by id and prepends new products.
- For full sync, replaces the product list.
- Saves last sync timestamp after successful responses.
- Persists products and rebuilds local state.

Search/filter behavior:

- Filters by category, name/localized names, barcode, HSN, price string, and item code.
- Name matching ranks starts-with matches before contains matches.
- Pagination is updated.
- `sellableOnly` parameter exists in filtering but is not actively applied in current logic.

Barcode index:

- Includes product barcode.
- Includes sale-unit barcodes.
- Barcode lookup trims input but is case-sensitive.

## Product Mutations

Supported operations:

- Add or update product locally.
- Delete product locally and through API.
- Update product snapshot.
- Add stock to product.
- Update stock details by stock id.
- Update stock quantity.
- Delete product.
- Get product by id.
- Filter product by barcode.

When product or stock pricing changes, cart and saved order item snapshots can be refreshed while preserving manual price overrides.

## Tax And Price Resolution

`taxBreakdown` extracts inclusive tax per item and groups by product tax components when possible.

Price helpers resolve:

- Cart tax rate.
- Per-unit inclusive tax amount.
- MRP.
- Wholesale minimum unit.
- Wholesale price.
- Unit price.

`_refreshCartItemPricing`:

- Recalculates price unless item has manual override, unless forced.
- Always refreshes MRP, tax rate, and tax amount.

## Cart Totals And Discounts

`subTotalBeforeDiscount` sums base `price * quantity`.

`cartTotal`:

- Sums subtotal.
- Extracts inclusive tax.
- Calculates flat discount and percentage discount amount.
- Caps discount at subtotal.
- Updates `priceSummary`.
- Returns net total.

`applyDiscount`:

- Stores raw flat and percentage discount values.
- Forces `cartTotal` recalculation.
- Notifies listeners.

`clearDiscount`:

- Resets discount values.
- Forces summary recalculation.
- Notifies listeners.

`getCurrentDiscount` returns raw configured flat and percentage values.

## Stock Reservation Internals

Reservation helpers:

- Normalize stock group ids by sorting and uniquing ids.
- Compare group id sets.
- Serialize/deserialize group ids and reservations.
- Build legacy reservations from selected stock plus `stockDeducted`.
- Sort stock candidates by expiry date, stock date, then id.
- Resolve reservation candidates from selected stock and/or stock group ids.
- Reserve, restore, and reapply saved reservations.
- Merge reservation deltas by stock id.

`_updateStockQuantityInternal`:

- No-ops if stock is disabled.
- Finds matching stock in `_products`.
- Applies quantity delta.
- Clamps new quantity at zero.
- Returns actual change.
- Persists and notifies when requested.

Partial reservation is allowed. The provider logs remaining quantity but still lets cart quantity exist.

## Add To Cart

`addToCart`:

- Looks up current product by id when possible.
- Uses requested quantity or 1.
- Finds an existing line by product, stock/group identity, and sale unit.

If existing:

- Merges stock group ids.
- Reserves additional stock.
- Increments base quantity.
- Applies explicit price/MRP when passed.
- Preserves existing manual price when price is null.
- Marks manual override when requested.
- Moves item to front unless increment came from compact quantity control.
- Refreshes pricing.

If new:

- Reserves stock.
- Resolves price/MRP/tax.
- Creates `LocalCartItem`.
- Inserts at front.
- Stores sale-unit metadata and manual override flag.

After both:

- Resets selected product.
- Saves products if stock changed.
- Saves cart.
- Notifies listeners.

## Change Cart Item Sale Unit

`changeCartItemSaleUnit`:

- Finds current line by product, stock/group identity, and current sale unit.
- Resolves target sale-unit metadata.
- Keeps display quantity constant while changing base quantity according to target conversion.
- Pre-checks stock availability when increasing quantity.
- Restores or reserves stock difference.
- If target line already exists, merges quantities, reservations, and comments.
- Otherwise replaces the current item.
- Refreshes pricing.
- Saves products/cart and notifies.

Failure usually means invalid selection or insufficient stock.

## Cart Row Updates

`removeFromCart`:

- Restores item stock reservations.
- Saves products.
- Removes row.
- Saves cart.
- Notifies.

`updateItemPrice`:

- Sets base price.
- Marks manual override.
- Recalculates tax amount.

`updateItemMrp`:

- Sets base MRP.

`updateItemTax`:

- Sets tax rate and recalculates tax amount.

`decrementCartItem`:

- Decrement step is sale-unit base quantity when sale unit exists, otherwise 1.
- Restores stock for the decremented amount.
- Removes row when quantity reaches zero.

`setCartItemQuantity`:

- Calculates difference from current quantity.
- Reserves stock when increasing.
- Restores stock when decreasing.
- Removes row when new quantity is zero or below.
- Refreshes pricing and persists.

`clearCart`:

- Restores all reservations.
- Clears cart items and cart Hive box.
- Clears discount.
- Notifies.

`clearCartAfterOrder`:

- Clears cart items and Hive box without restoring stock.
- Clears discount.
- Notifies.

## Order Payload

`buildOrderItemsPayload` expands cart items into API rows.

For reserved stock:

- One row per reservation.
- `stock_id` is reservation stock id.
- Quantity and price use sale-unit display values only when conversion is safe.
- Sale-unit ids are included for sale-unit payloads.

For unreserved quantity:

- Adds one row for remaining quantity.
- Uses selected stock id only when there are no reservations.
- Uses null stock id when remaining quantity is not tied to a reservation.

Rows with non-positive quantity are filtered out.

## Saved And Confirmed Orders

Order id:

- `_generateLocalOrderId` uses current microseconds and enforces monotonic increase.

Saved draft:

- `saveCurrentCartAsOrder` validates cart non-empty.
- Total is rounded/cart total plus delivery charge.
- Clones cart items.
- Generates `ORD-n`.
- Stores customer, payment, delivery, discount, credit, status, and extra metadata.
- Saves to Hive and notifies.

Confirmed local order:

- `saveCurrentCartAsConfirmedOrder` validates cart non-empty.
- Generates `CONF-n`.
- Stores cloned cart and metadata in confirmed list/Hive.

Move saved to confirmed:

- `moveToConfirmedOrders` finds saved order.
- Creates confirmed order using saved fields.
- Removes saved order.
- Saves both lists.

Load saved order:

- Finds saved order.
- Restores discounts.
- If stock enabled, releases current cart reservations and saves products.
- Clears cart.
- Clones saved items and re-applies saved reservations.
- Sets `_currentOrder`.
- Saves cart and notifies.

Load quotation draft:

- Restores discounts.
- Releases current cart reservations.
- Clears cart.
- Clones draft items.
- Does not reapply reservations.
- Sets current order and saves cart.

Update saved order:

- Replaces item snapshot from current cart.
- Recalculates total.
- Preserves existing fields when new values are null.
- Stores current discount values.
- Clears current order reference.
- Saves and notifies.

Delete saved/confirmed:

- Removes order from list/Hive.
- Clears current order if matching.

## Hive Persistence

Provider serializes:

- Products.
- Cart items, including product/stock JSON, group ids, reservations, sale-unit metadata, manual override, comments.
- Saved orders.
- Confirmed orders.

Adapters and boxes are initialized in `main.dart`.

Known persistence edge case:

- `SavedOrder` has `quotationId` and `quotationNumber`, but local Hive saved order schema does not persist these fields in the reported current code.

## Full Reset

`clearAllLocalData` clears products, cart, saved orders, confirmed orders, and product sync metadata, then resets in-memory collections and notifies.
