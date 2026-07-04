# Billing Mobile vs Desktop Checkout Parity Report

## Purpose

This report compares the desktop billing checkout source-of-truth behavior against the current mobile billing implementation, logic by logic. It is intended to guide implementation work toward desktop parity without changing application source code.

Inputs synthesized:

- Desktop reference: `C:\Users\gokul\.cursor\projects\c-Users-gokul-Desktop-Projects-Enke-eposmob\canvases\billing-checkout-audit.canvas.tsx`
- Mobile state audit transcript: `c55b30ec-f330-4936-ae62-a549169a830d.jsonl`
- Mobile payment parity audit transcript: `cfb35838-9924-436c-94a2-0ba73c085e77.jsonl`
- Mobile order-submit audit transcript: `5b16fb04-f8ce-41f5-bcd4-fc17d5198a17.jsonl`
- Source references under `lib/features/billing`, `lib/providers`, `lib/services`, and shared helper/domain files where the audits identified exact functions.

No app source code was changed while creating this report.

## Executive Summary

Mobile is not a modal-level clone of desktop checkout. It is a provider-centric implementation that embeds checkout state directly in the mobile Billing tab. Many core formulas and persisted payload shapes are close to desktop, especially customer defaulting, delivery defaults, payment validation helpers, multi-payment JSON, API `paid_methods` normalization, quotation payment suppression, and post-order default customer/delivery reapply.

The highest-priority parity gaps are:

1. **Offline confirm fallback differs from desktop.** Mobile `confirmOrder()` / `createOrderAndPrint()` fall back to local `saveOrderAndPrint()` when offline, while desktop blocks online confirm actions.
2. **`skipCustomerSelection` can weaken the final customer gate.** Desktop uses it for checkout navigation, not as permission to confirm without customer/phone data.
3. **Mobile payment amount can autofill too early.** `_syncAllSettings()` applies default payment and immediately syncs amount, while desktop default payment is flag-only until payment UI/direct confirm prep.
4. **Service-level validation is weaker than page-level validation.** Mobile page actions call `_validatePaymentReady()`, but `CheckoutService.confirmOrder()`, `createOrderAndPrint()`, and `saveOrderAndReturnConfirmed()` can be called with only selected-payment checks or no payment/customer validation.
5. **Cart-change payment reset is incomplete.** Mobile clears collected amounts but does not reset `paymentStepVisited` or pristine payment state, unlike desktop's `_hasOpenedPaymentModalOnce` reset.
6. **Debit/to-customer-credit has dangerous autofill semantics.** Mobile can treat `DEBIT` like a selected payment for autofill, and `syncCreditAmountWithRemaining()` appears to fill underpayment rather than excess credit.
7. **Phone fallback is inconsistent across save, save-print, confirm, and confirm-print.** Some mobile paths use robust `OrderCustomerFields`, while others use only `selectedCustomerPhone ?? mobileNumberText`.
8. **Saved-order payment rehydration does not clearly mark payment visited.** Desktop marks visited when restored payment/debit/extra exists.
9. **Resolved: Mobile price/MRP validation now matches desktop throughput behavior.** Desktop save requires cart only and desktop confirm has pricing validation commented out; mobile save/confirm service paths no longer block invalid local price/MRP, with TODOs left for backend validation.
10. **Reset semantics are double-layered.** Mobile service methods partially clear provider state, then page-level reset clears again and reapplies defaults. This is close to desktop's nested reset quirk, but service-only usage would not reapply defaults consistently.

## Desktop Source Of Truth Summary

Desktop checkout is a three-layer state system:

| Layer | Role | Key state |
|---|---|---|
| `BillingPage` | Persistent source of truth | Selected customer fields, customer manual flag, payment flags/controllers, dynamic payment maps, delivery fields, coupon, balance, `_hasOpenedPaymentModalOnce` |
| `CheckoutModal` | Wizard-local state and step gating | `_l*` local copies of customer, delivery, coupon, and payment state; `skipCustomerSelection` navigation; action-mode gating |
| `PaymentMethodModal` | Live payment entry | Pristine switching, split autofill, amount entry, balance/change, to-customer-credit |
| `BillingProvider` | Mirror/helper layer | Payment method IDs, modal payment updates, API helper support |

Core desktop rules:

- Customer defaulting is controlled by `autoAssignDefaultCustomer` and `autoAssignDefaultCustomerPhone`.
- A matched default customer sets a real customer and `CustomerSelectionProvider.isDefaultCustomer`.
- A non-matched default phone creates a phone-only default: phone fields are filled, selected customer is cleared, and `CustomerSelectionProvider.hasSelectedCustomer` remains false.
- Manual customer selection blocks default reapply until cleared/reset. Typing a phone number of length 10+ counts as manual.
- `skipCustomerSelection` jumps to the payment step in the checkout modal unless an explicit initial step is provided; it does not remove final confirm customer requirements.
- Default payment selects only a method flag. Amount is filled later when payment UI opens/renders or direct confirm-print prep runs.
- Rendering the desktop payment step can mark payment visited and autofill by post-frame callback.
- Pristine switching moves the full total from the old default method to the newly selected method instead of creating a split.
- Split payment fills newly selected methods with remaining due and refills the single remaining collected method to full total after deselection.
- `DEBIT` / to-customer-credit is excluded from collected payment, validation, and API `paid_methods`.
- Validation uses `PaymentValidation`: zero/near-zero total is valid; otherwise collected payment must cover net due with epsilon `0.009`.
- Customer previous positive balance reduces net due only when to-customer-credit is enabled and the customer is not the default customer.
- Balance/change is clamped at zero. API `paid_methods` subtracts change from first CASH/COD only.
- Cart change after payment clears amounts, keeps selection flags, and resets `_hasOpenedPaymentModalOnce`.
- Save order is local Hive/draft only and requires a non-empty cart, not customer/payment/internet.
- Confirm order requires internet, customer, payment readiness, non-empty cart, and car number for literal `Car Delivery`.
- Save-print requires customer and payment, saves locally, prints, then clears workspace.
- Confirm-print creates the order through API, fetches server order details, prints, and resets through a cleaner `_clearOrderWorkspace(providerCartAlreadyCleared:true)` path.
- Quotation mode suppresses payment defaults and clears automatic default customer when creating quotations.
- Saved-order rehydration overrides first-frame defaults and restores customer, payment JSON, dynamic extra payments, debit/credit state, delivery, coupon, and checkout visited state.
- Post-order reset clears fields and then reapplies default customer and delivery. Default payment is not explicitly reapplied by `_resetBillingWorkspaceUi()`, except via settings listener/direct prep paths.

