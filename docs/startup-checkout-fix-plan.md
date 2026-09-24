# CloudPOS startup and supermarket checkout fix plan

Status: client implementation and local verification completed as described in `startup-checkout-verification-2026-09-09.md`. Backend lookup/idempotency and affected-device rollout checks remain outstanding. Changes have not been deployed.

Scope: Windows launch visibility and supermarket billing, based on the reported 1.0.65+75 and newer-build complaints. Compare against 1.0.67+77 as the implementation baseline. Restaurant checkout findings are a separate follow-up.

## Product decision

When the user opens CloudPOS, immediately acknowledge the launch with a visible window. Show what is happening while the application prepares its data. On Confirm Order, acknowledge the click immediately, complete as soon as the server responds, and clearly distinguish a rejected order from a response that has not arrived.

The existing 30 seconds is a maximum wait, not an intentional delay. A response received in one second should finish in one second. Lowering the timeout does not speed up a seven-second response.

**Proposed checkout policy: a 20-second response deadline**, accompanied by the uncertain-order behavior below. Start with 20 rather than 15 seconds because client/server timing has not yet been measured. Make the setting centralized and configurable through application configuration; validate it against release-build timing before rollout. Keep a timeout so stalled requests cannot leave the checkout indefinitely loading.

At 20 seconds, stop showing an ordinary confirmation spinner and show that the result is unknown. Do not describe the order as failed, erase its data, automatically resend it, or display success without evidence. Backend processing can continue after a client timeout or cancellation.

## 1. Make launch visible before initialization

### Windows runner

- Show a small, branded native startup window before initializing the Flutter engine/plugins. This covers time spent before Dart can render anything. Use the existing app icon and a readable status; avoid an empty white or black window.
- Keep the native startup window's message loop serviced while initialization proceeds. If engine creation blocks the main runner thread, give the startup window a dedicated native UI thread with explicit ownership and shutdown signaling; do not access its HWND unsafely from another thread.
- Replace the native startup window with the real Flutter window only after its first usable frame. Keep the app represented in the taskbar, handle DPI correctly, and make closing startup terminate initialization without leaving an invisible process behind.
- On a second launch, bring the existing startup or main window forward. Handle minimized windows and the short interval before the first window exists. Align mutex/window matching so supported installation paths cannot silently exclude each other.
- If an existing process cannot be reached, display a clear message with Close and support details. Do not silently exit or forcibly kill a process that may be saving a sale.

### Flutter startup controller

- Initialize the required Flutter binding, then mount a minimal startup shell immediately. Do not wait for Sentry, Hive or translations before displaying this shell.
- Run initialization through an explicit controller with states: starting, opening storage, restoring data, ready, and failed. Track the current stage and elapsed time. Use simple built-in strings until saved language/translations are available, then use localized messages.
- Initialize Sentry without delaying visible feedback. Install essential error capture early and buffer startup diagnostics locally until reporting is ready. Preserve Flutter/Sentry binding and zone requirements; verify both debug and release startup.
- Preserve safe dependency order. Open required boxes before creating providers that access them; wait for product hydration before enabling billing. Mount the app's normal provider/lifecycle tree exactly once after its prerequisites are satisfied.
- Keep optional configuration/cache work off the critical path where consumers can tolerate it. Retain valid cached data and do not make fresh network access a prerequisite for showing the UI. Preserve existing authentication and offline-sale rules.
- Keep named per-stage timeouts and storage-size allowances. A stage timeout should produce an actionable error screen; it must not silently restart an unfinished operation.
- `Future.timeout` does not cancel the original work. Track one startup attempt, disregard late UI completions from an obsolete attempt, and avoid concurrent opens or migrations. For operations that cannot be safely stopped, require a controlled process restart before retrying.
- Preserve carts, saved orders and unresolved submissions during recovery. Do not add an automatic reset/delete action for sales data.

### Responsiveness

The early window fixes the invisible-launch experience. Keeping it responsive is a separate requirement: synchronous Hive frame decoding can still block Flutter rendering. Retain chunked product hydration, measure frame/event-loop stalls, and move expensive pure-data decoding to a worker isolate where feasible. Do not open the same writable Hive box concurrently across isolates. Consider a separate catalog-storage redesign only if measurement shows the initial Hive open still causes unacceptable stalls.

**Target to validate:** visible launch acknowledgment within one second on representative supported POS hardware under ordinary conditions. Treat this as an acceptance target, not a promise independent of OS load. Log process-start to native-window and first-Flutter-frame timings separately.

## 2. Give confirmation an explicit state and a 20-second deadline

