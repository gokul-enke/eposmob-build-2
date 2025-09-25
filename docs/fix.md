Fix plan for Billing, Saving/Loading, Offline, and UI persistence

1) New saved orders: include all fields
- Problem: First-time save of a new saved order did not include transactionId, couponId, deliveryMethodId, carNumber, deliveryDate, deliveryTime, status.
- Fix: Extend call to saveCurrentCartAsOrder in _saveOrder new-order branch to pass all fields.
- Status: Implemented.
  - File: lib/screens/billing/billing_page.dart
  - Location: _saveOrder(), "Save as new order" branch, call to saveCurrentCartAsOrder now passes:
    - transactionId, couponId, deliveryMethodId, carNumber, status, deliveryDate, deliveryTime

2) Loading saved order: properly restore manually typed phone
- Problem: When rehydrating, phone-only orders showed as blank or as "name phone" with empty name.
- Fix: In _rehydrateFromProvider(), detect when no customer id/name and show only the phone; also set mobileNumberText and mark manual selection.
- Status: Implemented.
  - File: lib/screens/billing/billing_page.dart
  - Location: _rehydrateFromProvider(): conditional now sets text to phone-only when name/id missing.

3) Preserve manual phone across navigation
- Problem: After loading a saved order with a manually typed number and switching page, number got reset to default sales executive.
- Root cause: Customer fetch default was applied even after user/manual selection; and phone field became read-only due to sales executive lock.
- Fixes:
  a) Make phone field read-only only when salesExecutivemobileNumberText is not empty AND no manual selection AND not editing a saved order.
     - Change condition in _buildMobileNumberInput():
       (salesExecutivemobileNumberText != "" && !_isCustomerManuallySelected && currentOrder == null) ? read-only : editable
  b) Strengthen rehydrate gate and manual selection:
     - In _rehydrateFromProvider(), require non-empty customerPhone before restoring.
     - Mark _isCustomerManuallySelected = true after restore.
  c) In _fetchCustomers(), preserve user entry if text field contains non-executive text.
- Status: Implemented.
  - File: lib/screens/billing/billing_page.dart
  - Locations:
    - _buildMobileNumberInput() condition adjusted.
    - _rehydrateFromProvider() non-empty check and phone-only UI logic.
    - _fetchCustomers(): manual-preserve logic present; logging enhanced.

4) Saving updated order: correct customer phone priority
- Problem: Manual phone was not chosen when saving.
- Fix: Priority order: 1) mobileNumberText (manual), 2) selectedCustomerPhone (list), 3) mobileNumberTextController.text (fallback), 4) selectedCustomerPhone (final fallback)
- Status: Implemented in both update (current order) and new save branches.
  - File: lib/screens/billing/billing_page.dart

5) Clear cart resets all customer state
- Problem: After Clear Cart, phone could remain.
- Fix: _clearCart() now resets mobileNumberText, selectedCustomer*, isCustomerFound, salesExecutivemobileNumberText, controller text, autocomplete key.
- Status: Implemented.
  - File: lib/screens/billing/billing_page.dart

6) Confirmed order modal shows missing fields
- Problem: Transaction ID, Balance Amount, Car Number, Order Status, Customer Name, Delivery Method not shown.
- Fix: Added conditional rows for these fields in ConfirmedOrderDetailModal.
- Status: Implemented.
  - File: lib/screens/sales/widgets/confirmed_order_detail_modal.dart

7) Parity of MRP/Price persistence (already in place)
- Ensure LocalProductProvider saves/loads item.price and item.mrp across cart, saved_orders, confirmed_orders; and printing uses correct totals.
- Status: Confirmed present in provider and print flows.

8) Offline flows
- Confirmed orders and saved orders persist all fields in Hive. Rehydration and detail modal read them back and display.
- Status: Confirmed.

Test checklist (manual)
- Create a saved order with manually typed phone only, set coupon and discounts, a delivery method with car number/date/time, set a transaction number, and multi-payment; save as new order. Verify:
  1. Returning to Orders -> select the saved order: phone field shows the typed phone and stays after switching away and back.
  2. Open Confirmed Order Detail Modal (for confirmed ones): shows customer name/phone (if present), delivery method, transaction id, balance, car number, status, discounts, coupon, payment breakdown, delivery date/time.
  3. Update an existing saved order: make sure manual phone still saves.
  4. Clear Cart: customer phone and all UI resets.
  5. Confirm (online) and Save&Print (offline): items include MRP, payment JSON saved, delivery fields passed.
