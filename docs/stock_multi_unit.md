# Stock + Multi Unit Scenarios

This document analyzes the current backend in `enkepos/` and explains how real supermarket POS scenarios should behave when:
- a product is purchased in one unit
- sold in another unit
- has multiple stock rows
- has wholesale pricing
- has barcode-based alternate sale units

This note is based on the current backend code and the current mobile billing flow.

Relevant backend files:
- `enkepos/app/Http/Controllers/Api/V1/ProductController.php`
- `enkepos/app/Services/CartService.php`
- `enkepos/app/Helper/Helper.php`
- `enkepos/app/Helper/CartHelper.php`
- `enkepos/app/Models/Product.php`
- `enkepos/app/Models/ProductStock.php`
- `enkepos/app/Models/ProductSaleUnit.php`
- `enkepos/app/Models/CartItem.php`

## High Level Backend Status

Your backend already supports more than the current mobile billing page is using.

### Already supported in backend

1. Product sale units
- `product_sale_units` table exists
- each sale unit stores:
  - `unit_id`
  - `conversion_rate`
  - `barcode`

2. Stock purchase unit linkage
- `product_stocks.purchase_unit_id` exists
- `product_stocks.purchase_qty` exists
- `purchase_unit_id` points to `product_sale_units.id`

3. Purchase-side conversion
- When stock is added using `purchase_unit_id` + `purchase_qty`, backend converts purchased quantity into base units before storing stock quantity.

4. Cart-side sale unit support
- `cart_items.product_sale_unit_id` exists
- `cart_items.conversion_rate` exists
- backend cart logic can preserve sale-unit-aware cart lines

5. Barcode resolution
- backend helper can resolve:
  - normal product barcode
  - sale-unit barcode
  - scale barcode

6. Wholesale support
- stock rows already store:
  - `wholesale_price`
  - `wholesale_min_unit`

### Not yet complete for product API / app contract

The backend stores useful stock-sale-unit data, but the product list API still does not expose enough billing-ready information for the mobile app to auto-resolve every real-world case safely.

Main missing pieces in product response:
- stock-level `purchase_unit_id`
- stock-level `purchase_qty`
- stock-to-sale-unit mapping in billing-friendly form
- sale-unit-specific pricing/tax context
- preferred stock or pricing-group hints for sale-unit scans

## Important Design Truth

There are two different business concepts:

1. Purchase unit
- How supplier sold the goods to us
- Example: we bought `7 Up` as `CASE`

2. Sale unit
- How customer buys from us
- Example: customer buys:
  - `1 PCS`
  - `1 PACK`
  - `1 CASE`

These are related, but they are not the same thing.

The app should not guess sale behavior from purchase behavior unless backend explicitly says that mapping is valid.

## Real World Supermarket Scenarios

## Scenario 1: Buy 7 Up as case, sell as pieces only

Example:
- Product: `7 Up 250ml`
- Base unit: `PCS`
- Sale units:
  - `CASE` = 24 PCS
- Purchase:
  - bought `10 CASE`
- Backend stores:
  - stock quantity = `240 PCS`

### Current backend handling

Purchase side:
- Correct.
- Backend converts `10 CASE` into `240 PCS` using `purchase_unit_id` + `purchase_qty`.

Billing side if mobile sends only product barcode:
- Correct for simple piece sale.
- Selling `1 PCS` deducts `1` from stock.

Billing side if mobile scans case barcode:
- Backend can support it if client sends `sale_unit_id`.
- Current mobile local billing does not send server-side cart sale-unit context.

### Correct handling

- Stock should remain in base quantity internally.
- Cart should preserve sale-unit identity when scanned as case.
- Example:
  - display: `1 CASE`
  - deduct stock: `24 PCS`

### Verdict

- Backend: correct and capable.
- Mobile billing: not fully using backend capability yet.

## Scenario 2: Buy 7 Up as case, sell as case or as pieces

