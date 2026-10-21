# Customer Transactions List

Owns Party Accounts > Customer Transactions listing and its View details dialog. The legacy route retains its constructor, export override and static keys, and delegates to the feature page.

- Domain: immutable record query, server cache key and original local matching rules.
- Data: InvoiceProvider compatibility repository using request-local responses (`updateState: false`), plus the existing shared validated ledger snapshot helper.
- Controller: input/focus lifecycle, debounce, API/local pagination, cache, latest-request publication, suggestions, reset/refresh and frozen export query.
- Presentation: shared filter panel, autocomplete/date picker, table/cards, labels and workbook.

Details View uses the already loaded `ListTransaction`; it makes no new API request. `CustomerLedgerRowActions` in `presentation/state/` resolves the payment label from the existing master-data provider when View is clicked, then opens the passive `CustomerLedgerDetailsDialog` in `presentation/widgets/`. The legacy row-actions file remains a compatibility export. Field order, raw values and precision, translations, fallback rules, shared dialog layout and close behavior are unchanged. No shared provider, API contract or ledger parser changes.

Check manually: amount/name/reference/type/date filters, customer selection followed by typing, Reset after date/local filters, pagination, Refresh, Export, copy and View at desktop/mobile sizes. Native Save As and live backend behavior require manual validation. No transaction creation is needed.

Tests: `flutter test --no-pub test/features/customer_ledger test/screens/transactions/transaction_list_test.dart test/providers/invoice_provider_customer_report_test.dart`. Covers full user sequences, request races, complete snapshot pagination/validation, export independence, filter reset, failures, lifecycle, workbook types and responsive layouts.

Details regression coverage includes every field, null/empty values, numeric and textual payment methods, missing master-data labels, payment-label snapshot timing, close/reopen on another row, long-comment scrolling, desktop/tablet/phone sizes and English/Arabic/Malayalam labels. All 18 details tests also passed against the original implementation. Temporary before/after visual comparisons matched at 1440x900, 800x900 and 390x800, plus Arabic at 1440x900.

Manual details check: open a Credit and a Debit row, compare name/date/amount/reference/status/payment/comment with the existing data, scroll long content, close using the footer and header, then open another row. List filters, pagination and export retain their existing behavior. Live demo checks after hot restart covered three existing rows (Credit receipt, Debit COGS and Debit invoice), matching the list's names, dates, amounts and references, CARD/N/A payment displays, missing-value fallbacks, both Close buttons and opening another row. No records were changed. Long-content scrolling and narrower layouts were covered by the automated tests.

Existing shared-dialog limitation: `CommonDetailsDialog` sets a minimum height of 480px and a maximum of 85% of the viewport height. At 375x300 these are invalid constraints (P2), reproduced against both the original and refactored details view. This architecture-only change leaves the shared UI unchanged.
