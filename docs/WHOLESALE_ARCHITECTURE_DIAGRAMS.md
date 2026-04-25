# Wholesale Pricing Architecture Diagrams

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        BILLING PAGE                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   7 CART ENTRY POINTS                    │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  1️⃣ Barcode Scan      4️⃣ Add Modal        7️⃣ Saved Order   │   │
│  │  2️⃣ Sidebar Product   5️⃣ Category List                  │   │
│  │  3️⃣ Autocomplete      6️⃣ Qty Control                    │   │
│  └──────────────────────┬───────────────────────────────────┘   │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────┐
        │  LocalProductProvider.addToCart │
        │          (Main Hub)              │
        └────────────┬────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
    ┌─────────────────┐   ┌──────────────────────┐
    │  Stock Model    │   │ Pricing Helper       │
    │  ✅ wholesale   │   │ • Determine Tier    │
    │  ✅ minUnit     │   │ • Get Effective Price
    └────────┬────────┘   │ • Calculate Savings  │
             │            └──────────┬───────────┘
             └────────────┬──────────┘
                          ▼
        ┌────────────────────────────────┐
        │  LocalCartItem Model           │
        │  ✅ pricingTier (RETAIL/WS)   │
        │  ✅ appliedPrice               │
        │  ✅ savingsPerUnit             │
        │  ✅ totalSavings               │
        └────────────┬────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
    ┌─────────────┐        ┌──────────────┐
    │  Cart View  │        │  Hive Persist│
    │  Show Badge │        │  Save State  │
    │  Show$$$    │        │ Restore Tier │
    └─────────────┘        └──────────────┘
```

---

## 🔄 Tier Calculation Flow

```
INPUT: Quantity Selected
       │
       ▼
Get Stock Details ─────┐
• wholesaleMinUnit     │
• wholesalePrice       │
• retailPrice          │
       │               │
       ├───────────────┤
       ▼               │
┌──────────────────────┴───────┐
│  Pricing Decision Tree        │
├───────────────────────────────┤
│                               │
│ Is wholesaleMinUnit set?      │
│  ├─ NO → RETAIL ONLY          │
│  └─ YES ↓                     │
│    Is qty >= wholesaleMinUnit? 
│     ├─ NO → RETAIL TIER       │
│     └─ YES ↓                  │
│       Is wholesalePrice > 0?  │
│        ├─ NO → RETAIL TIER    │
│        └─ YES → WHOLESALE ✨  │
│                               │
└───────────────┬───────────────┘
                ▼
OUTPUT: Final Price & Tier
        (Used for cart)
```

---

## 📊 Data Flow: Barcode Scan Scenario

```
USER SCANS BARCODE
│
▼
┌──────────────────────────────────────────┐
│ _processBarcodeInternal()                │
│ • Find product by barcode                │
│ • Get stock entry                        │
│ • Default qty = 1                        │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ addToCart(                               │
│   product: foundProduct,                 │
│   quantity: 1,           ← KEY FACTOR    │
│   selectedStock: stockEntry,             │
│ )                                        │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ WholesalePricingHelper.determineTier(    │
│   quantity: 1,                           │
│   stock: {                               │
│     wholesaleMinUnit: 10,                │
│     wholesalePrice: 8.50,                │
│   }                                      │
│ )                                        │
└──────────────┬───────────────────────────┘
               │
       ┌───────┴───────────┐
       ▼                   ▼
   1 < 10?             YES → RETAIL
   NO                  
   └─────────► Use Price: 10.00
               Tier: RETAIL
               Qty: 1
               Total: 10.00
               
               ▼
   ┌──────────────────────────────┐
   │ LocalCartItem Created:       │
   │ • price: 10.00               │
   │ • quantity: 1                │
   │ • pricingTier: 'RETAIL'      │
   │ • taxAmount: calculated      │
   └────────────┬─────────────────┘
                │
                ▼
   ┌──────────────────────────────┐
   │ Cart Display:                │
   │ Apples 1 × ₹10.00            │
   │          = ₹10.00 🏷️RETAIL   │
   └──────────────────────────────┘