Example:
- Purchase: `5 CASE`
- Conversion: `1 CASE = 24 PCS`
- Available stock: `120 PCS`
- Customer A buys `1 CASE`
- Customer B buys `3 PCS`

### Current backend handling

Backend model:
- Correct.
- This is exactly what base-quantity + sale-unit conversion is good at.

Backend cart API:
- Can support this correctly if request includes:
  - `product_id`
  - `quantity`
  - `sale_unit_id`
  - optional `stock_id`

Current mobile billing:
- Only partially correct.
- It converts sale-unit barcode into base quantity, but does not preserve cart identity as `CASE`.

### Correct handling

After scan of case barcode:
- cart line should say `1 CASE`
- stored base quantity should be `24`

After scan of piece barcode:
- cart line should say `3 PCS`
- stored base quantity should be `3`

### Verdict

- Backend: already capable.
- Product/cart contract from mobile should be improved.

## Scenario 3: Buy Coca-Cola as pack, sell as piece and wholesale by carton equivalent

Example:
- Base unit: `PCS`
- Sale units:
  - `PACK` = 6 PCS
  - `CASE` = 24 PCS
- Wholesale rule:
  - if customer buys `>= 48 PCS`, price changes

### Current backend handling

Backend stock model:
- can store `wholesale_price` and `wholesale_min_unit`

Current frontend local cart:
- applies wholesale threshold against selected stock quantity in base units

### Correct handling

This is correct if backend business rule is:
- wholesale threshold is always measured in base units

Example:
- 8 PACKS = 48 PCS
- wholesale should apply because total base quantity is 48

### Verdict

- Current quantity logic is conceptually correct if wholesale thresholds are base-unit thresholds.
- API should clearly document that `wholesale_min_unit` is in base units.

## Scenario 4: Same product has multiple stock layers with different cost, tax, expiry, and price

Example:
- `7 Up 250ml`
- Stock A:
  - 100 PCS
  - tax 0
  - retail 20
  - expiry in 5 months
- Stock B:
  - 24 PCS
  - tax 18
  - retail 18
  - bought as `CASE`
  - expiry in 2 months

### Current backend handling

Backend stores all this correctly as separate stock rows.

Current mobile flow:
- groups stock rows by pricing/tax/wholesale characteristics
- if multiple groups exist, user must choose

### What is good

- Safe, because user is forced to choose when pricing groups differ.

### What is not good

- Barcode alone is not enough for automatic billing decision.
- If scanned barcode is `CASE`, backend data currently stored is not enough in product response for app to deterministically auto-pick Stock B.

### Correct handling

API should tell client:
- which sale units are allowed on which stock rows
- or which pricing group belongs to which sale unit

### Verdict

- Backend storage: correct
- Product API contract: incomplete
- Mobile billing auto-resolution: not correct for this case

## Scenario 5: Buy as case, stock row is specifically linked to CASE purchase unit

Example:
- Product: `7 Up`
- `purchase_unit_id` on stock row points to sale unit `CASE`
- `purchase_qty = 10`

### Current backend handling

Backend stock creation:
- Correct.
- It stores `purchase_unit_id`
- It stores `purchase_qty`
- It converts quantity into base unit

### Problem

Current product response used by mobile billing usually does not expose:
- `purchase_unit_id`
- `purchase_qty`

So app cannot use that information for stock selection.

### Correct handling

Product API should include stock response like:

```json
{
  "id": 2286,
  "quantity": "240.000",
  "price": "18.000",
  "tax_rate": "18.00",
  "purchase_unit_id": 69,
  "purchase_unit_name": "CASE",
  "purchase_qty": "10.000"
}
```

### Verdict

- Backend DB/model: correct
- Product API exposure for billing: incomplete

## Scenario 6: Sale-unit barcode should directly produce a sale-unit-aware cart line

Example:
- Scan barcode of `1 CASE`
- conversion rate = `24`

