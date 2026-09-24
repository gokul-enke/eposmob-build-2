# CloudPOS startup and supermarket checkout verification

Baseline: 1.0.67+77. Implementation remains uncommitted; no version bump, installer publication or client deployment was performed.

## Startup failure: Restart CloudPOS

The Windows startup failure screen now offers **Restart CloudPOS**. A native helper verifies the requesting process's executable path, Windows session and creation time, then closes matching CloudPOS processes from the same installation/session. It requests normal window closure, allows four seconds for shutdown, and force-stops verified processes that remain. It waits for process exit before launching one replacement. It does not delete local data or kill processes based only on their name. Helper errors explain how to reopen manually. Other platforms keep the existing Close action.

Runtime verification used two real QA app processes (9392 and 6496) with the same executable and isolated demo storage. The second failed startup after a genuine products.lock conflict. Marionette clicked the actual restart button. Both old processes exited; a fresh process (19932) had a CLOUDPOS window and Responding=true. A dummy cloudpos.exe under a different path (20516) remained alive and was then explicitly cleaned up. No server orders were created in this test.

The Windows debug build passed. Four startup widget tests passed, including one restart per click sequence and a launch error retaining Close/retry controls. The test also found and fixed the existing UTF-16 conversion retaining its null terminator, which prevented runner command-line flags from matching; the real multi-instance and restart-helper paths now executed successfully. A startup error caused by damaged data or missing dependencies can still recur after restart; this action addresses process state, not data repair. Release packaging/deployment are still pending.

The helper waits after forced termination because that Windows operation is asynchronous ([Microsoft documentation](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess)).

## Latest behavior: explicit retries and manual reconciliation

At the user's request, an uncertain result no longer blocks the cashier from pressing Confirm again. Each explicit retry creates its own durable attempt record. The 20-second response deadline and active-request click guard remain. Known confirmed sales still require recovery/cleanup rather than being submitted again. No automatic retry or backend duplicate protection was added.

The snackbar now says confirmation was not received and that retry is available; it points to Sales → Orders to review. The review page explains possible duplicates and manual comparison with the admin panel. **Remove review log** requires confirmation and removes only the local record, leaving server orders and the cart untouched. Storage changes serialize deletion with late responses so a removed log cannot be recreated by an outstanding response.

Verification: 17 coordinator, recovery UI, and request-timing tests passed. Coverage includes same-cart retry after timeout, retry after restart, independent attempt IDs, active-click protection, late responses during retry, removal persistence, deletion failure and scope checks, and English/RTL Arabic removal confirmation and cancellation. The updated Windows app was hot-reloaded and the removal dialog visually checked; the retained demo log was kept. No server order was created or cancelled during this follow-up. Earlier blocking behavior described below is historical and superseded.

## Latest follow-up: review UI and billing feedback

The review page now uses the app's blue accents, neutral surfaces, status labels, item counts, formatted currency totals, and separate action rows. The details dialog shows saved items with quantity and unit price; support data stays collapsed. The new-sale and finish-order dialogs use the same layout. Empty, narrow English, and RTL Arabic states are covered.

Removed **View orders** from this page and removed the global bottom-right submission notification entirely, superseding the brief notification described below. Billing keeps its existing loading button and snackbar. The root wrapper still protects the cart during an active submission; unresolved records and new-sale safeguards remain intact.

Verification: 11 focused coordinator/UI tests passed; analysis of the changed component and recovery translations reported no issues. Hot-reloaded the Windows app and visually checked the review page, item-details dialog, and new-sale confirmation dialog. No additional server order was created for these UI checks. Release packaging and deployment remain pending.

## Follow-up: Sales → Orders to review

The permanent top banner and store-wide checkout block described in the original verification below have been replaced following user feedback. Desktop and mobile Sales menus now include **Orders to review**. Feedback floats briefly at the bottom, has a dismiss button, and does not reserve space above the app.

Each cart has a durable sale identity. An unresolved attempt blocks only that same sale; a fresh cart can be submitted even with identical items. The review page retains earlier attempts, provides **Start new sale**, and keeps late responses associated with their original sale. Starting a new sale preserves the unknown attempt's stock reservation. Dismissing a notification does not delete its recovery record.

The updated automated run passed **89 tests**, covering cart-identity persistence, legacy recovery records, independent new sales, duplicate prevention after restart, late results during a newer submission, dismissible narrow English/Arabic feedback, and existing billing/Hive lifecycle behavior. The release-build evidence below belongs to the earlier revision; rebuild a release before distributing this follow-up.

Backend lookup/idempotency is still needed to automatically resolve an old uncertain attempt, but it no longer prevents billing other customers.

Live Windows verification of this follow-up retained the interrupted SAR 3 attempt on the review page, opened an empty cart using **Start new sale**, and successfully submitted a new SAR 3 KitKat sale with the same items. The new request returned HTTP 201 in 614 ms; the submission operation completed in 726 ms. The earlier attempt remained available for review. No permanent top banner appeared on store selection or billing.

The final focused coordinator/UI run passed 11 tests (overlapping the regression run). After fixing an overlay-dependent notification tooltip, both English/Arabic UI tests also passed with the notification mounted in the actual MaterialApp builder position. The updated Windows debug app was built and exercised; the follow-up has not been packaged or deployed to clients.

## Original verification (before the sidebar follow-up)

## Implemented behavior

