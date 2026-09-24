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

## Test 6 — Composite `en_ar` language is hidden

> **Separate change, not part of the confirm-order hotfix.** Lives on `gokul-dev`.
> File: `lib/providers/language_provider.dart` — `/api/v1/languages` responses are
> filtered so codes in `hiddenLanguageCodes` (currently just `en_ar`) never reach the
> UI. Filtering happens once, at parse time in `fetchLanguages`, so it applies to every
> screen that reads `LanguageProvider.languages`.

The backend returns an `"English + Arabic"` entry (`id: 8`, `code: en_ar`) that is a
server-side composite, not a real product/category translation target.

1. Confirm the tenant's `/api/v1/languages` response still contains the `en_ar` row —
   the fix hides it client-side, it does not remove it server-side.
2. Open each screen that offers per-language text fields and check the list of
   languages offered:

| Screen | Path | Result |
|---|---|---|
| Add product (mobile) | Billing → add product → translations | |
| Add product (modal/desktop) | Billing → add product dialog | |
| Product details / edit | Tap a product → edit tab | |
| Product details dialog | Desktop product details | |
| Add category | Categories → add | |
| Edit category | Categories → edit | |
| Add category modal | Inline "add category" from product form | |

**Pass criteria**

- **"English + Arabic" appears nowhere.** Every other active language still does —
  English, Arabic, Urdu, tamil, Malayalam on the sample tenant.
- Saving a product or category still works, and the translations that *are* entered
  round-trip correctly after reopening.
- No empty state or "no other languages" message appears on a tenant that has other
  languages — i.e. the filter removed one entry, not the list.

**Not affected — spot-check these did not change:**

- **Bilingual receipts.** `en_ar` is a legitimate receipt language mode and comes from
  receipt configuration, not this API. Print an English + Arabic receipt and confirm it
  still renders bilingually.
- **Existing `en_ar` translation data** already saved on products still parses; it is
  simply no longer editable in the app.

- [ ] Language lists — [ ] Save round-trip — [ ] Bilingual receipt unaffected — notes:

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

---
---

# QA — Order Details: Payment & Delivery Method Translation

**Branch:** `gokul-dev`
**Commit:** uncommitted at time of writing
**Scope:** Sales → Order Details screen only

## What was fixed

The order details page rendered two fields raw while the rest of the app was
translated:

- **Payment method** showed the machine code — `CARD` instead of *Card* / *بطاقة* /
  *കാർഡ്* — in the Payment Details row and again in each Payment Breakdown line.
- **Delivery method** showed `delivery_method_name` exactly as the API returned it
  (`"Dine In"`), which the backend resolves to the store's default language and ships
  with no `translations` alongside it.

Both are now resolved on the client from reference data the app already caches. **No
API change was required**, and the stored data is unchanged — `payment_method` and the
`payments` map keys remain machine codes, because `PaymentHelper` and several call
sites branch on them. Translating those keys would silently break every lookup.

Resolution order, payment: loaded method's backend translation → the app's bundled
string → the raw code. Delivery: `delivery_method_id` → method name → any translation
→ the raw name.

## Files changed

| File | Change |
|---|---|
| `models/payment_method_registry.dart` | **New.** Static snapshot of loaded payment methods, mirroring `DeliveryMethodRegistry`, so the print/details layers can resolve a code with no `BuildContext` |
| `helpers/payment_method_display.dart` | **New.** `labelFor` (single code) and `labelForCodeList` (the comma-joined `payment_method` field) |
| `helpers/delivery_method_display.dart` | Added `labelForIdOrName` — resolves by id first, falls back to the name |
| `providers/master_data_provider.dart` | All four `_paymentMethodModels` assignments routed through one setter that also updates the registry |
| `screens/sales/widgets/buid_order_details_widget.dart` | Four render sites: delivery method (Store & Delivery, Shipping Details), payment method, payment breakdown key |
| `test/order_details_method_labels_test.dart` | **New.** 11 tests covering both resolution paths and every fallback |

---

## Setup

Any build works — no console markers needed. You will need:

- A store with **Arabic and Malayalam** enabled, so language can be switched.
- At least one order **paid by card**, one **split across two methods** (cash + card),
  and one with a **non-default delivery method** (e.g. Dine In).
- Language is switched from Settings; the order details page can stay open.

> Reference data matters here. Delivery-method translations come from the backend, so
> check in the admin panel whether the tenant has actually translated the delivery
> method under test. If they have not, Test 3 correctly shows English — that is the
> backend's gap, not an app bug.

---

## Test 1 — Payment method label

1. Open Sales → an order paid by **card** → Order Details.
2. Read the **Payment Method** row under Payment Details.
3. Read the label on each line under **Payment Breakdown**.
4. Switch the app language to Arabic, then Malayalam, returning to this order each time.

**Pass criteria**

| Language | Expected |
|---|---|
| English | `Card` |
| Arabic | `بطاقة` |
| Malayalam | `കാർഡ്` |

- The raw code `CARD` appears **nowhere** on the screen.
- The breakdown line and the Payment Method row show the **same** wording.
- The amount beside each breakdown line is unchanged.

