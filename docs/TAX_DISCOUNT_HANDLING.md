# Tax & Discount Handling in POS — Analysis & Fix Guide

## 1. Background

In a POS system, products can have **different tax rates** (e.g., 5%, 12%, 18% GST in India, or a flat 15% VAT in Saudi Arabia). When a discount is applied to the whole order, the tax must be recalculated correctly — not just subtracted from the grand total.

---

## 2. How Tax is Stored Per Item

Each `CartItem` row stores:

| Column | Description |
|---|---|
| `total_price` | Tax-inclusive price (base + tax) |
| `tax_rate` | Tax percentage for this product |
| `tax_amount` | Total tax for this line (quantity × per-unit tax) |

Since prices are **tax-inclusive**, the base price is:
```
base_price = total_price - tax_amount
```

---

## 3. The Problem — Current `createOrder()` Logic

**File:** `app/Http/Controllers/Api/V1/OrderController.php` ~line 95–115

```php
$grandTotalBeforeDiscount = $cartTotal + $shippingCost;
$price = $grandTotalBeforeDiscount - ($additionalData['discount'] ?? 0);
$grandTotal = Helper::priceRoundOffEnabled() ? Helper::roundPrice($price) : $price;

// ...

'tax' => $cart->cartItems->sum('tax_amount') + $deliveryTaxAmount,
```

### What's wrong

- `grand_total` is correctly reduced by the discount ✅
- `tax` is **not adjusted** — it reflects the full pre-discount tax ❌
- `sub_total` (tax-exclusive base) is also not adjusted ❌

This means the stored tax figure is inconsistent with the actual amount charged.

---

## 4. What Different Countries Require

### India (GST) & UAE / Saudi Arabia (VAT)

Tax must be calculated **after** the discount is applied. The discount reduces the taxable base.

> **Legal requirement:** The tax amount on the invoice must match the post-discount taxable amount × rate.

### Some US Retail Scenarios

Discount can be post-tax in certain cases — tax is calculated on the full price and discount is applied afterward. This is less common and jurisdiction-specific.

**For your POS (India/UAE/KSA context) — tax must be on the discounted amount.**

---

## 5. Why Proportional Split is Needed for Multi-Rate Tax

If all products had the same tax rate, you could simply scale the total tax down by the discount ratio. But with **different rates per product**, that would be wrong.

### Example

| Product | Price (incl. tax) | Tax Rate | Tax Amount |
|---|---|---|---|
| Product A | ₹600 | 5% | ₹28.57 |
| Product B | ₹400 | 18% | ₹61.02 |
| **Total** | **₹1000** | — | **₹89.59** |

Discount applied: **₹200**

**Wrong approach (scaling total tax):**
```
Adjusted tax = ₹89.59 × (800/1000) = ₹71.67
```
This treats both products as having the same effective rate — incorrect.

**Correct approach (per-item proportional discount):**

Each item gets its share of the discount based on its price:
- Product A discount = ₹200 × (600/1000) = ₹120 → discounted price = ₹480
- Product B discount = ₹200 × (400/1000) = ₹80 → discounted price = ₹320

Then back-calculate tax from each discounted price:
```
Tax formula (tax-inclusive): tax = price × (rate / (100 + rate))

Product A tax = ₹480 × (5/105)  = ₹22.86
Product B tax = ₹320 × (18/118) = ₹48.81
Total tax     = ₹71.67
```

Coincidentally the total matches here, but the **per-product tax is correctly attributed** — which matters for tax filing, ZATCA line-level reporting, and GST returns.

---

## 6. Correct Code for `createOrder()`

Replace the current tax and sub_total calculation with:

```php
$cartTotal = $cart->cartItems->sum('total_price');
$discountAmount = $additionalData['discount'] ?? 0;

$adjustedTax = $cart->cartItems->sum(function ($item) use ($cartTotal, $discountAmount) {
    if ($cartTotal <= 0 || $item->tax_rate <= 0) return 0;

    // Each item's proportional share of the discount
    $itemDiscount = $discountAmount * ($item->total_price / $cartTotal);
    $discountedItemTotal = $item->total_price - $itemDiscount;

    // Back-calculate tax from discounted tax-inclusive price
    $taxMultiplier = $item->tax_rate / (100 + $item->tax_rate);
    return $discountedItemTotal * $taxMultiplier;
});

$adjustedSubTotal = $cart->cartItems->sum(function ($item) use ($cartTotal, $discountAmount) {
    if ($cartTotal <= 0) return $item->total_price - $item->tax_amount;

    $itemDiscount = $discountAmount * ($item->total_price / $cartTotal);
    $discountedItemTotal = $item->total_price - $itemDiscount;

    if ($item->tax_rate <= 0) return $discountedItemTotal;

    $taxMultiplier = $item->tax_rate / (100 + $item->tax_rate);
    return $discountedItemTotal * (1 - $taxMultiplier); // base only
});

// Then in Order::updateOrCreate:
'sub_total' => $adjustedSubTotal + ($shippingCost - $deliveryTaxAmount),
'tax'       => $adjustedTax + $deliveryTaxAmount,
```

