# Billing Mobile Production Readiness TODO

Goal: make the mobile billing flow 100% production ready against the local billing reference in `wikidata/billing`.

This document is intentionally strict. Billing is money, stock, customer credit, delivery, tax, and printing. A mobile screen can look finished while still producing wrong order data. Treat this as the checklist to finish before calling mobile billing production ready.

## Production Ready Definition

- [ ] Mobile billing uses the same domain rules as desktop billing unless a documented mobile-specific exception is approved.
- [ ] Widgets are mostly presentation. Business rules live in helpers, providers, controllers, coordinators, or services.
- [ ] Cart mutations go through shared cart/product helpers, not duplicated widget logic.
- [ ] Stock reservation, sale-unit identity, cart clearing, saved draft, confirmed order, and online sale semantics match the wiki.
- [ ] Payment payloads support typed methods, dynamic backend methods, online terminal payments, and customer credit correctly.
- [ ] Barcode scanner input cannot be dropped during rapid scanning.
- [ ] Save, confirm, print, clear, and load operations have busy guards and cannot double-submit.
- [ ] The app survives offline/online changes, route changes, background/foreground, and token refresh situations.
- [ ] All P0 and P1 tasks below are done, tested, and manually verified on real mobile hardware.

## Priority Meaning

- `P0`: Must finish before production merge. These can cause data loss, wrong billing, wrong stock, or failed checkout.
- `P1`: Must finish before calling mobile billing feature-complete.
- `P2`: Hardening required before broad rollout.
- `P3`: Nice-to-have polish after production safety is achieved.

## Current Good Wiring To Preserve

- [ ] `LocalProductProvider` remains the owner of local cart, products, stock reservations, discounts, totals, saved drafts, confirmed local orders, and Hive persistence.
- [ ] `ProductCartHelper.handleProductSelection` remains the central product add path.
- [ ] `CheckoutService` remains the shared confirm, confirm-print, and save-order service layer.
- [ ] `CartProvider.addToOrderAPI` remains the online order API entry point.
- [ ] `BillingProvider.getPaidMethods` remains responsible for API paid-method normalization.
- [ ] `PaymentHelper.normalizePaidMethodsForApi` remains the rule for deducting customer balance/change from CASH/COD paid methods.
- [ ] Customer selection continues to write into both `BillingProvider` and `CustomerSelectionProvider`.
- [ ] `DeliveryMethodsProvider` remains the delivery methods cache/source.
- [ ] Barcode processing keeps embedded barcode and sale-unit barcode support.
- [ ] Pine Labs success continues to select `ONLINE` payment and write the transaction reference.

## Non-Negotiable Architecture Rules

- [ ] Do not put pricing, stock, payment, or checkout business rules directly inside mobile widgets.
- [ ] Do not duplicate desktop billing rules in mobile widgets if a shared helper/service already exists.
- [ ] Do not bypass `ProductCartHelper` when adding products.
- [ ] Do not bypass `CartQuantityStockHelper` when changing cart quantity from UI.
- [ ] Do not bypass `PaymentHelper` for payment payload conversion.
- [ ] Do not clear cart state after save/confirm/print unless the operation result proves it is safe.
- [ ] Do not merge cart lines unless product id, selected stock, stock group ids, and sale unit id match correctly.
- [ ] Do not store sale-unit display quantity as base quantity without conversion.
- [ ] Do not treat customer credit/debit as collected payment.
- [ ] Do not assume a backend tenant only has CASH, CARD, UPI, and COD.
- [ ] Do not assume stock is enabled just because a product has stock rows.
- [ ] Do not block add-to-cart at card level when `ProductCartHelper` should decide stock fallback or stock modal behavior.
- [ ] Do not introduce mobile-only order payload shapes unless `CartProvider.addToOrderAPI` and printing/sync code support them.
- [ ] Do not ignore `mounted` after awaited UI operations.
- [ ] Do not log customer phone, token, transaction id, or full payment payload in production logs.

## P0 - Billing Safety And Data Correctness

### P0.1 Save Order Must Not Clear Cart On Failure

- [ ] Replace the ambiguous `CheckoutService.saveOrder()` boolean with a clear result type.
- [ ] Suggested result: `SaveOrderResult.savedNew`, `SaveOrderResult.updatedExisting`, `SaveOrderResult.validationFailed`, `SaveOrderResult.failed`.
- [ ] Update `BillingPageMobile.saveOrder()` to clear the workspace only after `savedNew` or `updatedExisting`.
- [ ] Keep the cart intact when save fails due to empty cart, invalid price, exception, Hive failure, or validation error.
- [ ] Make the user message match the actual result.
- [ ] Add unit/widget tests proving failed save does not clear cart.
- [ ] Add test proving successful new draft save clears active workspace and preserves saved draft items.
- [ ] Add test proving successful existing draft update does not duplicate saved orders.

