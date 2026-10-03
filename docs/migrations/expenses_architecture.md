# Expenses architecture baseline

Base: 6e5284bb. Architecture-only migration; existing Expenses UI remains.

## Step 0: ownership and callers

- Model: lib/models/expense.dart.
- Shared state/API: lib/providers/expense_provider.dart.
- Pages: expense_list_screen.dart, create_expense_screen.dart, view_expense_screen.dart under lib/screens/transactions/.
- List helper: lib/screens/transactions/widgets/expense_list_responsive.dart. Only the status pill is used by production code.
- External callers: main.dart registers ExpenseProvider; daily_sales_close_list.dart reads the independent breakdown; sidebar_controller.dart owns slots 93 (list), 94 (create), 95 (details); widgets/side_menu.dart opens/highlights Expenses.
- Existing tests: expense_list_screen_test.dart, expense_list_responsive_test.dart, plus expense coverage in transaction_filter_behavior_test.dart, sales_filter_screens_test.dart and transaction_filter_screens_test.dart.

## Verification before migration

- flutter test: 2167 passed, 2 skipped, 1 failed. Existing failure: standard_pdf_layout_contract_test.dart, all six standard themes resolve the active-store address centrally (centered_simplified_tax_invoice/shared address resolver).
- flutter analyze: 3680 issues. Four existing errors in tmp/flutter_agp_check (dot-shorthands and unresolved widget-test import/class).
- Raw output retained in local TEMP: expenses-test-before.log and expenses-analyze-before.log.
- Isolated worktree uses an ignored, empty .env asset for test bundling; no credentials copied.

## Behavior to preserve

- Tenant/store headers, URLs, payload field types and first-page query semantics.
- Complete pagination validation, duplicate/reference/amount checks, latest-request-wins and retained rows on refresh failure.
- Provider filter, selection and notification API; successful create refreshes the list once.
- Daily closing breakdown is independent of the visible expense list.
- Export snapshots every loaded filtered row and flushes pending reference search without extra HTTP.
- Existing layout, labels, responsive cards, buttons and navigation slots.
