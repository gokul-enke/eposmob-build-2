# Wholesale Pricing Implementation Plan

## 📋 Executive Summary

This document outlines the complete implementation strategy for wholesale pricing in the billing page. Wholesale pricing is a **quantity-based pricing model** where products are sold at different rates based on the quantity ordered. This is a critical feature for B2B and bulk sales scenarios.

---

## 🎯 Business Objectives

1. **Enable bulk discounts** - Customers get better rates when ordering in bulk
2. **Support B2B sales** - Wholesale pricing attracts business buyers
3. **Incentivize larger orders** - Encourage customers to buy more quantity
4. **Maintain inventory** - Helps move stock by offering incentives
5. **Unified pricing logic** - Apply consistently across all cart entry points

---

## 🏗️ Current Architecture

### Existing Data Structure
```
Stock {
  id: int
  price: string (retail price)
  mrp: string
  quantity: num
  unit: string
  purchasePrice: string
  taxRate: string
  // ❌ MISSING: wholesalePrice, wholesaleMinUnit
}

LocalCartItem {
  product: GetProduct
  price: double (currently only one price)
  mrp: double
  quantity: num
  taxRate: double
  selectedStock: Stock
  // ❌ MISSING: pricingTier, wholesalePrice, isWholesale
}
```

### Cart Entry Points (7 Entry Points)
1. **Barcode Scanning** → `_processBarcodeInternal()` in billing_page.dart
2. **Sidebar Product Selection** → sidebar_product_list.dart
3. **Product Autocomplete** → product_autocomplete_list.dart
4. **Add Product Modal** → add_product_modal.dart
5. **Category List Click** → category_list_item.dart
6. **Quantity Control Increment** → compact_quantity_control_local.dart
7. **Saved Order Re-add** → order_list.dart

All converge to → `LocalProductProvider.addToCart()`

---

## 🔄 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 CART ENTRY POINT                            │
│ (Barcode, Sidebar, Autocomplete, Modal, Category, Quantity) │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ SELECT QUANTITY (q)  │
        └──────────────┬───────┘
                       │
                       ▼
        ┌──────────────────────────────────────┐
        │ GET STOCK ENTRY                      │
        │ (contains wholesaleMinUnit,          │
        │  wholesalePrice)                     │
        └──────────────┬───────────────────────┘
                       │
                       ▼
    ┌──────────────────────────────────────────┐
    │ EVALUATE PRICING TIER                    │
    │                                          │
    │ if (q >= wholesaleMinUnit &&            │
    │     wholesalePrice > 0)                  │
    │   → Apply WHOLESALE_PRICE                │
    │ else                                     │
    │   → Apply RETAIL_PRICE                   │
    └──────────────┬───────────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────────┐
    │ CREATE/UPDATE CART ITEM                  │
    │ • Store price (wholesale or retail)      │
    │ • Store pricingTier ('RETAIL'/'WHOLESALE')
    │ • Store original retail price (for UI)   │
    │ • Calculate tax on selected price        │
    └──────────────┬───────────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────────────┐
    │ DISPLAY IN CART                          │
    │ • Show unit price (with tier badge)      │
    │ • Show savings amount if wholesale       │
    │ • Show total line amount                 │
    └──────────────────────────────────────────┘
```

---

## 📦 Phase 1: Data Model Updates

### 1.1 Update `Stock` Model
**File**: `lib/models/get_product.dart`

```dart
class Stock {
  // ... existing fields ...
  final String? wholesalePrice;      // ✅ NEW: Wholesale price
  final int? wholesaleMinUnit;       // ✅ NEW: Minimum quantity for wholesale
  
  // copyWith() must include these new fields
}
```

**Where does this come from?**
- Already exists in API response as `wholesale_price` and `wholesale_min_unit`
- Needs to be mapped from product list API endpoint

### 1.2 Update `LocalCartItem` Model
**File**: `lib/providers/local_product_provider.dart`

```dart
class LocalCartItem {
  // ... existing fields ...
  
  String pricingTier;                // ✅ NEW: 'RETAIL' or 'WHOLESALE'
  double? wholesalePrice;            // ✅ NEW: The wholesale price if applicable
  double? retailPrice;               // ✅ NEW: The retail price (for reference/comparison)
  double? savingsPerUnit;            // ✅ NEW: Price difference for UI display
  double? totalSavings;              // ✅ NEW: Total savings on line (for UI)
  
