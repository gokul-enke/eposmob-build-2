# Wholesale Pricing - Developer Quick Reference

## 🚀 Quick Start

### Three Core Things to Understand:

1. **Stock model needs wholesale fields**
   ```dart
   Stock {
     wholesalePrice: "8.50",      // What user pays in bulk
     wholesaleMinUnit: 10,        // Min qty to unlock wholesale
   }
   ```

2. **Pricing helper determines tier**
   ```dart
   // Simple logic:
   if (qty >= wholesaleMinUnit && wholesalePrice > 0) {
     → WHOLESALE tier → use wholesalePrice
   } else {
     → RETAIL tier → use regular price
   }
   ```

3. **Cart item tracks the decision**
   ```dart
   LocalCartItem {
     price: 8.50,                 // Applied price (wholesale/retail)
     pricingTier: 'WHOLESALE',    // Which one was used
     savingsPerUnit: 1.50,        // Show in UI
   }
   ```

---

## 📁 Files to Modify

### 1. **Models** (30 min)
- [ ] `lib/models/get_product.dart` - Add Stock fields
- [ ] `lib/providers/local_product_provider.dart` - Update LocalCartItem
- [ ] `lib/models/local_models.dart` - Add Hive fields + generator

**Check List:**
- ✓ Stock.copyWith() includes new fields
- ✓ LocalCartItem constructor updated
- ✓ Hive fields have new @HiveField() annotations
- ✓ Run: `flutter pub run build_runner build`

### 2. **Helper** (1 hour)
- [ ] Create `lib/helpers/wholesale_pricing_helper.dart`

**Key Functions:**
```dart
enum PricingTier { RETAIL, WHOLESALE }

class WholesalePricingHelper {
  static PricingTier determinePricingTier({...}) 
    → Returns RETAIL or WHOLESALE
  
  static double getEffectivePrice({...}) 
    → Returns the price to use
  
  static Map<String, double> calculateSavings({...}) 
    → Returns savingsPerUnit, totalSavings
}
```

### 3. **Cart Logic** (3-4 hours)
- [ ] `lib/providers/local_product_provider.dart` - Update addToCart()

**Key Changes:**
```dart
void addToCart({...}) {
  // ... existing code ...
  
  // NEW: Get retail price
  final retailPrice = price ?? getDefaultPrice(...);
  
  // NEW: Determine tier
  PricingTier tier = WholesalePricingHelper.determinePricingTier(
    quantity: quantity ?? 1,
    selectedStock: selectedStock,
    retailPrice: retailPrice,
  );
  
  // NEW: Get effective price
  double effectivePrice = WholesalePricingHelper.getEffectivePrice(
    tier: tier,
    selectedStock: selectedStock,
    retailPrice: retailPrice,
  );
  
  // NEW: Calculate savings
  Map<String, double> savings = 
    WholesalePricingHelper.calculateSavings(
      quantity: quantity ?? 1,
      retailPrice: retailPrice,
      appliedPrice: effectivePrice,
    );
  
  // Use effectivePrice instead of price
  // Use tier.name for pricingTier field
  // Use savings['savingsPerUnit'] and savings['totalSavings']
  // Tax calculation: use effectivePrice not price
}
```

### 4. **UI Updates** (4-5 hours)
- [ ] `lib/screens/billing/billing_page.dart` → _buildCartItemsTable()
- [ ] `lib/widgets/compact_quantity_control_local.dart` → Show tier change
- [ ] `lib/widgets/add_product_modal.dart` → Preview wholesale
- [ ] `lib/widgets/product_details_dialog.dart` → Show tier info

**What Users Should See:**
```
[CART ITEM]
Apples 10 × ₹8.50 = ₹85.00 ✨WHOLESALE
         └─ Saved: ₹1.50/unit (15%)
         
[QTY CONTROL]
On increase 1→10: Toast → "✨ Wholesale unlocked! Save ₹15"
On decrease 10→9: Toast → "⚠️ Below minimum. Price: ₹10.00"

[MODAL PREVIEW]
Current Price: ₹10.00/unit
Wholesale Available: ₹8.50/unit (10+ units)
You Save: ₹1.50/unit
```

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] Test tier = RETAIL when qty < min
- [ ] Test tier = WHOLESALE when qty >= min
- [ ] Test tier = RETAIL when wholesale price = 0
- [ ] Test price calculation for both tiers
- [ ] Test savings calculation accuracy

