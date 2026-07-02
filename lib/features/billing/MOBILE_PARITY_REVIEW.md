# Mobile Billing — Desktop Parity Review

Deep comparison of the desktop billing monolith (`presentation/pages/billing_page.dart` ~9,400 lines + desktop modals) against the mobile rewrite (`billing_page_mobile.dart`, `controllers/`, `domain/`, `widgets/mobile/`). Every claim below was verified against the current code (July 2026, branch `gokul-dev`).

Classification: **MISSING** (desktop behavior absent on mobile), **DIVERGENT** (same feature, different rules), **PARITY** (confirmed equivalent), **N/A** (intentionally desktop-only).

---

## 1. Critical gaps (money / data correctness)

### 1.1 Pristine payment-method auto-switch — MISSING
- Desktop: `payment_method_modal.dart` `_recordPristineIfFullTotal` (L752–822) + `_applyPristineSwitch` (L728–751). When a method was auto-filled with the full total and the cashier taps a *different* method without touching the amount, desktop deselects the pristine method and moves the full amount to the new one.
- Mobile: `billing_mobile_ui_controller.dart` `toggleMethod` (L1386–1414) only autofills the *remaining* payable. If CASH was autofilled with the full total and the cashier taps CARD, CASH stays selected at full total and CARD autofills 0 remaining — the cashier must manually deselect CASH. Different (and easier-to-misuse) interaction: a distracted cashier can record payment under the wrong method.
- Suggested fix: replicate pristine tracking in `BillingMobilePaymentController` (record method+amount when autofilled to full total; on selecting another method with the pristine amount untouched, clear the pristine method first).

### 1.2 Single-method refill after amount edits — MISSING
- Desktop: `payment_method_modal.dart` `_refillIfSingleCollectedMethodRemaining` (L837–855) — when amounts change (e.g. one method deselected/zeroed) and exactly one collected method remains, its amount is refilled to the new balance.
- Mobile: `onAmountChanged` (billing_mobile_ui_controller.dart L1416–1436) only auto-selects the method and recalculates; no refill. Note: the *discount* path IS covered via `remapPaymentsAfterDiscountChange` → shared `PaymentAutoFillHelper` — the gap is only for manual edits/deselections inside the payment section.

### 1.3 Customer-credit field live sync — DIVERGENT
- Desktop: `_syncCreditAmountWithRemaining` (payment_method_modal.dart L1293–1306) keeps the to-customer-credit amount in sync as other amounts change.
- Mobile: credit amount is only clamped on field commit (`clampToCustomerCreditAmount`, billing_mobile_ui_controller.dart L1369–1379). If the cashier lowers a cash amount *after* enabling credit, the stale credit amount survives until commit-time clamp. Server-side validation may catch it, but the desktop UX prevents it earlier.

### 1.4 Background customer refresh after sale — MISSING
- Desktop: `_refreshCustomersInBackgroundAfterSale` (billing_page.dart L6963–7005), called after confirm (L6541) and create&print (L6886), so the next sale sees the customer's *updated* balance.
- Mobile: no equivalent anywhere in `billing_page_mobile.dart` / `billing_mobile_controller.dart`. After a credit sale, the cached customer list still shows the pre-sale balance. Since balance drives net-due math (`computeNetDue`, `maxToCustomerCreditAmount`), a back-to-back sale to the same credit customer can use a **stale previous balance** — this is the most consequential gap in the list.

---

## 2. Functional gaps

### 2.1 Customer search: altPhone + digit normalization — DIVERGENT
- Desktop: `checkout_modal.dart` `_filterCustomers` (L818–837) matches name, phone, **and altPhone**; `customer_input.dart` strips non-digits before phone matching (alphanumeric-formatted numbers still match).
- Mobile: `filterCustomers` (billing_mobile_ui_controller.dart L2235–2247) does raw lowercase `contains` on name and phone only. A customer stored with `+91 98…` won't match a search for `9198…`, and alternate phones are unsearchable.

### 2.2 Keyboard shortcut coverage — PARTIAL
- Mobile handles F1 (clear), F2 (confirm), F6 (create&print), F7 (new), F8 (save), F9 (save&print), Esc, Ctrl+A (`resolveShortcutAction`, billing_mobile_controller.dart L368–438).
- Missing vs desktop: F3/F4/F5/F10 (jump to customer/delivery/payment/discount step — meaningful on mobile as "jump to tab/section"), Ctrl+S (product search focus), Ctrl+H (shortcuts help dialog), Ctrl+Q/U/P (cart cell edit), Ctrl+D (cart focus), Ctrl+K (virtual keyboard), F12 (sidebar mode), Alt+D (cash drawer — the drawer button itself exists in `billing_status_header.dart`, only the shortcut is absent). For tablets with external keyboards, F3–F5/F10 tab-jumps and Ctrl+H help are the ones worth adding.
- Payment-modal shortcuts Ctrl+1..8 (toggle methods, transaction no., credit) have no mobile equivalent.