Acceptance:

- [ ] If a cart item has invalid price, tapping save shows error and cart remains unchanged.
- [ ] If Hive/provider save throws, cart remains unchanged.
- [ ] If save succeeds, saved order is visible in Orders and active workspace is reset safely.

### P0.2 Barcode Scanner Must Use FIFO Queue, Not Drop Events

- [ ] Replace debounce/drop behavior with a FIFO barcode queue.
- [ ] Queue must accept rapid scanner events while one barcode is processing.
- [ ] Queue must process one barcode at a time in original scan order.
- [ ] Queue processor must await `processBarcode`.
- [ ] Queue processor must continue after product add, missing barcode modal, or error.
- [ ] Empty barcode can be ignored, but non-empty scanned values must not be dropped.
- [ ] Keep embedded barcode support for 14-character values starting with `000`.
- [ ] Keep KG/KGS and PC/PCS embedded quantity parsing.
- [ ] Keep sale-unit barcode matching.
- [ ] Keep unknown barcode opening `AddProductWithBarcodeModal` with `isAddToCart: true`.
- [ ] Add tests for scanner bursts.

Acceptance:

- [ ] Scanning 10 valid products rapidly adds all 10 in order.
- [ ] A failed barcode does not block later queued barcodes.
- [ ] A sale-unit barcode still adds with the correct sale unit.
- [ ] Embedded barcode still computes quantity correctly.

### P0.3 Mobile Product Cards Must Not Incorrectly Block Add-To-Cart

- [ ] Remove raw stock-row add blocking from `MarketProductGrid`.
- [ ] Remove raw stock-row add blocking from `ProductCard`.
- [ ] Let `ProductCartHelper.handleProductSelection` decide stock enabled, stock fallback, stock modal, and insufficient-stock error.
- [ ] Product card stock badge can stay visual, but it must not be the source of add-to-cart business logic.
- [ ] If stock is disabled, products with no stock rows must still be addable.
- [ ] If stock is enabled and all stock rows are zero, helper fallback/behavior must match `wikidata/billing/presentation/product-entry-sidebar-cart.md`.
- [ ] Add widget test for product with no stock when stock management disabled.
- [ ] Add widget test for stock-enabled product with multiple stock groups opening stock selection modal.

Acceptance:

- [ ] A no-stock product can be added when stock management is disabled.
- [ ] A product with stock groups still routes through `StockSelectionModal` when needed.
- [ ] The mobile home screen never directly decides billing stock validity.

### P0.4 Mobile Quantity Changes Must Use Stock-Aware Helper

- [ ] Replace direct `LocalProductProvider.setCartItemQuantity` calls from mobile cart UI with `CartQuantityStockHelper.syncCartItemQuantity`.
- [ ] Keep sale-unit display quantity conversion before sending target quantity.
- [ ] Ensure increases consume current stock/group first.
- [ ] Ensure sale-unit increases snap to sale-unit base step.
- [ ] Ensure alternate stock groups are offered when current selection is exhausted.
- [ ] Ensure decreases directly release stock reservations.
- [ ] Add tests for increase, decrease, sale-unit step, insufficient current stock, and alternate group selection.

Acceptance:

- [ ] Plus/minus on mobile behaves like desktop cart quantity controls.
- [ ] Stock reservations remain correct after repeated mobile quantity edits.
- [ ] Sale-unit cart lines do not drift between display and base quantity.

### P0.5 Dynamic Backend Payment Methods Must Work On Mobile

- [ ] Mobile payment UI must render backend payment methods beyond CASH, CARD, UPI, and COD.
- [ ] Dynamic methods must have selected state, amount controller, method id, and display value.
- [ ] Dynamic method amount must be included in collected amount and balance calculation.
- [ ] Dynamic method must be included in saved order payment JSON.
- [ ] Dynamic method must be included in online API `payment_method` and `paid_methods`.
- [ ] Dynamic method must rehydrate correctly when loading a saved order.
- [ ] Dynamic method must print correctly for saved/local orders.
- [ ] Debit/customer credit must remain excluded from collected paid methods.
- [ ] Add tests with a fake backend method such as CHEQUE or WALLET.

Acceptance:

- [ ] A tenant with CASH, CARD, UPI, COD, CHEQUE can select CHEQUE on mobile.
- [ ] CHEQUE amount contributes to paid total.
- [ ] Saved draft with CHEQUE reloads with CHEQUE selected and amount restored.
- [ ] Confirm order sends CHEQUE method id and amount to API.

