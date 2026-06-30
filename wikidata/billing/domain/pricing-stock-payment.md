# Pricing, Stock, Sale Unit, Delivery, Discount, And Payment Rules

Sources:

- `lib/providers/local_product_provider.dart`
- `lib/features/billing/presentation/pages/billing_page.dart`
- `lib/features/billing/domain/payment_validation.dart`
- `lib/helpers/payment_helper.dart`
- `lib/helpers/payment_auto_fill_helper.dart`
- `lib/features/billing/presentation/widgets/payment_method_modal.dart`

## Price Summary

`LocalProductProvider.cartTotal` computes and stores `priceSummary`.

Rules:

- Subtotal is sum of `item.price * item.quantity`.
- Prices are treated as tax-inclusive.
- Total tax is extracted from subtotal, not added to it.
- Flat discount plus percentage discount amount is subtracted.
- Discount is capped at subtotal.
- If discount exceeds subtotal, the provider mutates stored discount values so the effective discount no longer exceeds subtotal.
- `netPayable` and `netTotal` are both subtotal after discount.
- `PriceSummary.percentageDiscount` stores the calculated discount amount, while `LocalProductProvider.getCurrentDiscount()` returns the configured raw percent.

Any flow that needs current summary should force-read `localProductProvider.cartTotal` first.

## Tax Breakdown

Tax extraction formula:

```text
inclusiveTax = itemTotal * taxRate / (100 + taxRate)
```

If product-level tax components match the current total tax rate, the provider splits extracted tax proportionally across tax names/rates. Otherwise it falls back to a generic tax label or single tax name.

The cart table repeats the same inclusive formula for the row tax amount.

## Price Source Priority

For cart item price:

1. Explicit custom/manual price from UI or history.
2. Existing manual override if item is already in cart.
3. Selected stock wholesale price when quantity qualifies for wholesale minimum.
4. Selected stock price.
5. Product price.
6. Fallback zero.

MRP priority:

1. Selected stock MRP.
2. Product MRP.
3. Fallback zero.

Tax priority:

1. Selected stock tax rate when present.
2. Product total tax rate.
3. Fallback zero.

## Minimum Sale Price

`LocalProductProvider.minimumSalePriceForProduct` computes a floor from product price and optional margin settings.

Supported floor inputs:

- `min_margin_percentage`: selling price reduced by percentage.
- `min_margin_price`: selling price reduced by fixed amount.

When both exist, the higher floor wins. Price cannot be below zero. If no selling price or no minimum config exists, there is no floor.

`PriceTextField` enforces this floor on blur and submit. Customer purchase history price application also checks this floor.

## Round-Off

`LocalProductProvider.getRoundedTotal(context)` uses `AmountHelper.roundOffAmount(cartTotal)` only when `appSettings.priceRoundOff` is true.

`BillingPage._getEffectiveOrderTotal`:

- Takes `priceSummary.netTotal` when available, otherwise `cartTotal`.
- Applies round-off if enabled.
- Adds delivery charge after round-off.

## Delivery Charge

`_getDeliveryChargeForOrder` applies:

- If `appSettings.freeDeliveryEnabled` is false, delivery charge is zero.
- If free-delivery minimum is configured and order net amount is greater than or equal to it, delivery charge is zero.
- If `_selectedDeliveryCharge` exists, use it.
- Otherwise match delivery method by id/name in `DeliveryMethodsProvider.deliveryMethods` and use base price.
- Fallback is zero.

Footer summary rule:

- `_getFooterPriceSummaryWithDeliveryCharge` adds delivery charge to `netPayable`.
- It leaves `netTotal` unchanged.

Effective order total rule:

- Delivery is added after optional round-off.

## Discount And Coupon

Manual discount:

- `CouponModal` rejects negative flat/percentage discounts.
- Percentage cannot exceed `100`.
- Flat discount cannot exceed cart subtotal.
- Empty cart cannot receive discount.
- Valid manual discount calls `LocalProductProvider.applyDiscount`.

Coupon selection:

- Discount list is fetched through `DiscountProvider`.
- Selecting a coupon populates either flat or percentage controller based on discount type.
- Validity is checked by `DiscountProvider.getValidityForDiscount`.
- Page `_applyCoupon` also calls `CartProvider.applyCoupon` with current total and coupon code.
- API response updates `CartProvider` price summary, while local cart discount is applied through the modal callback.

Clearing coupon:

- Calls `LocalProductProvider.clearDiscount`.
- Clears coupon code and applied flag.
- Fetches cart API again.

## Sale Unit Model

`LocalCartItem` always stores:

- Base-unit `quantity`.
- Base-unit `price`.
- Base-unit `mrp`.

Sale-unit metadata is optional:

- `saleUnitId`
- `saleUnitName`
- `saleUnitConversionRate`

Display conversions:

- Display quantity = base quantity / conversion rate.
- Base quantity = display quantity * conversion rate.
- Display price/MRP = base amount * conversion rate.
- Base price/MRP = display amount / conversion rate.

Payload conversion:

- `buildOrderItemsPayload` uses sale-unit payload fields only when conversion can round-trip safely.
- Otherwise it falls back to base-unit quantity and price.

## Stock Reservation

`StockReservation` stores stock id and reserved quantity.

Reservation rules:

- Disabled stock management means no reservation.
- Candidates come from selected stock and/or stock group ids.
- Candidates are sorted earliest expiry, then earliest stock date, then lowest id.
- Reservation subtracts from local stock and records actual quantity deducted.
- Local stock cannot go below zero.
- If requested quantity exceeds available stock, remaining quantity can still be added without reservation.
- Restore returns reserved stock in reverse reservation order.
- Saved order loading re-applies saved reservations to current stock.
- Quotation draft loading does not re-apply reservations.

Cart clear behavior:

- `clearCart()` restores all reservations.
- `clearCartAfterOrder()` does not restore reservations.

## Cart Item Identity

Cart lines are matched by:

- Product id.
- Sale unit id.
- Stock group ids when both incoming and existing groups exist.
- If grouped, active stock grouping key may be compared before raw id set.
- Otherwise selected stock id.
- Base/no-stock matches only other base/no-stock entries.

This prevents merging different sale units or different stock pricing groups into one line.

## Payment State Stored Locally

`_getPaymentMethodData` stores payment as JSON when any selected method exists:

```json
{
  "methods": ["cashId", "cardId"],
  "amounts": {
    "cashId": "100",
    "cardId": "50",
    "DEBIT": "0"
  },
  "isMultiPayment": true
}
```

Rules:

- CASH/CARD/UPI/COD use ids from `BillingProvider` when available.
- Dynamic extra payment methods are keyed by method id.
- DEBIT is stored only when to-customer-credit is enabled and debit amount is greater than zero.
- `paidAmount` excludes debit/customer credit.
- If no selected methods exist, stored payment method is empty and paid amount is `0`.

## Selected Payment Methods

`_getSelectedPaymentMethods` includes only selected methods with positive amount.

- CASH, CARD, UPI, COD use ids from `BillingProvider`.
- Dynamic extra methods with amount greater than zero are included.
- Debit/customer credit is intentionally excluded from selected payment methods for API paid methods.

## API Paid Methods

`_getPaidMethods` builds `{method, amount}` rows for selected CASH/CARD/UPI/COD and dynamic extra methods.

Then it calls `PaymentHelper.normalizePaidMethodsForApi`, which:

- Removes empty method ids and non-positive amounts.
- If balance/change amount is positive, deducts it once from first CASH or COD row.
- Also matches configured cash/COD ids.
- Removes rows that become zero.

This prevents customer change from being posted as collected payment.

## Balance And Customer Credit

`_calculateBalanceAmount` in the page and `_calculateBalance` in payment modal use the same concept:

- Total collected = cash + card + UPI + COD + dynamic extra amounts.
- Debit/to-customer-credit is not counted as collected payment.
- Result is clamped so displayed balance is never negative.

Without customer credit:

```text
balance = max(totalCollected - orderTotal, 0)
```

With customer credit and previous balance is negative:

```text
transactionExcess = totalCollected - orderTotal
balance = max(transactionExcess - min(debitAmount, transactionExcess), 0)
```

With customer credit and previous balance is positive or zero:

```text
netDue = orderTotal - previousBalance
availableBalance = totalCollected - netDue
balance = max(availableBalance - min(debitAmount, availableBalance), 0)
```

Default customers pass previous balance as zero.

## Payment Validation

Source: `lib/features/billing/domain/payment_validation.dart`.

Shared rules for desktop billing page, checkout modal, payment modal apply button, and `BillingProvider.validatePayment`.

Collected payment means money taken at the register now:

- CASH, CARD, UPI, COD when selected with amount greater than zero.
- Dynamic/extra backend methods when selected with amount greater than zero.
- DEBIT, customer credit row, and to-customer-credit are **not** collected payment.

`validateForOrder` checks:

1. At least one collected method has a positive amount (unless order total is zero).
2. Sum of collected amounts covers net due.
   - Default customer or to-customer-credit off: net due = order total.
   - To-customer-credit on with positive previous balance: net due = order total - previous balance (floored at zero).

