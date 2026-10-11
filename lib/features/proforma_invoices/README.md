# Proforma Invoice List

Owns listing inputs, API pagination, rendering and Excel export. The legacy route delegates to the feature page and preserves its constructor, test keys and mobile breakpoint helpers.

- Domain: immutable query and existing defensive map/text/integer conversions.
- Data: existing QuotationsProvider adapter, validated API pages and independent complete export snapshot.
- Controller: inputs, debounce, latest-request publication, error retention, reset, refresh, page selection and frozen export filters.
- Presentation: existing shared list scaffold/filter panel/table/cards, labels and workbook columns.

The shared provider and API contract are unchanged. The existing View callback/dialog remains in a legacy adapter with its body unchanged. No inner-page behavior is refactored.

Validation: existing Proforma widget tests cover responsive layouts, filters, pagination, failed and stale loads, export IDs/totals/numeric cells and View. Controller tests cover full user sequences, request races, error retry, export input changes and disposal. Manually check the existing list, filter/reset/refresh/page controls, copy/View and Excel Save As. No need to create an invoice. Live API responses and native file delivery require manual validation.