### Integration Tests
- [ ] Add product qty 1 → RETAIL tier
- [ ] Add product qty 10 → WHOLESALE tier (if min=10)
- [ ] Increment qty 1→10 → Tier changes → Price updates
- [ ] Decrement qty 10→9 → Tier changes back → Price updates
- [ ] Tax recalculated on tier change
- [ ] Cart saved/restored with correct tier

### Manual Tests (All 7 Entry Points)
- [ ] Barcode scan → qty 1 → RETAIL
- [ ] Sidebar product → qty varied → Correct tier
- [ ] Autocomplete → modal → Tier shown
- [ ] Category add → rapid clicks → No tier confusion
- [ ] Qty control increment/decrement → Toast feedback
- [ ] Qty control crosses threshold → Tier badge updates
- [ ] Load saved order → Tier restored correctly

---

## 🐛 Common Issues & Fixes

### Issue: Price not changing on qty increase
**Root Cause:** addToCart() called but tier recalc skipped
**Fix:** Ensure addToCart() always calls pricing helper

### Issue: Tax wrong after tier change
**Root Cause:** Tax calculated on old price
**Fix:** Recalculate tax using `effectivePrice` not original `price`

### Issue: Wholesale price > retail (data error)
**Root Cause:** Bad data in stock table
**Fix:** Add validation in stock entry; system uses whatever is set

### Issue: Tier reverts after save/reload
**Root Cause:** Hive not saving pricingTier field
**Fix:** Verify @HiveField() annotations added and build_runner run

### Issue: Performance slow with large orders
**Root Cause:** Tier calculation in loop
**Fix:** Tier calculation is O(1), shouldn't be slow

---

## 📝 Code Snippets Ready to Copy

### Pricing Helper Template
```dart
// lib/helpers/wholesale_pricing_helper.dart

enum PricingTier { RETAIL, WHOLESALE }

class WholesalePricingHelper {
  /// Determines pricing tier based on quantity and stock
  static PricingTier determinePricingTier({
    required num quantity,
    required Stock? selectedStock,
    required double retailPrice,
  }) {
    if (selectedStock == null) {
      return PricingTier.RETAIL;
    }

    final wholesaleMinUnit = selectedStock.wholesaleMinUnit ?? 0;
    final wholesalePrice = double.tryParse(
      selectedStock.wholesalePrice ?? '0'
    ) ?? 0.0;

    if (wholesaleMinUnit > 0 &&
        quantity >= wholesaleMinUnit &&
        wholesalePrice > 0) {
      debugPrint('✨ WHOLESALE tier activated (qty: $quantity >= min: $wholesaleMinUnit)');
      return PricingTier.WHOLESALE;
    }

    debugPrint('🏷️ RETAIL tier (qty: $quantity < min: $wholesaleMinUnit or price: $wholesalePrice)');
    return PricingTier.RETAIL;
  }

  /// Gets effective price based on tier
  static double getEffectivePrice({
    required PricingTier tier,
    required Stock? selectedStock,
    required double retailPrice,
  }) {
    if (tier == PricingTier.WHOLESALE && selectedStock != null) {
      double wsPrice = double.tryParse(
        selectedStock.wholesalePrice ?? '0'
      ) ?? retailPrice;
      debugPrint('💰 Using WHOLESALE price: $wsPrice (vs retail: $retailPrice)');
      return wsPrice;
    }
    debugPrint('💰 Using RETAIL price: $retailPrice');
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
    double savingsPercent = savingsPerUnit > 0
        ? (savingsPerUnit / retailPrice) * 100
        : 0.0;

    return {
      'savingsPerUnit': savingsPerUnit,
      'totalSavings': totalSavings,
      'savingsPercent': savingsPercent,
    };
  }
}
```

### LocalCartItem Update
```dart
class LocalCartItem {
  final GetProduct product;
  double? price;
  double? mrp;
  double? taxRate;
  double? taxAmount;
  num quantity;
  final Stock? selectedStock;
  num stockDeducted;
  List<int> stockGroupIds;
  List<StockReservation> stockReservations;
  String? comment;

  // ✅ NEW FIELDS
  String pricingTier;           // 'RETAIL' or 'WHOLESALE'
  double? wholesalePrice;       // The WS price if applicable
  double? retailPrice;          // Retail price (for comparison)
  double? savingsPerUnit;       // Price difference
  double? totalSavings;         // Total $ saved on line

  LocalCartItem({
    required this.product,
    this.price,
    this.mrp,
    this.taxRate,
    this.taxAmount,
    this.quantity = 1,
    this.selectedStock,
    this.stockDeducted = 0,
    List<int>? stockGroupIds,
    List<StockReservation>? stockReservations,
    this.comment,
    // ✅ NEW
    this.pricingTier = 'RETAIL',
    this.wholesalePrice,
    this.retailPrice,
    this.savingsPerUnit,
    this.totalSavings,
  })  : stockGroupIds = stockGroupIds ?? <int>[],
        stockReservations = stockReservations ?? <StockReservation>[];
}
```