Known desktop quirks that mobile parity must consciously preserve or intentionally fix:

- Phone-only default satisfies `hasCustomer` checks while `CustomerSelectionProvider.hasSelectedCustomer` stays false.
- Exact string phone matching is used for default customer lookup; no normalization.
- Sales executive switch clears customer but does not immediately reapply default.
- Desktop confirm phone fallback is weaker than save phone fallback.
- Checkout modal `cartTotal` can use subtotal while confirm uses effective total.
- Transaction reference is not generally required even when shown.
- `_confirmOrder` has nested/double reset side effects.
- Cart item order is reversed before POST in `CartProvider.addToOrderAPI`.
- Confirm catch block may log without showing a scaffold error.

## Mobile Architecture Summary

Mobile uses a persistent Billing tab rather than a checkout wizard modal:

| Mobile component | Role |
|---|---|
| `BillingPageMobile` | Orchestrates provider initialization, action handlers, settings sync, validation, rehydration, reset |
| `BillingMobileController` | Restores saved orders, applies/reset workspace defaults, handles cart changes, direct confirm-print prep, quotation clearing |
| `BillingMobileSettingsController` | Applies default payment and default delivery |
| `BillingMobileCustomerController` | Applies default customer/phone-only default, customer gates, sales-executive/user switch clearing |
| `BillingMobilePaymentController` | Payment autofill, pristine switch, split rules, payment-ready validation, debit/to-customer-credit UI helpers |
| `MobileBillingTab` | Persistent mobile checkout surface with customer, delivery, payment, coupon, summary, quotation sections |
| `PaymentMethodsSection` | Mobile payment UI, marks payment step visited, loads payment methods, schedules autofill |
| `DeliveryOptionsSection` | Mobile delivery UI and validation fields |
| `BillingProvider` | Mobile source of truth for customer/payment/delivery/coupon/order state |
| `CheckoutService` | Local save, API confirm, confirm-print, save-print local promotion, payload creation, service-side success/error handling |

Mobile already aligns with desktop in several important areas:

- Customer defaulting distinguishes real matched defaults from phone-only defaults.
- Delivery default resolution goes through `DeliveryMethodsProvider.resolveDefaultDeliveryMethod`.
- Payment formulas use shared `PaymentValidation`.
- API payment normalization uses `PaymentHelper.normalizePaidMethodsForApi`.
- Local save can persist multi-payment JSON.
- Quotation hides/suppresses payment and clears automatic default customer in quotation mode.
- Page-level successful actions usually call `resetBillingWorkspaceAfterOrder()` to clear and reapply default customer/delivery.

The main architectural difference is that mobile lacks desktop's separate `CheckoutModal` local-copy layer. Mobile edits mutate `BillingProvider` immediately, so parity depends on provider state discipline and public service boundaries.

## Logic-By-Logic Parity Matrix

### Customer And Default Autofill

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Real default customer | `_applyDefaultCustomerFromCacheIfNeeded()` exact-matches `autoAssignDefaultCustomerPhone`, sets selected customer, ID, phone, controller, and provider default flag. | `BillingMobileCustomerController.applyDefaultCustomerFromCacheIfNeeded()` returns matched result and `applyDefaultCustomerResult()` updates `BillingProvider` and `CustomerSelectionProvider`. | Match | Exact string match can miss formatted phone variants, but this matches desktop. | No parity fix. Document exact-match behavior if users report default misses. |
| Phone-only default | If no customer cache match, fills phone fields only and clears `CustomerSelectionProvider`; still satisfies desktop `hasCustomer` gates. | Mobile fills `salesExecutivemobileNumberText`, `mobileNumberText`, controller text, clears selected customer and `CustomerSelectionProvider`. | Match | Widgets depending on provider selected-customer state see no customer while checkout gates see phone. | Preserve this split state. |
| Default preconditions | Apply only when not editing saved order, no selected customer/phone, default enabled, default phone set, customer list loaded, not manually selected. | Mobile mirrors these guards through customer controller and page initialization. | Match | If mobile default is re-run after user edit, it can overwrite manual intent; current manual flag prevents this. | Keep manual-selection guard. |
| Manual selection | Autocomplete, modal selection, add-customer success, and typing 10+ digits set `_isCustomerManuallySelected`. Clear button resets. | Mobile provider has `isCustomerManuallySelected`, customer controller respects it. Walk-in phone UI in `MobileBillingTab` is commented/less available. | Partial | Mobile UI may not expose all desktop manual phone workflows even though provider gates support phone text. | Re-enable or provide equivalent walk-in phone entry if mobile must match typed-phone desktop flow. |
| Sales executive/user switch | Clears customer when default auto customer is enabled and not manually selected; does not immediately reapply default. | `handleSalesExecutiveChanged()` and `handleUserSwitched()` clear selection similarly. | Match with quirk | Looks like a bug if default customer disappears after sales-executive change, but this is desktop behavior. | Preserve if cloning desktop; otherwise product decision required. |
| Customer provider semantics | Phone-only default leaves `CustomerSelectionProvider.hasSelectedCustomer == false`. | Mobile does the same. | Match | UI pieces that rely only on `CustomerSelectionProvider` may hide customer-specific sections. | Ensure checkout/customer gate uses billing phone fields, not provider selected-customer only. |

