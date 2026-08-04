# E15 — Customers, profiles, and credit context

## Status

Needs follow-up. The approved take covers the Customers master list and its visible filters, row fields, type badges, actions, and pagination. Customer create/edit/delete, profile details, credit-limit changes, and transaction drill-down were not performed without an approved customer fixture.

## Recording

- Approved MP4: C:/Users/jim/.screencast-mcp/recordings/15-customers-profiles-credit-approved.mp4
- Duration: 10.5 seconds
- Resolution: 2560x1440
- Frame rate: 9.524 fps
- Codec: H.264 video, no audio
- Capture: Screencast MCP, CLOUDPOS application window
- Sanitization: profile and all customer-table content are blacked out in the approved copy; raw media remains local and unshared.

## Coverage

- Opened Customers from the side menu.
- Inspected the Customers page heading, customer search/filter area, add/customer action entry point, list columns, customer type indicator, row action controls, and pagination.
- Confirmed that no customer was opened, created, edited, deleted, or assigned credit.

## Expected and actual result

- Expected: customer records and their relevant account context are discoverable, with non-destructive list navigation.
- Actual: the Customers list loaded with visible controls and pagination. Sensitive customer values were removed from the approved media.

## Runtime errors

No new episode-specific Flutter runtime error was observed. The existing DTD log still contains the previously recorded P2 user-switcher ListTile assertion.

## Follow-up

Provide a disposable customer fixture to test create/edit/delete, duplicate phone/email validation, profile details, credit limit and outstanding balance, customer transactions, search/reset, pagination, and permission restrictions.
