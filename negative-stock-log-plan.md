# Negative Stock Log & Report — Implementation Plan

## Problem

A salesman sometimes forgets to enter stock even though the goods are physically
in the shop. He then bills more quantity than the system shows. Today that sale
**silently deducts nothing at all** — there is no record that the shop sold
goods it never registered.

Example:

| Step | Action | System stock | Reality |
|---|---|---|---|
| 1 | Stock created | 5 | 5 |
| 2 | Sale of 3 | 2 | 2 |
| 3 | Sale of 3 | **2 (unchanged!)** | −1 short |

We need step 3 to deduct the available 2, drive stock to 0, and record a
**shortage of 1** that shows up in a dedicated Negative Stock Report.

## Root cause

`Helper::adjustStock()` — [app/Helper/Helper.php:297-320](../app/Helper/Helper.php#L297-L320)

```php
} else {
    // Decrement stock
    if ($stock->quantity >= $quantity) {   // 2 >= 3 is FALSE
        $stock->quantity -= $quantity;
        ...
        return true;
    }
}
return false;   // ← nothing deducted, caller ignores this
```

Two separate defects:

1. **All-or-nothing per row.** If no single stock row covers the full quantity,
   nothing is deducted. A request for 3 against two batches of 2 + 2 also fails.
2. **Return value ignored.** The sale call site at
   [CreateOrderPage.php:1436](../app/Filament/Tenant/Resources/OrderResource/Pages/CreateOrderPage.php#L1436)
   does not check the `false`. The order saves; the stock leak is invisible.

Note the same gap exists in purchase returns at
[CreatePurchaseReturn.php:736](../app/Filament/Tenant/Pages/CreatePurchaseReturn.php#L736),
which only writes a `\Log::warning` and drops the shortage. Out of scope here,
but the new helper below can be reused there later.

## Storage decision: `product_stock_logs`

Use the **existing `product_stock_logs` table**. No new table, no migration.

Reasons:

- `product_id` is a real indexed column (`['product_id', 'created_at']` index),
  so "shortages for product X" is a direct query. `stock_logs` has no
  `product_id` at all and would need a schema change plus a join through
  `source_stock_entry_id → product_stocks`.
- `action` is a plain `string`, not an enum — `negative_stock` needs no
  `ALTER TABLE`. `stock_logs.type` is a MySQL ENUM requiring a raw-SQL migration.
- There is already precedent for using it as a movement log with a custom
  action and human-readable reason:
  [CreatePurchaseReturn.php:718](../app/Filament/Tenant/Pages/CreatePurchaseReturn.php#L718)
  writes `action = 'return_adjustment'`.
- It already carries `store_id`, `user_id`, `reason`, `notes`, `ip_address`,
  `company_id`, and `reference_type`/`reference_id` for tracing back to the Order.

### Known trade-offs (accepted)

- **Split from the ledger.** Sales deductions write `adjust_stock` rows to
  `stock_logs` via the event system; the shortage will live in
  `product_stock_logs`. The two halves of one sale sit in different tables.
  Acceptable because the shortage is its own standalone report, not part of the
  historical stock replay in
  [CompanyStocks.php:107](../app/Filament/Tenant/Pages/CompanyStocks.php#L107).
- **`product_id` is `NOT NULL` with `onDelete('cascade')`.** Deleting a product
  erases its shortage history. Flagged, not fixed — changing the FK is a
  separate decision.

### Row shape

| Column | Value |
|---|---|
| `product_id` | the product short-billed |
| `store_id` | store where the sale happened |
| `user_id` | `auth()->id()` — **the salesman**, the key audit field |
| `type` | `'automatic'` |
| `action` | `'negative_stock'` |
| `old_values` | `{"quantity": 2}` — balance before |
| `new_values` | `{"quantity": 0}` — balance after |
| `changed_fields` | `["quantity"]` |
| `reason` | `"Sale exceeded available stock - short by 1"` |
| `notes` | JSON: `{"requested":3,"available":2,"deducted":2,"shortage":1,"product_variant_id":null}` |
| `reference_type` | `App\Models\Order::class` |
| `reference_id` | order id |
| `company_id` | `Helper::tenantId()` |

Pass `old_values` / `new_values` / `changed_fields` as **plain arrays** — the
model casts them to `array` and encodes automatically. Do not `json_encode()`
them manually; `CreatePurchaseReturn` does and produces double-encoded JSON that
the model's accessors have to defensively decode
([ProductStockLog.php:107-115](../app/Models/ProductStockLog.php#L107-L115)).

## Implementation

### Step 1 — Add the logging helper

New method on `Helper` (or a small `NegativeStockLogger` service). Keeps the
payload shape in one place so the sale path and any future caller agree.

```php
public static function logNegativeStock(
    int $productId,
    float $requested,
    float $deducted,
    float $shortage,
    ?int $storeId = null,
    ?int $productVariantId = null,
    ?string $referenceType = null,
    ?int $referenceId = null
): void {
    ProductStockLog::create([
        'product_id'     => $productId,
        'store_id'       => $storeId,
        'user_id'        => auth()->id(),
        'type'           => 'automatic',
        'action'         => 'negative_stock',
        'old_values'     => ['quantity' => $deducted],
        'new_values'     => ['quantity' => 0],
        'changed_fields' => ['quantity'],
        'reason'         => "Sale exceeded available stock - short by {$shortage}",
        'notes'          => json_encode([
            'requested'          => $requested,
            'available'          => $deducted,
            'deducted'           => $deducted,
            'shortage'           => $shortage,
            'product_variant_id' => $productVariantId,
        ]),
        'reference_type' => $referenceType,
        'reference_id'   => $referenceId,
        'ip_address'     => request()?->ip(),
        'company_id'     => Helper::tenantId(),
    ]);
}
```

### Step 2 — Fix `Helper::adjustStock()` decrement branch

Replace lines 297-320. Deduct across batch rows until satisfied, then log the
remainder. This fixes the multi-batch bug at the same time.

```php
} else {
    // Decrement stock across batches (FIFO by created_at)
    $remaining     = $quantity;
    $lastStock     = null;
    $resolvedStore = $storeId;

    foreach ($stocks as $stock) {
        if ($remaining <= 0) {
            break;
        }

        $oldQuantity = $stock->quantity;
        $take        = min($stock->quantity, $remaining);

        if ($take <= 0) {
            continue;
        }

        $stock->quantity -= $take;
        $stock->save();
        $remaining -= $take;

        $lastStock     = $stock;
        $resolvedStore = $resolvedStore ?? $stock->store_id;

        event(new StockAdjusted(
            $stock,
            $oldQuantity,
            $stock->quantity,
            auth()->id(),
            ['user_id' => auth()->id(), 'company_id' => $stock->company_id],
            'sale'
        ));
    }

    if ($remaining > 0) {
        self::logNegativeStock(
            $productId,
            $quantity,
            $quantity - $remaining,
            $remaining,
            $resolvedStore,
            $productVariantId
        );
    }

    return true;   // sale proceeds; shortage recorded
}
```

**Also fix the early return at line 272.** When the product has *no* stock rows
at all, the method returns `false` before reaching the loop — that is the
salesman's exact case (stock never entered). Log the full quantity as shortage
there instead of returning silently:

```php
if (!$product || $product->productStocks->isEmpty()) {
    self::logNegativeStock($productId, $quantity, 0, $quantity, $storeId, $productVariantId);
    return false;
}
```

Guard this so it only fires on decrement (`$increment === false`) — an increment
against a product with no rows is a different situation.

### Step 3 — Pass the Order reference

`adjustStock()` does not currently know the order. Add two optional trailing
parameters (`$referenceType`, `$referenceId`) and pass them from
[CreateOrderPage.php:1436](../app/Filament/Tenant/Resources/OrderResource/Pages/CreateOrderPage.php#L1436):

```php
Helper::adjustStock(
    $cartItem->product_id,
    $deductionQty,
    false,
    $cartItem->product_stock_id,
    $cartItem->product_variant_id,
    $this->store_id,
    Order::class,
    $order->id
);
```

Optional trailing params keep the other ~8 call sites working unchanged
(`OrderHelper`, `OrderController`, `CreateSalesReturn`, `OrderImport`, etc.).

Without this the report still works — it just can't link a shortage to its
invoice. Recommended, but it can ship in a second pass.

### Step 4 — Build the Negative Stock Report page

New `app/Filament/Tenant/Pages/NegativeStockReport.php`, modelled on
[NonStockReport.php](../app/Filament/Tenant/Pages/NonStockReport.php).

```php
class NegativeStockReport extends Page implements HasTable
{
    use InteractsWithTable, HasPageShield, HasExportableTableColumns;

    protected static ?string $navigationGroup = 'Stock Reports';
    protected static ?int $navigationSort = 4;
    protected static string $view = 'filament.tenant.pages.negative-stock-report';
    protected static ?string $title = 'Negative Stock Report';
```

Query:

```php
ProductStockLog::query()
    ->where('product_stock_logs.action', 'negative_stock')
    ->where('product_stock_logs.company_id', Helper::tenantId())
    ->leftJoin('products', 'product_stock_logs.product_id', '=', 'products.id')
    ->leftJoin('stores', 'product_stock_logs.store_id', '=', 'stores.id')
    ->leftJoin('users', 'product_stock_logs.user_id', '=', 'users.id')
    ->select(
        'product_stock_logs.*',
        'products.name as product_name',
        'products.barcode',
        'stores.name as store_name',
        'users.name as user_name',
    )
```

Columns:

| Column | Source |
|---|---|
| Date & Time | `created_at` |
| Product | `product_name` |
| Barcode | `barcode` |
| Store | `store_name` |
| Salesman | `user_name` |
| Requested Qty | `notes → requested` |
| Available Qty | `notes → available` |
| **Shortage Qty** | `notes → shortage` — badge, `danger`, default sort |
| Invoice | `reference_id` → link to order |
| Reason | `reason` |

Extract the `notes` values with a `getStateUsing()` closure:

```php
TextColumn::make('shortage')
    ->label('Shortage Qty')
    ->getStateUsing(fn ($record) => data_get(json_decode($record->notes, true), 'shortage', 0))
    ->badge()
    ->color('danger'),
```

To make Shortage **sortable and searchable in SQL**, sort on the JSON path
instead of the accessor:

```php
->sortable(query: fn (Builder $q, string $dir) => $q->orderByRaw(
    "CAST(JSON_UNQUOTE(JSON_EXTRACT(product_stock_logs.notes, '$.shortage')) AS DECIMAL(20,6)) {$dir}"
))
```

Filters (same `Filter::make()` + `indicateUsing()` pattern as `NonStockReport`):

- **Date range** — from / to on `created_at`. Most important filter; default to
  the current month.
- **Store** — `Store::where('company_id', Helper::tenantId())`
- **Salesman** — user select, the field that answers "who is doing this?"
- **Product** — product select
- **Category** — via `products.category_id`

Add the Blade view at
`resources/views/filament/tenant/pages/negative-stock-report.blade.php`:

```blade
<x-filament-panels::page>
    {{ $this->table }}
</x-filament-panels::page>
```

Register the page permission through FilamentShield (`HasPageShield` is already
in the trait list) so it appears in role management.

### Step 5 — Optional summary widget

A "Total shortage this month" stat, grouped by salesman, gives the owner the
at-a-glance signal. Straightforward once the report query exists — defer until
the table is working.

## Open decision

**Should the sale be blocked instead of allowed?**

The plan above lets the sale proceed and records the shortage, which matches the
stated need (the goods are physically in the shop, so the sale is legitimate).

If some businesses want a hard block, gate it on a setting alongside the existing
`Helper::stockEnabled()`:

```php
if ($remaining > 0 && Helper::getSetting('BLOCK_NEGATIVE_STOCK', 0)) {
    // log, then return false — and make CreateOrderPage check the return value
}
```

This requires fixing the ignored return value at the call site either way.

## Files touched

| File | Change |
|---|---|
| [app/Helper/Helper.php](../app/Helper/Helper.php) | Fix `adjustStock()` decrement; add `logNegativeStock()` |
| [CreateOrderPage.php](../app/Filament/Tenant/Resources/OrderResource/Pages/CreateOrderPage.php) | Pass order reference |
| `app/Filament/Tenant/Pages/NegativeStockReport.php` | **New** report page |
| `resources/views/filament/tenant/pages/negative-stock-report.blade.php` | **New** view |

No migration required.

## Test scenarios

1. **Stated case** — stock 5, sale 3, sale 3 → stock 0, one log row with
   `shortage: 1`, `requested: 3`, `available: 2`.
2. **No stock row at all** — product never stocked, sale 3 → log row with
   `shortage: 3`, `available: 0`.
3. **Multi-batch** — batches 2 + 2, sale 3 → both rows deducted (2 then 1), no
   shortage logged. Currently broken; this verifies the fix.
4. **Exact match** — stock 3, sale 3 → stock 0, **no** shortage row.
5. **Normal sale** — stock 5, sale 3 → stock 2, no shortage row.
6. **Increment path** — returns/purchases still increment correctly and never
   write a shortage row.
7. **Tenant isolation** — a shortage in company A never appears in company B's
   report.