`isCheckoutPaymentComplete` adds a UI gate:

- Payment amounts must pass `validateForOrder`.
- User must have reached payment UI: payment modal opened once **or** checkout is currently on the payment step (supports autofill on step 3 without an extra click).

Error messages:

- `Please enter at least one payment amount`
- `Payment amount is less than the amount due`

## Collected Payment Method Behavior (Modal + Checkout)

Sources:

- `lib/features/billing/presentation/widgets/payment_method_modal.dart`
- `lib/features/billing/presentation/widgets/checkout_modal.dart` (embedded modal on payment step)

Typed values from backend:

- CASH, CARD, UPI, COD

Any other configured backend method becomes a **dynamic/extra** row (BANK, Cheque, Online Payment, etc.).

Credit row at the bottom is separate from collected payment. It is auto-calculated / store-credit allocation, not part of the shared collected-method rules below.

### Shared helpers inside PaymentMethodModal

All collected methods (typed + extra) use the same helpers:

| Helper | Purpose |
|--------|---------|
| `_applyPristineSwitch` | Untouched auto-filled full total on method A → select method B → clear A, move full total to B |
| `_autoFillRemainingForMethod` | Split payment: new method gets `cartTotal - sum(other collected methods)` |
| `_refillIfSingleCollectedMethodRemaining` | Deselect one of two → sole remaining method refills to full cart total |
| `_getTotalCollectedAmount` | Sum of selected typed amounts + selected extra amounts only |
| `_amountsEqual` / `_isFullCartTotal` | Numeric compare so `105` and `105.00` behave the same |

Pristine tracking uses method keys `cash`, `card`, `upi`, `cod`, and `extra_<methodId>`.

### Selection flows

**Single-method switch (pristine):**

1. Cash auto-filled with full total (untouched).
2. User clicks Cheque.
3. Cash cleared/deselected, Cheque gets full total.

**Split payment (edited or second method while first holds partial amount):**

1. Cash set to 50 (user edited or partial fill).
2. User clicks Card or Cheque.
3. Second method gets remaining 55 (when total is 105).

**Deselect refill:**

1. Cash 50 + Cheque 55.
2. User deselects Cheque.
3. Cash refills to 105.

**Apply / confirm validation:**

- Payment modal Apply button calls `PaymentValidation.validateForOrder` before closing.
- Billing page `_ensurePaymentReadyForConfirm` runs the same validation before online confirm, save-and-print, and create-and-print.

### Cart and workspace resets

`_onCartChanged` on billing page:

- If payment was configured, clears all collected amount controllers and extra-method maps.
- Resets payment-modal-opened flag.
- Recalculates balance.

`_resetBillingWorkspaceUi` also clears `_extraPaymentAmounts` and `_extraPaymentValues`.

### Dynamic method reload safety

When `MasterDataProvider` payment methods reload inside the modal, preserved extra-method amounts/selection are restored so a cache-then-fetch sequence does not wipe user input.

### Default customer in modal balance

When `isDefaultCustomer` is true:

- Previous balance is treated as zero in modal cash-balance calculation even if to-customer-credit toggle is on.
- Matches billing page `_calculateBalanceAmount`.

## Payment Modal Auto-Fill (Helper Layer)

`PaymentMethodModal` delegates remaining-balance math to `PaymentAutoFillHelper`.

`autoFillRemaining`:

- Takes a map of all collected method keys and amounts (`cash`, `card`, `extra_<id>`, …).
- Fills target method with `cartTotal - sum(other methods)`.
- Used by modal for both typed and extra methods.

`autoFillSingleMethod`:

- Legacy typed-only helper; still used where only CASH/CARD/UPI/COD strings are relevant.
- Can include extra amounts when computing remaining for a typed target.

`remapAmountsAfterDiscount`:

- When exactly one typed method was selected and its amount matched the old effective total, remap that method to the new effective total after discount.
- Used from checkout discount step; does not remap extra methods or manual splits.

## PaymentHelper

`parseLocalMultiPayment`:

- Parses local saved order payment JSON.
- Maps ids to display names through `MasterDataProvider` and `BillingProvider`.
- Returns display string and payment breakdown for printing.
- Also picks up positive amounts not present in the methods list, such as DEBIT.

`buildApiPaymentPayloadFromLocal`:

- Converts stored local payment data into online API fields for syncing local orders.
- Normalizes method names to ids.
- Excludes DEBIT/BALANCE as credit-only methods.
- Produces either single payment fields or multi-payment method lists.