- Windows displays a native startup window before creating the Flutter engine. Its own UI thread keeps that window responsive during engine/plugin initialization. A second launch shows the existing ready window and requests foreground focus, then exits; an unreachable instance produces an explanation.
- Flutter paints a startup screen before Sentry, storage and product hydration. Initialization stages and errors are visible. Required storage must succeed before the billing providers are mounted. A timed-out initialization cannot later replace the failure screen.
- Supermarket desktop/mobile Confirm and Confirm & Print share a durable submission coordinator. Other order workflows retain their existing request contract.
- A normal response completes immediately. After five seconds the text changes to “Still confirming…”. After 20 seconds without confirmation, the result becomes unknown and the ordinary spinner stops. This is a maximum wait, not a forced delay.
- A minimal tenant/store-scoped record is flushed before the POST. Unknown results survive reopening. A repeated confirmation cannot POST again while the earlier attempt is unresolved. A late successful response updates that attempt without automatically clearing whichever cart is open.
- Confirmed recovery checks the original items and saved-draft identity, then asks the operator before clearing a matching cart. It will not delete a different saved draft. Cleanup is acknowledged only after local persistence completes.
- Recovery offers the server Orders List and a readable saved-attempt summary. Technical details are expandable. Startup and submission status have built-in English/Arabic copy, including at narrow widths.
- Checkout diagnostics on the changed add-order path contain timings and result categories rather than credentials or full sale payloads.

## Executed verification

Runtime used `tool/qa_startup_checkout.dart` with separate `.tools/qa-data` storage and the user-authorized disposable demo tenant. Demo credentials are not part of source or this report. Marionette controlled the actual Windows Flutter UI.

| Scenario | Observed result |
| --- | --- |
| Normal real demo sale | HTTP 201 in 600 ms; complete submission operation in 890 ms. Cart cleared and recovery record acknowledged. |
| Deliberately delayed demo response | Ordinary wait ended at 20,094 ms with unknown-result text. HTTP 201 arrived at 25,515 ms; order ID 6046 became confirmed without another POST. Manual completion cleared the original cart. |
| Definitive validation rejection | Injected HTTP 422 returned in 1 ms; operation completed in 168 ms. Cart stayed present and no pending recovery record remained. The injected rejection was not sent to the demo server. |
| Repeated click during submission | An additional tap during the request did not increment the request counter. Automated tests also cover simultaneous submit calls. |
| Restart during an outstanding request | Recreated the Dart app before the delayed client sent the POST. The identical durable submission ID reappeared as unknown after login/store selection. The new process state reported zero order requests. No replay occurred. |
| Full process restart and another Confirm | Closed the QA executable, launched the rebuilt runner, signed in and confirmed the restored SAR 3 cart again. The same unresolved submission remained; the HTTP request counter stayed at zero. |
| Slow startup | With eight seconds deliberately added to the QA storage path, Marionette captured the visible “Still getting ready…” startup screen. App initialization then completed. |
| View orders | Opened the server Orders List and verified two confirmed SAR 3 demo sales, ORD-004504 and ORD-004505. This is the server sales screen, not the local offline-upload queue. |
| Native launch after process exit | A Win32 probe observed the native splash by 1,519 ms and the real Flutter window by 2,895 ms from the PowerShell launch call. These are upper bounds including launcher/probe overhead, on this development machine in debug mode. |
| Second Windows launch | After the native fix, a second process launched with a hidden-window flag exited and left the original Flutter window visible. Only one CloudPOS process remained. Foreground activation is requested; a background test launcher cannot guarantee Windows will allow it to steal focus. |

Automated verification:

- 14 startup, coordinator, recovery UI and request-timing tests passed after the recovery changes. This includes narrow English/Arabic layout, held input during submission, storage failure before POST, rejection vs. unknown outcomes, late success in another store, interrupted startup, and preserving other workflows.
- 90 selected existing lifecycle, Hive persistence, supermarket mobile UI, customer-history and subscription tests passed after the changes. Earlier regression runs also passed; these counts are overlapping, not additive unique coverage.
- The final Windows release build of `lib/main.dart`, including the native visibility fix, succeeded (`release_verified_build.log`, 224.3 seconds). Sentry reporting was disabled for the verification build with an empty `SENTRY_DSN`. The complete build directory is `build/windows/x64/runner/Release`; the executable requires its adjacent DLLs and data.

The native probe exposed an additional edge case: starting a second process with `SW_HIDE` could hide the existing window through its first `ShowWindow` call. The runner now explicitly shows the splash/ready window with `SetWindowPos`, and identifies a previously painted window even if it later becomes hidden. This is consistent with Microsoft's documented [first-call `ShowWindow` behavior](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow) and [`SWP_SHOWWINDOW`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos). It is a reproduced launcher edge case, not proof of the cause on every affected customer device.

The complete selected-file analyzer run reported no errors, but existing warnings/informational lints remain; it was not a clean repository-wide analysis.

## Limits before deployment

The demo API URL supplies access to a running service, not its backend source or an idempotency contract. No submission-ID lookup or atomic duplicate protection was verified. Consequently **automatic retry is disabled**. An unresolved attempt blocks another protected supermarket submission in that tenant/store until its outcome is reconciled; View Orders alone cannot safely prove that a missing order was never created. Backend work remains necessary for safe automatic status recovery and retry, and for a complete operator resolution flow after a permanently lost response.

The delayed-response tests inject client-side delay; they verify client behavior, not the cause of a customer's slow backend request. The observed 600 ms demo response does not establish production latency percentiles. Production server/database timing and a pilot on an affected POS are still needed.

No physical reboot of this computer, power-loss test, production tenant write, physical receipt printing test, or installer rollout was performed. Cold launch on an affected device with its actual catalog and storage remains a rollout check. The release build is not a signed/published installer.

QA files and logs are local and ignored. The test attempt left unresolved by the restart scenario is confined to the separate QA data directory. The two confirmed demo sales were intentionally left in the disposable tenant for review.
