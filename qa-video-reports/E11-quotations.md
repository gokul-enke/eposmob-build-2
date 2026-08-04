# E11 - Quotations

Status: Needs follow-up; read-only coverage completed.

## Purpose

Inspect quotation creation entry points, quotation filters/list layout, status display, and available view/convert/print actions.

## Steps and results

1. Inspected the Marionette UI tree before interacting.
2. Opened Quotations from the side menu.
3. Verified the empty quotation-entry workspace, product search fields, Add Item, Create Quotation, and Quotation List controls.
4. Opened Quotation List.
5. Verified quotation-number, customer, store, quotation-date, expiry-date, status, and action columns plus filters and New Quotation.
6. Did not create, convert, print, edit, or delete a quotation.

Expected: quotation creation and list entry points are visible and navigable without committing data.

Actual: both the creation workspace and list loaded. Existing list rows include customer and store data, so the approved video covers those table regions.

## Defects and blockers

- Follow-up: a safe non-production quotation fixture is required to test create/edit/save, expiry validation, conversion to order, duplicate conversion, print, and permission behavior.
- Existing runtime warning: the ListTile/DecoratedBox background/ink-splash assertion at lib/widgets/user_switcher.dart:464 remains present; no new quotation-specific runtime error was observed.

## Recording and media verification

- Raw recording: C:\Users\jim\.screencast-mcp\recordings\11-quotations.mp4 (kept local; not shared).
- Approved recording: C:\Users\jim\.screencast-mcp\recordings\11-quotations-final.mp4.
- Target: app window CLOUDPOS; duration 77.6 seconds; 2560x1440; 9.961 fps; H.264; no audio.
- Approved media size: 574,615 bytes.
- Sample frames: C:\Users\jim\.screencast-mcp\frames\E11-quotations-final\.
- The profile and quotation/order data regions were covered in the approved copy before sharing.

## Sharing

Cloudflare link: Pending until the final allow-listed share directory and tunnel are created.