```

---

## 📊 Data Flow: Quantity Increase Scenario

```
USER INCREASES QTY: 1 → 10 (via Qty Control)
│
▼
┌──────────────────────────────────────────┐
│ User clicks Qty+ button (9 times)        │
│ New quantity: 10                         │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ addToCart() called AGAIN with qty=10     │
│ (isIncreamentUsingCompactQuantityControl │
│  = true)                                 │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Check if item already in cart            │
│ YES → Update existing item               │
│   quantity: 1 + 10 = 11 → Actually: 10*  │
└──────────────┬───────────────────────────┘
               │     *Only increment by delta
               ▼
┌──────────────────────────────────────────┐
│ determinePricingTier(qty=10, stock...)   │
└──────────────┬───────────────────────────┘
               │
       ┌───────┴─────────────┐
       ▼                     ▼
   10 >= 10?              YES → WHOLESALE! ✨
   YES
   └─────────► Use Price: 8.50
               Tier: WHOLESALE
               Qty: 10
               Total: 85.00
               Savings: 1.50/unit
               
               ▼
   ┌──────────────────────────────┐
   │ Calculate Savings:           │
   │ savingsPerUnit = 10-8.50=1.50│
   │ totalSavings = 1.50×10=15.00 │
   └────────────┬─────────────────┘
                │
                ▼
   ┌──────────────────────────────┐
   │ LocalCartItem Updated:       │
   │ • quantity: 10 ← CHANGED     │
   │ • price: 8.50 ← CHANGED     │
   │ • pricingTier: WHOLESALE ←  │
   │ • savingsPerUnit: 1.50       │
   │ • totalSavings: 15.00        │
   │ • taxAmount: recalc'd        │
   └────────────┬─────────────────┘
                │
        ┌───────┴──────────────┐
        ▼                      ▼
   Hive Updated          UI Updated
   • Save qty=10         • Toast: "✨ Wholesale
   • Save price=8.50       unlocked! Save ₹15"
   • Save tier           • Cart refreshes:
                           Apples 10×₹8.50=₹85
                           WHOLESALE 💚
                           Saved: ₹15
```

---

## 🎯 Tier Decision Logic (Decision Tree)

```
                    START: Item Added to Cart
                              │
                              ▼
                    ┌─────────────────────┐
                    │ Get Stock Details   │
                    │ wholesaleMinUnit?   │
                    │ wholesalePrice?     │
                    └─────────┬───────────┘
                              │
                ┌─────────────┴────────────────┐
                ▼                              ▼
           Is NULL?                       Has Value?
                │                              │
                ▼                              ▼
          ┌──────────────┐            ┌──────────────────┐
          │ RETAIL ONLY  │            │ Check Qty vs Min │
          │ (No wholesale)           │ wholesaleMinUnit │
          └──────────────┘            └────────┬─────────┘
                                               │
                        ┌──────────────────────┼───────────────────┐
                        ▼                      ▼                   ▼
                   qty < min           qty >= min           qty >= min
                        │                      │                   │
                        ▼                      ▼                   ▼
                    RETAIL            Check Price        Check Price
                    Tier             > 0?                > 0?
                                        │                   │
                ┌───────────────────────┘            ┌──────┘
                ▼                                    ▼
            RETAIL                            WHOLESALE ✨
            Price = retail                    Price = wholesale
```

---

## 💾 Data State Transitions

```
SCENARIO: Add qty 1 → Increase to 10 → Decrease to 9

State 1: ADD QTY=1
┌─────────────────────────────────┐
│ quantity: 1                     │
│ price: 10.00                    │
│ pricingTier: 'RETAIL'          │
│ taxAmount: 0.71                 │
│ totalAmount: 10.71              │
└─────────────────────────────────┘
         │
         │ User: Qty+ 9 times
         ▼
State 2: INCREASE TO QTY=10
┌─────────────────────────────────┐
│ quantity: 10 ← CHANGED          │
│ price: 8.50 ← CHANGED          │
│ pricingTier: 'WHOLESALE' ← TIER │
│ taxAmount: 6.07 ← RECALC'D     │
│ totalAmount: 91.07 ← CHANGED   │
│ savingsPerUnit: 1.50 ← NEW     │
│ totalSavings: 15.00 ← NEW      │
└─────────────────────────────────┘
         │
         │ User: Qty- 1 time
         ▼
