# PR #236 Review Feedback

Please address the following issues before this PR is merged. The overall approach is useful, but these edge cases can produce incorrect barcode labels or confusing behavior.

## 1. Base-product labels can use a variant's batch dates

### Example

Consider a T-shirt product with these stock records:

- Red T-shirt variant: manufacturing date January 1, expiry date December 31
- Blue T-shirt variant: no stock
- Base T-shirt row: no standalone stock

If the Red variant is the product's only stock record, printing the base **T-shirt** row can copy the Red variant's manufacturing and expiry dates. Those dates belong to the Red variant, not to the base product.

This is especially risky for food, medicine, cosmetics, and other batch-controlled products.

### Required fix

When printing the base row of a product that has variants, retain only stock records where `productVariantId == null`. If there is no unambiguous base stock record, leave the manufacturing and expiry dates empty.

Please add tests for:

- A base product with one stock record belonging to a variant
- A base product with one standalone stock record
- A base product with multiple standalone stock records

## 2. Multi-unit labels can print the wrong price

### Example

Suppose:

- One bottle costs 100
- One box contains 12 bottles
- The box has no explicit `price` or `resolvedPrice`

The existing billing logic calculates:

```text
Box price = 100 × 12 = 1,200
```

The new barcode logic can fall back directly to the base price and print:

```text
Bottle (BOX)
Price: 100
```

The correct box-label price is 1,200.

### Required fix

Barcode printing must reuse the existing sale-unit pricing rules used by billing. It should support the complete fallback chain, including conversion-rate calculation, rather than implementing a separate simplified rule.

Please add tests for:

- A sale unit with `resolvedPrice`
- A sale unit with an explicit `price`
- A sale unit with neither price, requiring `base price × conversion rate`

## 3. A variant with price or MRP equal to zero can print incorrectly

### Example

Suppose:

- Base shoe price: 300
- Red variant price: 0

The existing product logic treats zero as "no valid variant price" and falls back to the base price. Billing therefore charges 300.

The new barcode logic uses null checks only, so it can print:

```text
Red Shoe
Price: 0
```

The same problem applies to variant MRP.

### Required fix

Use the existing variant price and MRP resolution helpers. Only use a variant price or MRP when it is greater than zero; otherwise, use the established base-product fallback.

Please add tests for:

- Positive variant price and MRP
- Null variant price and MRP
- Zero variant price and MRP

## 4. Sale-unit selection keys can collide when IDs are missing

### Example

Consider a Rice product with two locally created sale units:

- Box, with no database ID yet
- Bag, with no database ID yet

The current keys can both become:

```text
unit:25:null
unit:25:null
```

The application then treats both rows as the same item. This can cause:

- Selecting Box to also visually select Bag
- One selected row to overwrite the other
- **Print Selected** to print the wrong unit or omit one unit

### Required fix

The selection key must remain unique when `saleUnit.id` is null. Use stable unit information such as the product ID, unit ID/name, barcode, and conversion rate as the fallback key.

Please add a test with two sale units that both have null database IDs and verify that they can be selected and printed independently.

## 5. Pagination happens before products are expanded into barcode rows

### Example

The provider paginates 20 parent products. The screen then expands every product into:

- One base row
- Variant rows
- Sale-unit rows

If each of the 20 products expands into four rows, page 1 displays 80 rows. Page 2 still calculates its starting serial number as 21 because pagination counted products rather than displayed barcode rows.

Users can therefore see behavior such as:

```text
Page 1: rows 1–80
Page 2: numbering starts around 21
```

The page size also becomes unpredictable and can hurt rendering performance.

### Required fix

Either paginate the final `BarcodeRow` collection or redesign row numbering and page-size behavior so they are based on the expanded rows, not the parent products.

Please test products with multiple variants and sale units across at least two pages.

## 6. Inactive variants participate in search but are removed from the results

### Example

Suppose an inactive Blue variant has:

```text
Barcode: BLUE-001
SKU: BLUE-SKU
```

The provider searches all variants and finds the parent product. The barcode screen then skips the inactive Blue variant. Finally, the exact-barcode filter removes the base row and other variants because they do not match `BLUE-001`.

The provider believes it found a product, but the screen has no printable rows. This can produce an empty table instead of a proper **No results** state.

Searching for the inactive variant's SKU can similarly return a parent product based on a retired SKU.

### Required fix

Only active variants should participate in variant-barcode and variant-SKU searches. Apply this consistently in:

- `LocalProductProvider`
- Restaurant product search
- Desktop product autocomplete
- Mobile product autocomplete

Please add tests proving that active variant identifiers are searchable and inactive variant identifiers are excluded.

## Expected before re-review

- Fix all six issues above
- Add regression tests for each edge case
- Run the focused barcode, variant, multi-unit, search, and pagination tests
- Include the test results in the PR description
