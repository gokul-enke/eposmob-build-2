# Restaurant Order Panel — Mobile Responsiveness

## Problem
The mobile order panel (New Order / checkout screen) was not optimized for mobile:
1. `OrderPanel` was rendering with `isCompact: false` on mobile — causing desktop-sized buttons (48px), paddings, and fonts, leaving almost no room for cart items.
2. The summary card always showed 4 rows (Net Amount, Total Payable, Total Paid, Balance), taking up too much vertical space on mobile.

## Files Changed

### 1. [restaurant_page.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/billing/restaurant/restaurant_page.dart)
- Added `isCompact: true` to the `OrderPanel` instantiation inside `_buildOrdersView()` (mobile layout path).
- Desktop `OrderPanel` instantiation left untouched.

### 2. [order_panel_current_cart.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/billing/restaurant/widgets/order_panel_current_cart.dart)
- Updated `_buildCurrentCartSummaryCard` signature to accept `isCompact: bool = false`.
- When `isCompact: true` — collapses to a single "Total Payable" row with ▼ chevron by default.
- Tap to expand full 4-row breakdown with ▲ chevron.
- Tap again to collapse.
- Uses `StatefulBuilder` for local toggle state.
- No provider or business logic touched.
- Desktop (`isCompact: false`) layout left untouched.

## Result
- Cart items now clearly visible on mobile (2-3+ items visible without scrolling).
- Summary card collapsed by default saving ~60-70px of vertical space.
- Full breakdown accessible on tap.
- Desktop layout completely unchanged.

## Status
- Tested on mobile ✅
- Ready to commit to `mubashir-dev`