- [ ] Pass — [ ] Fail — notes:

## Test 2 — Split payment

The API returns `payment_method` as an array, which the model joins into one string
(`"CASH, CARD"`). Each code has to be resolved separately.

1. Open an order paid partly in cash and partly by card.
2. Read the Payment Method row.

**Pass criteria**

- Both methods are translated and comma-separated — `Cash, Card` / `نقد, بطاقة`.
- Not one half-translated string, and not the raw `CASH, CARD`.
- The breakdown below lists both, each translated, with correct amounts.

- [ ] Pass — [ ] Fail — notes:

## Test 3 — Delivery method label

1. Open an order with a non-default delivery method (Dine In, Car Delivery, …).
2. Read the **Delivery Method** row under Store & Delivery Info.
3. Scroll to **Shipping Details** and read its Delivery Method row.
4. Switch language and repeat.

**Pass criteria**

- Both rows show the **same** value.
- For a method the tenant has translated: the translated name appears.
- For a method with a known kind (Car Delivery, Store Takeaway, Door Delivery, Third
  Party Logistics): the app's own bundled translation appears even without a backend
  translation — e.g. `توصيل بالسيارة`.
- A numeric id (`199`) must **never** appear. That is a hard fail.
- An untranslated tenant method (Dine In with no backend translation) staying English
  is expected — note it, do not fail it.

- [ ] Store & Delivery row — [ ] Shipping Details row — notes:

## Test 4 — Cold start, straight into an order

The riskiest path: the lookup tables are populated during store bootstrap, so this
checks what happens before they load.

1. Fully close the app.
2. Relaunch in Arabic, log in, and navigate to Sales → Order Details **as fast as
   possible**, before any background sync finishes.

**Pass criteria**

- Payment method still shows the translated bundled string for core codes
  (`بطاقة` for card) — this path does not need the network.
- Delivery method shows the plain English name, **not** a numeric id.
- Nothing is blank, and nothing crashes.

- [ ] Pass — [ ] Fail — notes:

## Test 5 — Tenant-defined methods win

Confirms a store's own wording is not overwritten by the app's bundled strings.

1. On a tenant with a custom payment method (loyalty points, wallet, a renamed card
   entry such as "Card Machine"), open an order paid with it.

**Pass criteria**

- The **tenant's** label is shown, in the tenant's translation for the active language.
- The app's generic bundled string does not override a renamed method.

- [ ] Pass — [ ] Fail — notes:

## Test 6 — Language switch offline

Labels are resolved at render time from cached data, so this should need no network.

1. Open an order details page and note the labels.
2. Turn off networking.
3. Switch the app language and return to the same order.

**Pass criteria**

- Both labels re-render in the new language with no network call and no error.

- [ ] Pass — [ ] Fail — notes:

---

## Regression pass

The payment-method provider now pushes a snapshot on every load path, and the shared
`UiCodeLabels.payment` helper is reused. Confirm nothing downstream shifted.

| Path | What to check | Result |
|---|---|---|
| Billing — payment selector | All methods listed, correct labels, checkout completes | |
| Billing — split payment | Amounts allocate and reconcile as before | |
| Credit / "to customer balance" | Still offered even when the backend omits it | |
| Customer voucher list | Payment method column unchanged | |
| Supplier transactions / vouchers | Payment mode column unchanged | |
| Order details — return an order | Return flow still starts from this screen | |
| Switch store, then open order details | Labels follow the new store's methods | |

**Receipts and PDFs are deliberately out of scope.** The print layouts do their own
bilingual mapping keyed to the *document* language rather than the app UI language, so
`sales_order_details.dart` still passes raw values into `PrintPage`. Print one receipt
and one shared PDF and confirm they are **byte-for-byte what they were before** — any
change there is a regression, not the fix.

- [ ] Regression pass complete — [ ] Receipt unchanged — [ ] PDF unchanged

---

## Known state going in

- **Automated tests:** 1057 passing, 0 failing, including 11 new tests in
  `test/order_details_method_labels_test.dart` covering both resolution paths and every
  fallback (cold registry, deleted method, untranslated backend, unknown code).
- **Analyzer:** clean on all changed files. The 13 remaining issues in
  `buid_order_details_widget.dart` are pre-existing and on untouched lines
  (`withOpacity` deprecations, an unused `_calculateTotalMRP`, two stale null-aware
  operators). Zero new issues.
- **Backend follow-up, not a blocker.** Order details would be more robust if it
  returned `delivery_method_code` alongside the name and honoured `lang` on
  `delivery_method_name`. That removes the dependency on the lookup tables being warm —
  the Test 4 fallback. `payment_method` and the `payments` keys must **stay raw codes**.
- **`lib/providers/language_provider.dart`** is also modified in the working tree
  (hiding the `en_ar` composite language code). That is a **separate change** with its
  own coverage — see *Test 6* in the section above. It did not come from this work;
  keep the two apart when committing.

## Sign-off

| Tester | Build | Date | Result |
|---|---|---|---|
| | | | |
