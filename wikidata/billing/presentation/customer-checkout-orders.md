# Customer, Checkout, Orders, Printing, And Quotation Logic

Source: `lib/features/billing/presentation/pages/billing_page.dart`.

## Mobile scope

**Production v1:** Quotation mode is **not** available on mobile billing (`billing_page_mobile.dart` and `presentation/widgets/mobile/`). Mobile supports retail POS actions only (cart, save draft, confirm, print). Quotation entry (`BillingPageMode.quotation`, Create Quotation, Quotation List) and `_createQuotationFromCheckout` remain **desktop-only** until Phase 2. Verified 2026-06-30: no quotation affordances under `mobile/`.

## Customer Input

The mobile/customer field supports typed search and selection.

Search behavior:

- Numeric input searches customers by phone.
- Non-numeric input searches customers by name.
- The options builder updates `_currentCustomerOptions`.
- A 10 digit numeric input with exactly one result marks `isCustomerFound`.
- Arrow up/down changes highlighted option.
- Enter selects the highlighted option.

On customer selected:

- Sets `CustomerSelectionProvider`.
- Fetches cart API data for the selected customer.
- Updates selected customer id, phone, model, and text controller.
- Marks customer as manually selected.

Default/customer clear behavior:

- Add customer opens customer modal and then tries to select the created customer by response data or phone.
- Clear customer clears `CustomerSelectionProvider`, selected customer fields, controller text, customer-found flag, and focus.
- Default auto-assigned customer is controlled by app settings and sales executive/user switch events.

## Default Customer Rules

`_applyDefaultCustomerFromCacheIfNeeded` applies a default customer only when:

- There is no current order.
- User did not manually choose a customer.
- No selected customer already exists.
- `appSettings.autoAssignDefaultCustomer` is enabled.
- Default phone exists and matches a cached customer.

If no matching customer object exists, the phone text can be filled but the provider selection is cleared.

Quotation mode:

- `_clearAutomaticDefaultCustomerForQuotation` removes automatic default customer unless editing a current quotation draft.
- `_isDefaultCustomerPhone` returns false for current quotation drafts.

## Customer Balance Display

Balance display is hidden when:

- Phone is empty.
- Customer is default customer, except current quotation draft handling.
- The phone belongs to the sales executive automatic customer value.

Positive balance shows with plus sign. Negative balance is displayed as debt. Zero is neutral.

## Action Buttons

Buttons are disabled while `_isOrderActionInProgress`.

Normal page:

- Clear cart: `F1`.
- Save Order: `F8`.
- Confirm & Print: `F6`, online only.
- Confirm Order: `F2`, online only and controlled by `appSettings.showConfirmOrderButton`.
- Save & Print: `F9`, shown when offline.

Quotation page:

- Create Quotation.
- Quotation List navigates by setting sidebar index `87`.

## Saving Current Cart As Draft

`_saveCurrentCartAsDraft` collects:

- Payment method JSON and paid amount from `_getPaymentMethodData`.
- Customer name, phone, id, and type.
- Coupon id and discount state.
- Delivery method, delivery charge, comment, car number, date/time, address.
- Transaction number, paid amount, balance amount, customer credit flag.

If editing an existing local order:

- Calls `LocalProductProvider.updateSavedOrder`.

If no current order:

- Calls `LocalProductProvider.saveCurrentCartAsOrder(status: "saved")`.

## Resetting And Clearing Workspace

`_resetBillingWorkspaceUi` clears:

- Coupon code/state.
- Transaction, paid, balance.
- Payment selected flags and amount controllers.
- Dynamic extra payment amount/value maps.
- To-customer-credit state.
- Product entry fields and selected product.
- Delivery values.
- Comments and car number.
- Selected customer fields and autocomplete keys.
- Last rehydrated order id.
- `CustomerSelectionProvider`.

`_clearOrderWorkspace` decides how to clear provider cart:

- `clearCart()` restores stock reservations.
- `clearCartAfterOrder()` does not restore stock reservations.
- It also clears current order and resets page UI.

Rule:

- Use stock restore for draft/cancel/new workspace.
- Do not restore stock for confirmed/local sold orders.

## Clear Cart

`_clearCart`:

- Uses busy guard.
- Sets clear loading flag.
- Calls `_clearOrderWorkspace(preserveStockDeduction: false)`.
- Shows success/failure message.

## Save Order

`_saveOrder`:

- Uses busy guard.
- Requires non-empty cart.
- Calls `_saveCurrentCartAsDraft`.
- Clears workspace with stock restore.
- Shows saved message.

Saved draft has copied reservations, so active cart reservations are restored when leaving the workspace.

## Cart Change And Payment

When `LocalProductProvider` cart changes after payment was configured:

- Billing page clears collected amount controllers and extra-method maps.
- Resets payment-modal-opened flag.
- Recalculates balance.

User must reconfigure payment before confirm/save-and-print.

## Save Order And Print

`_saveOrderAndPrint`:

- Uses busy guard.
- Requires non-empty cart.
- Requires customer id or customer text.
- Calls `_ensurePaymentReadyForConfirm`: opens payment modal if needed, then runs `PaymentValidation.validateForOrder` (collected amounts must cover net due).
- If editing current order, updates saved order and moves it to confirmed orders.
- If no current order, creates confirmed local order.
- Prints through `printFromSavedOrder`.
- Resets autocomplete and clears workspace with `preserveStockDeduction: true`.

This means local confirmed orders keep stock deducted.

## Create New Order

`_createNewOrder`:

- If cart has items, saves current cart as draft.
- Clears workspace with stock restore.
- This lets cashier start a fresh cart without losing current draft.

## Loading Saved Order

`_loadSavedOrderForEditing`:

- Uses busy guard.
- Calls `LocalProductProvider.loadOrderForEditing`.
- Rehydrates page state.
- Refreshes payment method ids and rehydrates again.

Saved order load releases current cart reservations, clears cart, clones saved items, and re-reserves saved reservations.

## Checkout Modal Setup

`_showCheckoutModal`:

- Releases focus.
- Hydrates customer cache.
- In quotation mode, avoids default customer assignment.
- Clears automatic default customer for quotation.
- Refreshes payment method ids.
- Applies default payment method only when not quotation and no existing payment state.
- Passes current delivery, payment, discount, customer, quotation date, and extra payment method state into `CheckoutModal`.

Callbacks from modal update page state:

- Customer selection updates page fields and `CustomerSelectionProvider`.
- Add customer creates/selects customer and inserts into local list if response has data.
- Discount applies or clears `LocalProductProvider` discounts.
- Payment updates typed method flags, amount controllers, extra dynamic maps, payment ids, modal-opened flag, `BillingProvider` payment mirror, and balance.
- Delivery updates method/id, comments, car number, date/time, address, and charge.

Modal dismiss without checkout clears action loading flags and restores shortcut focus.

## Checkout Modal Completion Rules

Normal checkout:

- If `requireCheckoutCompletion` is false, confirm can proceed without completed customer/payment steps (draft save, quotation save).
- Otherwise customer must be selected.
- Payment must pass `PaymentValidation.isCheckoutPaymentComplete`:
  - Valid collected amounts (typed + selected extra methods) covering net due.
  - Payment step visited once **or** currently on payment step (autofill on step 3 counts).
- Quote-only customer needing save blocks confirm.

Quotation checkout:

- Requires a quotation customer.
- Expiry date cannot be before quotation date.
- Payment step is not used.

## Online Confirm And Print

`_createOrderAndPrint`:

- Requires internet.
- Calls `_ensurePaymentReadyForConfirm` (modal if needed + `PaymentValidation.validateForOrder`).
- Uses busy guard.
- Requires selected customer and Car Delivery car number when method is Car Delivery.
- Requires access token and cart id.
- Requires non-empty cart.
- Builds item payload with `LocalProductProvider.buildOrderItemsPayload`.
- Calls `CartProvider.addToOrderAPI`.
- Sends payment methods, paid methods, balance, comments, delivery, discount, credit, address, delivery charge, and quotation id.
- On success, refreshes customers in background, deletes current local order if present, clears cart after order, fetches order details, prints, optionally prints customer copy, clears state, and clears workspace without restoring stock.

Printing:

- First tries `PrintPage.autoPrint`.
- If auto-print fails, navigates to `PrintPage`.
- Double bill setting can ask to print customer copy.

## Online Confirm Without Print

`_confirmOrder` has the same validation and API payload as confirm-print, but skips fetching print details.

On success:

- Deletes current local saved order if present.
- Clears cart after order.
- Resets payment/customer/product/delivery/coupon fields.
- Clears `CustomerSelectionProvider`.
- Resets autocomplete.

Important current-code note: it then calls `_clearCart()` while the busy guard is still active. Since provider cart is already cleared, this is effectively redundant and may be blocked by the guard.

## Quotation Flow

**Desktop only** (see Mobile scope above).

`_createQuotationFromCheckout`:

- Requires non-empty cart.
- Requires existing customer id or inline quotation customer name.
- Requires expiry date not before quotation date.
- Builds payload with store id, customer data, delivery method id, shipping cost, quotation date, expiry date, discount, comment, and items.

Quotation item payload:

- `product_id`
- display quantity if sale unit is used, otherwise base quantity.
- display price if sale unit is used, otherwise base price.
- `product_stock_id` as first stock group id when only one group id exists, otherwise selected stock id where available.
- `product_sale_unit_id` when sale unit is used.

On success:

- Resets quotation dates.
- If print was requested, extracts created quotation id from several possible response shapes, fetches details, and prints through `QuotationPrintService`.
- May print customer copy based on app setting.
- Clears cart.

## Printing Saved Orders

`printFromSavedOrder` delegates to `PrintService.printSavedOrder` and then uses the same optional customer-copy logic.

Older manual order-detail conversion logic remains commented out in the page and is not active.
