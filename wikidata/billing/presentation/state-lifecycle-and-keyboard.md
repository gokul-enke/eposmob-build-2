# Billing Page State, Lifecycle, And Keyboard Logic

Source: `lib/features/billing/presentation/pages/billing_page.dart`.

## Page Modes

- `BillingPageMode.normal` is sales/order mode.
- `BillingPageMode.quotation` is quotation mode.
- `_isQuotationPage` switches UI labels, action buttons, default customer behavior, payment initialization, and checkout validation.
- `AutomaticKeepAliveClientMixin` returns `true`, so page state is kept alive across navigation.

## Core State Groups

The page owns these state groups directly:

- Text controllers and focus nodes for mobile/customer, coupon, barcode, quantity, unit price, product search, transaction, delivery, comments, car number, and autocomplete.
- Customer state: selected customer object, selected id, phone, manual selection flag, default-customer behavior, customer autocomplete highlight/options, and selected customer balance display.
- Delivery state: method name/id, car number, comment, address, date/time, selected delivery charge.
- Payment state: cash/card/UPI/COD/debit booleans, amount controllers, transaction number, to-customer-credit flag, extra dynamic payment method amount/value maps, `balanceAmount`, `paidAmount`, and modal-opened flag.
- Loading state: clear/save/create/confirm/save-print flags, barcode processing flags, product sync/resync flags, order busy flag.
- Sidebar state: visible flag, tab index, keyboard mode, resize fraction, stored width preference.
- Cart keyboard state: selected row/cell, open unit menu state, edit request ids for quantity/price.
- Quotation state: quotation date, expiry date, and rehydrated order tracking.

## Busy Guard

`_beginOrderAction` and `_endOrderAction` wrap order mutations. Save, clear, confirm, print, create-new-order, and load-saved-order flows use this guard to avoid duplicate execution.

Preserve this rule during refactor: no order mutation should run if another order mutation is already active.

## Initialization

`initState` does all of this:

- Loads saved sidebar width preference.
- Gets `AuthModel` user/token and asks `CartProvider` to fetch cart data from API.
- Adds focus listeners for quantity and unit price so text is selected when focused.
- Registers global hardware keyboard handler.
- Prints debug app-setting values.
- Initializes delivery method and payment method defaults.
- Starts with no payment methods selected.
- Hydrates customer list from `CustomerProvider` cache.
- Schedules post-frame stock setting sync and saved-order rehydrate.
- Initializes connectivity listener through `BillingProvider`.
- Subscribes to `BarcodeProvider.barcodeStream` and routes scanner events into barcode queue.
- Adds listeners to sales executive, auth/user switch, app settings, general settings, local product provider cart changes, and mobile number controller.

## Disposal

`dispose` removes:

- Hardware keyboard handler.
- Overlays and barcode stream subscription.
- Controllers and focus nodes.
- Debounce timer.
- Listeners added to sales executive, auth model, app settings, general settings, local product provider, and delivery methods provider.

Refactor rule: any extracted controller that registers a provider or hardware listener must own matching disposal.

## Stock Setting Sync

`_syncStockEnabledSetting` reads `GeneralSettingsProvider.generalSettings?.stockEnabled` and passes it to `LocalProductProvider.setStockEnabled`. The page listens to general settings changes and keeps the local provider aligned.

## Connectivity

`_initConnectivityListener` delegates to `BillingProvider.initConnectivityListener`.

- When internet is lost, the page shows a "No internet connection" message.
- When internet returns, the page shows an "Internet connection restored" message.
- `BillingProvider.hasInternet` also respects manual offline mode.

Online confirm flows check `hasInternet`; local save/print flows remain available offline.

## Rehydrating Saved Or Current Orders

`_rehydrateFromProvider` copies `LocalProductProvider.currentOrder` into page state.

When no current order exists:

- It infers discount/coupon state from `LocalProductProvider.priceSummary`.
- It clears the last rehydrated id marker.

When a current order exists:

