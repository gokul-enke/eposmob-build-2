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

## Step 7: final verification

- Architecture feature tests: 69 passed. Focused feature/caller/localization/toast suite: 91 passed before final boundary/navigation additions; those additions passed in the final module and full suites.
- Final flutter test: 2198 passed, 2 skipped, the same 1 existing standard PDF resolver failure. No new test failures.
- Final flutter analyze: 3669 issues (3263 info, 402 warnings, 4 errors), down from 3680 (3270 info, 406 warnings, 4 errors). The four errors remain solely in tmp/flutter_agp_check. No new warnings/errors in migration files.
- Feature analysis: no errors or warnings; retained legacy withOpacity informational diagnostics only.
- All feature Dart files are under 400 lines; architecture guard tests enforce layer boundaries, no old re-export files and navigation-only sidebar assignments.
- Provider method/getter surface compared against baseline: none missing. All callers updated, including main registration, daily sales closing and shared filter tests.
- git diff --check passed.

### Visual evidence

Captured original and migrated pages in identical Flutter widget-test harnesses.
Each pair is byte-identical at the requested widths; PNG files are retained
locally in TEMP rather than added as application assets.

| Page | 375px SHA-256 prefix | 1280px SHA-256 prefix |
| --- | --- | --- |
| List | 803882d8b867 | c6b8479ce98c |
| Create | 91868012c6fd | 6c12bc3e9875 |
| Details | 7e88f4c19a50 | 0ef3475843a9 |

The original detail header has a 12px right overflow at 375px. It was
reproduced with the original source, preserved in the image comparison and
explicitly recorded in its phone regression test. Fix it in separate UI work.

### Review boundaries

No live expense was created and no production API transaction was submitted.
HTTP contracts were verified with injected fakes, and visuals with Flutter
widget rendering. The primary working checkout and its unrelated pubspec.lock
were preserved. This branch is architecture-only; review/merge is required
before starting the next module or separate UI changes.
