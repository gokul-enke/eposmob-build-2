# Supplier Transactions Report listing architecture

## Scope and baseline

Only Reports → Supplier Transactions Report listing moves. It is different from
the standalone supplier transactions list and the supplier profile Transactions
tab. The 1,034-line legacy listing becomes a feature page, pure report data/query,
request-local source, controller and real frame/header/filter/table/card widgets.

The report details page and all standard/thermal print files remain untouched.
Shared SupplierProvider, models, SupplierRepository and SupplierApi are unchanged.
The API is already injectable and tenant/store-aware; duplicating it or migrating
shared supplier state would broaden this listing-only scope.

Before migration, 82 focused existing report/supplier API tests passed. Three
populated before/after screenshots (375×812, 1280×900 and 1440×900) are byte-identical.
Captures are outside the repository.

## Guide steps within the listing boundary

0. Mapped directory, grouped report API, selection, caller imports and slots 67/68.
1. Extracted pure supplier summary/query/option/page parsing to reports/domain.
2–3. Reused the public supplier repository/API through a local report source;
     preserved shared provider ownership and HTTP contracts.
4. Moved the listing with git mv, extracted request/input state and real widgets.
5. Named report route constants; ReportNavigation owns listing/details entry points.
   Desktop/mobile listing menus updated. Legacy details back buttons are unchanged.
6. Domain, source/API contract, controller and populated page/workflow tests.
7. Updated Reports README and removed the old listing import/path from lib/test.

## Explicit listing corrections

- Opening the report reads a directory snapshot instead of replacing shared
  supplier list state. Profile selection never becomes the report's filter.
- Filter changes and Reset start at page one, rather than reusing a later page
  belonging to the old filter.
- Date-field keys clear internal displayed dates on Reset without changing the
  shared calendar component.
- Request generations ignore older responses and work after disposal.
- Failed reloads and malformed response envelopes retain the previous page and
  surface an existing translated error toast instead of silently clearing rows.

These corrections are local to the listing. Debit/credit/balance parsing,
ID-based grouping, transaction counts, financial precision, dates sent to the
server, permissions and View's supplier selection contract are retained.

## Verification and limits

Focused command:

```powershell
flutter test --no-pub test/features/reports test/report_filter_screens_test.dart test/features/suppliers/data/supplier_api_test.dart
```

98 focused tests pass. Analyzer reports no errors or new warnings in the migrated
report; moved presentation code retains existing style/deprecation info messages.
Tests cover phone/desktop layouts, supplier/date/Reset/paging sequences, View,
request races, failure/retry and disposal. Shared API contract tests remain.

Full-suite run: 2,307 passed, two skipped, two failures. One was the existing
standard_pdf_layout_contract_test.dart active-store address resolver failure.
The other exposed numeric paginator metadata compatibility; that was corrected,
and the final serial focused run passed all 98 tests, including that regression.
The entire full suite was not repeated after the metadata correction.

No live API, stock/supplier mutation or physical printing was exercised. No UI
redesign, commit, push or pull is part of this local task.