### P0.6 Payment Amount Remap After Discount Must Be Correct

- [ ] Apply `PaymentAutoFillHelper.remapAmountsAfterDiscount` or equivalent shared logic after coupon/manual discount changes.
- [ ] If one selected method previously matched old payable total, update it to new payable total.
- [ ] If split payment is manually entered, do not overwrite user-entered split amounts incorrectly.
- [ ] Recalculate balance after coupon apply and coupon clear.
- [ ] Include dynamic extra methods in collected total.
- [ ] Keep debit/customer credit excluded from collected total.
- [ ] Add tests for one selected method, split methods, debit enabled, and dynamic method selected.

Acceptance:

- [ ] Cash selected for full amount automatically adjusts after applying coupon.
- [ ] Cash plus card split does not get destroyed by coupon if user manually split amounts.
- [ ] Customer credit amount remains the remaining payable and is not counted as collected cash.

### P0.7 Confirm And Confirm-Print Must Have Full Busy Guards

- [ ] Add explicit in-flight guards for confirm, confirm-print, save order, clear cart, load saved order, and create new order.
- [ ] Disable buttons while each operation is running.
- [ ] Prevent double tap from submitting two API orders.
- [ ] Prevent print button double tap from printing the same order twice.
- [ ] Ensure all flags reset in `finally`.
- [ ] Ensure route pop/background during operation cannot leave stale loading state.
- [ ] Add tests for double tap confirm and confirm-print.

Acceptance:

- [ ] Double tapping Confirm creates one API call.
- [ ] Double tapping Confirm & Print creates one API call and one print job.
- [ ] Failed API call resets UI loading state.

### P0.8 Online Confirm Payload Must Match Desktop Semantics

- [ ] Confirm requires internet.
- [ ] Confirm requires customer id or mobile customer phone according to desktop rules.
- [ ] Confirm requires at least one selected payment method.
- [ ] Confirm requires car number for Car Delivery.
- [ ] Confirm requires non-empty cart.
- [ ] Confirm validates price and MRP.
- [ ] Confirm uses `LocalProductProvider.buildOrderItemsPayload`.
- [ ] Confirm sends payment method ids, paid methods, balance, comment, delivery method id, car number, delivery date/time, coupon, discount, customer credit, address, and delivery charge.
- [ ] Confirm clears active cart with `clearCartAfterOrder`, not `clearCart`.
- [ ] Confirm deletes current saved draft if confirming an edited saved order.
- [ ] Confirm resets customer/payment/delivery/product/coupon state after success.
- [ ] Add tests for each validation failure.

Acceptance:

- [ ] Failed validation never mutates cart, stock reservations, or saved orders.
- [ ] Successful online order does not restore stock.
- [ ] API payload matches desktop payload for the same cart and payment state.

### P0.9 Delivery Charge Must Be Computed Once And Sent Correctly

- [ ] Extract delivery charge calculation into a shared service/helper if not already clean.
- [ ] If `freeDeliveryEnabled` is false, delivery charge must be zero.
- [ ] If free-delivery threshold is configured and order amount qualifies, delivery charge must be zero.
- [ ] Otherwise selected delivery method base price must be used.
- [ ] Footer display and order total must match the wiki split behavior.
- [ ] API payload must include delivery charge when applicable.
- [ ] Saved order must persist delivery charge or enough state to recalculate accurately.
- [ ] Add tests for disabled free delivery, below threshold, at threshold, above threshold, missing method, and selected method base price.

Acceptance:

- [ ] Mobile total payable equals desktop for same cart and delivery method.
- [ ] Confirm API receives the expected delivery charge.

### P0.10 Stock Reservation Release Semantics Must Be Exact

- [ ] Clear active workspace must restore active cart reservations.
- [ ] Save draft must preserve draft reservations and safely reset workspace.
- [ ] Load saved draft must release current workspace reservations before loading.
- [ ] Load saved draft must reapply saved reservations.
- [ ] Confirm online order must clear without restoring stock.
- [ ] Confirm local/saved order must keep sold stock deducted.
- [ ] Delete saved draft must restore saved reservations if needed.
- [ ] Add provider-level tests for each state transition.

Acceptance:

- [ ] Stock count returns when user clears an unconfirmed cart.
- [ ] Stock count does not return after successful online confirm.
- [ ] Loading one draft after another does not double-reserve stock.

## P1 - Mobile Feature Parity With Billing Wiki

### P1.1 Product Entry Header Must Respect `barcodeSales`

