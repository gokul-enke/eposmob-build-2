# Supplier Transactions List

Owns Party Accounts > Supplier Transactions listing only. The legacy `TransactionScreen` route retains its constructor, export override, keys and page size, and delegates to the feature page.

- Domain: immutable query and server snapshot cache key.
- Data: compatibility adapter to the existing `TransactionProvider`, parser and validated export snapshot.
- Controller: input/focus lifecycle, debounce, local filtering, cache, pagination, reset/refresh, latest-request publication and frozen export query.
- Presentation: original shared filter panel, table/cards, labels and workbook columns.

The legacy provider still publishes server pages. This controller serializes those calls and copies the response into its own visible state; stale responses do not replace the current list. The existing local matching rules and 50-row page size are preserved. Export fetches a separate complete snapshot and does not replace the visible page. Failed loads disable export until a successful retry.

No provider, API contract, model, sidebar or common details dialog changes. The details body is unchanged in a legacy row-action adapter; no inner-page behavior changes.

Validation: focused controller sequence/race/lifecycle tests, existing supplier list layout/filter/export tests and provider snapshot tests. Manually verify Search, supplier suggestion selection followed by editing, transaction type, type, status, Reset, pagination, Refresh, Export, reference copy and View. Live backend behavior and native Save As remain manual checks.
