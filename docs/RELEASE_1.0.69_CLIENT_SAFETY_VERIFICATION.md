# Client safety verification — 1.0.69 worktree

Date: 2026-09-10. This describes the revised fix plan and the current worktree;
no client installation or production deployment was performed.

## Changes

- Declared uuid 4.5.1 directly without changing the resolved version.
- Required order recovery storage uses the existing size budget and Windows lock
  retries. Nonrecoverable data is not deleted/recreated as disposable cache.
- Startup tracks source futures behind timeouts. Restart requests stop scheduling
  initialization, wait for tracked work and local persistence, and close Hive.
- The native helper pins its parent before requesting shutdown and asks each
  matching application window to prepare. Its initiating method stays pending so
  a failed/cancelled helper can restore controls. Failed preparation can be retried.
  After 30 seconds, forced closure requires a native warning with No as default.
  A fully active copy is not assumed safe to stop merely because Hive.close exists.
- Removed the root focus/pointer lock. Billing, barcode dispatch and user switching
  are guarded locally; focus is preserved. Sidebar navigation waits through the
  UI completion lease, including receipt handling, before disposing billing.
- Added translated Refresh stock action. It reads an authoritative catalog under
  the existing sync gate, checks store/tenant identity and reapplies current-cart
  reservations. It never adds a saved quantity repeatedly or deletes a review log.
  A malformed 200 response cannot be interpreted as an empty catalog.
- Restored safe release checkout lifecycle/printing diagnostics using failure
  types, HTTP outcomes and timing, without adding raw requests or customer data.
- Updated the pre-existing receipt test to expand the current disclosure UI.

## Automated evidence

- Full suite: 977 passing tests (`.tools/safety_full_final_tests.log`). An earlier
  run had 976 passes and the stale receipt workspace assertion; its updated test
  and the catalog error-envelope test also passed a focused rerun (5 tests).
- Added real Hive reopen tests for review records/cart identity and preservation
  of a nonrecoverable record. Hive 2.2.3 emits duplicate private-completer errors
  on failed opens; the corruption test explicitly observes those expected errors
  while still requiring the production call to fail and preserve the bytes.
- Added source-timeout/drain tests, local focus/input and deferred-navigation
  tests, stock refresh repeat/fetch-failure/store-change tests, and coordinator
  tests requiring retention of review logs after failed or repeated refresh.
- Earlier changed-source analysis had no errors. Three must-call-super warnings
  introduced by extracting guarded build methods were corrected. Existing unused
  code, deprecation and async-context diagnostics remain in older billing code.
- Windows QA debug build passed; final rebuild/static checks recorded below when
  complete. No test claims to prove safety under arbitrary forced process death.

## Marionette runtime evidence

Used `tool/qa_startup_checkout.dart`, with separate storage at
`.tools/qa-data/epos/hive_data`, and the user-authorized disposable demo tenant.
The QA target refuses non-demo order writes; it is not the release entrypoint.

1. Startup loaded 4,848 cached products and reached login in about 6.5 seconds.
2. Confirmed a SAR 3 test cart with QA mode `hold`. This suspends before forwarding
   the order POST, so that attempt could not create a server order. Confirm showed
   loading; selecting Dashboard kept billing mounted while submission was active.
3. At 20,010 ms, the attempt became unknown, the requested Dashboard opened, and
   the cart remained available for retry. No permanent banner appeared.
4. Switched QA mode to normal and explicitly retried the same sale. The server
   returned HTTP 201 in 640 ms (877 ms total coordinator duration). The successful
   cart cleared while the earlier unknown attempt remained reviewable.
5. Opened Orders to review, inspected the new stock dialog and refreshed twice.
   Success feedback retained the log. Removed only this test's held-attempt log
   through its confirmation dialog. After hot restart the three older QA records
   remained, the cart was empty and stock 499 read 103 (104 before the test sale).
6. Real native restart: held the QA products.lock from a separate process until
   two QA instances reached their genuine startup failure screens. Released the
   lock and clicked Restart CloudPOS with Marionette. Old PIDs 6236 and 15484
   exited, one replacement PID 9480 started, and the deliberately same-named
   executable at another path (PID 11744) remained alive. The test decoy was then
   cleaned up. SHA-256 comparisons of cart_items, saved_orders, confirmed_orders
   and order_submissions files were all unchanged after replacement.