### Manual Selection And Customer Gates

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Final confirm customer gate | Confirm/save-print require `selectedCustomerID || mobileNumberText || salesExecutivemobileNumberText`. | `BillingMobileCustomerController.isCustomerSatisfiedForCheckout()` returns true if that exists, otherwise returns `skipCustomerSelection`. `CheckoutService._hasCustomerForCheckout()` also supports skip. | Mismatch | `skipCustomerSelection` can allow final confirm without customer/phone data. | Restrict `skipCustomerSelection` to UI navigation. Final confirm/save-print gate should require actual customer/phone unless product explicitly supports walk-in API confirm. |
| Save order customer requirement | Desktop save requires cart only; customer optional. | Mobile save order requires cart and pricing validity, not customer/payment. | Partial | Customer parity is fine; pricing strictness differs. | Keep no customer gate for save. Address pricing strictness separately. |
| Robust save phone fallback | Desktop save uses selected phone, selected customer model phone, typed phone, controller text. | `CheckoutService.saveOrder()` uses `OrderCustomerFields.phoneForOrder()`. | Match | None. | Reuse this helper in all submit paths. |
| Save-print phone fallback | Desktop save-print should use robust save-style phone resolution. | `saveOrderAndReturnConfirmed()` uses `selectedCustomerPhone ?? mobileNumberText`. | Mismatch | Printed/local confirmed order can lose phone from selected customer model or controller-only text. | Use `OrderCustomerFields.phoneForOrder()` and `nameForOrder()` in `saveOrderAndReturnConfirmed()`. |
| Confirm phone fallback | Desktop audit notes confirm itself is weaker; clone checklist prefers robust handling. | API confirm uses `selectedCustomerPhone ?? mobileNumberText`. | Partial | Selected customer model phone or controller text can be omitted from API payload. | Use `OrderCustomerFields.phoneForOrder()` for `confirmOrder()` and `createOrderAndPrint()` unless intentionally preserving desktop quirk. |

### Phone-Only Default

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Phone-only default gate | Phone-only default should satisfy customer checks even with no customer ID/model. | Mobile sets phone text fields and customer gate sees them. | Match except skip caveat | If gate is changed incorrectly to selected-customer only, phone-only default will break. | Keep phone fields in final gate. Remove only `skipCustomerSelection` bypass. |
| Provider selected customer | Should remain cleared for phone-only default. | Mobile clears provider selected customer. | Match | Balance/to-customer-credit sections should remain hidden for phone-only default. | No fix. |
| Save/confirm payload | Phone-only value should propagate. | Save path does. Confirm path uses `selectedCustomerPhone ?? mobileNumberText`, so phone-only usually propagates if `mobileNumberText` is set. | Mostly Match | If only controller text exists, confirm can miss it. | Use shared fallback helper. |

### Payment Default And Autofill

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Default method selection | App setting selects CASH/CARD/UPI/COD flag only; no amount until payment UI/direct prep. | `BillingMobileSettingsController.applyDefaultPaymentMethodIfNeeded()` selects only flag. | Match at controller level | None. | Preserve flag-only default in settings controller. |
| Early amount autofill | Desktop amount fills when payment modal opens, checkout payment step renders, direct confirm-print prep runs, or fallback direct payment modal selects cash. | `BillingPageMobile._syncAllSettings()` applies default payment then calls `_paymentController.syncPaymentAutofillIfNeeded()`. | Mismatch | Amount can fill before user visits payment UI. This contradicts desktop default-payment timing and can make confirm appear configured too early. | Remove global settings-sync autofill. Keep autofill in `PaymentMethodsSection` render/open and `prepareDirectConfirmAndPrint()`. |
| Payment section render autofill | Desktop render of payment step can autofill and mark visited as a known quirk. | `PaymentMethodsSection` schedules autofill in build and marks visited in init. | Partial | Mobile Billing tab is persistent and initially expanded, so render quirk is more automatic than desktop wizard step. | If strict parity, mark visited on expand/touch; if retained, document as intentional mobile equivalent. |
| Direct confirm-print prep | Desktop skip checkout confirm-print prepares defaults, autofills amount, marks visited, updates provider, submits. | `prepareDirectConfirmAndPrint()` fetches methods, applies default, syncs delivery, autofills, marks visited, calculates balance. | Match with debit caveat | If default/selected method is DEBIT, autofill can be wrong. | Exclude `DEBIT` from collected autofill. |

### Split And Pristine Payment

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Pristine switch | If full-total default amount was not edited, switching method moves full amount from old method to new method. | `BillingMobilePaymentController._applyPristineSwitch()` and provider pristine state implement this. | Match | Stale pristine state after cart change can cause wrong movement. | Clear pristine state on cart changes. |
| Split autofill | Newly selected collected method gets remaining due after other collected amounts. | `toggleMethod()` uses `remainingPayable()` and extra payment maps. | Mostly Match | Dynamic extra selection/value may be lost or partially lost after amount clearing. | Verify/preserve selected dynamic method IDs and display values when clearing amounts only. |
| Deselect refill | If one collected method remains, refill it to full total. | `_refillIfSingleCollectedMethodRemaining()` does this. | Match | None. | No parity fix. |
| Text-entry selection | Desktop amount entry auto-selects method when field non-empty; clearing field does not necessarily deselect. | Mobile provider/controller behavior broadly supports amount-driven selection for payment items. | Partial | Need focused test coverage for core and extra text fields. | Add implementation tests when changing payment reset/autofill. |

### Dynamic Payments

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Backend methods | Load backend methods, classify core CASH/CARD/UPI/COD, exclude terminal, include dynamic methods keyed by backend ID. | `PaymentMethodsSection._loadPaymentMethods()`, `BillingMobilePaymentController.paymentItems()`, and provider extra maps use enabled sorted methods and IDs. | Mostly Match | Empty method list fallback is unclear despite comments. | Provide real CASH fallback or assert provider always supplies core methods. |
| Terminal/ONLINE methods | Desktop excludes terminal methods from normal dynamic collection; terminal handling is special. | Mobile has ONLINE/Pine Labs support and can send literal `"ONLINE"` in selected methods. | Partial | Backend may expect a configured payment method ID rather than literal `ONLINE`; desktop reference does not normalize this path. | Confirm API contract for ONLINE. Map to backend method ID if required. |
| Credit-behavior methods | Desktop classifies credit-behavior methods separately when customer exists and not default. | Mobile has `DEBIT` row and dynamic methods; comments indicate credit behavior but semantics are mixed. | Partial | Credit-behavior backend methods can be treated like ordinary collected methods. | Make credit-method classification explicit: pay-from-credit vs to-customer-credit vs collected dynamic payment. |