  // Constructor updated with default pricingTier = 'RETAIL'
}
```

### 1.3 Hive Persistence Updates
**File**: `lib/models/local_models.dart`

Add new HiveField entries to `HiveLocalCartItem`:
```dart
@HiveField(12)
String pricingTier;

@HiveField(13)
double? wholesalePrice;

@HiveField(14)
double? retailPrice;
```

---

## 🧮 Phase 2: Pricing Logic Implementation

### 2.1 Pricing Tier Calculator (Utility Function)

**Create new file**: `lib/helpers/wholesale_pricing_helper.dart`

```dart
enum PricingTier { RETAIL, WHOLESALE }

class WholesalePricingHelper {
  /// Determines which pricing tier to apply based on quantity and stock
  static PricingTier determinePricingTier({
    required num quantity,
    required Stock? selectedStock,
    required double retailPrice,
  }) {
    // Validation
    if (selectedStock == null) return PricingTier.RETAIL;
    
    final wholesaleMinUnit = selectedStock.wholesaleMinUnit ?? 0;
    final wholesalePrice = double.tryParse(
      selectedStock.wholesalePrice ?? '0'
    ) ?? 0.0;
    
    // Wholesale conditions
    if (wholesaleMinUnit > 0 && 
        quantity >= wholesaleMinUnit && 
        wholesalePrice > 0) {
      return PricingTier.WHOLESALE;
    }
    
    return PricingTier.RETAIL;
  }

  /// Gets the effective price based on tier
  static double getEffectivePrice({
    required PricingTier tier,
    required Stock? selectedStock,
    required double retailPrice,
  }) {
    if (tier == PricingTier.WHOLESALE && selectedStock != null) {
      return double.tryParse(
        selectedStock.wholesalePrice ?? '0'
      ) ?? retailPrice;
    }
    return retailPrice;
  }

  /// Calculates savings information
  static Map<String, double> calculateSavings({
    required num quantity,
    required double retailPrice,
    required double appliedPrice,
  }) {
    double savingsPerUnit = retailPrice - appliedPrice;
    double totalSavings = savingsPerUnit * quantity;
    
    return {
      'savingsPerUnit': savingsPerUnit,
      'totalSavings': totalSavings,
      'savingsPercent': (savingsPerUnit / retailPrice) * 100,
    };
  }
}
```

### 2.2 Update `LocalProductProvider.addToCart()`

**Current signature:**
```dart
void addToCart({
  int? productId,
  GetProduct? product,
  num? quantity,
  double? price,
  double? mrp,
  Stock? selectedStock,
  List<int>? stockGroupIds,
  bool? isIncreamentUsingCompactQuantityControl,
})
```

**Updated logic flow:**

```dart
void addToCart({
  int? productId,
  GetProduct? product,
  num? quantity,
  double? price,
  double? mrp,
  Stock? selectedStock,
  List<int>? stockGroupIds,
  bool? isIncreamentUsingCompactQuantityControl,
}) {
  // ... existing validation code ...
  
  final retailPrice = price ?? _getDefaultPrice(product, selectedStock);
  
  // ✅ NEW: Determine pricing tier
  PricingTier tier = WholesalePricingHelper.determinePricingTier(
    quantity: quantity ?? 1,
    selectedStock: selectedStock,
    retailPrice: retailPrice,
  );
  
  // ✅ NEW: Get effective price
  double effectivePrice = WholesalePricingHelper.getEffectivePrice(
    tier: tier,
    selectedStock: selectedStock,
    retailPrice: retailPrice,
  );
  
  // ✅ NEW: Calculate savings
  Map<String, double> savings = WholesalePricingHelper.calculateSavings(
    quantity: quantity ?? 1,
    retailPrice: retailPrice,
    appliedPrice: effectivePrice,
  );
  
  // ... rest of existing logic, but use effectivePrice instead of price ...
  
  // When creating/updating LocalCartItem:
  cartItem = LocalCartItem(
    product: product,
    quantity: quantity,
    price: effectivePrice,              // Use calculated effective price
    mrp: mrp,
    taxRate: taxRate,
    taxAmount: calculatedTax,
    selectedStock: selectedStock,
    pricingTier: tier.name,             // ✅ NEW
    wholesalePrice: tier == PricingTier.WHOLESALE 
      ? effectivePrice : null,           // ✅ NEW
    retailPrice: retailPrice,            // ✅ NEW
    savingsPerUnit: savings['savingsPerUnit'],  // ✅ NEW
    totalSavings: savings['totalSavings'],      // ✅ NEW
  );
}
```

---

## 🎭 Phase 3: UI/UX Display Updates

### 3.1 Cart Item Display Enhancement

**File**: `lib/screens/billing/billing_page.dart` → `_buildCartItemsTable()`

Show pricing tier badge and savings:

```
Product Name          Qty  Unit Price      Total        Status
┌────────────────────────────────────────────────────────────┐
│ Apples              10   ₹8.50/unit      ₹85.00       🏷️WHOLESALE
│                                (Saved: ₹1.50/unit)        
│                                (Total saved: ₹15)
└────────────────────────────────────────────────────────────┘
```

### 3.2 Quantity Control Enhancement

**File**: `lib/widgets/compact_quantity_control_local.dart`

When quantity increases and hits wholesale threshold:
```
Current price: ₹10/unit
Quantity: 5 → 10