## Limits

The original client PCs were not available. These are controlled reproductions
and regression checks, not proof of their original cause. Backend submission-ID
lookup/idempotency remains future work; explicit retries can still create duplicate
sales as the accepted manual workflow allows. Stock refresh is not order-status
verification. No physical receipt printer was used. Forced closure can still
interrupt data writes; it is an explicit fallback, never advertised as safe merely
because a timer elapsed.

## Final restart and regression follow-up

- Eight startup/storage tests passed after retry-preparation handling was added
  (`.tools/safety_final_startup_tests.log`). Twenty-one checkout/recovery/focus
  tests passed after extending the UI lease to cover validation as well as the
  request and receipt callback (`.tools/safety_final_checkout_tests.log`).
- Final focused analysis completed with zero errors and zero warnings; 44 existing
  informational diagnostics remain (`.tools/safety_completed_analysis.log`). The
  broader billing-file analysis retains pre-existing unused-code warnings.
- Latest Windows QA debug rebuild passed (`.tools/safety_windows_verified_build_2.log`).
- Through a debug-only Marionette extension, requested the same native restart
  channel from an already-ready QA copy (PID 18412). This exercises the explicit
  fallback: an active copy does not claim its independent work is drained.
  The native helper displayed the force-close warning after its grace period.
  Choosing No kept PID 18412 alive and returned PlatformException to the caller,
  allowing another attempt. Choosing Yes on a second attempt replaced it with
  PID 13480. Marionette reconnected and verified login UI, three review records,
  zero cart items, zero new order requests and stock 499 at 103. All four protected
  Hive file hashes were unchanged. The copy was idle during this force test;
  this is not a claim of crash-safe writes under forced termination.
- The warning is a native Windows dialog, outside the Flutter widget tree. Its
  title, owner PID and warning text were inspected through Win32, then its No/Yes
  actions were driven through that same API. The restart channel and replacement
  Flutter app were exercised through Marionette.

## Completed build checks

The production entrypoint `lib/main.dart` built successfully in Windows release
mode (`.tools/safety_windows_release_build.log`, 329.6 seconds). Output is the
complete `build/windows/x64/runner/Release` directory; the executable alone is not
an installer. The version remains 1.0.69+79; no release bump, commit, installer
publication or client deployment was performed. QA injection/extensions are only
in the separate debug QA entrypoint. The QA app was left running on Orders to
review for inspection. The original client-safety review document was retained.

The final code is in the working tree. Full-suite evidence is supplemented by the
final focused startup and checkout reruns for the last lifecycle adjustments.

## Working-tree review follow-up

The subsequent review correctly identified that the billing hardware handler
checked the checkout lease before checking whether a dialog owned the route.
That ordering is now reversed. KeyboardDispatcher pauses only its barcode-buffer
path while busy; focused dialog fields still receive printable characters. A
paused scan clears its partial buffer so it cannot spill into the next sale.
The redundant guard around the responsive billing shell was also removed; each
billing page retains its own guard and local loading state.

Three regression tests cover dialog text/Escape, receipt-prompt Enter/Escape,
and suppressed scans without replaying a partial prefix. The final focused run
passed all 34 tests across keyboard, guard, status, coordinator and responsive
routing (`.tools/review_followup_tests_final.log`). The first scanner-test run
stalled in asynchronous subscription cleanup; moving that cleanup to teardown
resolved it. The isolated scanner rerun and final combined run passed.

The billing/guard/dispatcher/test analyzer run reports zero errors, 10 existing
warnings in billing_page.dart and 57 informational diagnostics
(`.tools/review_followup_analysis.log`). This supersedes the pasted review's
warning-free claim for that broader file selection. These widget tests do not
replace native Windows keyboard or physical-printer testing; Marionette/native
tests and release-build evidence above predate this small keyboard follow-up.

The previously staged version changes to 1.0.81+81 / MSIX 1.0.81.81 and the
development tag example in Release.md were preserved and separated from the
behavior fixes. The local changes are split into dependency, recovery storage,
restart, billing, stock reconciliation, diagnostics, receipt-test, QA/documentation
and version commits. No push, tag creation, build publication or deployment was
performed by this follow-up. The earlier 1.0.69 build evidence is historical; it
does not certify a newly packaged 1.0.81 installer.
