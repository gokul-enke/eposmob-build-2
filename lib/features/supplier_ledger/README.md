# Supplier Transactions

Owns Party Accounts > Supplier Transactions listing and View details. The legacy `TransactionScreen` route retains its constructor, export override, keys and page size, and delegates to the feature page.

- Domain: immutable query and server snapshot cache key.
- Data: compatibility adapter to the existing `TransactionProvider`, parser and validated export snapshot.
- Controller: input/focus lifecycle, debounce, local filtering, cache, pagination, reset/refresh, latest-request publication and frozen export query.
- Presentation: original shared filter panel, table/cards, labels and workbook columns.
- Details: `SupplierLedgerRowActions` opens a passive `SupplierLedgerDetailsDialog` for the selected list record. The old row-action path remains a compatibility export. View requires no provider, API call or additional controller.

The legacy provider still publishes server pages. This controller serializes those calls and copies the response into its own visible state; stale responses do not replace the current list. The existing local matching rules and 50-row page size are preserved. Export fetches a separate complete snapshot and does not replace the visible page. Failed loads disable export until a successful retry.

No provider, API contract, model, sidebar or common details dialog changes. Details keep the same field order, date/code labels, raw money precision and status, nullable/empty fallbacks, and close/dismiss behavior.

Validation: focused controller sequence/race/lifecycle tests, existing supplier list layout/filter/export tests and provider snapshot tests. Manually verify Search, supplier suggestion selection followed by editing, transaction type, type, status, Reset, pagination, Refresh, Export, reference copy and View. Live backend behavior and native Save As remain manual checks.

Details validation covers the legacy import, all fields, optional values, unknown codes, long comments, closing/reopening different records, English/Arabic/Malayalam layouts, desktop row/View and mobile View actions, and filter/page/provider state after returning. The original implementation passes these same behavior tests. Temporary before/after screenshot comparisons matched at desktop, tablet, phone and Arabic desktop sizes.

Known pre-existing P2: at a very short viewport (for example 375 x 300), shared `CommonDetailsDialog` sets a minimum height of 480 above its maximum of 85% of screen height, causing invalid constraints. Reproduced before and after extraction; the shared UI remains unchanged in this architecture-only change.