- [ ] Mobile Home tab must show barcode input when `appSettings.barcodeSales` is enabled.
- [ ] Mobile Home tab must show autocomplete/product search when barcode sales is disabled.
- [ ] `MobileHomeTab` must either use its existing callbacks or remove dead parameters and wire the feature elsewhere.
- [ ] Submitting barcode input must use the same barcode queue as scanner stream.
- [ ] Product autocomplete selection must route through `ProductCartHelper`.
- [ ] Quantity and custom price entry must support the same rules as desktop product entry where mobile UX requires it.
- [ ] Focus restore must return to barcode or autocomplete after dialogs.
- [ ] Add widget tests for both barcode-sales enabled and disabled modes.

Acceptance:

- [ ] User can add product by scanner, manual barcode, and product search on mobile.
- [ ] App setting change switches input mode correctly.

### P1.2 Cart UI Must Support Sale Units

- [ ] Cart row must display current sale-unit name when item has sale unit.
- [ ] Cart row must allow switching between base unit and valid sale units.
- [ ] Sale-unit menu must remove duplicate units by id.
- [ ] Changing sale unit must preserve correct base quantity and price/MRP conversion.
- [ ] Sale-unit cart identity must prevent wrong merge.
- [ ] Sale-unit payload must use sale-unit fields only when conversion can round-trip safely.
- [ ] Add tests for base-to-sale-unit, sale-unit-to-base, duplicate sale units, and payload.

Acceptance:

- [ ] Mobile and desktop build identical order item payloads for same sale-unit cart.

### P1.3 Cart UI Must Support Price, MRP, And Tax Fields

- [ ] Mobile cart row must expose price edit when permitted by role/settings.
- [ ] Mobile cart row must expose MRP edit when required by current billing rules.
- [ ] Tax rate must display read-only where applicable.
- [ ] Tax amount must use inclusive formula: `price * quantity * rate / (100 + rate)`.
- [ ] Price field must enforce minimum sale price rules.
- [ ] Sale-unit display price must convert to base price before saving.
- [ ] Do not overwrite text while physical or virtual keyboard is editing.
- [ ] Add tests for minimum price, sale-unit price conversion, tax extraction, and manual override persistence.

Acceptance:

- [ ] Mobile row totals, subtotal, tax, and payable match desktop for edited price rows.

### P1.4 Cart UI Must Support Product Details And Purchase History

- [ ] Product details action must respect role permission.
- [ ] Purchase history action must respect app setting and non-default selected customer.
- [ ] Purchase history modal must fetch by selected customer and product.
- [ ] Applying old price must respect minimum sale price.
- [ ] Add tests for permission hidden/shown and history price application.

Acceptance:

- [ ] Cashier can inspect product details and customer purchase history from mobile cart where allowed.

### P1.5 Cart Keyboard And Scanner-Friendly Workflow

- [ ] Support hardware keyboard shortcuts required for mobile/tablet POS hardware.
- [ ] Define mobile-supported shortcut subset explicitly if full desktop set is not practical.
- [ ] Implement Esc focus restore.
- [ ] Implement F2/F3/F4/F5/F6/F7/F8/F9/F12 or document accepted mobile differences.
- [ ] Implement Ctrl+A barcode focus if scanner keyboard wedge needs it.
- [ ] Do not interfere with text input fields while editing.
- [ ] Add tests for shortcut dispatch.

Acceptance:

- [ ] Mobile POS can be operated with scanner and keyboard without touching screen for the main sale flow.

### P1.6 Customer Selection Must Match Checkout Rules

- [ ] Customer search by phone and name must remain fast with large customer lists.
- [ ] Selected customer must update `CustomerSelectionProvider`.
- [ ] Selected customer must update `BillingProvider`.
- [ ] Selected customer must update `CartProvider.fetchCartDataFromApi` context.
- [ ] Clear customer must clear all duplicated customer state.
- [ ] Default customer behavior must match app settings.
- [ ] Skip-customer-selection behavior must match checkout rules.
- [ ] Customer balance must display clearly and feed payment balance/customer credit rules.
- [ ] Add customer flow must create/select customer and refresh local list.
- [ ] Add tests for select, clear, default customer, add customer, and customer balance.

Acceptance:

- [ ] Product helpers always see the same selected customer as the UI.

### P1.7 Delivery UI Must Include Date And Time When Required

- [ ] If `appSettings.askDeliveryDate` is enabled, show delivery date control.
- [ ] If `appSettings.askDeliveryDate` is enabled, show delivery time control.
- [ ] Save delivery date/time in `BillingProvider`.
- [ ] Persist delivery date/time in saved orders.
- [ ] Rehydrate delivery date/time when loading saved order.
- [ ] Send delivery date/time to `CartProvider.addToOrderAPI`.
- [ ] Keep Car Delivery car number validation.
- [ ] Keep Door Delivery saved address suggestions.
- [ ] Add tests for date/time required and not required.