### Debit And To-Customer-Credit

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Debit exclusion | `DEBIT` / to-customer-credit excluded from collected total, validation, and API `paid_methods`. | `BillingProvider.getTotalPaidAmount()`, `validatePayment()`, and `getPaidMethods()` exclude debit. | Match | None if no autofill treats it as collected. | Preserve exclusion. |
| Debit autofill | Desktop does not use DEBIT as a collected payment autofill target. | `syncPaymentAutofillIfNeeded()` can fill DEBIT if it is the only selected method. | Mismatch | Validation can fail or state can imply underpaid/credit behavior incorrectly. | Exclude DEBIT from full-total autofill and `has selected payment for autofill` logic. |
| To-customer-credit excess | Desktop allocates transaction excess to customer credit, clamps by allowed max, and excludes from collected/API. | Mobile has `_ToCustomerCreditSection`, `prefillToCustomerCreditAmount()`, and `maxToCustomerCreditAmount()`. | Mostly Match | `syncCreditAmountWithRemaining()` appears to set debit amount to underpayment (`effectiveOrderTotal - totalPaid`) instead of excess. | Rewrite `syncCreditAmountWithRemaining()` to use excess only or remove it in favor of existing prefill/max semantics. |
| Default customer balance | Desktop does not reduce net due for default customer. | `PaymentValidation` receives default-customer context. Balance calculation guard is less explicit. | Partial | Provider math could reduce/change balance incorrectly if `_toCustomerCreditEnabled` is stale for default customer. | Add default-customer guard in balance calculation for robustness. |

### Validation

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Payment formula | Zero total valid; otherwise collected payment must cover net due; previous balance reduces due only for non-default customer with credit enabled. | Shared `PaymentValidation` implements this and `BillingProvider.validatePayment()` delegates to it. | Match | Depends on callers using it. | Keep shared domain helper. |
| Page-level confirm validation | Confirm/save-print require customer, payment-ready, cart, car number. | `BillingPageMobile._validatePaymentReady()` and page handlers call validation before service in normal UI paths. | Mostly Match | Alternate service callers can bypass. | Do not rely only on page-level validation. |
| Service-level confirm validation | Desktop confirm itself enforces final gates. | `CheckoutService.confirmOrder()` and `createOrderAndPrint()` only check weaker selected payment/customer logic and pricing/cart details. | Mismatch | Tests, shortcuts, or future callers can submit without payment visited or valid collected amounts. | Add `BillingMobilePaymentController.validatePaymentReadyForConfirm()` equivalent or shared validation at service boundary. |
| Save validation | Desktop save requires cart only. | Mobile save blocks invalid item pricing. | Mismatch / stricter mobile | Mobile can block local drafts desktop would save. | Reduce save validation to cart-only for parity or document mobile stricter rule as product decision. |
| Confirm pricing validation | Desktop pricing validation exists but is commented out. | Mobile confirm and confirm-print invalid price/MRP guards are disabled in place with a TODO for backend validation. | Match / disabled | Backend must eventually reject invalid price/MRP without blocking POS throughput client-side. | Keep disabled for desktop parity; implement backend validation later. |
| Transaction reference | Desktop audit says transaction reference is not generally required even when shown. | Mobile requires transaction reference for ONLINE/Pine Labs only. | Intentional difference / Partial | ONLINE mobile orders can be blocked where desktop would not block. | Decide if terminal integration requires this mobile-only strictness. |

### Balance And Change

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Clamp change | Balance/change clamped to `>= 0`; underpayment shows zero change, not negative. | `BillingProvider.calculateBalanceAmount()` broadly matches. | Match | None. | No parity fix. |
| Positive customer balance | If customer credit enabled and non-default customer has positive balance, net due can reduce. | `PaymentValidation` supports this. | Match in validation | Balance display may depend on provider context sync. | Keep `syncPaymentValidationCustomerContext()` calls close to customer changes. |
| Debt/excess allocation | With customer debt and to-customer-credit enabled, excess can be allocated to credit. | Mobile UI provides to-customer-credit section and max/prefill helpers. | Mostly Match | `syncCreditAmountWithRemaining()` underpayment issue can corrupt amount. | Fix underpayment/excess calculation. |
| API change subtraction | Subtract `_balanceAmount` from first CASH/COD only. | `BillingProvider.getPaidMethods()` calls `PaymentHelper.normalizePaidMethodsForApi()`. | Match | Overpay on CARD/UPI remains unnormalized, same desktop quirk. | Preserve helper behavior. |

### API `paid_methods`

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Positive collected only | `paid_methods` includes positive collected methods, excludes debit/customer credit. | Mobile builds core methods/extras, excludes DEBIT, normalizes balance. CASH can be included when selected with zero amount. | Partial | Zero CASH entry can produce invalid or noisy API payloads. | Include CASH only when amount > 0, matching CARD/UPI/COD and desktop positive-collected rule. |
| Selected payment method IDs | Use backend IDs for selected positive methods. | `getSelectedPaymentMethodsForApi()` maps core IDs/extras and literal ONLINE. | Mostly Match | Literal ONLINE may not match backend API contract. | Confirm/adjust ONLINE mapping. |
| Change normalization | Subtract balance from first CASH/COD. | Shared helper used. | Match | Same desktop quirk: card/UPI overpay not normalized. | No parity fix unless product wants improved behavior. |

### Cart Change Clearing

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Clear amounts only | Cart change after payment clears amounts but keeps selected method flags. | `BillingMobileController.onCartChanged()` calls `clearCollectedPaymentAmountsOnly()` when collected amounts exist. | Mostly Match | Extra payment value/label maps may be cleared more than expected. | Preserve selected dynamic IDs and display values if desktop-style selected flags must remain. |
| Reset visited | Desktop resets `_hasOpenedPaymentModalOnce`. | Mobile does not reset `paymentStepVisited` on cart change. | Mismatch | Confirm can remain gated as visited after payment amounts were cleared/reautofilled. | Call `resetPaymentStepVisited()` on cart changes that clear payment amounts. |
| Clear pristine | Desktop cart change resets payment setup state. | Mobile does not clearly clear pristine state. | Mismatch | Old full-total pristine record can move wrong amount after cart total changes. | Call `clearPristinePaymentState()` on cart change. |

