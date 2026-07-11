# Restaurant Mode → New Mobile Billing UI

## What's going on right now

We have **two separate mobile billing UIs** in the app:

1. **Old one:** `lib/screens/billing/restaurant/restaurant_page.dart`
   This one handles restaurant/dining (tables, KOT/kitchen printing, etc). It has its own mobile layout, its own bottom nav, everything built inside this one giant file.

2. **New one:** `lib/features/billing/presentation/pages/billing_page_mobile.dart` + the widgets under `lib/features/billing/presentation/widgets/mobile/`
   This is the clean, refactored mobile billing UI (product grid, cart, checkout sheets, etc). It currently only supports normal counter/delivery billing — **it does not know about tables or kitchen orders at all.**

**The task:** bring restaurant/table billing into the new UI, so eventually we can retire the old file's mobile layout.

Do NOT touch desktop billing (`billing_page.dart`) — it must keep working exactly as it does today. Only mobile files change.

---

## Step 1: Table Selection Screen

**Goal:** a mobile bottom-sheet where the waiter picks a dining table, similar to how Delivery/Coupon/Payment already open as sheets.

**New file to create:**
`lib/features/billing/presentation/widgets/mobile/billing/table_selection_sheet.dart`

**Look at these for reference:**
- `lib/features/billing/presentation/widgets/mobile/billing/delivery_options_sheet.dart` — copy this pattern (same sheet structure, same `MobileSheetHeader`)
- `lib/screens/billing/restaurant/widgets/tables_panel.dart` — this has the actual table-fetching/display logic you need to reuse (don't rewrite it, just wrap it in the new sheet look)
- `lib/providers/restaurant/table_provider.dart` — this is where table data comes from (`TableProvider.tables`, `loadTables()`)

**Criteria (must all be true when done):**
- [ ] Tapping the table row/button opens a sheet showing all tables (same data as desktop `TablesPanel`)
- [ ] Selecting a table closes the sheet and shows the table name somewhere visible (like `BillingSectionRow` shows the delivery method today)
- [ ] Selecting a table clears any selected delivery method, and vice versa — **a cart is either a table order OR a delivery order, never both.** (See `_selectDiningTable` / `_selectDeliveryMethod` in `restaurant_page.dart` for the existing rule.)
- [ ] Works with `flutter analyze` clean, no new warnings

---

## Step 2: Turn "Delivery" row into "Delivery OR Table" depending on mode

**File to change:**
`lib/features/billing/presentation/widgets/mobile/billing_tab.dart` (this is where `BillingSectionRow` for Delivery currently lives)

**Criteria:**
- [ ] Add a boolean flag, e.g. `isRestaurantMode`, passed down from `billing_page_mobile.dart`
- [ ] When `isRestaurantMode == true`, show a "Table" row (opens the new Step 1 sheet) instead of / in addition to the Delivery row
- [ ] When `isRestaurantMode == false`, behavior is 100% unchanged (this is important — don't break the existing delivery-only flow)

**How the flag gets there:**
`billing_page_mobile.dart` needs to accept a `restaurantMode` param (same idea as the existing `storeMode` param you'll see on `RestaurantPage` in the old file) and pass it down through `BillingMobileController`.

---

## Step 3: Kitchen actions (Send to Kitchen / KOT / Print)

**Goal:** in restaurant mode, the checkout buttons should include "Send to Kitchen" (KOT), not just "Confirm Order".

**Files to look at (old logic to copy, not to delete):**
- `lib/screens/billing/restaurant/restaurant_page.dart` — search for `_sendOrderToKitchenWithLoading`, `_printOrderWithLoading`, `_sendKotBillWithLoading`
- `lib/screens/print/print_kot.dart` — actual KOT printing logic

**File to change:**
`lib/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart`

**Criteria:**
- [ ] In restaurant mode, show a "Send to Kitchen" button
- [ ] Tapping it calls the same backend action as the old `_sendOrderToKitchenWithLoading` (don't reinvent — call into `CheckoutService`, same as everything else in mobile billing does)
- [ ] Shows a loading spinner while sending (copy the loading-state pattern already used for Confirm/Save buttons in this file)
- [ ] In normal (non-restaurant) mode, nothing changes

---

## Step 4: Ongoing table orders (orders already sent to kitchen, not yet paid)

**Goal:** waiter can tap a table that already has an active order and continue billing it (add items, take payment), instead of starting fresh.

**File to look at:**
`lib/features/billing/presentation/widgets/mobile/orders_tab.dart` — closest existing pattern for "list of orders, tap to open"

**Criteria:**
- [ ] Tables with an active/unpaid order show a visual badge (e.g. colored dot) in the Step 1 table sheet
- [ ] Tapping such a table loads its existing cart items instead of starting empty
- [ ] Saving/confirming that order clears the table's "active" badge

---

## General rules for the intern

1. **Never delete old code until the new code is proven working.** Old restaurant_page.dart stays until we explicitly decide to remove it.
2. **Reuse logic, don't copy-paste business rules.** If you find yourself copying a big function from `restaurant_page.dart`, stop and ask — usually it means that logic should move into a shared helper/service both old and new UI can call.
3. **Desktop must never break.** `billing_page.dart` (desktop) must not import anything from the mobile folder, and vice versa isn't a problem, but don't change shared services (`CheckoutService`, providers) in a way that changes desktop behavior.
4. **After every step:** run
   ```
   flutter analyze lib/features/billing
   flutter test
   ```
   Both must be clean/green before moving to the next step.
5. **Ask before guessing on business rules** — e.g. "can a table order and delivery order both be open on the same cart?" — the answer is no, but if unsure about something like this, ask rather than assume.

---

## Suggested order of work

1. Step 1 (table sheet) — safe, additive, no risk to existing flows
2. Step 2 (wire it into billing_tab with the mode flag) — still safe, flag defaults to off
3. Step 3 (kitchen actions) — touches checkout buttons, test carefully
4. Step 4 (ongoing orders) — most complex, do last
