# Client safety implementation and verification plan

Revised 2026-09-10 after checking the proposed fixes against current code.

## Required behavior

Show startup immediately. Retain uncertain sales across restarts. Allow explicit
retry after the 20-second response deadline. Keep records under Sales without a
permanent banner, with the white background and existing success snackbar.
Recovery must not automatically resend orders, cancel orders or add stock
speculatively. Preserve confirmed-cart protection.

## 1. Dependencies

Declare the already resolved uuid 4.5.1 directly. Preserve unrelated resolutions.
Verify dependency resolution and analyze affected sources.

## 2. Recovery storage

Use the existing size-based open budget and Windows lock retry for
order_submissions. Keep it required and do not delete/recreate it automatically:
it contains uncertain sales and the active cart identity. Preserve unreadable data
and show the actionable startup failure screen. Persistent locks and timeouts can
still fail. Test released locks, exhausted retries and unreadable-data preservation.

## 3. Restart lifecycle

Track source futures behind startup deadlines, including individual box opens and
hydration. Stop scheduling new initialization steps when shutdown begins. Await
tracked work, flush local persistence and close Hive before normal teardown.

The helper must verify/pin the original process before requesting shutdown. Do
not exit Dart immediately after merely launching the helper. Send a dedicated
shutdown request to matching application windows so responsive copies can drain
storage before their engines close. A bounded forced fallback cannot promise data
safety: require an explicit recovery decision instead of calling a longer delay safe.

Test delayed source work, failed shutdown, helper launch failure, delayed helper
startup and matching/mismatching executable paths. Verify actual Windows restart
through Marionette. Do not launch a replacement before matching processes exit.

## 4. Checkout input and lifecycle

Remove the global focus/pointer lock; retain global scope selection. Protect cart
mutation and duplicate checkout actions locally, covering desktop/mobile, scanner,
shortcuts, payment dialogs and pointer input. Preserve focus.
Navigation must not discard completion work: retain the billing page during the
submission or move durable completion outside its widget lifecycle. Protect by
captured cart/store identity so a completed request cannot clear a newer sale.
Keep receipt recovery available if printing cannot complete. Test busy-to-idle
focus, unrelated UI input, navigation, late success and explicit timeout retries.

## 5. Stock reconciliation

Replace additive release with an explicit server stock refresh after manual
verification. Adding quantities then deleting a separate Hive record is not atomic
and can double-credit stock after a crash. Unawaited reservation saving can lose
information before a cart is cleared.

Read authoritative server quantities and apply them using the existing catalog
path that subtracts current active-cart reservations. Repeated refresh must converge
to server quantities, not add quantities repeatedly. Coordinate with existing sync
and tenant/store scope. Fetch/persistence failures retain the review record and
show an error. Refresh does not verify whether an order exists. Remove review log
remains a separate confirmed action and never cancels orders or changes stock.

Test legacy records, multiple attempts per cart, active reservations, repeat
refresh, scope changes, late responses and fetch/persistence failures. Translate
UI text and verify with Marionette.

## 6. Diagnostics

Log checkout timing, outcome, HTTP status and exception type. Restore printing
failure diagnostics without raw payloads, responses, credentials, customer data
or exception text that can contain those values. Preserve friendly cashier text.

## Verification and release

Run focused failure tests, relevant persistence/checkout/startup/UI tests, analysis
and the full suite. Investigate failures instead of expecting a fixed pass count.
Build Windows and use Marionette on isolated QA storage for failure, retry,
navigation, review, stock refresh and restart. Fault injection stays outside the
production entrypoint. Record commands, results and limits in verification notes.
Do not equate simulated failures with reproduction on client PCs. Keep any release
bump separate; distribution to clients is a subsequent step.