- Introduce one shared supermarket submission coordinator used by desktop/mobile confirmation and keyboard shortcuts. Maintain one operation state, rather than independent spinners with different error interpretation.
- Acquire the submission guard synchronously on the first click/key press. Show feedback immediately, before asynchronous validation. Release it appropriately for validation rejection, authoritative completion or the explicit uncertain state.
- Use states: validating, submitting, slow response, confirmed, rejected, and outcome unknown. Keep each response tied to the originating attempt so it cannot clear or modify a subsequent cart.
- At five seconds without a response, update the status text. Do not insert a five-second delay for fast responses.
- At 20 seconds without a conclusive response, show the outcome-unknown panel and stop the normal submit spinner. Keep the original sale accessible and prevent an ordinary Confirm action from resending that attempt.
- A received rejection, such as a valid backend stock-validation error, is different from a timeout, connection loss after sending, malformed response or server error that does not prove whether a commit happened. Classify these outcomes explicitly.
- Use a monotonic stopwatch to time submission and its stages. Keep the deadline in one place for the actual request; do not stack UI and provider timeouts that race each other.
- On an authoritative success, show success immediately, record the result against the submission, then clear the corresponding cart and reset the workspace once. Do not wait for customer/list refresh or printing to recognize a confirmed sale.
- If local cleanup fails after server success, preserve the success and provide recovery. Do not relabel the sale as rejected or invite another POST.
- Preserve the existing validation and stock/payment rules. Confirm and Confirm & Print must share submission state so a timeout followed by a different button cannot create a second order.

Implementation starts in `lib/providers/cart_provider.dart`, `lib/services/checkout_service.dart`, the supermarket `billing_page.dart`, `billing_page_mobile.dart`, and their confirmation modal/controller paths.

## 3. Protect uncertain submissions, including after reboot

### Client changes

- Generate a stable submission ID and persist a minimal pending record before sending. It should contain the immutable sale snapshot needed to identify/reconcile the attempt, its creation time and eventual server order ID. Exclude credentials and unnecessary personal information.
- If the record cannot be saved, stop before sending and show a storage error. Keep its storage separate from disposable catalog caches.
- Keep the same ID for the same attempt; never silently turn Retry into a new submission. A changed cart is a distinct sale and cannot reuse the old payload under that ID.
- Preserve pending records on timeout, app close and reboot. On next launch, restore unresolved attempts and make them visible before a cashier accidentally rebills them.
- If a late successful response arrives while the app is running, reconcile it to the recorded attempt. Do not apply it to whichever cart happens to be open.
- Offer View Orders immediately. Allow manual verification using available order details, but do not interpret a missing row in a paginated or stale list as proof that the order was never created.

### Backend contract to verify/implement

The backend is not part of the examined checkout. Its existing capabilities must be verified; do not assume an idempotency header alone adds protection.

- Accept a stable submission ID scoped to tenant/store.
- Enforce uniqueness atomically with order creation. Repeated requests for the same ID and payload must return the same order; reuse with a different payload must produce a conflict.
- Expose an authoritative lookup by submission ID, including processing, confirmed, rejected and definitive not-created outcomes. Define whether and when not-created is safe to retry, including in-flight requests.
- Support bounded status checks and reconciliation across reconnect/restart.

Until that contract exists, ship clear uncertainty handling, durable records and View Orders, but no automatic retry. An explicit Check Order Status button should appear only when a real lookup exists. A failed or inconclusive lookup returns to the uncertainty panel instead of spinning forever.

For the lookup, propose a separate 10-second request deadline and at most one automatic check before asking for user action; subsequent checks are explicit. Do not repeatedly resend the order in the background.

## 4. Measure and fix the actual delay

Record non-sensitive timings for launch stages and checkout validation, POST start/finish, response handling, local persistence and workspace reset. Include app version, attempt/correlation ID, result category, item count and catalog size. Exclude tokens, API keys and full payment/customer payloads; replace the existing credential/payload debug logging on this path.

Correlate slow POSTs with backend request timing. Check database work, lock contention and any synchronous receipt, notification or external integration work if the backend trace identifies them. Move nonessential post-sale work out of the response path without weakening transactional stock/payment correctness.

Inspect performance in release builds on actual POS hardware. A 20-second deadline is a recovery limit, not the desired checkout speed. Set normal-response targets using observed median and 95th-percentile timings; do not claim success merely because the spinner stops at 20 seconds.

## 5. User-facing text

Keep these messages localized and consistent across supermarket desktop and mobile. Stage text must describe the stage actually running; do not show fabricated percentages or a countdown presented as completion time.

