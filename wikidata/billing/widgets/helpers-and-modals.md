# Billing Helpers, Widgets, And Modals

This file lists the delegated logic from files imported or called by `billing_page.dart`.

## ProductCartHelper

Source: `lib/helpers/product_cart_helper.dart`.

Responsibilities:

- Central product selection and add-to-cart path.
- Resolve effective customer from passed args or `CustomerSelectionProvider`.
- Sync stock-enabled state into `LocalProductProvider`.
- Sync stock grouping fields from `MasterDataProvider`.
- Filter available stock by active store.
- Group stock by configured pricing fields.
- Auto-select single group.
- Prefer sale-unit matching stock group when possible.
- Open stock modal when multiple groups exist.
- Preserve existing custom cart price when adding another quantity to same item.
- Pass sale-unit metadata into `LocalProductProvider.addToCart`.

## CartQuantityStockHelper

Source: `lib/helpers/cart_quantity_stock_helper.dart`.

Responsibilities:

- Apply quantity edits from cart controls and keyboard.
- Directly set provider quantity for decreases, disabled stock, or no selected stock.
- For increases, consume current stock/group first.
- For sale units, snap extra quantity to sale-unit base step.
- Offer alternate stock groups when current selection is exhausted.
- Use `StockSelectionModal` when multiple alternate groups exist.
- Return applied quantity so UI can correct itself when requested amount could not be fully applied.

## PaymentHelper

Source: `lib/helpers/payment_helper.dart`.

Responsibilities:

- Parse local multi-payment JSON for printing.
- Map method ids to readable names through master data and billing provider.
- Normalize local payment JSON into API payment payloads.
- Exclude credit-only DEBIT/BALANCE from paid methods.
- Deduct customer balance/change from first CASH/COD paid method before API sync.

## PaymentAutoFillHelper

Source: `lib/helpers/payment_auto_fill_helper.dart`.

Responsibilities:

- `remapAmountsAfterDiscount`: keep a single selected typed method aligned when discount/order total changes.
- `autoFillSingleMethod`: fill one typed method with remaining amount (can subtract other typed + extra amounts).
- `autoFillRemaining`: generic remaining fill for any method key (`cash`, `extra_<id>`, …) using a collected-amount map.

## PaymentValidation

Source: `lib/features/billing/domain/payment_validation.dart`.

Responsibilities:

- `sumCollected`, `hasCollectedPayment`, `computeNetDue`, `coversNetDue`.
- `validateForOrder`: minimum collected amount + covers net due.
- `isCheckoutPaymentComplete`: validation plus payment-step-visited / on-payment-step gate.

Used by:

- `PaymentMethodModal` apply button.
- `BillingPage._ensurePaymentReadyForConfirm`.
- `CheckoutModal._hasCompletedPaymentSetup`.
- `BillingProvider.validatePayment` (typed methods; ONLINE shortcut for terminal success).

## CheckoutModal

Source: `lib/features/billing/presentation/widgets/checkout_modal.dart`.

State copied locally:

- Customer list, selected customer, customer search.
- Quotation customer name/phone.
- Delivery method/id, selected delivery charge, car number, comment, address, date/time.
- Discount/coupon fields.
- Payment selected flags, amount strings, transaction, customer credit, dynamic extra methods.
- Quotation date and expiry date.
- Current step and confirmation/printing flags.

Step logic:

- Steps are Customer, Delivery, Discount, Payment.
- `initialStep` can open directly to a step.
- Delivery step is invalid when delivery is disabled.
- Quotation mode does not open payment step.
- App setting `skipCustomerSelection` can jump normal checkout to payment step when no explicit step was requested.

Keyboard logic:

- Has its own hardware key handler.
- Supports step navigation and confirm/print from keyboard when allowed.
- Focuses current step controls after frame.

Payment callback:

- `_handlePaymentUpdate` copies method flags/amounts/extra methods, marks payment modal opened, and calls parent callback.
- Payment step seeds autofill once via `_syncPaymentAutofillIfNeeded` so pre-filled cash on step 3 counts as configured.

Completion logic:

- Quotation requires quotation customer and valid date range.
- Normal checkout with `requireCheckoutCompletion: true` needs selected customer and `PaymentValidation.isCheckoutPaymentComplete`.
- Payment complete means: valid collected amounts **and** (payment step visited once **or** currently on payment step).
- Confirm/Print disabled message comes from `_disabledActionMessage` (specific text for missing amount vs insufficient amount vs customer).
- Save/quotation actions pass `requireCheckoutCompletion: false` so payment is optional for drafts.

## PaymentMethodModal

Source: `lib/features/billing/presentation/widgets/payment_method_modal.dart`.

Initialization:

- Loads payment methods from `MasterDataProvider` cache or API.
- Assigns typed method ids by value: CASH, CARD, UPI, COD.
- Creates dynamic extra method rows for every other method value.
- Restores initial typed and extra amounts; preserves extra amounts if methods reload.
- Restores initial debit amount as to-customer-credit.
- Tracks pristine auto-filled method (`cash` / `card` / … / `extra_<id>`) for clean switching.

Collected payment rows (typed + dynamic/extra):

