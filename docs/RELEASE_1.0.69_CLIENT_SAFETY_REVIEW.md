# Client-Safety Review — Releases 1.0.68+78 → 1.0.69+79

**Reviewed:** 2026-09-10
**Branch:** `hotfix/urgent-fix`
**Commits under review:**

| Commit | Title | Size |
|---|---|---|
| `36cd26ab` | chore(release): bump version to 1.0.68+78 and update release documentation | 33 files, +2955 / −260 |
| `927ca83d` | chore(release): bump version to 1.0.69+79 and implement CloudPOS restart functionality | 14 files, +330 / −8 |
| `c1fa0fa5` | feat: update startup window dimensions and enhance UI elements | 4 files, +17 / −9 |

**Question asked:** is this safe to ship to existing clients running older builds?

---

## Verdict

**Not a safe drop-in as-is.** The design intent is sound — durable-before-send order recovery, no automatic resend, no assumed backend idempotency — and there is no API or Hive schema change, so no backend work or data migration is required. But four issues should be fixed before these builds reach production tills, and a fifth (the new Windows restart helper) has a data-loss path that is most likely to trigger in exactly the situation it was written for.

Two of the three commits are labelled `chore(release): bump version` while shipping substantial behaviour change. See [Commit hygiene](#commit-hygiene).

---

## Blockers

### 1. New required Hive box has no recovery path — can make the till unstartable

**Where:** `lib/main.dart:242`

```dart
await _requiredStartupStep('open order recovery storage', () async {
  await Hive.openBox('order_submissions');
});
```

Every other required box goes through `_openBoxWithRecovery`, which provides a lock-conflict retry loop, a size-scaled timeout budget, and optional recreate-on-corruption. This one uses a bare `Hive.openBox` with the 10-second default timeout and none of that.

**Why it matters:** the comments in `_openBoxWithRecovery` document `errno = 33` (lock violation) and `errno = 32` (sharing violation) as *observed in production on Windows*. If this new file is locked by a shutting-down copy, or is corrupted, the app now dies on the startup failure screen. A client whose till previously opened fine cannot bill at all — and the box holds only recovery metadata, nothing worth failing a sale over.

**Fix:** route it through `_openBoxWithRecovery(..., recreateIfUnreadable: true)`, or move it to `_optionalBoxNames`.

---

### 2. The entire app is made inert during every order submission

**Where:** `lib/components/order_submission_status.dart:59`

```dart
ExcludeFocus(
  excluding: coordinator.isBusy,
  child: AbsorbPointer(absorbing: coordinator.isBusy, child: widget.child))
```

This wraps `MaterialApp.builder`, so it covers the whole widget tree.

**Why it matters:** for up to the 20-second submission timeout, the entire UI stops accepting pointer input *and* `ExcludeFocus` detaches focus from every field in the app. On a counter with a barcode scanner — which types into a focused text field — focus is dropped mid-sale and is not guaranteed to return when the submission completes. Double-submit protection is worth having; app-wide input lockout is a larger change than the problem requires.

**Fix:** scope the guard to the billing action (disable the confirm button, or that screen), not the whole app.

---

### 3. Stock reservations can leak permanently

**Where:** `lib/providers/local_product_provider.dart:4033`

```dart
if (isStockEnabled &&
    !OrderSubmissionCoordinator.instance.isCartAwaitingReview(_cartSessionId)) {
  // ... restore reservations
}
```

`clearCart()` now skips restoring reservations when the cart has a `pending` (unknown-outcome) submission. That is correct when the order really did commit server-side.

**Why it matters:** when the order was *never* created, the stock stays deducted forever. Neither `removeReviewLog` nor `markReviewed` restores it. Clients running stock management will drift downward by one sale on every checkout timeout, with no way to correct it from the app.

**Fix:** add a stock-release path to the Orders-to-review screen, taken when the cashier confirms the order does not exist in the admin panel.

---

### 4. `uuid` is used but not declared

**Where:** `lib/providers/local_product_provider.dart:5` imports `package:uuid/uuid.dart`, but `pubspec.lock` records `uuid: dependency: transitive` and `pubspec.yaml` does not list it.

**Why it matters:** it compiles today only because another package happens to pull it in. Any dependency bump that drops it breaks the build with no warning. `crypto` was correctly added to `pubspec.yaml` in the same commit; `uuid` was missed.

**Fix:** add `uuid: ^4.x` to `pubspec.yaml` alongside `crypto`.

---

### 5. Restart helper can hard-kill the app mid-Hive-write

**Where:** `windows/runner/app_restart.cpp` — `kGraceMs = 4000`, then `TerminateProcess`

The process-identification logic is genuinely careful and is **not** the concern: the helper pins the parent by handle, creation time, image path, and session — never by process name — holds a `Local\` mutex against concurrent restarts, and runs before the single-instance gate so the mutex is released first. That part is well built.

The concern is the shutdown sequence. `main.dart` documents that a startup timeout **does not cancel the work behind it**:

- `await _initializeApp().timeout(_startupBudget)` — box opens keep running
- `localProducts.hydrated.timeout(...)` — hydration keeps running (see the comment at `lib/main.dart:174`)

So when the failure screen appears *because something timed out*, Hive is very likely still writing when the cashier presses **Restart CloudPOS**. Four seconds later the process is terminated hard.

If a torn write lands in `cart_items`, `saved_orders`, or `confirmed_orders` — the three boxes deliberately opened with `recreateIfUnreadable: false` at `lib/main.dart:448` because they hold unsynced sales — the box becomes unreadable and the till is **permanently unstartable**. That is the exact state the restart button exists to escape.

**Fix (either):**

- have Dart close Hive cleanly before invoking the restart method channel, or
- raise `kGraceMs` well past the worst-case Hive open budget.

---

## Lower-risk observations

### `Utf8FromUtf16` fix silently re-arms `--allow-multiple-instances`

`windows/runner/utils.cpp:66` now trims the trailing NUL that `WideCharToMultiByte` includes when the length argument is `-1`. The fix is correct and the old behaviour was a real latent bug.

Side effect: `HasFlag` compares `argument == flag`, so with the embedded NUL the flag **never matched** and the single-instance guard was unconditional. It now works as designed. The code's own comment says a second copy pointing at the same Hive directory "can corrupt the boxes outright". In practice no client shortcut carries a flag that never did anything — but this is a behaviour change shipped inside a fix, and worth knowing.

### Diagnostics were stripped in the same commit that rewrote checkout

- All `debugPrint` of order payload and response removed from `cart_provider` and `billing_page`
- `catch (error) {}` at `billing_page.dart:6915` silently swallows receipt-print failures
- `BillingMobileErrorMessages.checkoutException(...)` replaced with a generic string in `checkout_service`

This removes exactly the field-diagnosis trail you want in the first week after shipping a checkout change.

### Success path can no-op on unmount

`if (!context.mounted) return;` / `if (!mounted) return;` now guards the `.then` callback in all three checkout callers. On a genuine success with a disposed widget the order exists server-side, but the cart is not cleared, the draft is not deleted, and nothing prints. The Orders-to-review banner is the safety net — the cashier has to notice it.

### Second-instance launch is now visible

Launching CloudPOS while it is already starting blocks for up to 3 seconds (30 × 100 ms retry loop) and can show a modal `MessageBox`, where it previously exited silently. Every client who double-clicks the icon twice will see this.

### No automated coverage for the C++ helper

The two new Dart tests cover the restart button well (launch-once, launch-failure). The 175 lines of native code that enumerate and terminate processes have no test coverage and were not built or executed during this review — the assessment above is from code reading only.

---

## What checked out fine

- **No API contract change.** The request body is byte-identical. `protectSubmission` only routes through the new coordinator; non-supermarket order flows keep the old path. **No backend change is required for old clients.**
- **No Hive schema change.** No new type adapters; the recovery box stores plain maps.
- **Hive round-trip typing is safe.** Verified empirically: nested maps come back from Hive as `Map<dynamic, dynamic>`, not `Map<String, dynamic>`. Every consumer uses `Map.from`, `as Map`, or `jsonEncode`, all of which tolerate that. Worth noting the test suite would *not* have caught a bug here — `MemorySubmissionStore` round-trips through JSON, which produces `Map<String, dynamic>` and hides the difference.
- **Upgrade path for an in-flight cart is sound.** A pre-upgrade cart falls back to the `'legacy'` session id and moves to a UUID on the next clear.
- **New UI copy is fully translated** for both supported locales (`en`, `ar`) via `lib/resources/recovery_text.dart`. The app supports only those two, so coverage is complete.
- **`c1fa0fa5` is cosmetic and safe.** Splash height 240 → 300 dp, icon drawn via `DrawIconEx` from the regenerated 256 px `app_icon.ico`, Flutter screen swaps the storefront glyph for `assets/logo/cloudpos-icon.png`. Asset confirmed present (134 KB) and `assets/logo/` is declared in `pubspec.yaml`, so the failure screen will not render a broken image.

---

## Verification performed

Run against `c1fa0fa5` (HEAD).

```bash
flutter analyze --no-pub lib/main.dart lib/components/startup_gate.dart lib/components/order_submission_status.dart lib/services/order_submission_coordinator.dart
```

**0 errors, 0 warnings.** Four `withOpacity` deprecation infos in `main.dart` only.

```bash
flutter test --no-pub
```

**964 passed, 1 failed.** The failure is `test/receipt_configuration_workspace_test.dart` looking for the string `"Receipt Setup & Live Preview"`, which exists nowhere in `lib/`. Stale since commit `44301095`, **unrelated** to any of the three commits reviewed here.

```bash
flutter test --no-pub test/startup_gate_test.dart
```

**4/4 pass**, including both new restart tests.

Also run: a throwaway probe test writing a record through `HiveSubmissionStore`, closing and reopening the box, and asserting the consuming casts in `order_submission_status.dart` survive the round trip. Passed; probe deleted afterwards.

**Not verified:** the Windows runner was not built or executed. The splash window, single-instance changes, and restart helper are assessed from code reading only.

---

## Commit hygiene

`36cd26ab` and `927ca83d` are both titled `chore(release): bump version …`. Between them they ship:

- a rewritten Flutter startup path (`StartupGate`, staged initialization)
- a new durable checkout submission layer (`OrderSubmissionCoordinator`)
- an app-wide input guard
- a native Windows splash window
- changes to single-instance detection
- a native helper that enumerates and terminates processes

For a hotfix branch going to existing clients, this makes it impossible to revert the risky part without also reverting the version bump and the docs. If one client hits a problem in the field, there is no clean escape hatch.

**Recommendation:** for the remaining work on this branch, keep version bumps in their own commit and give behaviour changes titles that describe them.

---

## Suggested order of work

1. Add `uuid` to `pubspec.yaml` — one line, removes a latent build break.
2. Route `order_submissions` through `_openBoxWithRecovery` — removes a new single point of startup failure.
3. Raise `kGraceMs`, or close Hive from Dart before restarting — removes the corruption path in the recovery feature.
4. Narrow the `AbsorbPointer` / `ExcludeFocus` guard to the billing action.
5. Add a stock-release path to the Orders-to-review screen.
6. Restore enough logging around checkout to diagnose field reports.
