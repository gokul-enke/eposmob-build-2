# CloudPOS startup and confirmation diagnosis

Analyzed checkout: `2c0b306f`, version `1.0.67+77`, on Windows with Flutter 3.44.8 / Dart 3.12.2. No production source was changed. Two diagnostic test files were added. No live tenant orders were submitted.

**Both reported symptoms are possible in the current code.** The startup mechanism is established by source inspection; the billing wait behavior is reproduced with controlled HTTP responses. This does not establish which mechanism occurred on the clients' machines. Their OS and logs are still needed to make that attribution.

The user confirmed **supermarket billing**, primarily **1.0.65+75**, with another report described as a "67 + 7" build. The latter is provisionally compared to the repository's **1.0.67+77**, pending the exact installed build string. The restaurant finding below is an additional project issue and does **not** explain the confirmed supermarket complaint.

## Version comparison relevant to these clients

Compared release commit `24f56942` (whose pubspec declares `1.0.65+75`) with current `2c0b306f` (`1.0.67+77`).

| Behavior | 1.0.65+75 | 1.0.67+77 |
| --- | --- | --- |
| Sentry before the first frame | Awaited without a timeout, outside the overall startup budget | Bounded to 10 seconds |
| Required Hive box fails to open | Records a warning and continues, even though provider field initializers require open boxes; can subsequently fail during provider construction | Stops normal startup and shows a storage failure screen |
| Hive open budget | Fixed eight seconds per open | Scales with size, capped at 90 seconds per open |
| Overall app-initialization allowance | 60 seconds, excluding unbounded Sentry initialization | 300 seconds, plus Sentry's allowance |
| Provider product hydration | Decodes the whole catalog synchronously | Decodes in chunks of 300 |
| Stock-related cart persistence | Can synchronously serialize the full catalog and then clear/rewrite the box | Persists changed products; full rewrites are chunked and upsert before pruning |
| Window shown before initialization completes | No | No |
| Supermarket POST timeout and desktop failure handling | 30 seconds; generic desktop failure message | Same code |

There is **no diff** between these releases in `cart_provider.dart`, `checkout_service.dart`, supermarket `billing_page.dart`, `subscription_action_guard.dart`, or the native single-instance runner. Therefore the claim that simply updating from 65 to 67 newly adds the 30-second order timeout would be incorrect: 65 already has it. Version 67 addresses substantial storage-related startup and UI work, but retains the hidden-startup design and the same supermarket API wait/error behavior.

The older full-catalog persistence is a plausible additional contributor to responsiveness with stock enabled; its actual cost on client data was not benchmarked. It should not be automatically blamed for a spinner that keeps animating while awaiting the POST. Runtime timing must distinguish main-isolate freezes from server waits.

## Findings

### 1. Windows can have a running process with no visible window during startup

- `windows/runner/flutter_window.cpp:30` shows the window only in Flutter's next-frame callback.
- `lib/main.dart:164` awaits Sentry initialization for up to 10 seconds, then `lib/main.dart:172` awaits the entire app initialization before `runApp` at line 188.
- That initialization opens eight Hive boxes sequentially and loads translations, preferences and other configuration. The per-box open allowance starts at eight seconds, grows with file size, and caps at 90 seconds. The overall initialization allowance is 300 seconds.
- Consequently, slow storage can leave the process invisible for tens of seconds or minutes. The configured async allowances total up to approximately 310 seconds including Sentry, rather than displaying immediate progress. These timers are not watchdogs capable of interrupting synchronous decoding or a native hang.
- A required storage failure now produces `StartupFailureApp`, but only after the failed step returns or times out. Carts and unsynced orders are protected from the cache recreation path.

The installed Hive 2.2.3 source confirms that normal boxes read the file into memory and synchronously decode frames (`FrameIoHelper.framesFromFile` and `StorageBackendVm.initialize`). Provider hydration is now chunked; the earlier Hive open still precedes the first frame. Reboot-related slow disk access or memory pressure are plausible aggravating conditions, not conditions reproduced in this investigation.

**Recommended change:** display a startup shell immediately, then initialize dependencies and show named progress/error states. Construct the billing providers only when their required boxes are ready. If native engine/plugin startup is also implicated, add a native startup indication. Record duration, failure and file size for each stage; do not simply increase timeouts.

The project's existing `future/HIVE_WINDOWS_STABILITY.md`, section 4.3, explicitly records this hidden-window issue as remaining work. Its historical production-lock findings are project documentation, not independently retrieved production telemetry in this investigation.

### 2. Order confirmation waits for the API response, up to 30 seconds

- Desktop supermarket billing starts its spinner at `lib/features/billing/presentation/pages/billing_page.dart:7051` and awaits `CartProvider.addToOrderAPI`.
- Mobile uses `lib/services/checkout_service.dart:123`, which awaits the same provider call.
- `lib/providers/cart_provider.dart:1031` performs the POST with the 30-second timeout declared at line 35. This timeout is already implemented in this checkout.
- A controlled response held for seven seconds kept the confirmation Future pending throughout those seven seconds. A stalled response returned the expected timeout after 30 simulated seconds.

For ordinary supermarket confirmation, customer refresh and cart-list refresh are launched in the background, and receipt printing is not part of the plain Confirm action. The previous subscription preflight refetch is also disabled by default. Therefore the current normal path does not justify attributing several seconds to those older behaviors.