Acceptance:

- [ ] Mobile saved draft and online order preserve delivery date/time exactly.

### P1.8 Coupon And Discount Must Be Fully Parity-Safe

- [ ] Manual flat discount validates non-negative amount.
- [ ] Manual percentage discount validates range 0 to 100.
- [ ] Flat discount cannot exceed subtotal.
- [ ] Selected coupon must validate against current cart total.
- [ ] Selected coupon must call API coupon endpoint when needed.
- [ ] Local cart discount and API price summary must stay consistent.
- [ ] Clearing coupon must clear coupon code, selected coupon, and local discount.
- [ ] Payment amount remap must run after discount changes.
- [ ] Add tests for invalid coupon, expired/invalid coupon, flat discount, percentage discount, clear coupon, and payment remap.

Acceptance:

- [ ] Mobile payable and desktop payable match for same coupon and cart.

### P1.9 Orders Screen Must Cover Saved, Ongoing, Confirmed, And Print Flows

- [ ] Replace placeholder Saved/Ongoing segments in mobile cart/orders UI with real data or remove misleading tabs.
- [ ] Saved orders must list local drafts.
- [ ] Ongoing orders must list appropriate in-progress/local pending orders if the product requires it.
- [ ] Confirmed local orders must be accessible if offline/local confirmation exists.
- [ ] Loading saved order must call shared load order logic.
- [ ] Editing saved order must rehydrate customer, delivery, coupon, payment, dynamic methods, and cart reservations.
- [ ] Print saved order must be supported where desktop supports it.
- [ ] Delete saved order must use correct stock restore rules.
- [ ] Add tests for load, edit, print, delete, and rehydrate.

Acceptance:

- [ ] A saved mobile draft can be loaded, edited, confirmed, and printed without losing payment or stock state.

### P1.10 Quotation Mode Must Be Implemented Or Explicitly Scoped Out

- [ ] Decide whether mobile billing must support quotation mode for production.
- [ ] If yes, add mobile quotation entry point.
- [ ] If yes, quotation mode must not require payment.
- [ ] If yes, quotation requires quotation customer and valid date range.
- [ ] If yes, expiry date cannot be before quotation date.
- [ ] If yes, quotation payload must include store id, customer data, delivery method, shipping cost, quotation date, expiry date, discount, comment, and items.
- [ ] If yes, quotation print must use `QuotationPrintService`.
- [ ] If no, document this as a product decision and hide/disable quotation affordances on mobile.
- [ ] Add tests for chosen behavior.

Acceptance:

- [ ] Mobile quotation behavior is either complete or intentionally unavailable with no broken UI.

### P1.11 Pine Labs / Online Terminal Payment Must Be Hardened

- [ ] Confirm expected amount passed to Pine Labs equals payable amount.
- [ ] Handle Pine Labs success, failure, cancel, timeout, and duplicate callback.
- [ ] Store transaction reference safely.
- [ ] Reset `ONLINE` selection when payment is voided/cancelled.
- [ ] Rehydrate saved order with ONLINE payment correctly.
- [ ] Prevent confirm if ONLINE selected but terminal success/reference is missing, unless product decision allows manual online.
- [ ] Add tests with fake terminal provider.

Acceptance:

- [ ] Terminal success creates one ONLINE payment row and one transaction reference.
- [ ] Terminal failure cannot accidentally confirm as paid.

### P1.12 Print Flow Must Be End-To-End Mobile Ready

- [ ] Confirm & Print must fetch order details after successful confirm.
- [ ] Confirm & Print must call correct print service.
- [ ] Support optional customer copy if app setting requires double bill.
- [ ] Failed print after successful order must not retry order creation.
- [ ] User must be able to retry print without re-confirming order.
- [ ] Saved order print must use local saved order print path.
- [ ] Dynamic payment breakdown must print correctly.
- [ ] Delivery charge, discount, tax, sale unit, and customer credit must print correctly.
- [ ] Add tests where possible and manual printer QA cases.

Acceptance:

- [ ] Network/API success but printer failure leaves order confirmed and allows print retry.

## P2 - Architecture Cleanup And Hardening

### P2.1 Extract Mobile Business Logic Out Of Widgets

- [ ] Audit every file under `lib/features/billing/presentation/widgets/mobile`.
- [ ] Move payment calculations into controller/coordinator/service.
- [ ] Move delivery charge and selected-method logic into shared helper/service.
- [ ] Move customer selection mutation sequence into controller/coordinator.
- [ ] Move coupon validation/application orchestration into controller/coordinator.
- [ ] Keep widgets responsible for layout, input, and callback wiring.
- [ ] Add small unit tests for each controller/coordinator.

