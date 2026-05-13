# Multi Sale Unit Billing Scenarios

This note explains how multi-sale-unit products behave in the billing page today, what is already correct, what is still incomplete, and what the product API should ideally return so the app does not have to guess.

Relevant app code today:
- `lib/models/get_product.dart`
- `lib/providers/local_product_provider.dart`
- `lib/helpers/product_cart_helper.dart`
- `lib/widgets/stock_selection_modal.dart`
- `lib/screens/billing/billing_page.dart`

## Current Data Model Status

The app already parses these product-level fields correctly from the product API:
- `product_id`
- `category_id`
- `product_name`
- `barcode`
- `unit`
- `price.base_price`
- `mrp`
- `purchase_price`
- `taxes`
- `stock`
- `sale_units`
- `sellable`
- `purchasable`
- `names`

The app already parses these stock-level fields correctly:
- `id`
- `store_id`
- `store_name`
- `quantity`
- `price`
- `mrp`
- `unit`
- `tax_rate`
- `purchase_price`
- `date`
- `expiry_date`
- `wholesale_price`
- `wholesale_min_unit`

The app already parses these sale-unit fields correctly:
- `unit_id`
- `unit_name`
- `conversion_rate`
- `barcode`

## What Is Already Correct

These parts are already working as expected:

1. Product fetch and sync
- `sale_units` from API are stored in the product model.
- Both normal sync and store bootstrap use the same product fetch path, so multi-sale-unit data is persisted locally.

2. Barcode lookup
- Local barcode indexing now includes both the main product barcode and each `sale_units[].barcode`.
- This means scanning a sale-unit barcode can find the product locally.

3. Multi-stock grouping
- Multiple stock rows are grouped by effective pricing characteristics.
- If there is only one pricing group, the app auto-selects it.
- If there are multiple pricing groups, the app shows the stock selection modal.

4. Wholesale pricing
- Wholesale pricing is already applied from the selected stock when quantity reaches `wholesale_min_unit`.
- If quantity is below minimum, regular stock price is used.

5. Sale-unit barcode quantity conversion
- Billing now recognizes when the scanned barcode belongs to a `sale_unit`.
- It converts the scanned sale unit to base quantity using `conversion_rate`.

Example:
- Product base unit: `PCS`
- Sale unit: `DZ`
- Conversion rate: `12`
- Scanning `DZ` barcode adds quantity `12`

That part is correct if the business rule is: "sale unit barcode means add converted base-unit quantity."

## Real World Scenarios

### Scenario 1: Single stock, single sale unit

Example:
- Base unit: `PCS`
- Sale unit: `DZ`
- Conversion rate: `12`
- One stock row only
- Stock price: `5`

Current handling:
- Correct.
- Scanning the `DZ` barcode finds the product.
- Billing converts it to quantity `12`.
- Stock selection is skipped because only one pricing group exists.
- Price comes from that selected stock.

Correct handling:
- Same as current.

Verdict:
- Already correct.

### Scenario 2: Single stock, multiple sale units

Example:
- Base unit: `PCS`
- Sale units:
  - `DZ` = 12
  - `PACKS` = 30

Current handling:
- Correct in a quantity-conversion sense.
- `DZ` barcode adds `12`
- `PACKS` barcode adds `30`

What is missing:
- Cart line still behaves like base product quantity, not "1 DZ" or "1 PACKS".

Correct handling:
- Either of these is valid:
  - Option A: show `12 PCS` and keep logic simple
  - Option B: show `1 DZ` / `1 PACKS` in UI while reserving base units internally

Verdict:
- Logic is acceptable.
- Presentation can be improved.

### Scenario 3: Multiple stock rows, same effective pricing

Example:
- Two stock rows in same store
- Same price, tax, mrp, wholesale settings
- One sale-unit barcode scanned

Current handling:
- Correct.
- App groups those stocks into one pricing group.
- It auto-selects the group and reserves from the grouped stock pool.
- Quantity conversion from sale unit still works.

Correct handling:
- Same as current.

Verdict:
- Already correct.

### Scenario 4: Multiple stock rows, different pricing groups

