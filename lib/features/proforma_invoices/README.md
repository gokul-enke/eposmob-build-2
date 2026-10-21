# Proforma Invoices

Owns listing inputs, API pagination, rendering and Excel export. The legacy route delegates to the feature page and preserves its constructor, test keys and mobile breakpoint helpers.

- Domain: immutable query and existing defensive map/text/integer conversions.
- Data: existing QuotationsProvider adapter, validated API pages and independent complete export snapshot.
- Controller: inputs, debounce, latest-request publication, error retention, reset, refresh, page selection and frozen export filters.
- Presentation: existing shared list scaffold/filter panel/table/cards, labels and workbook columns.

Details View is also owned by this feature: `ProformaDetailsRepository` delegates to the existing provider, `ProformaRowActions` handles navigation and error feedback with a mounted check after the request, and the passive `ProformaDetailsDialog` renders the existing response fields and item table. The legacy row-actions path remains a compatibility export. The shared provider, API contract, UI, fallback text and request behavior are unchanged. This list has no separate Create action.

Validation: existing Proforma widget tests cover responsive layouts, filters, pagination, failed and stale loads, export IDs/totals/numeric cells and View. Controller tests cover full user sequences, request races, error retry, export input changes and disposal. Details tests cover authentication/ID forwarding, fields and decimal quantities, close/reopen, malformed and missing data, failed requests and recovery, disposal, scrolling many items, desktop/tablet/phone layouts and en/ar/ml labels. The same details tests were checked against the legacy implementation; temporary visual comparisons also matched at 1440x900, 800x900 and 390x800.

Live demo validation after a successful terminal hot restart covered three existing invoices: different pending/order-created records, matching invoice/customer/quotation/date/amount fields, item quantities and amounts, item scrolling and both Close controls. A record with a missing customer name retained the list's fallback. No records were created or changed. Additional desktop interaction stopped when the desktop was locked.

For manual review, check View on different rows, response fields/items and both Close controls. This list has no Create action. Native file delivery is outside this details refactor.

Existing shared-dialog limitation (also reproduced against the legacy implementation): a short viewport such as 375x300 throws non-normalized height constraints because `CommonDetailsDialog` sets minimum height 480 and maximum height to 85% of the screen. This architecture extraction leaves the shared UI unchanged.