### 2.3 Payment notification debounce — N/A (note)
- Desktop modal debounces parent notification 300ms; coupon modal debounces manual discount 500ms. Mobile writes providers directly — no correctness issue found, but rapid typing in amount fields triggers `calculateBalance` per keystroke; fine unless profiling says otherwise.

---

## 3. Behavioral divergences (same feature, different rules — mostly acceptable)

- **Payment-not-ready flow**: desktop `_ensurePaymentReadyForConfirm` (L612–633) reopens the payment modal with a retry callback; mobile `_validatePaymentReady` shows an error and switches tab. Different UX, same gate.
- **Coupon auto-apply**: desktop `coupon_modal._findDiscountByCode` auto-selects *and applies* an exact code match; mobile `coupon_section.dart` (L70) matches the code but applies on explicit tap. Deliberate-feeling; keep.
- **Add-customer insertion**: desktop inserts the created customer at index 0 of the cached list *and* dedupes by phone; mobile `select_customer_page.dart` (L119–127) does the same — PARITY.

## 4. Confirmed PARITY (verified, with citations)

| Behavior | Desktop | Mobile |
|---|---|---|
| Transaction number for CARD/UPI | payment_method_modal | `payment_methods_section.dart`, `pine_labs_section.dart` |
| Car number required for Car Delivery | `_confirmOrder` | `checkout_service.dart:102` (`validateCarNumberIfNeeded`) — shared |
| `skipCustomerSelection` setting | checkout_modal L419 | `checkout_service.dart:70,284`, `billing_page_mobile.dart:683` |
| Min-sale-price clamp + user warning | `price_fields.dart:86–121` | `mobile_cart_price_fields.dart:206`, `cart_item_card.dart:487` |
| Low-stock indication in cart | billing_page.dart:3285+ | `cart_screen.dart:103`, `cart_item_card.dart` |
| Rehydration duplicate-guard | `_lastRehydratedOrderId` billing_page.dart:278 | `billing_page_mobile.dart:62,174,574` |
| Quotation reset (dates→now+30d, clear inline customer, clear cart) | billing_page.dart:7730 | `billing_page_mobile.dart:900–906` |
| Save&Print promotes draft to confirmed | `_saveOrderAndPrint` L6064–6200 | `CheckoutService.saveOrderAndReturnConfirmed()` (status:"confirmed"), `billing_page_mobile.dart:919–975`, incl. print-retry snackbar and customer copy |
| Balance/credit math (debt→transaction-excess vs credit→net-due, ≥0 clamps) | payment_method_modal `_calculateBalance` L1094–1194 | `computeTransactionExcess` / `maxToCustomerCreditAmount` / `prefillToCustomerCreditAmount` (billing_mobile_ui_controller.dart L1303–1340) — line-for-line equivalent branches |
| Autofill fallback-to-CASH safety net | checkout_modal `_syncPaymentAutofillIfNeeded` | `syncPaymentAutofillIfNeeded` L1466–1496 |
| Stock deduction preserved on confirm, restored on clear | `preserveStockDeduction` flag | shared `LocalProductProvider.clearCartAfterOrder()` (L3175) vs `clearCart()` (L3148) — mobile routes through the same provider |
| Payment payload normalization (balance deducted from first CASH/COD, credit-only methods filtered) | via `payment_helper.dart` | same shared helper via `CartProvider.addToOrderAPI` path |
| Cash drawer button | header/Alt+D | `billing_status_header.dart` (button only; shortcut missing, see 2.2) |
| Sales-executive context | `_onSalesExecutiveChanged` etc. | present in `billing_page_mobile.dart`, `billing_tab.dart`, controllers |
| Purchase-history price apply (respects min price, no unit conversion) | desktop history widget | `applyPurchaseHistoryPrice` L793–818 + `billing_customer_history_flow_test.dart` |

## 5. Intentionally desktop-only (no action)
Resizable sidebar + F12 keyboard mode, cart-table cell navigation (Ctrl+Q/U/P, unit overlay menu), virtual keyboard (Ctrl+K), checkout step modal itself (mobile uses tabs), 300/500ms debounce plumbing.

## 6. Test-coverage gaps (present on mobile but untested)
- `fillExactCash`, `selectMethodOnTap`, `onToCustomerCreditAmountChanged` auto-enable path.
- `saveOrderAndPrint` end-to-end (promotion + print-retry + workspace reset) — only pieces are covered.
- Customer search filtering (`filterCustomers`) has no test — add one when fixing 2.1.
- No test asserting customer balance freshness after confirm (would have caught 1.4).

## 7. Recommended priority order
1. **1.4** background customer refresh after sale (stale-balance money risk).
2. **1.1** pristine method switch + **1.2** single-method refill (cashier speed/correctness).
3. **2.1** altPhone + digit-normalized customer search.
4. **1.3** live credit sync (or at least clamp on every recalculation).
5. **2.2** F3–F5/F10 tab-jump shortcuts + Ctrl+H help for keyboard-attached tablets.
6. Section 6 tests alongside each fix.