✨ WHOLESALE UNLOCKED! 
New price: ₹8.50/unit
You save: ₹1.50/unit × 10 = ₹15.00
```

### 3.3 Product Details Dialog Enhancement

**File**: `lib/widgets/product_details_dialog.dart`

Show available pricing tiers upfront:
```
Pricing Tiers Available:
├─ Retail: ₹10.00/unit (Min: 1 unit)
└─ Wholesale: ₹8.50/unit (Min: 10 units) ✅ RECOMMENDED
```

---

## 📊 Phase 4: Usage Scenarios

### Scenario 1: Barcode Scan → Auto Add Quantity 1
```
1. User scans barcode: "123456789"
2. System finds product with stock
3. Stock has: wholesaleMinUnit=10, wholesalePrice=8.50
4. Auto-add with qty=1
5. Tier determined: RETAIL (qty 1 < min 10)
6. Price applied: ₹10.00 (retail)
7. Cart shows: "Apples - 1 × ₹10.00 = ₹10.00 (RETAIL)"
```

### Scenario 2: User Increases Quantity via Control
```
1. Cart item shows: "Apples - 1 × ₹10.00 = ₹10.00 (RETAIL)"
2. User clicks Qty+ button 9 times → qty becomes 10
3. System re-evaluates tier
4. Tier determined: WHOLESALE (qty 10 >= min 10) ✅
5. Price recalculated: ₹8.50 × 10 = ₹85.00
6. Toast shows: "✨ Wholesale pricing unlocked! Save ₹15"
7. Cart item updates: "Apples - 10 × ₹8.50 = ₹85.00 (WHOLESALE)"
```

### Scenario 3: Autocomplete Selection with Modal
```
1. User types "app" in product field
2. Autocomplete shows "Apples" with "Retail: ₹10 | Wholesale: ₹8.50 (10+)"
3. User clicks to select
4. Add Product Modal opens
5. Modal shows:
   - Unit Price: ₹10.00 (RETAIL)
   - Wholesale Info: Available at 10+ units for ₹8.50
   - Quantity input: [    ]
6. User enters qty=15
7. Modal shows: "Wholesale tier active! Unit Price: ₹8.50"
8. User clicks Add to Cart
9. Item added with WHOLESALE tier at ₹8.50
```

### Scenario 4: Quantity Decrease Below Threshold
```
1. Cart has: "Apples - 10 × ₹8.50 = ₹85.00 (WHOLESALE)"
2. User clicks Qty- button to reduce to 9
3. System re-evaluates tier
4. Tier determined: RETAIL (qty 9 < min 10)
5. Price recalculated: ₹10.00 × 9 = ₹90.00
6. Toast warns: "⚠️ Below wholesale minimum (10 units). Price: ₹10.00/unit"
7. Cart item updates: "Apples - 9 × ₹10.00 = ₹90.00 (RETAIL)"
```

### Scenario 5: Multiple Stock Entries (Same Product)
```
Stock A: Price=₹10, Qty=5, Wholesale=N/A
Stock B: Price=₹11, Qty=20, WholesaleMin=5, WholesalePrice=₹8.50

1. User adds qty=3 from Stock A → RETAIL ₹10.00
2. User adds qty=5 from Stock B → WHOLESALE ₹8.50 (meets minimum)
3. Cart shows two line items:
   - Stock A: 3 × ₹10.00 = ₹30.00 (RETAIL)
   - Stock B: 5 × ₹8.50 = ₹42.50 (WHOLESALE)