### Delivery Defaults And Charges

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Default delivery resolution | App setting ID/name/code, provider default, store takeaway, first method, fallback. | `BillingMobileSettingsController.syncDefaultDeliveryMethod()` and `BillingMobileController.setDefaultDeliveryMethod()` use `DeliveryMethodsProvider.resolveDefaultDeliveryMethod()`. | Match | Default may be absent until provider methods load. | Ensure sync reruns when delivery methods load. |
| Delivery fields | Method/id, charge, car, comment, date/time, address propagate to save/API. | `DeliveryOptionsSection`, `BillingProvider`, and `CheckoutService` propagate these fields. | Match | None. | No parity fix. |
| Car number validation | Required only when delivery method display text equals literal `Car Delivery`. | `BillingProvider.requiresCarNumber` checks literal display name. | Match with quirk | Renamed/localized methods can bypass validation. | Preserve for parity or improve with method metadata by product decision. |
| Delivery charge setting | `freeDeliveryEnabled` controls whether charge logic runs; minimum can zero charge. | `DeliveryChargeHelper` and `resolveDeliveryCharge(context)` follow same semantics. | Match | Setting name is misleading. | No parity fix; add comments/tests if touched. |
| Saved charge override | Saved orders restore delivery charge override. | `BillingProvider.deliveryChargeOverride` restored during order restore. | Match | UI/helper drift could show different charge than submitted. | Prefer shared helper for UI and payload. |

### Checkout Gating And Mobile Modal Substitute

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Checkout modal local state | Desktop has `CheckoutModal` with `_l*` local copies and action modes. | Mobile has no modal; `MobileBillingTab` mutates provider directly. | Architectural mismatch | Harder to clone desktop wizard edge cases and cancel semantics. | Accept as mobile architecture or introduce a modal/wizard if exact desktop interaction parity is required. |
| `skipCustomerSelection` | Desktop uses it to jump to payment step unless explicit initial step. | Mobile uses it in final customer gate too. | Mismatch | Customerless confirms. | Restrict to navigation/display only. |
| Payment visited gate | Desktop requires payment modal/step visited for confirm, with render-step quirk. | Mobile payment section marks visited on mount. | Partial | Gate can become passive. | Mark visited on user expand/touch for stricter parity, or document current behavior. |
| Save mode gating | Save does not require checkout completion. | Mobile save does not require customer/payment. | Match except pricing strictness | Mobile can block on pricing. | Align save validation. |

### Save Order

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Local draft only | Save uses local persistence, no API. | `CheckoutService.saveOrder()` and controller draft save are local. | Match | None. | No parity fix. |
| Required fields | Cart non-empty only. | Cart non-empty plus invalid-pricing validation. | Mismatch / stricter mobile | Draft cannot be saved in states desktop allows. | Remove pricing validation or document divergence. |
| Payment serialization | Persist multi-payment JSON when payment exists, including methods/amounts/debit/extras/transaction/balance. | `BillingProvider.createOrderData()` and save paths persist multi-payment data when selected methods exist. | Mostly Match | No-payment save persists empty payment, which is acceptable if desktop also has no payment. Dynamic selected-with-zero edge needs review. | Add test coverage for single method, split, debit, extras, and no-payment saves. |
| Post-save reset | Clear cart/workspace, restore stock, reapply default customer/delivery. | Page `saveOrder()` calls `clearCart()` after save, which resets workspace and shows clear-cart UX. | Partial | User may see extra “Cart Cleared Successfully”; reset path is not semantically named as order workspace clear. | Use non-snackbar order workspace reset after save while preserving stock restore. |

### Confirm Order

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Internet required | Offline confirm blocks. | Offline confirm calls `saveOrderAndPrint()`. | Mismatch | Online confirm silently becomes local save-print. | Block offline confirm/confirm-print; do not fallback unless explicit save-print. |
| Customer/payment required | Confirm requires customer and valid payment setup. | Page-level path validates; service-level path is weaker. | Partial | Alternate calls can bypass validation. | Add service boundary validation. |
| API payload | Items, customer, multi-payment methods, normalized paid methods, balance, delivery, discounts/coupon, credit, source/status. | `CheckoutService.confirmOrder()` sends these. | Mostly Match | Phone fallback and selected payment method edge cases. | Use robust phone helper and positive-collected payment methods. |
| Edited saved order deletion | Delete current saved order after API success. | Mobile deletes edited saved order after confirm success. | Match | None. | No parity fix. |
| Error UX | Desktop no `order_id` shows order failed; catch may only log. | Mobile service shows scaffold errors for several failure/exception paths. | Mostly Match / improved | Some errors differ from desktop wording/strictness. | Preserve clear user-facing errors; ensure catch paths always surface errors. |

### Save-Print

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Local confirmed + print | Requires cart/customer/payment, promotes local order, prints, resets. | Mobile `saveOrderAndPrint()` uses `saveOrderAndReturnConfirmed()` and print flow. | Mostly Match | Service helper lacks robust phone fallback and validation relies on page. | Add robust phone helper and service-level validation. |
| Phone fallback | Use robust save fallback chain. | Uses `selectedCustomerPhone ?? mobileNumberText`. | Mismatch | Printed order can miss phone. | Use `OrderCustomerFields.phoneForOrder()`. |
| Offline confirm fallback | Desktop does not route confirm into save-print. | Mobile does. | Mismatch | User action semantics change. | Remove fallback from confirm/create-print online actions. |

### Confirm-Print

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Direct skip checkout prep | Apply default customer/payment, autofill default payment, mark visited, update provider, submit. | `prepareDirectConfirmAndPrint()` does this. | Match with debit caveat | DEBIT autofill can corrupt prep. | Exclude DEBIT from autofill. |
| API then print server order | API confirm, fetch server order details, print, reset. | Mobile `createOrderAndPrint()` follows service/controller flow. | Mostly Match | Offline fallback changes semantics. | Block offline create/print instead of save-print fallback. |
| Cleaner reset | Desktop confirm-print uses cleaner reset than confirm. | Mobile page-level reset after success gives consistent default reapply. | Mostly Match | Service-only use does not fully reset/reapply defaults. | Keep reset at page/controller boundary or move full reset orchestration into one layer. |

### Quotation

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Payment suppression | Quotation mode suppresses payment defaults and clears auto default customer. | Mobile `_initializeProviders()` calls `clearAutomaticDefaultCustomerForQuotation`; `MobileBillingTab` hides payment and uses quotation checkout section. | Match | None. | No parity fix. |
| Inline quotation customer | Desktop quotation has separate customer/date gating. | Mobile `createQuotationFromCheckout()` syncs inline customer and validates existing/inline customer. | Mostly Match | Inline customer can diverge from selected customer summary if user switches modes. | Add tests/manual QA for selected customer to inline customer transitions. |
| Reset after quotation | Desktop clears workspace after quotation flow. | Mobile quotation creation clears cart/reset through controller paths. | Mostly Match | Need ensure default payment remains suppressed in quotation mode after reset. | Verify quotation reset does not apply default payment. |

