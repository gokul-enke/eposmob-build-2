# QA — Confirm Order Freeze Hotfix

**Branch:** `hotfix/urgent-fix`
**Commit:** `3aef818b` — fix(billing): stop confirm-order freezes and never-ending spinner
**Base release:** 1.0.55+67

## What was fixed

Cashiers reported the confirm button hanging for 20–30 seconds, and the loading
indicator sometimes never finishing. Three causes, all on the order path:

1. **The subscription guard re-verified on every order action.** With the company
   subscription endpoint not live, each stale check cost a failed probe plus a full
   app-settings refetch — up to 15s of frozen button before the spinner was even
   raised, and again on every app resume. A single failed app-settings fetch latched
   the failure state, after which *every* click paid that cost and hit a blocking
   "Unable to verify" dialog.
2. **Order writes had no timeout.** A stalled socket left the future pending forever,
   so the `finally` that clears the spinner never ran.
3. **The spinner was raised after the guard**, so the button looked idle while the
   guard was still working.

Enforcement is unchanged: a blocked company is still rejected by the backend on the
order response (`403` / `SUBSCRIPTION_BLOCKED`).

## Files changed

| File | Change |
|---|---|
| `subscription_action_guard.dart` | `refreshIfStale` defaults to `false`; `unknown` falls back to in-memory app settings, failing open |
| `cart_provider.dart` | 30s timeout + `TimeoutException` handling on `addToOrderAPI`, `updateOrderAPI`, `addToOrderConfirmAPI` |
| `app_settings_provider.dart` | 15s timeout on `fetchAppSettings` |
| `checkout_service.dart` | Spinner raised before the guard in all three checkout entry points |

---

## Setup

Run a **debug or profile** build so console output is visible — the diagnostic markers
are `debugPrint` and need an attached console.

```bash
flutter run -d windows --profile
```

Two console markers matter throughout:

- `APP SETTINGS PARSING DEBUG:` (with the ticket emoji) — app settings were fetched
- `Sending POST request to server...` / `Response status code:` — an order write

---

## Test 1 — No network call on the order path

The main fix. Verifies the 15s freeze is gone.

1. Log in, open billing, add items to cart.
2. Clear the console.
3. Place an order. Note the console output.
4. **Wait 3+ minutes** (longer than the old 2-minute staleness window), then place
   another order.
5. Repeat once more after another 3 minutes.
6. Switch to another window for a minute, return, and immediately place an order.

**Pass criteria**

- Only the order POST markers appear on each confirm.
- The app-settings parsing block **never appears** when tapping confirm.
- The button responds instantly every time, including after the waits and after resume.

> Before the fix, steps 4 and 6 printed the app-settings block and froze the button
> for several seconds. That is the regression this test guards.

- [ ] Pass — [ ] Fail — notes:

## Test 2 — Cold start, first order

1. Fully close the app.
2. Relaunch, log in, add items, and place an order **as fast as possible** — before
   any background sync completes.

**Pass criteria**

- The order goes through.
- The "Unable to verify subscription" dialog does **not** appear.

> Exercises the fail-open path: app settings are still unloaded at that point and the
> guard must allow the sale.

- [ ] Pass — [ ] Fail — notes:

## Test 3 — Timeout (the never-ending spinner)

Requires a connection that **stalls**, not one that fails — airplane mode will not
work, because the internet check catches that first and shows "no internet".

**Method (Windows):** tap Confirm, then immediately block the connection so the
already-open socket stalls. Get the API host IP and have this ready to paste:

```bash
New-NetFirewallRule -DisplayName "POS-Stall-Test" -Direction Outbound -RemoteAddress <API_IP> -Action Block
```

1. Add items to cart, tap **Confirm Order**.
2. Run the command above within a second or two.
3. Watch the spinner and time it.

**Pass criteria**

- The spinner **stops within ~30 seconds**. It must not run indefinitely.
- Message shown: *"The request timed out. The order may still have been created -
  check the order list before billing it again."*
- Console shows `Order request timed out after 30s`.

4. Remove the rule:

```bash
Remove-NetFirewallRule -DisplayName "POS-Stall-Test"
```

5. **Check the order list.** Confirm whether the order was actually created
   server-side. Either outcome is acceptable — the point is that the message tells the
   cashier to check rather than encouraging a blind retry that double-bills.

Repeat for **Confirm & Print** and for **editing an existing order**, which exercise
`addToOrderConfirmAPI` and `updateOrderAPI` respectively.

- [ ] Confirm Order — [ ] Confirm & Print — [ ] Edit order — notes:

## Test 4 — Spinner covers the whole operation

On a slow connection, or using a brief stall as in Test 3:

1. Tap Confirm and watch the button closely.
2. Tap it repeatedly while the operation runs.

**Pass criteria**

- The spinner appears on the **first frame after the tap**.
- There is no window where the button looks tappable but does nothing.
- Repeated taps do **not** fire a second order.

- [ ] Pass — [ ] Fail — notes:

## Test 5 — Subscription enforcement still works

Confirms the behaviour change is safe. Needs backend cooperation.

1. Have the backend return `403` with `code: SUBSCRIPTION_BLOCKED` on the order
   endpoint for a test tenant.
2. Add items, tap Confirm.

**Pass criteria**

- The blocked dialog appears and the order is rejected.

> Timing shift, expected: the block now surfaces **after** the cashier taps Confirm,
> not before they build the cart. Enforcement moved to the order response.

Optionally, if you plan to use the app-settings row: set `COMPANY_SUBSCRIPTION_STATUS`
to `blocked` with its status enabled, and confirm the guard blocks *before* submission.

- [ ] 403 path — [ ] app-settings row (optional) — notes:

---

## Regression pass

The guard change touches 18 call sites. Place one order through each entry point and
confirm it completes normally.

| Path | What to check | Result |
|---|---|---|
| POS billing — Confirm Order | Order created, cart cleared, fields reset | |
| POS billing — Confirm & Print | Order created **and** receipt prints | |
| Save Order & Print | Saved order returned and prints | |
| Restaurant — order panel / KOT | Order and KOT flow intact | |
| Kiosk billing | Order completes | |
| Kiosk order page | Order completes | |
| Edit existing order | Update saves | |
| Create invoice modal | Invoice created | |
| Confirmed orders screen | Actions work | |

Also verify **offline behaviour is unchanged**: with no internet, tapping Confirm
should still show the "no internet" message immediately.

- [ ] Regression pass complete

---

## Known state going in

- **Automated tests:** 930 passing, 1 failing — `receipt_configuration_workspace_test.dart`
  ("shows synced fields and switches receipt sections"), a PDF logo decode failure.
  Verified pre-existing on a clean tree. Not related to this fix; do not chase it.
- **Analyzer:** 43 issues on the changed files, identical to baseline. All are
  pre-existing info-level `use_build_context_synchronously`. Zero new issues.
- **`pubspec.yaml` / `docs/Release.md`** carry an unrelated version bump
  (1.0.55+67 to 1.0.61+71) that did not come from this fix. Resolve before building
  the release — that number is ahead of `gokul-dev` (1.0.60+70), which looks wrong
  for a hotfix off 1.0.55+67.
- **`main` is a placeholder** (single "Initial commit" file) and is not a valid PR
  target. This goes to `hotfix/urgent-fix`, then forward to `gokul-dev`.

## Sign-off

| Tester | Build | Date | Result |
|---|---|---|---|
| | | | |