4. Total: ₹72.50
5. Savings: ₹10 (if all were retail: ₹82.50)
```

### Scenario 6: Save Order → Resume Later
```
1. Cart has: "Apples - 10 × ₹8.50 = ₹85.00 (WHOLESALE)"
2. User clicks "Save Order"
3. Order saved with:
   - quantity: 10
   - price: 8.50 (applied price)
   - pricingTier: 'WHOLESALE'
   - retailPrice: 10.00 (for reference)
4. Later, user loads saved order
5. Cart restored with same pricing tier and price
6. ✅ Consistency maintained
```

### Scenario 7: Admin Override (Future Enhancement)
```
1. Cart shows: "Apples - 5 × ₹10.00 = ₹50.00 (RETAIL)"
2. Admin clicks "Apply Custom Price"
3. Admin enters: ₹8.00 (below retail, above wholesale)
4. System marks: pricingTier = 'CUSTOM_OVERRIDE'
5. Cart shows: "Apples - 5 × ₹8.00 = ₹40.00 ⚙️CUSTOM"
6. Notes custom price applied by [admin name]
```

---

## 🔧 Phase 5: Implementation Steps

### Step 1: Data Model Updates (2-3 hours)
- [ ] Add fields to Stock class
- [ ] Add fields to LocalCartItem class
- [ ] Update Hive models and adapters
- [ ] Create migration for existing Hive data

### Step 2: Create Pricing Helper (1 hour)
- [ ] Create `wholesale_pricing_helper.dart`
- [ ] Write pricing tier logic
- [ ] Add unit tests for edge cases

### Step 3: Update addToCart Logic (3-4 hours)
- [ ] Integrate pricing helper into addToCart()
- [ ] Handle quantity-based recalculation
- [ ] Update for all 7 entry points
- [ ] Add logging for debugging

### Step 4: UI Updates (4-5 hours)
- [ ] Update cart item display with badges
- [ ] Add savings information display
- [ ] Update quantity control UI feedback
- [ ] Update product details dialog
- [ ] Add toast notifications for tier changes

### Step 5: Testing & Refinement (3-4 hours)
- [ ] Unit tests for pricing logic
- [ ] Integration tests for cart flow
- [ ] Manual testing all 7 entry points
- [ ] Manual testing all 7 scenarios

### Step 6: Documentation & Deployment (1-2 hours)
- [ ] Update code comments
- [ ] Create user documentation
- [ ] Prepare release notes

---

## 🧪 Test Cases

### Unit Tests - Pricing Helper
```
✓ Test: Retail tier when qty < wholesaleMinUnit
✓ Test: Wholesale tier when qty >= wholesaleMinUnit
✓ Test: Wholesale tier when wholesalePrice = 0 (disabled)
✓ Test: Wholesale tier when wholesaleMinUnit not set
✓ Test: Correct price returned for RETAIL tier
✓ Test: Correct price returned for WHOLESALE tier
✓ Test: Savings calculation accuracy
```

### Integration Tests - addToCart Flow
```
✓ Test: Single product, retail qty, creates RETAIL item
✓ Test: Single product, wholesale qty, creates WHOLESALE item
✓ Test: Quantity increment crosses threshold, updates tier
✓ Test: Quantity decrement crosses threshold, updates tier
✓ Test: Tax recalculated on price change
✓ Test: Stock deduction works with both tiers
✓ Test: Cart persistence restores correct tier
```

### Manual Tests - All Entry Points
```
✓ Test: Barcode scan → qty 1 → RETAIL
✓ Test: Sidebar selection → vary qty → correct tier
✓ Test: Autocomplete → modal → wholesale shown
✓ Test: Category list → rapid add → no tier confusion
✓ Test: Qty control increment → tier change → toast shows
✓ Test: Qty control decrement → tier change → warning shows
✓ Test: Load saved order → tier restored correctly
```

---

## ⚠️ Edge Cases & Considerations

1. **Zero Wholesale Price**
   - If `wholesalePrice = 0`, treat as disabled
   - Always use retail price even if qty meets minimum

2. **Negative Wholesale Price**
   - Validation: reject during stock entry
   - Fallback: treat as 0 (disabled)

3. **Wholesale Price > Retail Price**
   - This is data error but shouldn't break system
   - System will still use the entered price
   - Add validation warning in stock entry

4. **Very Large Quantities**
   - No upper limit, wholesaling applies
   - Recalculation still accurate

5. **Stock with No Wholesale Data**
   - Default to retail only
   - `wholesaleMinUnit = null` → always retail
   - `wholesalePrice = null` → always retail

6. **Tax Handling**
   - Tax calculated on **final applied price** (wholesale or retail)
   - Tax amount recalculated when tier changes

7. **Custom Pricing Override**
   - When manager enters custom price, don't recalculate on qty change
   - Store override flag: `isCustomPrice = true`
   - Mark tier as `'CUSTOM_OVERRIDE'`

8. **Performance with Large Orders**
   - Tier calculation is O(1) - negligible
   - No N+1 queries
   - Hive saves are batched

---

## 📱 UI/UX Design Notes

### Cart Item Tier Badge
- **RETAIL**: Gray badge "🏷️RETAIL"
- **WHOLESALE**: Green badge "✨WHOLESALE" with savings highlight
- **CUSTOM**: Orange badge "⚙️CUSTOM" (admin override)

### Tooltip Information
```
Hover/tap on tier badge shows:
• Applied Price: ₹8.50/unit
• Base Price: ₹10.00/unit
• Savings: ₹1.50/unit (15%)
• Minimum for this tier: 10 units
```

### Toast Notifications
- ✨ "Wholesale pricing unlocked! Save ₹{amount}"
- ⚠️ "Below wholesale minimum. Price adjusted to ₹{price}"
- 💾 "Saved order tier preserved: {tier}"

---

## 🔌 API Integration Notes

### Existing API
The backend already supports:
- `wholesale_price` in stock response
- `wholesale_min_unit` in stock response

### Required Changes
1. **Product List API**: Ensure wholesale fields included in response
2. **Stock Details API**: Verify wholesale fields in response
3. **Create Order API**: Send `pricingTier` and `appliedPrice` for audit
4. **Confirm Order API**: Include tier info for reporting

### Payload Examples

**When creating order:**
```json
{
  "items": [
    {
      "product_id": 1,
      "quantity": 10,
      "applied_price": 8.50,
      "pricing_tier": "WHOLESALE",
      "retail_price": 10.00,
      "total_amount": 85.00
    }
  ]
}
```

---

## 📈 Reporting & Analytics

### Metrics to Track
1. **Wholesale vs Retail Sales Ratio**
   - How many orders use wholesale pricing?
   
2. **Average Order Value Impact**
   - Do wholesale orders have higher AOV?
   
3. **Discount Impact**
   - Total discount given via wholesale pricing

4. **Conversion Metrics**
   - How many customers upgrade qty to reach wholesale?

### Dashboard Queries
```sql
SELECT 
  pricing_tier,
  COUNT(*) as order_count,
  SUM(quantity) as total_qty,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as avg_order_value
