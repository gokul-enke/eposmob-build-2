# E14 — Stock and product barcode views

## Status

Needs follow-up. Stock and product-barcode list views were inspected safely, but stock adjustments, barcode creation/editing, selection, printing, and duplicate-validation paths were not performed without an approved fixture.

## Recording

- Approved MP4: C:/Users/jim/.screencast-mcp/recordings/14-stock-and-barcodes-approved.mp4
- Duration: 29.0 seconds
- Resolution: 2560x1440
- Frame rate: 9.075 fps
- Codec: H.264 video, no audio
- Capture: Screencast MCP, CLOUDPOS application window
- Sanitization: profile and stock/product data regions are blacked out in the approved copy; raw media remains local and unshared.

## Coverage

- Opened Product > Stock and inspected the stock-list layout, filters, rows, quantities, dates, and row actions without selecting or changing a record.
- Opened Product > Product Barcode and inspected barcode filters, selection controls, list rows, barcode/quantity fields, pagination, and row actions without selecting, printing, or changing a record.
- Verified that navigation between the two read-only surfaces completed without intentional business-data mutation.

## Expected and actual result

- Expected: stock and barcode information is discoverable and read-only navigation does not mutate business data.
- Actual: both pages loaded and exposed their expected list/filter/pagination controls. Mutation and print workflows remain pending.

## Runtime errors

No new episode-specific Flutter runtime error was observed. The existing DTD log still contains the previously recorded P2 user-switcher ListTile assertion.

## Follow-up

Use a disposable product/stock fixture to test stock adjustment, transfer, withdrawal, barcode uniqueness, multi-select, barcode-layout preview, printer handoff, and rollback.