### Saved-Order Rehydration

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Defaults then override | Desktop defaults apply first, then saved order rehydration overwrites. | Mobile restore/default flow follows similar ordering through controller/page initialization. | Match | Timing bugs if provider updates async. | Keep restore idempotent and guarded against default reapply. |
| Customer restore | Restore by ID or virtual customer from saved fields; set provider. | Mobile controller restores selected customer data and provider fields. | Mostly Match | Phone fallback inconsistency can originate from saved order data. | Use robust customer field helpers in all save paths. |
| Payment restore | Restore multi-payment JSON or single method by backend ID/literal, core flags, amounts, DEBIT, extras, paid/balance, transaction, credit. | `BillingMobileController.restorePaymentMethods()` and provider helpers restore core, COD/ONLINE, extras, balance, transaction, credit. | Partial | Audit did not find clear `paymentStepVisited` marking on restore. | Mark payment visited when restored payment/debit/extra amount exists. |
| Dynamic extras | Desktop restores dynamic extra methods by positive amount keys. | Mobile restores extras from amount maps. | Mostly Match | Clearing amount/value maps can lose labels. | Preserve or reload extra method labels during restore and cart reset. |

### Post-Order Reset

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Clear then re-default | Clear customer/payment/delivery/coupon/etc., then reapply default customer and delivery. | `resetBillingWorkspaceAfterOrder()` calls `_resetBillingWorkspaceCore(clearCart:false, syncDefaultDelivery:true, syncSalesExecutive:false)` and reapplies default customer/delivery. | Match | None if always called. | Ensure every successful page action calls it. |
| Default payment reapply | Desktop reset does not directly call default payment; it may lag until settings listener/payment UI/direct prep. | Mobile reset core clears payment; global settings sync can later apply and autofill too early. | Partial | Payment amount can reappear too early after reset/settings sync. | Remove global settings autofill; only apply flag default where appropriate. |
| Double/nested reset | Desktop confirm has nested `_clearCart()` quirk. | Mobile service partially clears, then page reset clears again. | Partial / similar quirk | Ordering can hide bugs; service-only call skips full reapply. | Consolidate reset ownership or document that service methods must be called only through page/controller success path. |
| Cart clear after save | Desktop order workspace clear differs from manual cart clear UX. | Mobile successful save calls `clearCart()` and can show clear-cart snackbar. | Partial | Extra UX noise. | Use silent workspace reset after save success. |

### Error And Loading UX

| Item | Desktop Expected | Mobile Actual | Status | Risk | Required Fix |
|---|---|---|---|---|---|
| Confirm loading guard | Desktop uses `_isOrderActionInProgress` / modal loading states. | Mobile guards `_isConfirmingOrder`, `_isConfirmingAndPrinting`, `_isSavingOrder`, `_isSavingAndPrinting`. | Match | None. | No parity fix. |
| Offline confirm | Desktop blocks with error. | Mobile fallback to save-print. | Mismatch | Silent semantic change. | Block and show no-internet message. |
| Validation messaging | Desktop modal/action disabled messages and scaffold errors. | Mobile shows scaffold errors from page/service/controller. | Mostly Match | Service strict pricing errors differ from desktop. | Align validation rules first; keep user-visible errors for true blockers. |
| Exception handling | Desktop catch may log without scaffold error in confirm. | Mobile generally shows scaffold errors in service paths. | Mobile improvement | Better UX than desktop, not harmful. | Preserve user-facing errors even if other parity fixes are applied. |

## Mismatch List Ordered By Severity

1. **Critical: Offline confirm and confirm-print fall back to local save-print.** This can create a local confirmed/printed order when the user requested an online API confirmation.
2. **Critical: `skipCustomerSelection` weakens final customer gate.** Customerless confirms can pass when desktop expects a customer ID or phone.
3. **Critical: Service-level confirm/create-print validation can bypass payment readiness.** Page actions validate, but public service paths enforce weaker conditions.
4. **Critical: DEBIT can be autofilled as if it were collected payment.** This conflicts with validation/API exclusion and can produce confusing or invalid state.
5. **High: `syncCreditAmountWithRemaining()` appears to fill underpayment into customer credit.** To-customer-credit should allocate excess, not remaining due.
6. **High: Cart changes do not reset `paymentStepVisited` or pristine state.** Confirm can remain payment-visited after amounts were invalidated by cart edits.
7. **High: Default payment amount autofills during global settings sync.** Desktop default payment should be flag-only until payment UI/direct prep.
8. **High: Save-print and confirm phone fallback are weaker than robust save fallback.** Phone data can be lost in local confirmed/printed or API orders.
9. **High: Saved-order payment restore does not clearly mark payment visited.** Restored orders with payment may fail or behave differently from desktop.
10. **Medium: `getPaidMethods()` may include selected CASH with zero amount.** Desktop API rule is positive collected methods only.
11. **Resolved: Mobile save/confirm pricing validation is disabled for desktop parity.** The disabled confirm/confirm-print blocks retain TODO context for backend validation.
12. **Medium: Payment step visited is marked on mobile section mount.** Similar to desktop render quirk, but easier to trigger because mobile Billing tab is persistent.
13. **Medium: Dynamic/ONLINE payment mapping needs API confirmation.** Literal `ONLINE` may not be a backend payment method ID.
14. **Medium: Extra payment labels/selection may be lost in amount-only clear paths.** This can affect dynamic payment UX after cart changes.
15. **Low: Save success uses manual clear-cart UX.** It can show a second cart-cleared snackbar instead of silent order workspace reset.
16. **Low: Car delivery validation uses literal display name.** This matches desktop but remains brittle for localization/renaming.
17. **Low: Phone default matching is exact string only.** This matches desktop but is operationally fragile.

## Implementation Checklist

### Critical