FROM order_items
GROUP BY pricing_tier
```

---

## 🚀 Deployment Strategy

### Phase Rollout
1. **Phase 1**: Internal testing only (staging)
2. **Phase 2**: Beta with single store
3. **Phase 3**: Gradual rollout to all stores
4. **Phase 4**: Monitor and optimize

### Rollback Plan
- If critical issues found:
  - Disable wholesale pricing via app settings flag
  - Default to retail pricing for all items
  - No data loss, can re-enable anytime

### Data Backup
- Export cart data before deployment
- Create Hive backup checkpoint
- Test restore procedure

---

## ✅ Success Criteria

- ✅ All 7 cart entry points correctly apply wholesale pricing
- ✅ Pricing tier correctly determined in all scenarios
- ✅ Tax recalculated accurately when tier changes
- ✅ Cart persistence maintains correct tier on reload
- ✅ UI clearly communicates pricing tier and savings
- ✅ No performance degradation (< 50ms for price calc)
- ✅ All edge cases handled gracefully

---

## 📚 References

### Related Documentation
- `/docs/multi_stock_review.md` - Stock selection logic
- `lib/providers/local_product_provider.dart` - Cart provider
- `lib/models/get_product.dart` - Product models
- `lib/widgets/add_product_modal.dart` - Add to cart flow

### API Documentation
- Backend wholesale pricing API contract
- Stock endpoint response format

---

## 👤 Questions for Product Team

1. Should wholesale discount display as percentage or absolute amount?
2. Do we want to warn before going below wholesale minimum?
3. Should wholesale tier be locked per product in same order?
4. Do we track which products hit wholesale most often?
5. Future: Support tiered wholesale (5-10 @ ₹9, 10-20 @ ₹8.50, 20+ @ ₹8)?

---

**Document Version**: 1.0  
**Last Updated**: April 23, 2026  
**Status**: Ready for Development