Acceptance:

- [ ] Reading a widget file should not be required to understand billing money/stock rules.

### P2.2 Align With Feature Folder Map

- [ ] Use `wikidata/billing/feature-folder-map.md` as the migration target.
- [ ] Introduce application use cases when shared helpers become too large.
- [ ] Keep legacy providers until migration is safe, but do not add more unrelated responsibilities to them.
- [ ] Add `billing_payment_state`, `billing_delivery_state`, and `billing_cart_state` models if needed.
- [ ] Keep desktop and mobile using the same use cases.
- [ ] Document any mobile-specific divergence in `wikidata/billing`.

Acceptance:

- [ ] Desktop and mobile call the same domain use cases for stock, payment payload, delivery charge, and checkout validation.

### P2.3 Rehydration Must Restore Every Field

- [ ] Rehydrate customer id, phone, name, and default/manual flag.
- [ ] Rehydrate cart items including stock JSON, group ids, reservations, sale-unit metadata, manual overrides, and comments.
- [ ] Rehydrate typed payments.
- [ ] Rehydrate dynamic payment methods.
- [ ] Rehydrate debit/customer credit.
- [ ] Rehydrate ONLINE/Pine Labs state safely.
- [ ] Rehydrate transaction number.
- [ ] Rehydrate delivery method/id, car number, comment, address, date, time, and charge.
- [ ] Rehydrate coupon id, code, flat discount, percentage discount, and applied state.
- [ ] Rehydrate total order amount and balance.
- [ ] Add tests using saved order JSON with all fields populated.

Acceptance:

- [ ] Loading a saved order and immediately saving it again does not lose any field.

### P2.4 Settings Synchronization

- [ ] Mobile must listen to `GeneralSettingsProvider.stockEnabled` and sync it into `LocalProductProvider`.
- [ ] Mobile must respond to `appSettings.barcodeSales`.
- [ ] Mobile must respond to default payment method setting.
- [ ] Mobile must respond to default delivery method setting.
- [ ] Mobile must respond to discount/coupon visibility setting.
- [ ] Mobile must respond to customer purchase history visibility setting.
- [ ] Mobile must respond to delivery date setting.
- [ ] Add tests or manual QA for settings toggles.

Acceptance:

- [ ] Changing settings and reopening mobile billing produces correct behavior without stale provider state.

### P2.5 Connectivity And Offline Behavior

- [ ] Online confirm must be blocked without internet.
- [ ] Local save must work without internet.
- [ ] Offline saved orders must sync later if product scope requires it.
- [ ] API errors must show actionable messages and preserve cart.
- [ ] Token expiration must not clear cart.
- [ ] Customer/cart API fetch failure must not block local sale entry unless required.
- [ ] Add offline tests with fake connectivity.

Acceptance:

- [ ] Losing internet during checkout does not lose cart or stock reservation state.

### P2.6 Performance With Large Catalogs

- [ ] Product list search must remain responsive with realistic product count.
- [ ] Customer search must remain responsive with realistic customer count.
- [ ] Avoid rebuilding whole mobile page on each amount text change.
- [ ] Use selectors/consumers narrowly around changing state.
- [ ] Cache network images appropriately.
- [ ] Avoid synchronous heavy work in build methods.
- [ ] Add performance profiling on low-end Android device.

Acceptance:

- [ ] Product search and cart amount editing remain smooth on target hardware.

### P2.7 Accessibility And Mobile Usability

- [ ] Minimum touch target should be at least 44x44 logical pixels.
- [ ] Text should remain readable on small phones.
- [ ] Bottom action bars must respect safe area and keyboard insets.
- [ ] Form fields must have labels, hints, and correct keyboard types.
- [ ] Screen reader labels should be added for critical buttons.
- [ ] Error messages should be visible and not hidden behind bottom sheets.
- [ ] Landscape/tablet layout must not overflow.
- [ ] Add widget tests for common small-screen constraints.

Acceptance:

- [ ] No critical mobile billing action is hidden, clipped, or inaccessible on small Android devices.

### P2.8 Logging, Privacy, And Crash Safety

- [ ] Remove or gate debug logs containing customer phone, token, transaction reference, payment amounts, and full payloads.
- [ ] Replace noisy debug prints with structured debug-only logging if needed.
- [ ] Ensure no crash happens when auth token is null.
- [ ] Ensure no crash happens when selected customer is null.
- [ ] Ensure no crash happens when delivery methods are empty.
- [ ] Ensure no crash happens when product has missing price/MRP/tax/stock fields.
- [ ] Ensure all awaited UI operations check `mounted` before calling `setState` or navigation.

