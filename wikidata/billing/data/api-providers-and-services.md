# API Providers, Shared Providers, And Services

This file documents billing logic outside the page/provider pair but directly used by the billing flow.

## BillingProvider

Source: `lib/providers/billing_provider.dart`.

Connectivity:

- Tracks device internet state through `internet_connection_checker_plus`.
- Tracks manual offline mode through `SharedPreferenceProvider`.
- `hasInternet` is true only when device has internet and manual offline mode is false.
- `initConnectivityListener` checks initial access and subscribes to status changes.
- Optional callback lets billing page show lost/restored messages.

Legacy/shared billing state:

- Has loading flags for clear, save, create, confirm, save-print, add item, and barcode processing.
- Owns many controllers/focus nodes used by older billing logic.
- Stores payment method ids for CASH/CARD/UPI/COD.
- `updatePaymentFromModal` mirrors current modal payment selection, amounts, transaction number, customer credit, and method ids.

The desktop page currently owns most active payment state but still updates this provider so helpers/printing/sync can resolve ids.

Payment validation:

- `validatePayment` delegates to `PaymentValidation.validateForOrder` for typed CASH/CARD/UPI/COD amounts.
- ONLINE with terminal success is treated as valid without amount checks (Pine Labs path).
- Does not yet mirror desktop extra-method maps; mobile/desktop parity for dynamic methods may differ.

## CartProvider

Source: `lib/providers/cart_provider.dart`.

`fetchCartDataFromAPI`:

- Called during billing page init and customer selection.
- Uses auth token and customer id/phone context.
- Keeps server cart state aligned where online cart data exists.

`addToOrderAPI`:

- Posts to `APPUrl.addToOrderUrl`.
- Adds active store id from SharedPreferences when present.
- Sends tenant header `X-Tenant` and bearer token.
- Accepts both payment formats.

Multi-payment request body:

- `items`
- `phone`
- optional `customer_id`
- `transaction_number`
- `payment_method` as list of method ids
- `paid_methods` as list of `{method, amount}`
- `source_type: executive`
- `balance`
- `coupon_id`
- optional order, comment, delivery, table, car, status, delivery date/time
- flat discount, percentage discount, discount amount
- `to_customer_credit`
- address
- quotation id
- `delivery_charge`
- store id

Single-payment request body:

- Same fields, but uses scalar `payment_method` and `paid_amount`.

Items are reversed before posting.

`applyCoupon`:

- Calls coupon endpoint with query params `price`, `coupon_code`, and active store id.
- Returns success/message/data object.
- Throws API-key missing error through caught response behavior where applicable.

## MasterDataProvider

Billing uses master data for:

- Fetching payment methods.
- Resolving method id to payment method value/name during rehydration.
- Active stock grouping fields used by product cart and stock selection logic.

Payment method ids from this provider are mirrored into `BillingProvider`.

## DeliveryMethodsProvider

Source: `lib/providers/delivery_methods_provider.dart`.

Responsibilities:

- Holds delivery method list.
- Caches methods in memory and SharedPreferences per active store.
- Fetches API data with active store id.
- Parses list and map response shapes.
- Provides `defaultDeliveryMethod`, preferring names containing "store takeaway", otherwise first method, otherwise fallback id `11` and name `Store Takeaway`.
- `resolveDefaultDeliveryMethod` matches app setting default by id, name, or code.

Billing page uses this for:

- Initial delivery method.
- Delivery modal options.
- Delivery charge lookup.

## CustomerProvider And CustomerSelectionProvider

`CustomerProvider`:

- Provides cached customer list.
- Searches customer by phone or name for autocomplete.
- Fetches all customers in background after sale.

`CustomerSelectionProvider`:

- Stores selected customer object, phone, id, and default-customer flag.
- `setSelectedCustomer` notifies listeners.
- `clearSelectedCustomer` resets all fields.
- `updateCustomerPhone` stores typed/manual phone.

Billing page writes to this provider whenever customer changes because product add helpers read it when no customer is passed explicitly.

## CustomerPurchaseProvider

Billing cart row purchase-history action:

- Calls provider to fetch recent purchases for selected customer and product.
- Displays latest entries in modal.
- Lets user apply selected historical price after minimum-sale validation.

## QuotationsProvider

Billing quotation flow uses:

- `createQuotation` for payload submission.
- `fetchQuotationDetails` after creation when print is requested.

The page extracts created quotation id from multiple response shapes:

- top-level `quotation_id`
- top-level `id`
- `data.quotation_id`
- `data.id`
- `data.quotation.id`
- `quotation.id`
- scalar numeric/string `data`

## SalesProvider

Confirm-print flow uses `SalesProvider.listOrderDetails` after successful online order creation.

The returned order details feed `PrintPage.autoPrint` or fallback print screen navigation.

## Printing Services

`PrintPage.autoPrint`:

- Used for live online order print.
- If it returns false, the page navigates to `PrintPage`.

`PrintService.printSavedOrder`:

- Used by local saved/confirmed order printing.
- Uses `PaymentHelper.parseLocalMultiPayment` for readable multi-payment data.

`QuotationPrintService.printQuotationDetails`:

- Used after quotation creation and detail fetch.

Double bill:

- If `appSettings.posPrintDoubleBill` is enabled and first print succeeds, billing asks whether to print customer copy.

## SyncProvider

Billing uses sync for:

- Sidebar empty product state resync.
- Manual full sync through `syncAllData`.
- `SyncButton` in header.

`_triggerSyncFromShortcut` exists and checks internet plus `SyncProvider.isSyncing`, then calls `syncAllData`, but the current `Ctrl+S` shortcut focuses product search instead.

## BarcodeProvider

Billing subscribes to `BarcodeProvider.barcodeStream`.

Each stream value goes into the page barcode queue and is processed by barcode logic.

## Settings Providers

`AppSettingsProvider` influences:

- Barcode sales mode.
- Discount/coupon visibility.
- Price round-off.
- Tax/MRP/item code table columns.
- Confirm-order button visibility.
- Default customer assignment.
- Default payment method.
- Default delivery method.
- Skip customer selection in checkout.
- Double bill printing.
- Delivery charge/free delivery rules.
- Ask delivery date.
- Customer last purchase history visibility.

`GeneralSettingsProvider` influences:

- `stockEnabled`, synchronized into `LocalProductProvider`.

`RoleProvider` influences:

- Product view permission in cart row.

`SharedPreferenceProvider` stores:

- Sidebar width fraction per user.
- Manual offline mode.
- API keys/tokens and active store data used by providers.

`StoreSessionProvider` supplies:

- Active store id/name for stock filtering and delivery/product API context.
