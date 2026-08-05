# Purchase Order Tax Support - Backend Handoff

## Goal

The Flutter Create Purchase screen now supports two independent tax-inclusion settings:

1. `tax_include`
   - Shared by retail price and wholesale price.
2. `tax_include_purchase`
   - Used only by purchase rate.

The backend must accept, persist, return, and calculate these settings independently. This is especially important for purchase orders created now and received later.

## Temporary Flutter compatibility mode

Until this backend work is deployed, Flutter intentionally keeps
`tax_include` and `tax_include_purchase` synchronized and calculates purchase
order totals from the entered purchase rate, matching the current API.

After the backend implementation is deployed, inform the Flutter developer so
this temporary synchronization can be removed and independent purchase-tax
totals can be enabled.

## Current Flutter behavior

Flutter sends both fields on every purchase-order item:

```json
{
  "tax_include": true,
  "tax_include_purchase": false
}
```

Meanings:

- `true`: the entered price already includes tax.
- `false`: the entered price excludes tax, so tax must be added to obtain the effective price.

Retail and wholesale deliberately share `tax_include`. Purchase uses `tax_include_purchase`.

## Affected endpoints

### Create purchase order

```http
POST /api/v1/add-purchase-order
```

Each item can be pending (`receive: false`) or immediately received (`receive: true`).

Example item:

```json
{
  "product_id": 123,
  "quantity": 10,
  "unit_price": 100,
  "retail_price": 150,
  "wholesale_price": 130,
  "mrp": 160,
  "tax_include": true,
  "tax_include_purchase": false,
  "receive": false
}
```

Required validation:

```php
'items.*.tax_include' => 'boolean',
'items.*.tax_include_purchase' => 'boolean',
```

For backward compatibility:

```php
$taxInclude = (bool) ($row['tax_include'] ?? true);
$taxIncludePurchase = (bool) (
    $row['tax_include_purchase'] ?? $taxInclude
);
```

### List purchase orders

```http
GET /api/v1/list-purchase-order
```

Every returned item must include:

```json
{
  "unit_price": "100.000",
  "total_price": "1180.000",
  "calculated_purchase_rate": "118.000",
  "tax_include": true,
  "tax_include_purchase": false
}
```

`calculated_purchase_rate` is the effective tax-inclusive purchase rate. It can be calculated as:

```php
$calculatedPurchaseRate = $item->quantity > 0
    ? $item->total_price / $item->quantity
    : $item->unit_price;
```

The Flutter app uses these fields to restore both switches and display the correct purchase total when a pending order is reopened.

### Receive pending purchase order

```http
POST /api/v1/receive-purchase-order/{id}
```

Example item:

```json
{
  "purchase_item_id": 456,
  "quantity": 10,
  "unit_price": 100,
  "retail_price": 150,
  "wholesale_price": 130,
  "mrp": 160,
  "tax_include": true,
  "tax_include_purchase": false
}
```

Use the submitted values when present. Otherwise, fall back to the values persisted on the purchase item:

```php
$taxInclude = (bool) (
    $row['tax_include'] ??
    $purchaseItem->tax_include ??
    true
);

$taxIncludePurchase = (bool) (
    $row['tax_include_purchase'] ??
    $purchaseItem->tax_include_purchase ??
    $taxInclude
);
```

## Database changes

Add both flags to `purchase_items`. This is required because `product_stocks` does not exist yet for a pending purchase item.

Suggested migration:

```php
Schema::table('purchase_items', function (Blueprint $table) {
    $table->boolean('tax_include')
        ->default(true)
        ->after('total_price');

    $table->boolean('tax_include_purchase')
        ->default(true)
        ->after('tax_include');
});
```

Add both fields to `PurchaseItem::$fillable`:

```php
'tax_include',
'tax_include_purchase',
```

Recommended casts:

```php
protected $casts = [
    'tax_include' => 'boolean',
    'tax_include_purchase' => 'boolean',
];
```

The existing `product_stocks.tax_include_purchase` field should receive the purchase-specific value when stock is created.

## Calculation rules

The server should calculate tax using the product/category tax configuration. Client-provided tax amounts should not be treated as authoritative.

### Purchase rate

```php
[$purchaseTaxRate, $purchaseTax] = CartHelper::calculateTax(
    (float) $row['unit_price'],
    (int) $product->category_id,
    $product->id,
    $taxIncludePurchase
);

$effectivePurchaseRate = $taxIncludePurchase
    ? (float) $row['unit_price']
    : (float) $row['unit_price'] + $purchaseTax;

$lineTotal = $effectivePurchaseRate * $quantity;
```

Use `$lineTotal` for:

- `purchase_items.total_price`
- Purchase voucher subtotal/total
- Supplier balance and accounting calculations

Keep `purchase_items.unit_price` as the originally entered purchase rate. This allows the UI to show the entered value and its tax treatment accurately.

When received, store:

```php
'purchase_rate' => $effectivePurchaseRate,
'tax_amount_purchase' => $purchaseTax,
'tax_include_purchase' => $taxIncludePurchase,
```

### Retail and wholesale

Retail and wholesale both use `$taxInclude`:

```php
[$retailTaxRate, $retailTax] = CartHelper::calculateTax(
    (float) $row['retail_price'],
    (int) $product->category_id,
    $product->id,
    $taxInclude
);

[$wholesaleTaxRate, $wholesaleTax] = CartHelper::calculateTax(
    (float) $row['wholesale_price'],
    (int) $product->category_id,
    $product->id,
    $taxInclude
);
```

Do not use `tax_include` to calculate purchase tax when `tax_include_purchase` is supplied.

## Suggested backend files

- `app/Http/Controllers/Api/V1/PurchaseController.php`
- `app/Models/PurchaseItem.php`
- A new migration for the two `purchase_items` columns

## Acceptance cases

Assume purchase tax is 18%, entered purchase rate is `100`, and quantity is `2`.

### Case 1: Purchase rate includes tax

```json
{
  "tax_include_purchase": true
}
```

Expected:

- Effective purchase rate: `100`
- Purchase total: `200`
- Reopening the pending order shows the purchase switch enabled.

### Case 2: Purchase rate excludes tax

```json
{
  "tax_include_purchase": false
}
```

Expected:

- Purchase tax per unit: `18`
- Effective purchase rate: `118`
- Purchase total: `236`
- Reopening the pending order shows the purchase switch disabled.

### Case 3: Independent settings

```json
{
  "tax_include": true,
  "tax_include_purchase": false
}
```

Expected:

- Retail and wholesale are treated as tax-inclusive.
- Purchase rate is treated as tax-exclusive.
- Purchase tax behavior must not change when the selling-price switch changes.

### Case 4: Pending order lifecycle

1. Create an order with `receive: false`.
2. List or fetch the order again.
3. Confirm both flags are returned unchanged.
4. Receive the order.
5. Confirm the created stock, voucher total, and supplier/accounting amount use the effective purchase rate.

### Case 5: Older clients/orders

When `tax_include_purchase` is absent, fall back to `tax_include`. Existing clients must continue to work without validation errors.