Acceptance:

- [ ] Production logs do not leak customer/payment details.
- [ ] Crash-free manual QA across missing-data fixtures.

### P2.9 Error Handling And User Recovery

- [ ] Every failed save/confirm/print/coupon/customer/delivery operation must show a useful error.
- [ ] Errors must not clear cart unless explicitly safe.
- [ ] Failed print after confirmed order must offer retry print.
- [ ] Failed payment terminal request must allow retry or alternate payment.
- [ ] Failed stock modal selection must return user safely to cart/product list.
- [ ] API timeout must allow retry without duplicate order.

Acceptance:

- [ ] User can recover from every common failure without losing sale progress.

## P3 - Polish And Product Quality

### P3.1 Visual Consistency

- [ ] Align typography and spacing with mobile design guide.
- [ ] Keep product cards, cart rows, payment rows, and delivery cards visually consistent.
- [ ] Avoid color-only status communication.
- [ ] Make loading, empty, and error states consistent.
- [ ] Add skeleton/loading state for product/customer/payment method fetches.

### P3.2 Faster Cashier Flow

- [ ] Add quick cash exact amount button.
- [ ] Add quick split payment shortcuts if product needs it.
- [ ] Add recent products/favorites if product needs it.
- [ ] Add repeat last quantity if scanner workflow needs it.
- [ ] Add clear payment method shortcut.

### P3.3 Better QA Tooling

- [ ] Add debug-only fixture screen for sample products, stock groups, sale units, customers, coupons, and delivery methods.
- [ ] Add fake scanner burst test harness.
- [ ] Add fake Pine Labs provider for QA.
- [ ] Add fake printer provider for QA.

## Feature Matrix

| Area | Current Mobile Status | Required Production Status |
| --- | --- | --- |
| Product add via cards | Partial | Must route fully through `ProductCartHelper`; no incorrect stock gating |
| Barcode scanner | Partial | FIFO queue, no dropped scans, embedded/sale-unit support |
| Manual barcode input | Partial/missing UI | Visible when `barcodeSales` is enabled |
| Product autocomplete | Partial/missing UI | Visible when `barcodeSales` is disabled |
| Cart totals | Mostly wired | Must match desktop subtotal/tax/discount/payable |
| Cart quantity | Partial | Must use `CartQuantityStockHelper` |
| Sale units | Partial | Must support selector, conversion, identity, payload |
| Price/MRP/tax editing | Missing | Must support shared `PriceFields` rules or mobile equivalent |
| Purchase history | Missing | Must support app setting and selected customer rules |
| Product details | Missing | Must support role permission |
| Payment typed methods | Mostly wired | CASH/CARD/UPI/COD/DEBIT/ONLINE correct |
| Dynamic payment methods | Missing | Backend-configured methods fully supported |
| Payment discount remap | Partial | Must use shared remap logic |
| Customer selection | Mostly wired | Must include default/skip/balance/clear edge cases |
| Delivery method | Mostly wired | Must include date/time and delivery charge persistence |
| Coupon | Partial | Must fully match local/API/payment remap semantics |
| Confirm order | Mostly wired | Must pass full validation and payload parity |
| Confirm & Print | Partial | Must handle print retry/customer copy |
| Save draft | Risky | Must not clear cart on failure |
| Orders screen | Partial | Saved/edit/print/delete/confirmed/ongoing as scoped |
| Quotation | Missing or unscoped | Implement or explicitly remove from mobile scope |
| Keyboard shortcuts | Partial | Implement supported hardware POS shortcut set |
| Offline | Partial | Save local safely; online confirm blocked without data loss |
| Performance | Unknown | Verified on target device/catalog size |
| Accessibility | Unknown | Verified on small phone, tablet, landscape |

## Test Plan

### Unit Tests

- [ ] `BillingMobileCartController` totals from `LocalProductProvider.cartTotal` and `priceSummary`.
- [ ] Mobile quantity controller calls stock-aware helper path.
- [ ] Payment controller builds typed and dynamic payment rows.
- [ ] Payment controller calculates collected amount with dynamic methods and without debit.
- [ ] Payment discount remap behavior.
- [ ] Delivery charge helper/service.
- [ ] Save order result mapping.
- [ ] Barcode queue order and failure recovery.
- [ ] Customer selection controller writes all required providers.

### Widget Tests

