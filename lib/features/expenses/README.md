# features/expenses

Owns expense listing, creation and details, plus the expense breakdown used
by daily sales closing. This migration preserves the existing listing kit,
form/detail appearance, endpoint contracts and provider state behavior.

## Layers

```text
features/expenses/
├── domain/
│   ├── models/expense.dart       Expense parsing, serialization and copies
│   ├── expense_filter.dart      Pure filter and selection rules
│   └── expense_options.dart     Account option extraction and normalization
├── data/
│   ├── expense_api.dart         Injectable GET/POST and TenantSession
│   ├── expense_payloads.dart    Form values to the existing request body
│   └── expense_repository.dart  Request boundary for shared expense state
└── presentation/
    ├── state/                   Provider, list/form controllers, selection
    ├── navigation/              Named routes and reference selection
    ├── export/                  Excel snapshot builder
    ├── pages/                   List, create and view pages
    └── widgets/                 Data and callback-driven list/form/details
```

Expenses has no offline cache. Domain code imports only Dart or other
domain files. Data has no UI/provider lookups; tenant/store values come
from the injected `TenantSession`. Page controllers own their inputs,
focus, debounce and export lifecycle. Providers are captured in page
`initState`; leaf widgets receive values/controllers and callbacks.

## Public surface

- `domain/models/expense.dart`: `Expense`.
- `data/expense_api.dart`: `ExpenseApi`, `ExpenseHttpGet`, `ExpenseHttpPost`
  for injected request dependencies.
- `data/expense_repository.dart`: `ExpenseRepository` for request access.
- `presentation/state/expense_provider.dart`: `ExpenseProvider`, registered
  in `main.dart`. Its existing public methods, getters, option lists,
  selection, filtering and notification behavior are retained. Optional
  constructor repository injection supports tests.
- `presentation/state/expense_view_controller.dart`: `ExpenseViewController`
  is the shared selected reference, populated by navigation.
- `presentation/navigation/expense_navigation.dart`: `ExpenseNavigation`
  opens the list, create form or selected expense details.
- `presentation/pages/`: `ExpenseListPage`, `CreateExpensePage`,
  `ViewExpensePage` are the sidebar entry points.

Other modules must not import leaf widgets or page controllers.

## Sidebar

`SideBarController.expenseListScreenIndex = 93`,
`createExpenseScreenIndex = 94`, `viewExpenseScreenIndex = 95`.
Only `ExpenseNavigation` assigns these sidebar slots. Details selection is
published before changing the slot so the first detail build has the right
reference. The menu uses named constants for highlighting.

## Preserved behavior

- List loading stages all pages and rejects invalid pagination/rows,
  duplicates and incomplete totals. Stale requests stop before continuing
  pagination. Refresh failures keep the previous rows and disable export.
- Filters, local page sizes, labels and amount precision are unchanged.
  Export flushes pending reference search and snapshots every loaded
  filtered row without making an extra API call.
- Creation preserves master-data string IDs and original account-ID types;
  the API adds the active store. Success refreshes once; create-another
  resets the same inputs. Account-restricted payment method behavior stays.
- Daily closing uses its explicit store/date and does not mutate the list.
- Borrowed export controllers remain owned by their caller. Disposed forms
  ignore late async completions and do not refocus or navigate.

## Tests and known baseline

```bash
flutter test test/features/expenses
flutter test test/transaction_filter_behavior_test.dart test/transaction_filter_screens_test.dart test/sales_filter_screens_test.dart
flutter analyze lib/features/expenses test/features/expenses
```

Tests mirror the feature layers. Existing request/provider, layout, export,
copy, filter and navigation tests were retained and split by responsibility.
New tests cover injected API/session contracts, payload types, lifecycle,
create/retry, options, model copies and layer boundaries. The old 880px
responsive helper and its two threshold tests were removed because no
production caller used it; real shared-kit responsive tests remain.

List, create and detail screenshots at 375px and 1280px are byte-identical
before/after. The original detail header overflows by 12px on a 375px
surface; its regression test explicitly records that preserved limitation
for a separate UI fix. See `docs/migrations/expenses_architecture.md` for
repository-wide baseline failures and final verification evidence.