---

## 7. ZATCA-Specific Issue

**File:** `app/Services/ZatcaService.php`

### How ZATCA declares a discount

ZATCA uses an `allowanceCharge` block at the invoice level:

```json
"allowanceCharges": [{
    "isCharge": false,
    "reason": "discount",
    "amount": 200.00,
    "taxCategories": [{ "percent": 15, "taxScheme": { "id": "VAT" } }]
}]
```

### The inconsistency in current code

**Line 1196** — tax per line is calculated from the **full pre-discount amount**:
```php
$taxAmountItem = round($lineInclusiveTotal * 15 / 115, 2);
```

**Line 1244** — but `taxableAmount` in the tax total deducts the discount:
```php
'taxableAmount' => round($lineExtensionAmount - $discountAmount, 2),
```

**ZATCA validates:** `taxableAmount × 15% = taxAmount`

With the current code this will **not match**, causing a ZATCA validation failure.

### What ZATCA requires

```
lineExtensionAmount  = sum of all line totals (tax-exclusive, pre-discount)
taxableAmount        = lineExtensionAmount - discount
taxAmount            = taxableAmount × 15%
taxInclusiveAmount   = taxableAmount + taxAmount
payableAmount        = taxableAmount + taxAmount
allowanceTotalAmount = discount
```

### Correct ZATCA tax calculation

```php
// After the foreach loop that builds $invoiceLines:

$taxableAmount = round($lineExtensionAmount - $discountAmount, 2);
$totalTaxAmount = round($taxableAmount * 0.15, 2);  // recalculate from discounted base

$invoiceData['invoice']['taxTotal'] = [
    'taxAmount' => $totalTaxAmount,
    'subTotals' => [[
        'taxableAmount' => $taxableAmount,
        'taxAmount'     => $totalTaxAmount,
        'taxCategory'   => [
            'percent'   => 15,
            'taxScheme' => ['id' => 'VAT'],
        ],
    ]],
];

$invoiceData['invoice']['legalMonetaryTotal'] = [
    'lineExtensionAmount'  => round($lineExtensionAmount, 2),
    'taxExclusiveAmount'   => $taxableAmount,
    'taxInclusiveAmount'   => round($taxableAmount + $totalTaxAmount, 2),
    'payableAmount'        => round($taxableAmount + $totalTaxAmount, 2),
    'allowanceTotalAmount' => round($discountAmount, 2),
];
```

> **Note:** ZATCA Saudi Arabia uses a flat 15% VAT for all goods. Per-line tax rates are not applicable here — the fix is simpler than the multi-rate case. The discount reduces the total taxable base, and tax is recalculated once on that discounted base.

---

## 8. Summary of Issues & Fixes

| Location | Issue | Fix |
|---|---|---|
| `OrderController::createOrder()` line ~115 | `tax` column not adjusted for discount | Use proportional per-item tax recalculation |
| `OrderController::createOrder()` line ~111 | `sub_total` not adjusted for discount | Recalculate base after proportional discount |
| `ZatcaService.php` line ~1196–1245 | `taxAmount` calculated pre-discount, `taxableAmount` shows post-discount — mismatch | Recalculate `taxAmount` from discounted `taxableAmount` |

---

## 9. Key Rules to Remember

1. **Tax is always on the discounted amount** — in India, UAE, and Saudi Arabia this is a legal requirement.
2. **Different tax rates per product** → split discount proportionally per item, recalculate each item's tax independently.
3. **ZATCA flat 15% VAT** → simpler case, discount reduces the single taxable base, tax recalculated once.
4. **Invoice tax figures must be consistent** — `taxableAmount × rate = taxAmount` is validated by ZATCA and must match exactly.
