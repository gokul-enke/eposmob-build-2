# E23 — Negative validation and recovery

Status: Needs follow-up

## Scope

Safe, read-only negative checks for empty-cart confirmation and guaranteed no-match customer/product searches. No login attempt, payment, stock change, customer selection, sale confirmation, save, or other business-data mutation was performed.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\23-negative-validation-recovery-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 124.5 seconds
- Sanitization: sidebar/profile, customer-list/modal content, Home product/order panel, and search/query areas were redacted; flow labels and validation states remain visible
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E23-negative-validation-recovery-approved\`

## Steps and observations

1. From the empty billing workspace, selected Confirm Order. The app opened the Finalize Order customer-selection flow rather than committing an order; Confirm and Confirm & Print were disabled while the order summary was zeroed.
2. Entered the guaranteed no-match customer query `QA-NONEXISTENT-999`. The customer flow displayed “No customers found”. The modal was closed without selecting a customer.
3. Entered the same guaranteed no-match query in the Home product search. No product suggestion/result appeared; the field was cleared.
4. Verified the app returned to the Home billing workspace. No financial or master data was created or changed.

## Expected / actual

- Expected: invalid or empty inputs remain recoverable and do not commit data. Actual: the empty-cart confirmation routed to a guarded Finalize Order flow; no-match customer feedback was shown; no-match product search remained empty; clearing the input restored the workspace.

## Edge-case coverage still blocked

Failed login, invalid payment, insufficient stock, timeout/retry, and network recovery need disposable fixtures or controlled service faults. These were not simulated against the live store.

## Runtime errors

Runtime buffer was cleared before the episode. After the recorded actions, Marionette/Dart runtime inspection reported no Flutter runtime errors.

## Result

Safe validation and recovery behavior is captured and verified. The episode remains Needs follow-up until controlled authentication, payment, inventory, and network-failure fixtures are available.