### Current backend handling

Backend cart supports:
- `product_sale_unit_id`
- `conversion_rate`

`CartHelper::listCartItems()` can already return:
- `unit_name`
- `product_sale_unit`
- `conversion_rate`

That means backend can represent cart as:
- quantity `1`
- sale unit `CASE`
- base quantity internally derived by conversion

### Current mobile handling

- Mobile local cart is still mostly base-quantity-driven.
- It turns this into `24 PCS`.

### Correct handling

Billing should preserve both:
- sale quantity: `1 CASE`
- base quantity: `24 PCS`

### Verdict

- Backend cart model: already correct
- Mobile local billing: not using full backend capability

## Scenario 7: Buy 2 cartons, sell 1 pack, then 3 pieces

Example:
- `1 CARTON = 24 PCS`
- `1 PACK = 6 PCS`
- opening stock after purchase = `48 PCS`
- sell:
  - `1 PACK` => 6
  - `3 PCS` => 3
- remaining should be `39 PCS`

### Current backend handling

This is conceptually correct if all sale quantities are converted into base units before stock validation/deduction.

Backend cart validation already works this way:
- existing cart quantities are converted to base quantity
- new sale-unit quantity is converted to base quantity
- stock check is against total base quantity

### Verdict

- Backend logic: correct

## Scenario 8: Same product sold as piece, pack, and case with different selling prices

Example:
- 1 PCS = 10
- 1 PACK (6 pcs) = 55
- 1 CASE (24 pcs) = 200

This means sale unit is not just quantity conversion.
It is also pricing context.

### Current backend handling

Current `product_sale_units` stores only:
- unit
- conversion_rate
- barcode

It does not store:
- sale-unit retail price
- sale-unit MRP
- sale-unit tax override

Current backend cart can scale price by conversion rate, but that assumes:
- case price = piece price * conversion rate

That is not always true in retail.

### Correct handling

Sale unit should optionally store its own billing price:

```json
{
  "id": 69,
  "unit_name": "PACK",
  "conversion_rate": "6.00",
  "barcode": "111000127",
  "retail_price": "55.00",
  "mrp": "60.00"
}
```

### Verdict

- Current backend is only correct for linear pricing models.
- It is not sufficient for true retail pack pricing.

## Scenario 9: FIFO with multi-unit sales

Example:
- Stock A: older, 12 PCS
- Stock B: newer, 24 PCS
- Sell `1 CASE` = 24 PCS

### Current backend handling

Backend stock service has FIFO-style concepts in some areas.
Frontend local provider also sorts by expiry/date for grouped reservation.

But there is no complete product API contract telling mobile:
- which exact stock rows to consume first for a given sale-unit scan

### Correct handling

Best practice:
- backend should decide reservation/consumption order
- client should not guess FIFO for complex mixed-stock cases

### Verdict

- Current system is only partially deterministic for local-first mobile billing.

## Scenario 10: Tax-inclusive pricing with sale units

Example:
- Piece price already includes tax
- Pack price also includes tax
- Cart needs accurate tax split

### Current backend handling

Backend cart service:
- determines tax-inclusive price
- scales it for sale unit
- extracts tax after scaling

That is a good design.

### Verdict

- Backend cart flow is correct if sale-unit pricing is linear or provided explicitly.

## Scenario 11: Product with both variants and sale units

Example:
- `Chips`
- variants:
  - Salted
  - Masala
- sale units:
  - PCS
  - BOX

### Current backend handling

Backend cart service already includes variant-aware stock validation.

That means variant + sale unit + stock can coexist conceptually.

### What is needed

Product API should tell the client whether a sale unit is:
- valid for all variants
- or valid only for specific variants

### Verdict

- Backend structure can support this direction
- product response still needs richer mapping if client must automate it

## Scenario 12: Promotional supermarket pack

Example:
- `Buy 1 PACK of biscuits`
- pack barcode is different
- pack retail price is not equal to `piece_price * 6`
- pack may also map to specific stock batch