- It restores customer from the customer list when possible.
- If no saved customer exists, it creates a virtual customer object from stored name/phone.
- It updates `CustomerSelectionProvider`.
- It restores customer text, selected id/phone, and manual/default flags.
- It restores payment from local JSON multi-payment or single payment value.
- It maps typed payment ids for CASH, CARD, UPI, COD, DEBIT, BALANCE, ONLINE, and dynamic extra methods through `BillingProvider` and `MasterDataProvider`.
- It restores paid amount, balance amount, transaction number, delivery method/id, selected delivery charge, comment, car number, delivery date/time, delivery address, coupon id, flat/percentage discounts, and to-customer-credit flag.
- It marks payment modal as opened if any payment or credit data exists.
- It recalculates balance and resets autocomplete after frame.

Important edge case: local saved order payment is stored as JSON for multi-payment. Rehydration must support both typed methods and dynamic methods.

## Focus And Keyboard Policy

`_shouldSuppressSystemKeyboard` uses `SystemKeyboardPolicy.shouldSuppressForContext` with `fieldWantsVirtualKeyboardOnly: true`.

Primary focus helpers:

- `_focusTextField` focuses barcode when `appSettings.barcodeSales` is enabled, otherwise product autocomplete.
- `_focusSearchProductField` focuses product autocomplete.
- `_focusBarcodeField` focuses barcode input.
- `_restoreShortcutFocus` restores product/barcode focus after dialogs.

## Global Shortcuts

The page only handles billing shortcut keys and control shortcuts when no route/dialog is on top. It ignores normal typing.

Handled shortcuts:

- `Esc`: exits sidebar keyboard mode or focuses product/barcode entry.
- `F1`: clear cart.
- `F2`: checkout confirm flow, or quotation create flow.
- `F3`: open checkout at customer step.
- `F4`: open checkout at delivery step.
- `F5`: open checkout at payment step.
- `F6`: confirm/print flow for normal page, quotation print flow for quotation page.
- `F7`: create new local order, saving current cart as draft first when needed.
- `F8`: save order or create quotation depending on page mode.
- `F9`: save and print local order when offline/available.
- `F10`: open checkout at discount step.
- `F12`: toggle sidebar keyboard mode and product/orders tab.
- `Ctrl+A`: focus barcode.
- `Ctrl+S`: focus product search. A separate `_triggerSyncFromShortcut` exists but is not currently wired to this key.
- `Ctrl+H`: open shortcut help.
- `Ctrl+K`: toggle virtual keyboard.
- `Ctrl+D`: focus cart table.
- `Ctrl+Q`: request quantity edit on selected cart row.
- `Ctrl+U`: open cart unit selector on selected row.
- `Ctrl+P`: request price edit on selected cart row.
- `Alt+D`: open cash drawer.

Barcode field also handles `Tab` to move to product search.

## Sidebar Layout And Resize

The main build uses a row layout when sidebar is visible:

- Usable width is total width minus the resize handle.
- Sidebar width is calculated by `BillingSidebarMetrics.clampedWidth`.
- Main content receives the remaining width.
- When hidden, main content takes full width.

Sidebar width preference is stored per user through `SharedPreferenceProvider.getBillingSidebarWidthFraction` and `saveBillingSidebarWidthFraction`.

`BillingSidebarMetrics` rules:

- Minimum preferred width: `250`.
- Maximum width: `420`.
- Main content should not be squeezed below `620`.
- On narrow widths, the lower bound can shrink to `40%` of usable width.

## Sidebar Tabs

The sidebar has Products and Orders tabs.

Product tab:

- Reads `LocalProductProvider.sellableProducts`.
- Shows sync/loading state from `SyncProvider`.
- If product list is empty, shows resync action.
- Resync first fetches products with refresh, then can call `syncProvider.syncAllData`.

Orders tab:

- Shows local saved orders through `HorizontalSavedOrdersView`.
- Shows products through `HorizontalProductViewLocal`.
- Selecting a saved order first saves current non-empty cart as draft, then loads the selected saved order for editing.