- [ ] Mobile Home tab in barcode-sales mode.
- [ ] Mobile Home tab in autocomplete mode.
- [ ] Product card add button routes to helper even with no stock when stock disabled.
- [ ] Cart row plus/minus updates display/base quantity correctly.
- [ ] Sale-unit selector displays and changes unit.
- [ ] Price/MRP/tax fields validate correctly.
- [ ] Payment section renders dynamic backend payment method.
- [ ] Coupon apply and clear update totals.
- [ ] Delivery section shows car number only when needed.
- [ ] Delivery section shows date/time only when setting enabled.
- [ ] Customer select page search, select, clear, add customer.
- [ ] Orders screen load/edit/delete saved order.

### Integration Tests

- [ ] Add product by product card, pay cash, confirm.
- [ ] Add product by barcode scanner, pay card, confirm-print.
- [ ] Add sale-unit product, edit quantity, confirm API payload.
- [ ] Add stock-group product, choose stock, save draft, load draft, confirm.
- [ ] Apply coupon, dynamic payment method, confirm.
- [ ] Door Delivery with address and delivery charge.
- [ ] Car Delivery without car number blocks confirm.
- [ ] Offline save draft, reconnect, load, confirm.
- [ ] Pine Labs success, confirm.
- [ ] Pine Labs failure, alternate payment, confirm.
- [ ] Print failure after confirm, retry print.

### Manual Device QA

- [ ] Android small phone portrait.
- [ ] Android small phone landscape.
- [ ] Android tablet portrait.
- [ ] Android tablet landscape.
- [ ] Real barcode scanner keyboard wedge.
- [ ] Real Bluetooth/USB printer.
- [ ] Real Pine Labs terminal if available.
- [ ] Low battery/background/foreground during cart.
- [ ] Network loss during confirm.
- [ ] Network loss during print details fetch.

## Golden Business Scenarios

Run these before release. For each scenario, compare mobile result with desktop result for the same product/customer/settings.

- [ ] Simple cash sale, one product, no tax, no delivery.
- [ ] Simple cash sale, one tax-inclusive product.
- [ ] Multiple products with different tax rates.
- [ ] Product with stock disabled and no stock rows.
- [ ] Product with stock enabled and one stock group.
- [ ] Product with stock enabled and multiple pricing groups.
- [ ] Product with insufficient stock but partial reservation allowed.
- [ ] Sale unit product with conversion rate.
- [ ] Embedded KG barcode.
- [ ] Embedded PCS barcode.
- [ ] Sale-unit barcode.
- [ ] Unknown barcode add-product modal.
- [ ] Manual price override above minimum.
- [ ] Manual price below minimum blocks or corrects as desktop.
- [ ] Flat discount.
- [ ] Percentage discount.
- [ ] Coupon discount.
- [ ] Coupon clear.
- [ ] Cash full payment.
- [ ] Card full payment.
- [ ] UPI full payment.
- [ ] COD full payment.
- [ ] Split CASH/CARD.
- [ ] Dynamic method such as CHEQUE.
- [ ] Customer credit/debit.
- [ ] Customer with positive previous balance.
- [ ] Customer with negative previous balance.
- [ ] Door Delivery with saved address.
- [ ] Car Delivery with car number.
- [ ] Delivery charge below threshold.
- [ ] Free delivery at threshold.
- [ ] Save draft and load draft.
- [ ] Save draft, clear workspace, load draft, confirm.
- [ ] Confirm and print.
- [ ] Confirm without print.
- [ ] Print saved order.
- [ ] Quotation if mobile scope includes quotation.

## Verification Commands

Run these after related changes:

```powershell
flutter analyze lib/features/billing/controllers/billing_mobile_ui_controller.dart lib/features/billing/controllers/billing_mobile_controller.dart lib/features/billing/presentation/pages/billing_page_mobile.dart
flutter test test/billing_mobile_ui_controller_test.dart test/billing_page_mobile_smoke_test.dart --reporter expanded
flutter test --reporter expanded
git diff --check
git diff --cached --check
```

Notes:

- [ ] Repo-wide `flutter analyze` may show existing unrelated warnings. Changed files must be clean.
- [ ] If a P0/P1 change touches shared provider/helper/service code, run the full test suite.
- [ ] If a change touches checkout, payment, stock, or order payload code, test both desktop and mobile paths.

## Release Gate

Do not call mobile billing production ready until all are true:

- [ ] All P0 items complete.
- [ ] All P1 items complete or explicitly scoped out in writing.
- [ ] No known data-loss path remains.
- [ ] No known wrong-payment payload path remains.
- [ ] No known wrong-stock reservation path remains.
- [ ] No scanner event drop path remains.
- [ ] Full test suite passes.
- [ ] Changed files pass `flutter analyze`.
- [ ] Manual device QA completed.
- [ ] Product owner has approved any mobile-specific deviations from desktop billing.
- [ ] Rollback plan exists for production release.