State 3: DECREASE TO QTY=9
┌─────────────────────────────────┐
│ quantity: 9 ← CHANGED          │
│ price: 10.00 ← CHANGED         │
│ pricingTier: 'RETAIL' ← REVERTED
│ taxAmount: 6.43 ← RECALC'D     │
│ totalAmount: 96.43 ← CHANGED   │
│ savingsPerUnit: 0 ← RESET      │
│ totalSavings: 0 ← RESET        │
└─────────────────────────────────┘

Notes:
• Every qty change triggers tier re-evaluation
• Tax amounts recalculated
• UI updates immediately with feedback
• Hive saved after each change
```

---

## 🎨 UI State Transitions (Cart Item)

```
State 1: RETAIL TIER (qty=1)
┌──────────────────────────────────┐
│ Apples (x1)                      │
│ Unit Price:    ₹10.00            │
│ Status:        🏷️RETAIL           │
│ Total:         ₹10.00            │
│ Actions: [+] [-] [×]             │
└──────────────────────────────────┘

        ↓ (User clicks [+] 9 times)
        ↓ qty changes to 10

    TOAST SHOWS:
    ✨ Wholesale pricing unlocked!
       Save ₹15.00 on this item

        ↓ (Toast disappears)

State 2: WHOLESALE TIER (qty=10)
┌──────────────────────────────────┐
│ Apples (x10)                     │
│ Unit Price:    ₹8.50 (was ₹10)  │
│ Status:        ✨WHOLESALE        │
│ Savings/Unit:  ₹1.50             │
│ Total Savings: ₹15.00            │
│ Total:         ₹85.00            │
│ Actions: [+] [-] [×]             │
└──────────────────────────────────┘

        ↓ (User clicks [-])
        ↓ qty changes to 9

    TOAST SHOWS:
    ⚠️ Below wholesale minimum (10 units)
       Price adjusted to ₹10.00/unit

        ↓ (Toast disappears)

State 3: BACK TO RETAIL (qty=9)
┌──────────────────────────────────┐
│ Apples (x9)                      │
│ Unit Price:    ₹10.00            │
│ Status:        🏷️RETAIL           │
│ Total:         ₹90.00            │
│ Actions: [+] [-] [×]             │
└──────────────────────────────────┘
```

---

## 🧪 Test Scenario Flows

### Test 1: Barcode Scan Flow
```
[INIT] Cart is empty

[ACTION] Scan barcode: 123456789

[SYSTEM]
  1. Find product
  2. Get stock (min=10, ws=8.50)
  3. Set qty=1
  4. Calc tier: qty(1) < min(10) → RETAIL
  5. Use price: 10.00
  6. Add to cart

[RESULT]
  ✓ Cart shows: Apple 1×₹10.00 🏷️RETAIL
  ✓ No savings shown
  ✓ Tax: ₹0.71
```

### Test 2: Quantity Threshold Crossing
```
[INIT] Cart: Apple 1×₹10.00 🏷️RETAIL

[ACTION] Click Qty+ button (9 times)
         qty: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

[SYSTEM RECALC AT EACH STEP]
  qty < 10: RETAIL ✓
  ...
  qty = 10: qty(10) >= min(10) AND ws(8.50) > 0
          → Tier changed to WHOLESALE!
          → Recalc price: 8.50
          → Recalc tax: 6.07
          → Calc savings: 15.00

[RESULT]
  ✓ Qty 1-9: Price stays 10.00
  ✓ Qty 10: Price drops to 8.50 instantly
  ✓ Toast shows savings: ₹15.00
  ✓ Cart updates: 10×₹8.50=₹85 ✨WHOLESALE
  ✓ UI badge changes color
```

### Test 3: Multiple Stocks (Same Product)
```
[INIT] Cart is empty
       Product has 2 stocks:
       Stock A: price=11, qty=5, no wholesale
       Stock B: price=12, qty=20, min=5, ws=9

[ACTION] 
  1. Add qty=3 from Stock A
  2. Add qty=5 from Stock B

[SYSTEM]
  Add 1: qty(3) < min(N/A) → RETAIL from Stock A
         Use price: 11.00
         
  Add 2: qty(5) >= min(5) AND ws(9) > 0 → WHOLESALE from Stock B
         Use price: 9.00

[RESULT]
  ✓ Cart shows 2 line items:
    - Stock A: 3×₹11.00=₹33 🏷️RETAIL
    - Stock B: 5×₹9.00=₹45 ✨WHOLESALE (Save ₹15)
  ✓ Order total: ₹78.00
  ✓ Identified savings: ₹15.00