### Current backend handling

Not fully modeled in `product_sale_units`.

### Correct handling

If supermarket POS must support this properly, sale unit needs optional fields like:
- `retail_price`
- `mrp`
- `tax_rate`
- `stock_group_key`
- `preferred_stock_ids`

### Verdict

- Needs API/data-model enhancement

## What Backend Already Does Better Than Mobile

These are important because they show the backend is already ahead of the current app integration:

1. Sale unit barcode resolution
- `Helper` can resolve sale-unit barcode directly.

2. Cart item sale unit identity
- `CartItem` stores `product_sale_unit_id`
- `CartItem` stores `conversion_rate`

3. Cart API response can return unit-aware lines
- `CartHelper::listCartItems()` already includes `unit_name` and `product_sale_unit`

4. Conversion-aware stock validation
- `CartService` validates stock using base quantity after conversion

This means:
- if mobile used backend cart APIs directly for multi-unit billing,
- much of the complex logic could be centralized server-side.

## Where Product API Is Still Too Thin

Current product response is good for basic catalog display.
It is not rich enough for supermarket-grade billing automation.

### Recommended product response additions

#### On each sale unit

```json
{
  "id": 69,
  "unit_id": 7858,
  "unit_name": "CASE",
  "conversion_rate": "24.00",
  "barcode": "111000127",
  "retail_price": "200.00",
  "mrp": "220.00",
  "tax_rate": "18.00",
  "preferred_stock_ids": [2286],
  "pricing_group_key": "case_stock_group",
  "allowed_variant_ids": [],
  "display_label": "1 CASE = 24 PCS"
}
```

#### On each stock row

```json
{
  "id": 2286,
  "quantity": "240.000",
  "price": "18.000",
  "mrp": "20.000",
  "tax_rate": "18.00",
  "wholesale_price": "15.000",
  "wholesale_min_unit": 48,
  "purchase_unit_id": 69,
  "purchase_unit_name": "CASE",
  "purchase_qty": "10.000",
  "pricing_group_key": "case_stock_group",
  "supported_sale_unit_ids": [69, 70]
}
```

## Best Supermarket POS Contract

If you want this to behave correctly in a real supermarket POS, the clean rule is:

1. Stock is stored internally in base units
- always

2. Sale unit defines customer-facing selling identity
- `PCS`
- `PACK`
- `CASE`
- `BOX`

3. Product API must provide billing-ready metadata
- not just conversion metadata

4. Client should not infer sale-unit-to-stock mapping from purchase metadata
- unless backend explicitly includes that mapping in response

## Final Practical Recommendation

### Already correct today
- purchase conversion into base stock
- backend cart conversion-aware stock validation
- sale-unit barcode lookup
- wholesale thresholds in base-unit terms
- multi-stock storage

### Partially correct today
- mobile billing with sale-unit barcode + multiple stock groups
- cart display for sale-unit identity
- automatic stock choice for scanned alternate-unit barcodes

### Not correct enough yet for supermarket-grade automation
- sale-unit-specific pricing
- sale-unit-specific tax
- automatic stock resolution for alternate-unit barcode scans
- FIFO-safe automatic stock selection across mixed stock groups
- variant-aware sale-unit constraints in product response

## Example: 7 Up Supermarket Case

### Purchase
- Buy `10 CASE`
- `1 CASE = 24 PCS`
- backend stock becomes `240 PCS`

### Customer sales
- sell `2 PCS`
- sell `1 PACK` of 6
- sell `1 CASE`
- total base stock consumed = `2 + 6 + 24 = 32 PCS`
- remaining = `208 PCS`

### Correct system behavior
- UI may show:
  - `2 PCS`
  - `1 PACK`
  - `1 CASE`
- stock engine should always deduct:
  - `2`
  - `6`
  - `24`

That is the supermarket POS model you should optimize for.