- **Pristine switch:** untouched full-total method → select another → clear first, move full total.
- **Split:** select second method while first holds partial amount → second gets remaining balance.
- **Deselect refill:** deselect one of two → remaining method refills to full cart total.
- Typing in any amount auto-selects that method.
- Deselecting clears that method's amount.
- Keyboard shortcuts `C+1` … `C+4` apply to typed four only (not dynamic rows).

Credit row (bottom):

- Separate from collected payment rules.
- Auto-calculated; not validated by `PaymentValidation.validateForOrder`.

Balance:

- Collected = selected typed amounts + selected extra amounts only (`_getTotalCollectedAmount`).
- To-customer-credit/debit is not counted as collected cash.
- Default customer uses previous balance zero in modal balance math.
- Previous customer balance affects cash balance only when to-customer-credit is enabled and customer is not default.
- Negative displayed balance is clamped to zero.

Apply button:

- Runs `PaymentValidation.validateForOrder` before close.
- Shows error if no collected amount or insufficient total.

Callback:

- Emits typed method flags, typed amounts (empty string when deselected), debit mapped from customer credit, transaction number, customer credit flag, method ids, extra amount map, and extra value map.

## CouponModal

Source: `lib/features/billing/presentation/widgets/coupon_modal.dart`.

Behavior:

- Initializes from provider current discount or passed initial discount.
- Fetches discounts through `DiscountProvider` when empty.
- Finds selected discount by coupon code.
- Manual discount typing clears selected coupon.
- Selected coupon writes its discount value into flat or percentage field based on type.
- Validates non-empty cart.
- Rejects negative discounts.
- Rejects percentage greater than 100.
- Rejects flat discount above subtotal.
- Checks selected coupon validity against current cart total.
- Calls parent with flat and percentage values.

## DeliveryMethodModal

Source: `lib/features/billing/presentation/widgets/delivery_method_modal.dart`.

Behavior:

- Initializes delivery method/id, car number, comment, address, date, and time.
- Shows methods from `DeliveryMethodsProvider`.
- Uses translated labels for known method names.
- Arrow keys traverse delivery method tiles.
- Shows car number input only for Car Delivery.
- Shows date/time controls when `appSettings.askDeliveryDate` is true.
- Shows saved customer addresses for Door Delivery.
- Emits selected method/id, car number, comment, date, time, and address.

## PriceFields

Source: `lib/features/billing/presentation/widgets/price_fields.dart`.

`PriceTextField`:

- Converts sale-unit display price to base price.
- Updates provider on change.
- Enforces minimum sale price on blur/submit.
- Handles arrow up/down and tab commit.
- Avoids overwriting text while physical or virtual keyboard is editing.

`MrpTextField`:

- Converts sale-unit display MRP to base MRP.
- Updates provider on change and submit.
- Allows empty text as zero during editing.

`TaxTextField`:

- Displays tax rate read-only.

## CompactQuantityControlLocal

Source: `lib/widgets/compact_quantity_control_local.dart`.

Behavior:

- Displays sale-unit quantity while provider stores base quantity.
- Converts display to base before sync.
- Plus/minus and text edits call stock-aware helper.
- Debounce delay is currently zero milliseconds.
- Maintains pending quantity and updating flag to avoid overlapping sync.
- Handles external edit/refresh requests by identity key.
- Keeps text stable while user edits.

## StockSelectionModal

Source: `lib/widgets/stock_selection_modal.dart`.

Behavior:

- Groups stocks by active pricing fields.
- Displays combined stock options.
- Combined quantity is sum of grouped stock quantities.
- Representative stock is earliest expiry/date/id.
- Returns selected combined stock plus original stock list.

## ProductAutocomplete And Sidebar Lists

Billing uses these widgets for product selection:

- `ProductAutocomplete`
- `SideBarProductList`
- `HorizontalProductViewLocal`

Their selected products route back into the same `ProductCartHelper` and `LocalProductProvider` cart mutation path. This keeps barcode, search, sidebar, and horizontal product flows consistent.

## Saved Orders View

`HorizontalSavedOrdersView` displays saved local orders and returns selected order id to the page.

Page responsibility after selection:

- Save current cart as draft if needed.
- Load selected order for editing.
- Rehydrate UI state.

## Product Details Dialog

Product details icon opens `ProductDetailsDialog` when role permission allows it.

The dialog is informational from billing row context. It does not replace the cart mutation path.

## Customer Purchase History Modal

`CustomerPurchaseHistoryModal` displays fetched purchase history entries.

Page applies selected price only after:

- User chooses an entry.
- Entry is not "use current price".
- Price passes minimum-sale validation.

## Add Product Modal

When barcode lookup fails, billing opens `AddProductWithBarcodeModal` with:

- scanned barcode
- `isAddToCart: true`

The page clears barcode field and restores barcode focus after closing.

## Cash Drawer And Sync Widgets

Header includes:

- `OpenCashDrawerButton`, also triggered by `Alt+D`.
- `SyncButton`, plus sidebar empty-state resync.

Cash drawer shortcut calls `CashDrawerService.openCashDrawer`.

Sync shortcut helper exists but is not currently bound to `Ctrl+S`; the visible `SyncButton` remains the active UI path.