| Situation | Heading / button | Supporting text |
| --- | --- | --- |
| Native launch | **Opening CloudPOS…** | Please wait while the app starts. |
| Flutter preparing storage | **Getting your counter ready…** | Loading products and saved orders. |
| Startup stage is taking longer | **Still getting ready…** | Your saved data is taking longer to load. Please keep CloudPOS open. |
| Unrecoverable storage/startup error | **CloudPOS couldn’t finish starting** | We couldn’t load the data needed to open your counter. Close CloudPOS and open it again. If this continues, share the error details with support. |
| Startup error actions | **Copy error details** · **Close CloudPOS** | Show the technical cause in expandable details. Only offer Restart when controlled shutdown/restart is implemented. |
| Existing process cannot be focused | **CloudPOS is already starting or running** | We couldn’t bring its window forward. Wait a moment and try opening CloudPOS again. If this continues, contact support. |
| Confirm action begins | **Confirming order…** | Please wait for confirmation. |
| No response after five seconds | **Still confirming…** | The server is taking longer to respond. Please keep this order open. |
| No conclusive response by 20 seconds | **We haven’t received confirmation yet** | This order may already be saved. Check its status before creating it again. |
| Unknown-result actions without backend lookup | **View orders** | Keep the original sale and its pending status available; do not offer a generic Retry button. |
| Unknown-result actions with backend lookup | **Check order status** · **View orders** | Show Check order status only when its backend lookup is implemented. |
| Status check also unavailable | **We still can’t verify this order** | The server couldn’t confirm its status. Your order details are saved on this device. Check again when the connection is available. |
| Successful confirmation | **Order confirmed** | Order {orderNumber} has been saved. |
| Authoritative rejection | **Order wasn’t confirmed** | Show the actionable backend explanation, such as which item has insufficient stock. |
| App reopens with unresolved attempt | **An order needs checking** | An earlier order is waiting for confirmation. Check its status before billing it again. |

Use the statement “Your order details are saved on this device” only after durable persistence succeeds. Do not promise that all local data is safe when a storage failure prevents verification. Text about printing should be separate from order confirmation, because a printer failure does not undo a sale.

## 6. Validation and rollout

### Automated checks

- Startup shell appears while initialization is deliberately stalled; expected stage and failure messages appear.
- Late completions after startup timeout cannot mount the normal app or trigger a second initialization attempt.
- Required-storage errors do not construct billing providers or delete carts/orders.
- Duplicate clicks and keyboard confirmation produce only one submission.
- Fast success returns immediately; five-second message appears only when needed; outcome becomes unknown at 20 seconds.
- Late success is reconciled once, including navigation/disposal races. It cannot clear a newer cart.
- Timeout, post-send disconnect and inconclusive response preserve the pending record; definitive rejection and success take distinct paths.
- Restore an unresolved submission after process restart and reconcile it without duplicate creation.
- Existing stock, tax, discount, multi-payment, saved-order and offline workflows continue to pass.
- Backend concurrency/idempotency tests verify that identical submissions commit one order and mismatched payload reuse is rejected.

Update the diagnostic test that currently characterizes the 30-second timeout to assert the chosen 20-second policy when the implementation changes. Convert diagnostic assertions into the intended regression behavior as fixes land.

### Windows/manual release checks

- Real reboot, then first launch on a representative client POS with its catalog size and storage type.
- Slow/offline network, large catalog, missing/corrupt required storage and Sentry unavailable.
- Repeated double-click, launch while loading, minimized instance, second supported installation path and close during startup.
- Backend success arriving before and after the deadline; app killed/reopened after the server commits but before the response is received.
- Confirm & Print failure still displays the sale as confirmed and offers print recovery.

### Delivery order

1. Immediate native/Flutter startup feedback, safe lifecycle handling and timing instrumentation.
2. Shared supermarket submission states, durable uncertain-order recovery, correct messages and 20-second deadline as one coordinated change.
3. Backend lookup/idempotency verification or implementation; enable safe status checks/retry only after contract tests pass.
4. Optimize the measured bottleneck, then pilot on an affected client before broad release.

The rollout gate is not “no analyzer errors.” It is visible startup on affected hardware, prompt acknowledgment of Confirm, preserved sales across uncertainty/reboot, and no duplicate order creation during supported retry scenarios.

## Technical reference

[`Future.timeout`](https://api.dart.dev/dart-async/Future/timeout.html) creates a bounded wait; the underlying operation can still complete later. Both the startup retry design and checkout recovery must account for this. See the companion `startup-billing-diagnostic-report-2026-09-09.md` for source locations and executed diagnostic results.
