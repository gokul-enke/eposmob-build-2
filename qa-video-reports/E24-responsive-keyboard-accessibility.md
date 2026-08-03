# E24 — Responsive, keyboard, and accessibility checks

Status: Needs follow-up

## Scope

Read-only checks of the compact desktop layout, visible focus/keyboard affordances, semantic discoverability, no-match search recovery, and the empty saved-order state. No order, payment, stock, customer, or master-data mutation was performed.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\24-responsive-keyboard-accessibility-approved.mp4`
- Raw source and intermediate crops: retained locally and not shared
- Capture: CLOUDPOS application window only; cropped final 1870×1170; H.264; no audio
- Duration: 47.2 seconds
- Sanitization: profile/sidebar account area and the right-side product/order panel were redacted; navigation, labels, focus rings, layout, and empty-state structure remain visible
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E24-responsive-keyboard-accessibility-approved-final\`

## Steps and observations

1. Inspected the compact layout after resizing the app window before recording. The sidebar remains navigable, the billing workspace remains usable, and table headers visibly truncate at the smaller size rather than overflowing the app window.
2. Entered the safe no-match query `QA-ACCESSIBILITY-NOMATCH` in product search, observed no suggestion/result, and cleared it.
3. Used the visible F1 shortcut through the active app window. Focus moved to the Barcode field without changing business data. Tab keystrokes were sent afterward as a focus-order smoke check.
4. Verified semantic inspection exposes the main `TextFormField` controls and labels for Barcode, Search product, Quantity, Unit Price, Add Item, Clear Cart, Save Order, Confirm and Print, and Confirm Order. The saved-order empty state remained visible.

## Expected / actual

- Expected: the compact view stays usable, controls have discoverable labels/shortcuts, focus can move without committing data, and empty states remain understandable. Actual: layout stayed usable with truncated table labels, F1 focused Barcode, semantic labels were available, no-match search recovered cleanly, and the empty saved-order state was preserved.

## Edge-case / blocker

Full mobile/portrait coverage, screen-reader announcements, contrast auditing, and exhaustive keyboard traversal need a mobile/assistive-technology fixture or a separate build. They were not simulated through the live desktop store.

## Runtime errors

Final post-recording inspection reported no Flutter runtime errors. An earlier discarded take generated one Marionette service-extension exception because a text matcher could not find the Search product hint; it was a test-harness lookup error, not an app-code failure, and was cleared before the final take.

## Result

The safe desktop responsive, keyboard-affordance, semantic-label, and empty-state checks are captured. Mobile/portrait and assistive-technology follow-up remains required.