**Recommended change:** measure tap-to-submit, POST duration, response parsing and UI reset separately in the release build, and correlate with backend request timing. Network/server response time remains unmeasured here; a timeout limits waiting but does not make a slow server faster.

### 3. Desktop hides the uncertain-order warning after a timeout

- The provider returns `timed_out: true` and a message explaining that the order may still have been created (`lib/providers/cart_provider.dart:1079`).
- Desktop replaces that message with `billing.order_failed` at `lib/features/billing/presentation/pages/billing_page.dart:7239`. Its exception handler at line 7244 also only logs the error.
- The test confirmed that a mocked successful response can arrive after the caller has already received the timeout. The provider does not reconcile that late success. There is no automatic retry in the tested call, but a cashier can manually submit again.

**Impact:** a generic failure can encourage rebilling an order that the server already saved. The code does not establish whether the backend already implements independent duplicate protection.

**Recommended change:** preserve the provider's timeout warning in desktop billing, retain the cart in an explicit uncertain state, and offer an order-status check. Add a stable submission identifier and backend-supported idempotency/reconciliation before allowing safe retry. Merely reducing the timeout increases ambiguous outcomes.

This is consistent with Dart's documented semantics: [`Future.timeout`](https://api.dart.dev/dart-async/Future/timeout.html) stops waiting; the original Future can finish later.

### 4. Restaurant saved-order confirmation can wait indefinitely after success

- In `lib/screens/billing/restaurant/widgets/order_panel.dart:8312`, a successful saved-order confirmation waits an additional 500 ms and then awaits `_fetchSavedOrders()`.
- `_fetchSavedOrders` calls `CartProvider.listSavedOrders`. Its GET at `lib/providers/cart_provider.dart:1502` has no application timeout.
- The confirmation loading state clears only afterwards, in `finally` at `order_panel.dart:8342`.
- A controlled test left that GET pending for two simulated minutes; it remained pending until the mocked server responded.

**Impact:** the sale can already be confirmed while the checkout operation still waits for an unrelated list refresh. This finding specifically applies to the restaurant saved/ongoing-order path; fresh counter confirmation has a different flow. Confirm-and-print additionally waits for printing.

**Recommended change:** complete checkout and clear its loading state after authoritative order success. Refresh the list separately with a bounded request, independent loading state and retry. A list-refresh failure must not turn a successful sale into a failed checkout.

### Additional Windows edge case: second launch can exit silently

`windows/runner/main.cpp:155` exits when the shared single-instance mutex already exists, even if `FocusRunningInstance()` finds no suitable window. The mutex name is shared across installations, but window matching at line 67 requires an identical executable path. Two installed copies at different paths, or a first process stalled before creating its window, can therefore make a second launch appear ineffective. This is source-confirmed conditional behavior, not reproduced on a client device.

Recommended follow-up: align mutex identity with supported installation behavior and handle failure to find/focus the existing instance visibly, with a bounded wait for window creation.

A process from before a full reboot is not the likely explanation for a stale mutex: Windows closes process handles on termination and destroys a mutex when its final handle closes, as documented by [Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createmutexw). A newly started or automatically restarted instance can still be slow or stuck.

## Execution results

| Check run in this investigation | Result |
| --- | --- |
| Existing order lifecycle, Hive persistence, mobile UI controller, offline buttons and payment-validation tests | 80 passed |
| New `test/billing_request_latency_test.dart` | 3 passed: seven-second wait, 30-second timeout with late success, unbounded saved-orders refresh |
| New `test/hive_startup_probe_test.dart` | 1 passed: generated, closed, reopened and hydrated 30,000 synthetic product rows using production adapters/provider |
| Selected production-file analysis | 0 errors, 13 warnings, 110 informational diagnostics |

The synthetic catalog was **38,862,234 bytes (about 37.1 MiB)**. Reopening its Hive box took **246 ms**; provider hydration took **513 ms** on this machine in a Flutter test process. It loaded all 30,000 products. These are diagnostic observations, not performance targets: the test had a warm OS file cache, simple product data, no client antivirus/disk constraints, no native app startup and no actual reboot. Thus it did not reproduce a local startup freeze and does not rule one out on client hardware.

The HTTP tests use a fake clock and a MockClient; their delays are injected scenarios, not measured production latency. The constructor's unrelated cart refresh is overridden in those request tests. Only Windows and browser targets were available; no Android device was connected. The complete GUI, production API and customer reboot conditions were not exercised.

## Reproduce

```powershell
flutter test --no-pub test/billing_request_latency_test.dart test/hive_startup_probe_test.dart --reporter expanded
flutter test --no-pub test/order_lifecycle_test.dart test/local_product_provider_hive_persistence_test.dart test/billing_mobile_ui_controller_test.dart test/billing_action_buttons_offline_test.dart test/billing_provider_validate_payment_test.dart --reporter expanded
flutter analyze --no-pub lib/main.dart lib/providers/cart_provider.dart lib/services/checkout_service.dart lib/features/billing/presentation/pages/billing_page.dart lib/features/billing/presentation/pages/billing_page_mobile.dart
```

For these supermarket clients, prioritize immediate startup feedback and correct handling of uncertain orders. Confirm that the newer affected installation is exactly 1.0.67+77. Obtain server/request timings before selecting a backend performance fix. The unbounded restaurant refresh should be tracked separately.