Example from your payload:
- Stock `2285`: qty `1000`, price `150`, tax `0`
- Stock `2286`: qty `30`, price `2`, tax `18`
- Sale unit `PACKS` barcode = `111000127`
- Conversion rate = `30`

Current handling:
- Partially correct, but not business-safe.
- Scanning `111000127` converts to quantity `30`.
- Then `ProductCartHelper` checks stock groups.
- Because pricing groups differ, the app shows stock selection modal.
- User must manually choose which stock group to use.

Why this is a problem:
- The scanned sale-unit barcode suggests a very specific sale context.
- But the app still does not know which stock row the barcode is intended for.
- If user chooses the wrong stock group, price/tax/wholesale behavior may be wrong.

Correct handling:
- API should tell the app which stock or which stock type is valid for that scanned sale unit.
- Billing should auto-resolve the proper stock group when the barcode belongs to a known sale unit.

Verdict:
- Not fully correct.
- Current behavior is safe only because it asks the user to choose.
- It is not automatic or deterministic.

### Scenario 5: Sale unit barcode should prefer matching stock purchase unit

Example:
- Sale unit scanned: `PACKS`
- Matching stock row has `purchase_unit_id = PACKS`
- Other stock row is generic `PCS`

Current handling:
- Not handled.
- The app does not parse or use `purchase_unit_id`.
- So it cannot prefer the stock row that represents pack-based stock.

Correct handling:
- Billing should detect:
  - scanned sale unit = `PACKS`
  - stock row unit mapping = `PACKS`
- Then auto-select that stock row or its pricing group.

Verdict:
- Not correct today.

### Scenario 6: Sale unit barcode with wholesale threshold

Example:
- Sale unit `PACKS` conversion rate = `30`
- Selected stock has:
  - normal price = `2`
  - wholesale price = `1`
  - wholesale min qty = `100`

Current handling:
- Correct after stock selection is resolved.
- If quantity is `30`, wholesale does not apply.
- If quantity later reaches `100`, price can switch to wholesale.

Important detail:
- Wholesale is evaluated on final cart quantity against the selected stock.
- It is not evaluated on "number of packs scanned", but on base-unit quantity in cart.

Correct handling:
- Usually this is correct, if backend defines wholesale thresholds in base units.

Verdict:
- Correct, assuming wholesale thresholds are base-unit thresholds.

### Scenario 7: Sale unit barcode with mixed tax across stock rows

Example:
- Stock A tax rate = `0`
- Stock B tax rate = `18`
- Same product, same sale unit barcode scanned

Current handling:
- Not deterministic automatically.
- If app asks user to choose stock, tax becomes correct after selection.
- But app cannot auto-pick tax correctly from barcode alone.

Correct handling:
- API should tell which stock context or pricing context belongs to that sale-unit barcode.

Verdict:
- Partially correct only because user must choose manually.

### Scenario 8: Sale unit barcode should display sale-unit identity in cart

Example:
- Scan `PACKS` barcode once
- Backend meaning: 1 pack = 30 pcs

Current handling:
- Cart stores base product with quantity `30`
- It does not retain "user scanned PACKS"

Correct handling:
- Cart line should preserve:
  - scanned sale unit id
  - scanned sale unit name
  - scanned sale quantity = 1
  - base quantity = 30

Verdict:
- Not fully correct if business/UI needs sale-unit-aware cart display.

### Scenario 9: Manual quantity edits after scanning a sale-unit barcode

Example:
- User scans `DZ` barcode, app adds `12`
- Then user increments quantity in cart

Current handling:
- App treats the item as base-unit quantity.
- After that, it no longer knows it came from `DZ`.

Correct handling:
- Depends on business rule:
  - If cart is base-unit-driven, current behavior is acceptable.
  - If cart must preserve sale-unit identity, app needs extra cart metadata.

Verdict:
- Acceptable only for base-unit-driven design.

## Summary Matrix

| Scenario | Current Status | Notes |
|---|---|---|
| Product fetch includes sale units | Correct | Already parsed and synced |
| Billing can find sale-unit barcode | Correct | Local barcode index supports it |
| Sale-unit scan converts quantity | Correct | Uses `conversion_rate` |
| Single stock + sale unit | Correct | Works well |
| Multiple equivalent stocks | Correct | Grouping works |
| Wholesale price after stock chosen | Correct | Uses selected stock threshold |
| Multiple stock groups with different pricing | Partial | User must choose manually |
| Auto-link sale unit to correct stock row | Not correct | Missing API guidance |
| Cart shows scanned sale-unit identity | Not correct | Current cart becomes base quantity only |
| `purchase_unit_id` based resolution | Not correct | Not parsed/used |