- [ ] In `BillingPageMobile.confirmOrder()` and `BillingPageMobile.createOrderAndPrint()`, remove offline fallback to `saveOrderAndPrint()`; block online confirm actions with no-internet UX.
- [ ] In `BillingMobileCustomerController.isCustomerSatisfiedForCheckout()` and service customer gates, stop treating `skipCustomerSelection` as final confirm customer satisfaction.
- [ ] Add service-boundary payment readiness validation in `CheckoutService.confirmOrder()`, `CheckoutService.createOrderAndPrint()`, and `CheckoutService.saveOrderAndReturnConfirmed()`.
- [ ] Ensure service-boundary validation checks collected amount coverage, payment visited state, customer gate, cart, car number, and ONLINE/Pine Labs requirements where applicable.
- [ ] Exclude `DEBIT` from `BillingMobilePaymentController.syncPaymentAutofillIfNeeded()` and any helper path that chooses a method for collected full-total autofill.

### High

- [ ] Rewrite or remove `BillingMobilePaymentController.syncCreditAmountWithRemaining()` so to-customer-credit uses excess payment only, not underpayment.
- [ ] In `BillingMobileController.onCartChanged()`, call `billingProvider.resetPaymentStepVisited()` when payment amounts are cleared.
- [ ] In the same cart-change path, call `billingProvider.clearPristinePaymentState()`.
- [ ] Review `BillingProvider.clearCollectedPaymentAmountsOnly()` so it keeps method-selection flags but does not lose dynamic payment labels/IDs needed for UI parity.
- [ ] Remove `_paymentController.syncPaymentAutofillIfNeeded(billingProvider)` from `BillingPageMobile._syncAllSettings()` or guard it so it only runs after payment UI/direct prep.
- [ ] Use `OrderCustomerFields.phoneForOrder()` and `OrderCustomerFields.nameForOrder()` in `CheckoutService.saveOrderAndReturnConfirmed()`.
- [ ] Use `OrderCustomerFields.phoneForOrder()` for `CheckoutService.confirmOrder()` and `CheckoutService.createOrderAndPrint()` unless intentionally preserving desktop's weaker confirm fallback.
- [ ] Mark `paymentStepVisited` during saved-order payment restore when any restored core payment, ONLINE payment, DEBIT/credit amount, or dynamic extra amount exists.
- [ ] Ensure post-order reset does not immediately autofill default payment amount through settings sync.

### Medium

- [ ] Change `BillingProvider.getPaidMethods()` to include CASH only when amount > 0, matching CARD/UPI/COD and desktop positive-collected semantics.
- [ ] Confirm backend contract for ONLINE/Pine Labs payment: literal `"ONLINE"` vs backend payment method ID.
- [ ] Decide whether mobile ONLINE transaction reference requirement is intentional divergence from desktop.
- [x] Disable stricter mobile item price/MRP validation in `CheckoutService.saveOrder()`, `confirmOrder()`, and `createOrderAndPrint()` for desktop parity; leave TODOs for backend validation.
- [ ] If strict desktop parity is required, reduce save validation to cart non-empty only.
- [x] Confirm pricing validation is disabled in place to match desktop's commented-out pricing check.
- [ ] If strict payment visited parity is required, move `markPaymentStepVisited()` from `PaymentMethodsSection.initState()` to user expand/touch or explicit payment edit.
- [ ] Add tests for direct confirm-print default prep with CASH/CARD/UPI/COD and ensure DEBIT is not autofilled as collected.
- [ ] Add tests for cart-change after split payment: amounts cleared, flags retained, visited reset, pristine cleared.
- [ ] Add tests for saved-order rehydration of single payment, split payment, dynamic extra, DEBIT/to-customer-credit, balance, and transaction reference.

### Low

- [ ] Replace successful save's user-facing `clearCart()` call with a silent order workspace reset that preserves desktop save-reset semantics and avoids extra snackbar noise.
- [ ] Document literal `Car Delivery` validation as parity behavior or migrate both desktop/mobile to method metadata.
- [ ] Document exact phone matching for default customer or normalize in both implementations as a product-level improvement.
- [ ] Document mobile's provider-centric architecture and lack of checkout modal local state so future desktop modal changes are mapped deliberately.
- [ ] Add regression notes for desktop quirks intentionally preserved: phone-only default provider-cleared state, sales executive clear-without-reapply, default payment lag after reset, CASH/COD-only change normalization.

## Implemented Fixes

Implemented on Jul 3, 2026:

- Mobile online confirm and confirm-print now block while offline with the existing no-internet errors instead of silently routing to local save-print.
- Final mobile customer gates no longer allow `skipCustomerSelection` to bypass confirm/save-print customer data. Final actions require a selected customer id, typed mobile number, or sales-executive/default phone.
- `CheckoutService.confirmOrder()`, `createOrderAndPrint()`, and `saveOrderAndReturnConfirmed()` now enforce service-boundary customer/payment/car validation using the shared mobile payment readiness path, so alternate callers cannot bypass page-level validation.
- Confirm, confirm-print, save, and save-print payloads now use `OrderCustomerFields.phoneForOrder()` / `nameForOrder()` fallbacks so selected-customer phone and controller-only phone text are preserved.
- Mobile settings sync keeps default payment selection flag-only; amount autofill remains in payment UI/direct confirm-print prep instead of running globally during settings sync.
- Cart changes that clear payment amounts now also reset payment-step visited and pristine payment state while preserving selected core methods and selected dynamic method labels.
- `DEBIT` / to-customer-credit is excluded from full-total payment autofill, and to-customer-credit sync now uses excess collected payment rather than underpayment.
- API `paid_methods` now includes CASH only when the collected cash amount is positive, matching CARD/UPI/COD behavior.
- Saved-order payment rehydration marks the payment step visited when restored payment data exists, including multi-payment JSON, core amounts, dynamic extras, DEBIT, COD, and ONLINE markers.
- Successful mobile local save now clears the order workspace through the non-snackbar reset path instead of showing an extra cart-cleared snackbar.
- Mobile draft save pricing validation was relaxed to cart-only parity with desktop save. Confirm/confirm-print invalid price/MRP validation is now disabled in place to match desktop's commented-out guard, with TODO comments noting backend validation should handle invalid price/MRP later without blocking POS throughput.

## File And Function Reference Appendix

### Desktop Reference Files

