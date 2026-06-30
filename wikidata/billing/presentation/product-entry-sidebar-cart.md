# Product Entry, Sidebar, And Cart Logic

Sources:

- `lib/features/billing/presentation/pages/billing_page.dart`
- `lib/helpers/product_cart_helper.dart`
- `lib/helpers/cart_quantity_stock_helper.dart`
- `lib/widgets/compact_quantity_control_local.dart`
- `lib/features/billing/presentation/widgets/price_fields.dart`
- `lib/widgets/stock_selection_modal.dart`

## Product Entry Modes

The header entry area changes based on `appSettings.barcodeSales`.

When barcode sales is enabled:

- Barcode field is the primary autofocus target.
- Submitting barcode calls `processBarcode`.
- A selected product name field is shown read-only after product selection.

When barcode sales is disabled:

- Product autocomplete is the primary entry.
- Selection routes through product selection logic and usually adds to cart directly.

The Add Item button:

- Reads `LocalProductProvider.selectedProduct`.
- Parses quantity and custom unit price.
- Calls `ProductCartHelper.handleProductSelection` with `customPrice` only when price is positive.
- Clears product fields and focus after success.
- Shows an error when no product is selected.

The Clear Entry button resets selected product, quantity/price fields, selected product name, provider selected product, and then focuses the entry field.

## Barcode Queue

`processBarcode` enqueues scans. `_enqueueBarcode` serializes events with `_isProcessingBarcode`, so rapid scanner input is processed one barcode at a time.

Processing behavior:

- Empty barcode is ignored with an invalid-barcode message.
- Normal barcode calls `LocalProductProvider.filterProductByBarcode`.
- Embedded barcode format is detected when value starts with `000` and length is `14`.
- Embedded product code is `query.substring(3, 9)`.
- Embedded quantity/weight segment is the last five digits.
- For KG/KGS sale units, quantity is parsed as first two digits plus last three digits as grams.
- For PC/PCS sale units, quantity is parsed as an integer count.
- Sale-unit barcode match can set selected sale unit and conversion rate.
- Matched product is added through `ProductCartHelper.handleProductSelection`.
- Missing product opens `AddProductWithBarcodeModal` with the scanned barcode and `isAddToCart: true`.
- Success and failure both clear barcode input and restore focus.

Important: if multiple products match a barcode, the page uses the first product.

## ProductCartHelper Selection Logic

`ProductCartHelper.handleProductSelection` is the central add-to-cart entry point.

It resolves effective customer data from parameters first, then falls back to `CustomerSelectionProvider`.

It reads:

- `LocalProductProvider`
- `GeneralSettingsProvider`
- `StoreSessionProvider`
- `MasterDataProvider`
- active store

Stock logic:

- Reads `generalSettings.stockEnabled`.
- Updates `LocalProductProvider.setStockEnabled`.
- Mirrors active stock grouping fields into `LocalProductProvider.setActiveStockGroupingFields`.
- If stock is disabled or product has no stock, uses product base price/MRP.
- If stock is enabled, filters stock options by active store and positive quantity.
- Groups stock using `groupStocksByPricing`.
- If exactly one stock pricing group exists, auto-selects that group.
- If selected sale unit has matching purchase-unit stocks and exactly one preferred group can cover requested quantity, auto-selects that preferred group.
- If multiple groups remain, opens `StockSelectionModal`.
- If stock selection is cancelled, add-to-cart aborts.
- If selected stock cannot cover requested sale-unit quantity, add-to-cart aborts with an error.

Price logic:

- Explicit custom price marks the cart item as manual price override.
- If product already exists in cart with same product, stock/group identity, and sale unit, helper preserves the existing custom price/MRP by passing `null` for price/MRP.
- New items use resolved stock/product price and MRP.

Final mutation:

- Calls `LocalProductProvider.addToCart`.
- Passes product, quantity, resolved price/MRP, selected stock, stock group ids, manual override flag, sale unit id/name/conversion.
- Shows "Added To Cart".

## Stock Grouping Modal

`StockSelectionModal` groups stock by pricing attributes before display.

Default grouping fields are:

- `price`
- `unit`

`MasterDataProvider.activeStockGroupingFields` can change the grouping key. Supported key fields include price, MRP, purchase price, unit, HSN code, tax rate, wholesale price, and wholesale minimum unit.

`CombinedStock.firstStock` chooses the earliest expiry date first, then earliest stock date, then lowest stock id.

Returning a combined stock also returns `originalStocks`, and their ids become `stockGroupIds` for reservation and cart identity.

## Sidebar Product And Orders Logic

Products tab:

- Reads `LocalProductProvider.sellableProducts`.
- Uses `SideBarProductList` for product cards.
- Empty state can trigger product refresh and full sync.

Orders tab:

- Shows saved orders from local provider.
- Selecting a saved order while cart has items first calls `_saveCurrentCartAsDraft`.
- Then `_loadSavedOrderForEditing` loads the chosen order and rehydrates page state.