```

---

## 🔌 API Integration Points

```
Frontend (Billing Page)
         │
         ├─→ Get Product List API
         │   Response includes:
         │   • product.price (retail)
         │   • stock[].price (retail/stock-specific)
         │   • stock[].wholesale_price
         │   • stock[].wholesale_min_unit
         │
         ├─→ Add to Cart (LOCAL - No API)
         │   Calculates tier locally
         │   No API call needed
         │
         ├─→ Create Order API
         │   Send payload:
         │   {
         │     items: [{
         │       product_id: 1,
         │       quantity: 10,
         │       applied_price: 8.50,
         │       pricing_tier: 'WHOLESALE',
         │       retail_price: 10.00
         │     }]
         │   }
         │
         └─→ Confirm Order API
             Same payload with order details
             Backend records pricing tier for audit

Backend Database
         │
         ├─→ Stock table
         │   • wholesale_price
         │   • wholesale_min_unit
         │
         ├─→ Order Items table
         │   • applied_price (what customer paid)
         │   • pricing_tier ('RETAIL'/'WHOLESALE')
         │   • retail_price (for reference/reports)
         │
         └─→ Audit Log
             Track all pricing decisions for compliance
```

---

## ⚡ Performance Characteristics

```
Operation: Calculate Pricing Tier
├─ Time Complexity: O(1) ← Constant time
├─ Space Complexity: O(1) ← No allocations
└─ Typical Duration: < 1ms

Operation: Add to Cart (with tier calc)
├─ Time Complexity: O(1) ← No loops
├─ Space Complexity: O(1) ← Fixed fields
└─ Typical Duration: 5-10ms

Operation: Hive Save
├─ Time Complexity: O(1) ← Single record
├─ Space Complexity: O(1) ← Fixed size
└─ Typical Duration: 2-5ms

Operation: Cart Render
├─ Time Complexity: O(n) where n=items in cart
├─ Space Complexity: O(n)
└─ Typical Duration: 20-50ms for 20 items

Conclusion: Zero performance concerns ✓
```

---

## 🎓 Code Structure Overview

```
lib/
├── helpers/
│   └── wholesale_pricing_helper.dart ← NEW
│       ├── PricingTier enum
│       ├── determinePricingTier()
│       ├── getEffectivePrice()
│       └── calculateSavings()
│
├── models/
│   ├── get_product.dart (MODIFIED)
│   │   └── Stock {
│   │       + wholesalePrice
│   │       + wholesaleMinUnit
│   │     }
│   │
│   ├── local_models.dart (MODIFIED)
│   │   └── LocalCartItem {
│   │       + pricingTier
│   │       + wholesalePrice
│   │       + retailPrice
│   │       + savingsPerUnit
│   │       + totalSavings
│   │     }
│   │
│   └── local_models.g.dart (AUTO-GENERATED)
│
├── providers/
│   └── local_product_provider.dart (MODIFIED)
│       └── addToCart() {
│           + tier calculation
│           + savings calculation
│           + tax recalculation
│         }
│
└── screens/billing/
    ├── billing_page.dart (MODIFIED)
    │   └── _buildCartItemsTable() {
    │       + tier badge
    │       + savings display
    │     }
    │
    └── widgets/
        ├── compact_quantity_control_local.dart (MODIFIED)
        │   └── onQtyChange() {
        │       + tier toast notifications
        │     }
        │
        └── add_product_modal.dart (MODIFIED)
            └── _buildPricingInfo() {
                + tier preview
              }
```

---

## 🧠 Mental Model Summary

**Simple Way to Think About It:**

1. **When item added to cart:**
   - Check: "Is quantity high enough for wholesale?"
   - If YES: Use cheaper wholesale price + mark as WHOLESALE
   - If NO: Use regular retail price + mark as RETAIL

2. **When quantity changes:**
   - Re-check the same logic
   - If tier changed: Update price, tax, and show notification
   - Save updated item to cart and Hive

3. **When displaying cart:**
   - Show which tier is active (badge color)
   - Show savings amount (if wholesale)
   - Show price per unit clearly

4. **When saving order:**
   - Remember which tier was applied
   - Send this info to backend for audit
   - Can restore same tier if customer loads saved order

**That's it!** The logic is simple, just need to apply it consistently everywhere.