### addToCart Logic Insert
```dart
// Inside void addToCart() method

// Get retail price
final retailPrice = price ?? 
  (selectedStock?.price != null 
    ? double.tryParse(selectedStock!.price!)
    : product.price?.price != null
      ? double.tryParse(product.price!.price!)
      : 0.0) ?? 0.0;

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

// Use effectivePrice for tax calculation
final taxRate = _resolveCartTaxRate(product, selectedStock: selectedStock);
final calculatedTax = _calculateTaxAmount(effectivePrice, taxRate);

// When creating LocalCartItem:
LocalCartItem(
  product: product,
  quantity: quantity ?? 1,
  price: effectivePrice,  // ← Use calculated price
  mrp: mrp,
  taxRate: taxRate,
  taxAmount: calculatedTax,
  selectedStock: selectedStock,
  pricingTier: tier.name,  // ← NEW
  wholesalePrice: tier == PricingTier.WHOLESALE ? effectivePrice : null,
  retailPrice: retailPrice,  // ← NEW
  savingsPerUnit: savings['savingsPerUnit'],  // ← NEW
  totalSavings: savings['totalSavings'],  // ← NEW
)
```

---

## 🎯 Implementation Order (Recommended)

1. **Day 1 Morning (1-2 hours)**
   - [ ] Update Stock model with new fields
   - [ ] Update LocalCartItem model
   - [ ] Update Hive models
   - [ ] Run build_runner

2. **Day 1 Afternoon (1 hour)**
   - [ ] Create WholesalePricingHelper
   - [ ] Write unit tests for helper

3. **Day 2 Morning (3-4 hours)**
   - [ ] Integrate pricing helper into addToCart()
   - [ ] Write integration tests
   - [ ] Manual test all entry points

4. **Day 2 Afternoon (4-5 hours)**
   - [ ] Update cart display UI
   - [ ] Update quantity control feedback
   - [ ] Add toast notifications
   - [ ] Manual UI testing

5. **Day 3 (1-2 hours)**
   - [ ] Final testing, edge cases
   - [ ] Documentation
   - [ ] Code review prep

---

## 📊 Git Commit Messages (Suggested)

```
feat(wholesale): Add stock model fields for wholesale pricing

- Add wholesalePrice and wholesaleMinUnit to Stock class
- Update copyWith() method
- Add fields to Stock.fromJson()

---

feat(wholesale): Implement pricing tier logic

- Create WholesalePricingHelper with tier determination
- Add savings calculation
- Include unit tests

---

feat(wholesale): Integrate wholesale pricing into addToCart

- Calculate tier for all new items
- Apply correct price based on quantity
- Recalculate tax on price changes
- Persist tier in LocalCartItem

---

feat(wholesale): Add UI feedback for pricing tiers

- Show tier badge in cart items
- Display savings information
- Add toast notifications on tier changes
- Update quantity control styling
```

---

## ✅ Definition of Done

- ✓ All 7 entry points add to cart with correct tier
- ✓ Qty change triggers tier re-evaluation
- ✓ Price updates instantly when tier changes
- ✓ Tax recalculated on tier change
- ✓ UI shows tier badge, savings, current price
- ✓ Toast feedback on tier unlock/downgrade
- ✓ Cart saves/loads with tier persisted
- ✓ All unit tests passing
- ✓ All integration tests passing
- ✓ Manual tests across all scenarios passing
- ✓ Code reviewed
- ✓ Documentation complete

---

## 🎓 Quick Mental Model

```
Add Product → Check Qty vs Min → Choose Price → Add to Cart
              if qty >= min        ↓
              use wholesale    Apply Price
              else            Set Tier
              use retail      Calc Tax
                              Save Cart
                              Show Feedback
```

That's the whole feature!

---

**Last Updated:** April 23, 2026  
**Ready to Code:** ✅ Yes