| File | Relevant functions / state |
|---|---|
| `lib/features/billing/presentation/pages/billing_page.dart` | `_applyDefaultCustomerFromCacheIfNeeded()`, `_showCheckoutModal()`, `_showPaymentMethodModal()`, `_ensurePaymentReadyForConfirm()`, `_confirmOrder()`, `_saveOrder()`, `_saveOrderAndPrint()`, `_createOrderAndPrint()`, `_confirmAndPrintWithoutCheckoutModal()`, `_rehydrateFromProvider()`, `_resetBillingWorkspaceUi()`, `_clearOrderWorkspace()`, `_onCartChanged()`, `_clearPaymentAmountsOnly()`, `_customerPhoneForOrder()` |
| `lib/features/billing/presentation/widgets/checkout_modal.dart` | `CheckoutModal`, `_applyInitialStepFromSettings()`, `_buildPaymentStep()`, `_syncPaymentAutofillIfNeeded()`, `_hasCompletedPaymentSetup()`, `_handlePaymentUpdate()`, `_handleConfirm()` |
| `lib/features/billing/presentation/widgets/payment_method_modal.dart` | `PaymentMethodModal`, `_applyPristineSwitch()`, `_autoFillSelectedMethodAmount()`, `_refillIfSingleCollectedMethodRemaining()`, `_calculateBalance()`, `_loadPaymentMethods()` |
| `lib/features/billing/domain/payment_validation.dart` | `PaymentValidation.parseAmount()`, `sumCollected()`, `computeNetDue()`, `coversNetDue()`, `validateForOrder()` |
| `lib/features/billing/domain/order_customer_fields.dart` | Customer name/phone fallback helpers |
| `lib/helpers/payment_auto_fill_helper.dart` | Remaining-payment and discount-remap helper |
| `lib/helpers/payment_helper.dart` | `normalizePaidMethodsForApi()` |
| `lib/providers/billing_provider.dart` | Payment mirror, selected method IDs, serialized payment data |
| `lib/providers/cart_provider.dart` | `addToOrderAPI()` |
| `lib/providers/local_product_provider.dart` | Local saved order/cart persistence |
| `lib/providers/customer_selection_provider.dart` | `setSelectedCustomer()`, `clearSelectedCustomer()`, default customer flag |
| `lib/providers/delivery_methods_provider.dart` | `resolveDefaultDeliveryMethod()` |
| `lib/features/billing/controllers/billing_desktop_payment_controller.dart` | Core/dynamic/terminal/credit payment classification |

### Mobile Source Files

| File | Relevant functions / state |
|---|---|
| `lib/features/billing/presentation/pages/billing_page_mobile.dart` | `BillingPageMobileState._initializeProviders()`, `_syncAllSettings()`, `_applyDefaultCustomerFromCacheIfNeeded()`, `_rehydrateFromProvider()`, `_validatePaymentReady()`, `confirmOrder()`, `createOrderAndPrint()`, `saveOrder()`, `saveOrderAndPrint()`, `clearCart()` |
| `lib/features/billing/controllers/billing_mobile_controller.dart` | `restoreOrderState()`, `restorePaymentMethods()`, `_resetBillingWorkspaceCore()`, `resetBillingWorkspaceAfterOrder()`, `clearCartData()`, `prepareDirectConfirmAndPrint()`, `onCartChanged()`, `clearAutomaticDefaultCustomerForQuotation()`, `saveCurrentCartAsDraft()`, `createQuotationFromCheckout()` |
| `lib/features/billing/controllers/billing_mobile_ui_controller.dart` | `BillingMobileSettingsController.applyDefaultPaymentMethodIfNeeded()`, `syncDefaultDeliveryMethod()`, `BillingMobilePaymentController.syncPaymentAutofillIfNeeded()`, `toggleMethod()`, `_applyPristineSwitch()`, `_refillIfSingleCollectedMethodRemaining()`, `validatePaymentReadyForConfirm()`, `syncCreditAmountWithRemaining()`, `BillingMobileCustomerController.applyDefaultCustomerFromCacheIfNeeded()`, `applyDefaultCustomerResult()`, `isCustomerSatisfiedForCheckout()`, `handleSalesExecutiveChanged()`, `handleUserSwitched()` |
| `lib/features/billing/presentation/widgets/mobile/billing_tab.dart` | `MobileBillingTab`, payment/customer/delivery/quotation section composition, order total syncing |
| `lib/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart` | `PaymentMethodsSection.initState()`, `_loadPaymentMethods()`, build-time autofill scheduling, `markPaymentStepVisited()` |
| `lib/features/billing/presentation/widgets/mobile/billing/delivery_options_section.dart` | `DeliveryOptionsSection`, method selection, car number, door delivery address, date/time, comment |
| `lib/services/checkout_service.dart` | `confirmOrder()`, `createOrderAndPrint()`, `saveOrder()`, `saveOrderAndReturnConfirmed()`, customer/payment/cart/pricing validation, API/local payload creation |
| `lib/providers/billing_provider.dart` | `paymentStepVisited`, pristine payment state, `validatePayment()`, `calculateBalanceAmount()`, `getTotalPaidAmount()`, `getPaidMethods()`, `getSelectedPaymentMethodsForApi()`, `createOrderData()`, `clearCollectedPaymentAmountsOnly()`, `clearAllPaymentMethods()`, customer/delivery state |
| `lib/features/billing/domain/payment_validation.dart` | Shared validation formulas used by mobile |
| `lib/features/billing/domain/order_customer_fields.dart` | Robust customer name/phone fallback used by some mobile save paths |
| `lib/helpers/payment_helper.dart` | Shared API `paid_methods` balance normalization |
| `lib/helpers/delivery_charge_helper.dart` | Delivery charge / free-delivery minimum behavior |

## Recommended Implementation Order

1. Fix action semantics first: offline confirm blocking, final customer gate, and service-level validation. These prevent the most serious incorrect orders.
2. Fix payment invalidation next: cart-change visited/pristine reset, DEBIT autofill exclusion, and credit excess calculation.
3. Fix payload consistency: robust phone fallback across save-print/confirm/confirm-print and positive-only `paid_methods`.
4. Fix timing and UX: remove early settings-sync payment autofill, saved-order visited restore, and save success reset/snackbar behavior.
5. Decide intentional divergences: ONLINE transaction reference requirement, mobile payment section mount-as-visited, and literal car delivery validation.

## Core Conclusion

Mobile is close to desktop in formulas and payload structure, but not yet parity-safe in action semantics and state timing. The implementation work should focus less on rewriting mobile architecture and more on tightening the gates around existing provider/service flows: final customer requirement, payment readiness at the service boundary, cart-change invalidation, debit/credit semantics, and consistent customer phone propagation.