## What The Product API Should Return

You mentioned you do not want the app to manually map with purchase data. That is the right approach. The product API should provide enough billing-ready information directly.

### Minimum recommended additions

Each `sale_unit` should include fields that make billing deterministic:

```json
"sale_units": [
  {
    "id": 69,
    "unit_id": 7858,
    "unit_name": "PACKS",
    "conversion_rate": "30.00",
    "barcode": "111000127",
    "price": "60.00",
    "mrp": "200.00",
    "tax_rate": "18.00",
    "is_base_unit": false,
    "billing_quantity": "1.00",
    "base_quantity": "30.00",
    "preferred_stock_ids": [2286],
    "stock_group_key": "pack_stock_group",
    "display_label": "1 PACKS = 30 PCS"
  }
]
```

### Why these are needed

- `price`
  - So billing does not need to infer price from unrelated stock rows.
- `mrp`
  - So sale-unit-specific selling context is explicit.
- `tax_rate`
  - So tax is not guessed from whichever stock row user picks.
- `is_base_unit`
  - So app can distinguish real alternate sale units from the base unit row.
- `billing_quantity`
  - Useful when UI wants to show `1 PACKS`.
- `base_quantity`
  - Explicit converted quantity used for stock deduction.
- `preferred_stock_ids`
  - Lets app auto-resolve valid stock rows for this sale unit.
- `stock_group_key`
  - Lets app map sale unit to a pricing group even if stock ids change.
- `display_label`
  - Useful for UI without rebuilding labels on app side.

## Recommended Stock API Additions

If stock rows are intended to serve different sale-unit contexts, API should also expose billing-safe fields on each stock row:

```json
"stock": [
  {
    "id": 2286,
    "price": "2.000",
    "mrp": "200.000",
    "tax_rate": "18.00",
    "quantity": "30.000",
    "purchase_unit_id": "PACKS",
    "purchase_qty": "1.000",
    "sale_unit_ids": [69],
    "billing_role": "sale_unit_specific",
    "pricing_group_key": "pack_stock_group"
  }
]
```

### Why these are needed

- `sale_unit_ids`
  - Direct mapping from stock row to supported sale units.
- `billing_role`
  - Helps distinguish generic stock from sale-unit-specific stock.
- `pricing_group_key`
  - Gives a stable API-driven grouping instead of app-generated grouping.

## Best API Shape For Billing

The cleanest design is this:

1. Product API returns billing-ready sale units
- Every sale unit already includes quantity conversion, price, tax, and preferred stock mapping.

2. Billing page scans barcode
- If barcode matches product barcode: use base unit flow.
- If barcode matches sale-unit barcode: use sale-unit flow directly.

3. App does not guess
- No app-side mapping from `purchase_unit_id`
- No app-side interpretation of purchase metadata
- No manual stock inference when API could tell it directly

## Recommended Correct Billing Behavior

For a scanned sale-unit barcode, the correct flow should be:

1. Find product by barcode.
2. Find exact sale unit by barcode.
3. Read sale-unit-specific billing config from API.
4. Resolve stock automatically using `preferred_stock_ids` or `pricing_group_key`.
5. Add cart line with:
- product id
- scanned barcode
- sale unit id
- sale unit name
- sale quantity = `1`
- base quantity = converted quantity
- price/tax/mrp from resolved sale-unit billing context

## Final Recommendation

If your billing design is base-quantity-driven only, current implementation is already good enough for:
- simple sale-unit scanning
- stock grouping
- wholesale thresholds on selected stock

If your billing must be fully correct for real-world multi-stock + multi-sale-unit pricing/tax contexts, the API should provide:
- sale-unit-specific billing price
- sale-unit-specific tax
- sale-unit-specific preferred stock mapping
- optional sale-unit-specific pricing group key

That will keep the app simple, predictable, and aligned with backend rules.
