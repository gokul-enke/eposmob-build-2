# Offline-first sales: open work

Date: 2026-09-29
Related doc: `docs/OFFLINE_FIRST_SALES.md` (how it works today)

This lists what was found while building and testing offline-first sales, the
`OFFLINE_FIRST_SALES` setting, the Confirmed Orders tools (Retry, Log, Remove),
bill numbers and the Save & Print removal, but was deliberately left for later.

---

## Backend

### 1. `OFFLINE_FIRST_SALES` company setting does not exist yet
The app reads it from `/api/v1/website-settings`, but no `CompanyProp` row is
created by `CompanyPropsSeeder` or `CompanyOnboarding`. Until it exists every
tenant is offline-first. `active = 1` → offline-first, `active = 0` →
online-first (which still falls back to offline-first when the till is
offline).

### 2. Rejections come back as HTTP 500
`add_to_order` and `updateOrder` return 500 for validation errors
(`errorResponse()` defaults to 500) and for any exception in the general
`catch (\Exception)`. The app treats 500 as "result unknown", so a clearly
rejected sale goes to **Needs review** instead of **Rejected**. In online-first
this also clears the cart instead of letting the cashier fix it. Return 422 for
validation and business errors; keep 500 for real failures.

### 3. Every database error is reported as a duplicate bill number (409)
`add_to_order` turns any `QueryException` into "The receipt number or client
sale ID is already in use." without logging it. Return a specific code (for
example `receipt_number_conflict`, ideally with the next free sequence) only
for a real duplicate, and log everything else.

### 4. Sales return list cannot be searched by bill number
`listReturnOrders` validates `order_number` with `exists:orders,order_number`
and matches it exactly. Use `nullable|string` and
`matchingSaleReference()`, as `listReturnOrderItems` already does. A request
note was prepared for the backend developer.

### 5. Optional: resume and protect bill numbering automatically
Today the operator fixes numbering by hand (Settings → POS Counter Identity →
Last bill sold today). If clashes become common:
- an endpoint returning the highest used sequence for store + counter + day, so
  the app resumes automatically after a reinstall;
- counter claiming per `pos_device_id`, so two devices cannot share a counter.

### 6. ZATCA: which number is the official invoice number?
The printed bill labels `2-01-260929-0002` as "Invoice No." and the ZATCA QR is
generated on the device, while the backend also creates Invoice records with
their own numbers. Confirm which number is the official one submitted to ZATCA.

---

## App

### 7. API reset and Clear Local Storage delete unsent sales
Both call `LocalProductProvider.clearAllLocalData()`, which empties the local
confirmed-orders box, including `needs_review` and `rejected` sales. Their sync
records stay, but Confirmed Orders lists sales from the local copies, so they
vanish and cannot be retried or reprinted. Proposed:
- keep unsent sales through resets;
- store the company (API key or server URL) on each sync record;
- disable Retry for a sale that belongs to a different company than the
  current login (only Remove allowed), so a sale is never posted to the wrong
  company.

Bill numbering (sequence, counter, device ID) already survives every reset.

### 8. Offline sales need a manual Retry each
There is no automatic send when the connection returns. Options:
- a **Send now** action for sales that were never sent (skips the "check the
  admin panel first" warning, since the app knows they never left the device);
- automatic sending when connectivity returns, now that the backend
  deduplicates by `client_sale_id`.

### 9. Removed sales are invisible
Remove hides a sale but keeps it (with `dismissed_at` and `dismiss_note`).
Nothing lists them. Add a "Show removed" filter if audits need it.

### 10. Time zone fallback is India time
If no business time zone is loaded, `DateHelper._convertToLocal` falls back to
+05:30. Default to `Asia/Riyadh` (the backend default) and log a warning.

### 11. Sale details popup has stale wording for rejected sales
`confirmed_order_detail_modal.dart` tells cashiers to "correct the problem
before creating a new sale". Now that Retry exists, say to fix the cause and
use Retry.

### 12. Retention
Synced sales are deleted after 30 days (`LocalSaleSyncService.syncedRetention`).
Lower to 7 days once production is stable.

### 13. Online-first falls back to offline-first when offline
Chosen so the till never stops selling. If some tenants must never sell
without a server check, add a third mode ("online-only").

### 14. Save & Print still exists in unused legacy files
Removed from every live surface, but still present in
`screens/billing/billing_page_desktop.dart`,
`screens/billing/billing_page_restaurant.dart`,
`features/billing/presentation/widgets/action_buttons.dart` and
`CheckoutService.saveOrderAndReturnConfirmed`. Delete them together with the
legacy screens.

### 15. Existing `CONF-…` local-only sales
Sales made by the old Save & Print show as "Local only" with no way to send
them. They can only be deleted from the sale details popup and billed again.
Consider a one-time notice on devices that still have them.

### 16. Sync console output prints in release builds
The `[LocalSaleSync]` lines use `debugPrint`, which also prints in release
builds (Android logcat). Request bodies include customer phone numbers and
amounts. Consider wrapping them in `kDebugMode`.

### 17. Legacy Orders to review page
Kept only for records from older builds (`OrderSubmissionCoordinator`). Remove
after a release proves the `order_submissions` box has no unresolved records.

### 18. Not yet verified in the running app
- mobile and restaurant offline confirm (including a restaurant table order
  confirmed offline from the panel);
- Retry, Log and Remove on Confirmed Orders;
- Bill No. on Sales Return and the Orders list;
- Last bill sold today in Settings;
- bill numbering surviving an API reset.
