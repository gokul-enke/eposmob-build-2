# Customer Transactions List

Owns Party Accounts > Customer Transactions listing only. The legacy route retains its constructor, export override and static keys, and delegates to the feature page.

- Domain: immutable record query, server cache key and original local matching rules.
- Data: InvoiceProvider compatibility repository using request-local responses (`updateState: false`), plus the existing shared validated ledger snapshot helper.
- Controller: input/focus lifecycle, debounce, API/local pagination, cache, latest-request publication, suggestions, reset/refresh and frozen export query.
- Presentation: shared filter panel, autocomplete/date picker, table/cards, labels and workbook.

No shared provider, API contract or ledger parser changes. Existing transaction details remain in a legacy adapter, with their body unchanged. No inner-page behavior changes.

Check manually: amount/name/reference/type/date filters, customer selection followed by typing, Reset after date/local filters, pagination, Refresh, Export, copy and View at desktop/mobile sizes. Native Save As and live backend behavior require manual validation. No transaction creation is needed.

Tests: `flutter test --no-pub test/features/customer_ledger test/screens/transactions/transaction_list_test.dart test/providers/invoice_provider_customer_report_test.dart`. Covers full user sequences, request races, complete snapshot pagination/validation, export independence, filter reset, failures, lifecycle, workbook types and responsive layouts.
