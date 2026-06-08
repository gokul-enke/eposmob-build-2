# Restaurant Page — Button Conditions

## Shared Variables

| Variable | Source | Meaning |
|---|---|---|
| `hasItems` | `LocalProductProvider.cartItems.isNotEmpty` | Cart has at least one item |
| `canCheckout` | `hasItems` | Alias for hasItems |
| `hasInternet` | `BillingProvider.hasInternet` | Online/offline status |
| `isCheckoutActionLoading` | `_isLoadingCounterConfirmOrder \|\| _isLoadingCounterConfirmAndPrint` | A confirm/print action is in progress |
| `disableConfirmActions` | `_shouldDisableCounterCheckoutActions() \|\| isCheckoutActionLoading` | Currently: only `isCheckoutActionLoading` (checkout never disabled by table/dine-in anymore) |
| `showConfirmAndPrintButton` | `appSettings?.showConfirmOrderButton ?? true` | App setting toggle |
| `isCounterBillingMode` | `_isCounterBillingMode` | Counter mode vs table mode |
| `allowCounterBilling` | `widget.allowCounterBillingFromAttender` | Role-level permission |

---

## Footer Action Bar (`_buildCounterActionBar`)

> The entire action bar is only rendered when `_isCounterBillingMode = true`.

---

### Clear Cart — `F1`

| Condition | Value |
|---|---|
| **Visible** | Always (in counter mode) |
| **Enabled** | `hasItems && !isCheckoutActionLoading` |

---

### Save Order — `F8`

| Condition | Value |
|---|---|
| **Visible** | Always (in counter mode) |
| **Enabled** | `hasItems && !isCheckoutActionLoading` |

---

### Confirm and Print — `F6`

| Condition | Value |
|---|---|
| **Visible** | `hasInternet && showConfirmAndPrintButton` (`appSettings.showConfirmOrderButton`) |
| **Enabled** | `canCheckout && !disableConfirmActions` → `hasItems && !isCheckoutActionLoading` |
| **Loading** | `_isLoadingCounterConfirmAndPrint` |

---

### Confirm Order — `F2`

| Condition | Value |
|---|---|
| **Visible** | `allowCounterBilling && isCounterBillingMode && hasInternet` |
| **Enabled** | `canCheckout && !disableConfirmActions` → `hasItems && !isCheckoutActionLoading` |
| **Loading** | `_isLoadingCounterConfirmOrder` (or `_isLoadingCounterConfirmAndPrint` when Confirm and Print is hidden) |

> **Note:** Previously this button was also disabled when a table was selected or dine-in delivery method was chosen. That restriction was removed — Confirm Order is now always enabled for dine-in and table orders.

---

### Save & Print — `F9`

| Condition | Value |
|---|---|
| **Visible** | `!hasInternet` (offline only — replaces Confirm Order / Confirm and Print) |
| **Enabled** | `canCheckout && !disableConfirmActions` → `hasItems && !isCheckoutActionLoading` |
| **Loading** | `isCheckoutActionLoading` |

---

## History — Why Confirm Order Was Disabled for Dine-In

**Before the fix**, `_shouldDisableCounterCheckoutActions()` returned `true` when:
- A table was selected (`_activeTableId != null`), **OR**
- The selected delivery method normalized to `"dinein"` (code/name stripped to alphanumeric == `"dinein"`)

This caused two side effects:
1. `disableConfirmActions = true` → button was **greyed out**
2. `showCartPanelConfirmOrder = !_shouldDisableCounterCheckoutActions()` became `false` → `showFooterConfirmOrder = true` (button stayed visible but disabled)

**After fix 1** (`_shouldDisableCounterCheckoutActions` always returns `false`):
- Button was **enabled**, but `showCartPanelConfirmOrder` flipped to `true` → `showFooterConfirmOrder = false` → button **disappeared** from the footer entirely

**After fix 2** (`showFooterConfirmOrder` decoupled from `_shouldDisableCounterCheckoutActions`):
- Button is **always visible and enabled** for counter billing mode with internet, regardless of table or delivery method selection
