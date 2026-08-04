# E12 - Categories

Status: Needs follow-up; read-only coverage completed.

## Purpose

Inspect category search, pagination, list structure, and the Add/Edit entry points without changing master data.

## Steps and results

1. Inspected the Marionette UI tree before interacting.
2. Opened Category from the side menu.
3. Verified Category List, search field, Reset, Add Category, category name/slug columns, and edit actions.
4. Used Next to move to page 2 and Previous to return to page 1.
5. Did not add, edit, disable, or delete a category.

Expected: category list/search/pagination are usable and mutation entry points are visible.

Actual: list and pagination worked; CRUD validation and permission behavior remain untested.

## Defects and blockers

- Follow-up: safe master-data fixture and approval are required for add/edit/disable/delete and duplicate/invalid-name validation.
- Existing runtime warning: the ListTile/DecoratedBox background/ink-splash assertion at lib/widgets/user_switcher.dart:464 remains present; no new category-specific runtime error was observed.

## Recording and media verification

- Raw recording: C:\Users\jim\.screencast-mcp\recordings\12-categories.mp4 (kept local; not shared).
- Approved recording: C:\Users\jim\.screencast-mcp\recordings\12-categories-approved.mp4.
- Target: app window CLOUDPOS; duration 63.5 seconds; 2560x1440; 9.953 fps; H.264; no audio.
- Approved media size: 753,512 bytes.
- Sample frames: C:\Users\jim\.screencast-mcp\frames\E12-categories-approved\.
- The user/profile area was covered in the approved copy before sharing.

## Sharing

Cloudflare link: Pending until the final allow-listed share directory and tunnel are created.