## Cart Unit Selector

Each row can switch between base unit and product sale units.

Rules:

- `_parseSaleUnitRate` parses positive conversion rate only.
- `_validSaleUnitsForCartItem` keeps valid sale units and removes duplicates by id.
- Base unit option uses current base/product unit label.
- Sale unit options use sale unit id/name/conversion.
- Selecting base calls `LocalProductProvider.changeCartItemSaleUnit` with null target metadata.
- Selecting sale unit calls the same provider method with sale unit id/name/rate.
- Failure means insufficient stock or invalid selection and shows an error.

The unit menu supports mouse and keyboard:

- Up/down cycles options.
- Enter/space selects.
- Esc closes.
- Tab closes and moves cart focus.

## Cart Table Columns

Cart rows come from `LocalProductProvider.getCartItems`.

Conditional columns/settings:

- Item code column from app settings.
- Tax rate and tax amount columns from app settings.
- MRP column from app settings.
- Product detail icon from role permission `billing.product.view`.
- Customer purchase history icon only when purchase history setting is enabled and a non-default customer is selected.

Row behaviors:

- Product name cell can open product details.
- Unit cell opens unit selector.
- Quantity cell uses `CompactQuantityControlLocal`.
- Tax cell is read-only `TaxTextField`.
- MRP cell uses `MrpTextField`.
- Price cell uses `PriceTextField`.
- Tax amount uses inclusive extraction: `(price * quantity * taxRate) / (100 + taxRate)`.
- Total cell is `price * quantity`.
- Remove icon calls `LocalProductProvider.removeFromCart` with product id, selected stock, stock group ids, and sale unit id.

## Cart Keyboard Mode

The cart table is a single focus stop with internal row/cell selection.

Keys:

- Arrow up/down changes row.
- Arrow left/right changes cell.
- Enter/space triggers selected cell action.
- Delete removes selected item.
- `+` increases quantity through stock-aware helper.
- `-` decreases quantity through stock-aware helper.
- `h` opens purchase history for selected row when allowed.
- Tab moves across cells and rows; reverse tab moves backward.

Cell actions:

- Cell 0: product details.
- Cell 1: unit menu.
- Cell 2: quantity edit request.
- Cell 3: price edit request.
- Cell 4: remove item.

## Quantity Control

`CompactQuantityControlLocal` displays quantity in sale-unit display units, but syncs base quantity to the provider.

Behavior:

- Plus/minus changes display quantity.
- Text field supports hardware and virtual keyboard input.
- On edit commit or debounce, calls `CartQuantityStockHelper.syncCartItemQuantity`.
- It converts display quantity to base quantity with `LocalCartItem.toBaseQuantity`.
- It converts provider base quantity back to display quantity with `toDisplayQuantity`.
- It avoids overwriting typed text while user is editing.
- External edit/refresh request ids let the page focus or refresh a specific cart row.

## Stock-Aware Quantity Changes

`CartQuantityStockHelper.syncCartItemQuantity` handles increases/decreases.

If quantity decreases, stock is disabled, or item has no selected stock:

- It directly calls `LocalProductProvider.setCartItemQuantity`.

If quantity increases with stock enabled:

- It first uses available quantity from the current selected stock/group.
- For sale units, it snaps additional quantity to the sale-unit base step.
- If current stock cannot cover the increase, it asks for alternative stock options.
- If one alternative group exists, it auto-selects it.
- If multiple groups exist, it opens `StockSelectionModal`.
- Each selected stock/group gets its own `addToCart` call, preserving item price/MRP/manual override/sale unit.
- If no stock is available, it reports a blocked message.

## Price, MRP, And Tax Fields

`PriceTextField`:

- Shows sale-unit display price when item has sale unit.
- Converts entered display price back to base price before provider update.
- Updates provider immediately on text change.
- On blur or submit, enforces `LocalProductProvider.minimumSalePriceForProduct`.
- If below floor, it clamps to the minimum, updates provider, and shows an error.
- Arrow up/down increments/decrements price by 1.
- Tab commits and ends editing.

`MrpTextField`:

- Shows sale-unit display MRP when available.
- Converts entered display MRP back to base MRP.
- Updates provider on change and submit.
- Empty text is allowed during editing and stores 0.

`TaxTextField`:

- Displays tax rate only.
- It is read-only and disabled in the current widget.

## Customer Purchase History From Cart

Purchase history action requires:

- Setting enabled.
- Non-default selected customer.
- Product id.
- Access token.

It fetches last purchases through `CustomerPurchaseProvider`, shows the modal, and can apply a selected old price to the cart row.

When applying a history price:

- If the selected entry says to keep current price, no update is made.
- Otherwise the price is checked against `minimumSalePriceForProduct`.
- Valid price calls `LocalProductProvider.updateItemPrice` with stock/group/sale-unit identity.
