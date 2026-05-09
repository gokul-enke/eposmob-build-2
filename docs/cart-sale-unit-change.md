# Cart Sale Unit Change

## Goal

Allow the cashier to change a cart row between the product base unit and any configured sale unit after the item has already been added to the cart.

## Rule

The cart stores quantity and price in the product base unit. Changing the visible unit must not change the base quantity, stock reservation, or base price.

Example:

- Product base unit: `PCS`
- Sale unit: `CASE`
- Conversion rate: `12`
- Stored cart quantity: `24 PCS`

When the row is changed to `CASE`, the stored quantity remains `24`, but the cart displays `2 CASE`.

## Implementation

The safe transformation lives in `LocalProductProvider.changeCartItemSaleUnit`.

It receives the existing cart row identity:

- `productId`
- selected stock
- stock group ids
- current sale unit id

It receives the target unit metadata:

- `newSaleUnitId`
- `newSaleUnitName`
- `newSaleUnitConversionRate`

If the target metadata is omitted or invalid, the row becomes a base-unit row.

## What Is Preserved

- Base quantity
- Base price
- Base MRP
- Tax rate and tax amount
- Selected stock
- Stock group ids
- Stock reservations
- Manual price override flag
- Item comment

## Merging Behavior

Cart identity includes `saleUnitId`. If changing a row would create the same identity as another existing row, the provider merges into the target row.

Example:

- Existing row: `5 PCS`
- Existing row: `2 CASE`, stored as `24 PCS`
- Change `CASE` row to base unit
- Result: one row with `29 PCS`

This matches the existing add-to-cart behavior where duplicate cart identities are not kept as separate lines.

## Billing Page UI

The unit cell in `billing_page.dart` now shows a popup selector when the product has valid sale units.

The selector includes:

- The product base unit
- Each sale unit with a valid positive conversion rate

Selecting a unit calls `LocalProductProvider.changeCartItemSaleUnit`.

## Order Payload

`LocalProductProvider.buildOrderItemsPayloadFrom` already converts sale-unit rows back to display quantity and display price when sending the order payload.

After unit change:

- Base unit rows omit `sale_unit_id`
- Sale unit rows include `sale_unit_id`
- Quantity and price are sent in the selected display unit

## Tests

`test/sale_unit_cart_change_test.dart` verifies:

- Base row to sale unit keeps base quantity unchanged
- Sale unit row to base unit keeps base quantity unchanged
- Payload changes correctly after unit change
- Changing to an already existing unit identity merges rows
