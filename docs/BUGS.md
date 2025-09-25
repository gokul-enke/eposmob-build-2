Below is a consolidated “engineer-level” walkthrough of the two core files and the moving pieces they orchestrate.
1. HIGH-LEVEL COMPONENT MAP
• UI / State
BillingPageState (≈4 700 LOC) – the billing screen the cashier works in.
LocalProductProvider (≈1 800 LOC) – local/offline product & cart store backed by Hive.
Network helpers (only referenced here)
CartProvider – online cart / order API wrapper.
SalesProvider – fetches full order details for printing.
CustomerProvider – customer look-ups.
GeneralSettingsProvider – toggles “stock management”.
Persistence
Hive boxes: products, cart_items, saved_orders, confirmed_orders.
2. HOW THE BILLING PAGE WORKS END-TO-END
2.1 Lifecycle & Setup
initState
Fetch default customer list -> picks the current sales-executive as the default “customer”.
Loads any server cart (CartProvider.fetchCartDataFromApi).
Starts internet-connectivity stream (InternetConnectionCheckerPlus).
Wires up listeners for user switch / sales-executive switch.
2.2 Product entry
Two modes:
a) Barcode (setting barcodeSales == true):
Timer-debounced lookup → LocalProductProvider.filterProductByBarcode
For weight-encoded EAN-14 the qty logic reads prefix “000”, calculates kg / pcs.
When found it calls ProductCartHelper.handleProductSelection which, ultimately,
funnels back into LocalProductProvider.addToCart(... addToCartDirectly:true …).
If barcode not found → opens AddProductWithBarcodeModal to create product.
b) Manual autocomplete:
ProductAutocomplete builds out selectedProduct + (optionally) a selected Stock row.
The “Add Item” button assembles quantity / unitPrice / stock and calls
LocalProductProvider.addToCart (after injecting stockEnabled flag from
GeneralSettingsProvider).
2.3 Cart display
_buildCartItemsTable maps LocalProductProvider.cartItems → a table.
Quantity alteration happens inside CompactQuantityControlLocal which calls
LocalProductProvider.setCartItemQuantity / increment / decrement.
2.4 Multi-payment mini system
Three check-boxes (cash/card/upi) ↔ three amount fields.
Helper getSelectedPaymentMethods() only returns methods with >0 amount.
Summary rows shown in buildQuickAccessIcons.
Validation is done in confirmOrder / _createOrderAndPrint (fails if no method).
2.5 Action buttons
Clear Cart → LocalProductProvider.clearCart + UI reset.
Save Order (offline) → LocalProductProvider.saveCurrentCartAsOrder or updateSavedOrder
Save & Print (offline) → saveCurrentCartAsConfirmedOrder + PrintPage route.
Confirm Order / Confirm & Print (online) → build JSON for CartProvider.addToOrderAPI.
Always passes paymentMethods + paidMethods arrays (single or multi pay).
On success clears cart, optionally fetches order details for print, resets UI.
2.6 Editing an existing saved order
HorizontalSavedOrdersView returns orderId.
_loadSavedOrderForEditing loads it into LocalProductProvider.loadOrderForEditing ➜
rebuilds cart and very carefully patches every UI field (customer drop-down,
multi-payment, deliveryMethod, coupon, etc.).
When user presses “Save Order” again, updateSavedOrder overwrites Hive record.
3. LOCALPRODUCTPROVIDER – WHAT IT DOES
3.1 Product & Stock cache
Products fetched once online via fetchProductsFromAPI then serialized to
HiveProduct (json blob).
_stockEnabled flag is injected from BillingPage each time addToCart fires.
If true: addToCart, decrementCartItem, removeFromCart, clearCart call
updateStockQuantity to mutate in-memory & Hive product stock.
3.2 Cart
addToCart rules:
Identifies unique key by productId + selectedStock.id (null allowed).
If item exists: quantity +=, preserves existing custom price/mrp unless
caller passes new values.
If new: decides price/mrp order: custom > stock > product.
Every change persisted to HiveLocalCartItem.
Stock deduction/restoration happens whenever stockEnabled && stock != null.
3.3 Orders (local only)
SavedOrder (status “saved”), ConfirmedOrder (status “confirmed”).
Both persisted with full item list (price, mrp, selectedStock as json).
generateOrderNumber / generateConfirmedOrderNumber give ORD-N / CONF-N.
moveToConfirmedOrders migrates Hive records (used when “Save & Print” edits a saved order).
3.4 Price summary
cartTotal getter recalculates totals and creates PriceSummary instance
(discount, tax are currently stubs).
4. ONLINE SYNC PATH
1. BillingPage presses Confirm/Confirm + Print.
Builds items payload (id, qty, custom price, custom mrp, stock_id).
Calls CartProvider.addToOrderAPI with either:
paymentMethod null, paymentMethods list (multi-pay) OR
paymentMethod string, paidAmount string (legacy single-pay)
BalanceAmount, couponId, deliveryMethodId, etc. are included.
On success local cart is cleared; if Print variant, SalesProvider.listOrderDetails
-> PrintPage.
5. KNOWN WEAK POINTS / POTENTIAL BUGS
1. StockEnabled timing
BillingPage sets it only right before addToCart in some places.
If other code paths call addToCart directly without setting the flag
the provider assumes “stock disabled” and will not deduct.
Consider storing the boolean once from GeneralSettingsProvider at app start.
Payment method validation
_getSelectedPaymentMethods filters out methods with 0 amount – good.
But if user selects e.g. “Cash” checkbox and keeps amount 0 the method is
silently ignored; UI still shows Cash selected → confusion.
Balance logic
_updateBalanceAmount sets balance = max(totalPaid – cartTotal, 0).
That treats “balance” as change to return, not amount still due.
Everywhere else variable is called balanceAmount and shown in Balance row,
but Confirm/Print send balanceAmount to API (server most likely expects
“amount still due”, not change). If cartTotal < totalPaid a negative outstanding
is never sent – might break accounting.
addToCart pricing
When incrementing via quantity control and no explicit price is passed,
existing custom price is preserved – good.
But when adding same product again via Barcode (no price param) the code path
resets price if current cart price == 0 but preserves otherwise.
Edge case: custom price already set then want to switch back to base price
cashier has no way to do it.
Offline → online stock drift
Offline confirmed orders deduct stock only in local cache; once device
reconnects there is no code sending “stock consumed” delta to server.
Opening the app later after a full products download will overwrite local
stock quantities and lose deductions.
Multi-payment JSON parsing on order load
In loadSavedOrderForEditing the code expects savedOrder.paymentMethod
either plain “CASH” or a JSON string. The check startsWith('{')
fails for a JSON string starting with “[” (array). Only current writer
uses { so ok, but brittle.
_confirmOrder / createOrderAndPrint
Variable paymentMethod is computed but never sent (passed as null) when
multi-payment path is used – intentional, but if user uses single payment and
enters amount only in cashAmountController etc. selectedPaymentMethods
returns “CASH” (amount >0) so still multi-payment path, server may interpret
differently.
Race conditions on sales-executive switch
_onSalesExecutiveChanged resets customer only if _isCustomerManuallySelected
is false. That flag relies on many manual setState calls – easy to miss
a path and end up with previous executive’s customer.
Very large files
billing_page.dart at 4 700 LOC is close to Dart analyzer limits; hot-reload
compile times go up; consider splitting into widget classes.
6. RECOMMENDATIONS
1. Centralise stockEnabled: inject once into LocalProductProvider after login.
Replace balanceAmount semantic with two explicit fields: changeDue and
amountDue to avoid confusion (and verify API contract).
Extract state management logic from BillingPage into a
BillingController/BLoC – easier to test and maintain.
Implement a “sync queue” in LocalProductProvider to send offline-confirmed
orders and stock deltas when online.
Harden JSON-parsing (jsonDecode try/catch) and startWith check on “[”.
Unit-test addToCart paths for price/mrp overrides to avoid silent over-write.
Break payment modal into separate widget; enforce amount >0 or disable method.
7. TAKE-AWAY
• The overall architecture is solid: offline-first cart with Hive persistence,
optional stock tracking, and explicit online confirmation path.
No crash-level bugs spotted, but subtle logical issues (balance semantics,
stock-sync, payment validation) could bite production.
Refactoring BillingPage into smaller widgets + controller would massively
improve maintainability.